const std = @import("std");
const Adler32 = std.hash.Adler32;
const AVL = @import("avl.zig").AVL;

pub const Exit = union(enum) {};

// FSM       : fn (type) type , Example
// State     : type           , A, B
// FsmState  : type           , Example(A), Example(B)

pub fn FSM(
    comptime name: []const u8,
    context: type,
    enter_fn: ?fn (*context, type) void,
    state: type,
) type {
    return struct {
        pub const Name = name;
        pub const Context = context;
        pub const EnterFn = enter_fn;
        pub const State = state;
    };
}

pub fn FsmStateMap(max_len: usize) type {
    return struct {
        root: i32 = -1,
        avl: AVL(max_len, struct { type, usize }) = .{},

        fn checkConsistency(comptime b: []const u8, comptime a: []const u8) void {
            if (comptime !std.mem.eql(u8, b, a)) {
                const error_str = std.fmt.comptimePrint(
                    \\The state machine name are inconsistent.
                    \\You used the state of state machine [{s}] in state machine [{s}]."
                , .{ b, a });
                @compileError(error_str);
            }
        }

        pub fn collect(self: *@This(), fsm_state: type) void {
            const fsm_state_hash = Adler32.hash(@typeName(fsm_state));
            const Name = fsm_state.Name;
            if (self.avl.search(self.root, fsm_state_hash)) |_| {
                return;
            } else {
                const idx = self.avl.len;
                self.root = self.avl.insert(self.root, fsm_state_hash, .{ fsm_state, idx });
                switch (@typeInfo(fsm_state.State)) {
                    .@"union" => |un| {
                        inline for (un.fields) |field| {
                            const next_fsm_state = field.type;
                            const NewName = next_fsm_state.Name;
                            checkConsistency(NewName, Name);
                            self.collect(next_fsm_state);
                        }
                    },
                    else => @compileError("Only support tagged union!"),
                }
            }
        }
    };
}

pub fn collect_fsm_state(max_len: usize, fsm_state: type) FsmStateMap(max_len) {
    @setEvalBranchQuota(10_000_000);
    var fsmap: FsmStateMap(max_len) = .{};
    fsmap.collect(fsm_state);
    return fsmap;
}

pub fn NextState(state: type) type {
    const State = state;
    return union(enum) {
        no_trasition: void,
        next: State,
        current: State,
    };
}

pub fn Runner(max_len: usize, is_inline: bool, fsm_state: type) type {
    const Context = fsm_state.Context;
    const fsm_state_map = collect_fsm_state(max_len, fsm_state);

    return struct {
        pub const StateId = std.math.IntFittingRange(0, fsm_state_map.avl.len);

        pub fn fsm_state_to_state_id(FsmState: type) StateId {
            const key = comptime Adler32.hash(@typeName(FsmState));
            if (fsm_state_map.avl.search(fsm_state_map.root, key)) |mdata| {
                const id: StateId = @intCast(mdata.@"1");
                return id;
            } else {
                const str = std.fmt.comptimePrint("Can't find type {s}", .{@typeName(FsmState)});
                @compileError(str);
            }
        }

        pub fn run_handler(curr_id: StateId, ctx: *Context) void {
            sw: switch (curr_id) {
                inline 0...fsm_state_map.avl.len - 1 => |idx| {
                    const State = fsm_state_map.avl.nodes[idx].data.@"0".State;
                    if (State == Exit) return;
                    const handler = State.handler;
                    const handle_res =
                        if (is_inline) @call(.always_inline, handler, .{ctx}) else handler(ctx);
                    switch (handle_res) {
                        inline else => |new_fsm_state_wit, tag| {
                            _ = tag;
                            const new_idx = fsm_state_to_state_id(@TypeOf(new_fsm_state_wit));
                            continue :sw @as(StateId, @intCast(new_idx));
                        },
                    }
                },
                else => unreachable,
            }
        }

        pub fn run_conthandler(curr_id: StateId, ctx: *Context) ?StateId {
            sw: switch (curr_id) {
                inline 0...fsm_state_map.avl.len - 1 => |idx| {
                    const State = fsm_state_map.avl.nodes[idx].data.@"0".State;
                    if (State == Exit) return null;
                    const conthandler = State.conthandler;
                    const cont_handle_res =
                        if (is_inline) @call(.always_inline, conthandler, .{ctx}) else conthandler(ctx);
                    switch (cont_handle_res) {
                        inline .no_trasition => return idx,
                        inline .next => |wit0| {
                            switch (wit0) {
                                inline else => |new_fsm_state_wit, tag| {
                                    _ = tag;
                                    const new_idx = fsm_state_to_state_id(@TypeOf(new_fsm_state_wit));
                                    return @as(StateId, @intCast(new_idx));
                                },
                            }
                        },
                        inline .current => |wit0| {
                            switch (wit0) {
                                inline else => |new_fsm_state_wit, tag| {
                                    _ = tag;
                                    const new_idx = fsm_state_to_state_id(@TypeOf(new_fsm_state_wit));
                                    continue :sw @as(StateId, @intCast(new_idx));
                                },
                            }
                        },
                    }
                },
                else => unreachable,
            }
        }
    };
}

pub const Graph = struct {
    name: []const u8,
    node_set: std.AutoArrayHashMapUnmanaged(u32, Node),
    edge_array_list: std.ArrayListUnmanaged(Edge),
    node_id_counter: u32 = 0,

    pub const Node = struct {
        name: []const u8,
        id: u32,
    };

    pub const Edge = struct {
        from: u32,
        to: u32,
        label: []const u8,
    };

    const Self = @This();

    pub const init: Self = .{ .name = "", .node_set = .empty, .edge_array_list = .empty };

    pub fn format(
        val: @This(),
        comptime _: []const u8,
        options: std.fmt.FormatOptions,
        writer: anytype,
    ) !void {
        try writer.writeAll("digraph fsm_state_graph {\n");

        { //state graph
            try writer.writeAll("subgraph cluster_");
            try writer.writeAll(val.name);
            try writer.writeAll(" {\n");

            try writer.writeAll("label = \"");
            try writer.writeAll(val.name);
            try writer.writeAll(
                \\_state_graph";
                \\ labelloc = "t";
                \\ labeljust = "c";
                \\
            );

            var node_set_iter = val.node_set.iterator();
            while (node_set_iter.next()) |entry| {
                try std.fmt.formatIntValue(entry.key_ptr.*, "d", options, writer);
                try writer.writeAll(" [label = \"");
                try std.fmt.formatIntValue(entry.value_ptr.id, "d", options, writer);
                try writer.writeAll("\"];\n");
            }
            for (val.edge_array_list.items) |edge| {
                try std.fmt.formatIntValue(edge.from, "d", options, writer);
                try writer.writeAll(" -> ");
                try std.fmt.formatIntValue(edge.to, "d", options, writer);
                try writer.writeAll(" [label = \"");
                try writer.writeAll(edge.label);
                try writer.writeAll("\"];\n");
            }

            try writer.writeAll("}\n");
        }

        { //all_state

            try writer.writeAll("subgraph cluster_");
            try writer.writeAll(val.name);
            try writer.writeAll("_state {\n");

            try writer.writeAll("label = \"");
            try writer.writeAll(val.name);
            try writer.writeAll(
                \\_state";
                \\ labelloc = "t";
                \\ labeljust = "c";
                \\
            );

            try writer.writeAll("all_node [shape=plaintext, label=<\n");
            try writer.writeAll("<TABLE BORDER=\"0\" CELLBORDER=\"1\" CELLSPACING=\"0\">\n");

            const nodes = val.node_set.values();

            for (nodes) |node| {
                try writer.writeAll("<TR>");
                try writer.writeAll("<TD ALIGN=\"LEFT\">");
                try std.fmt.formatIntValue(node.id, "d", options, writer);
                try writer.writeAll(" -- ");
                try writer.writeAll(node.name);
                try writer.writeAll("</TD>");
                try writer.writeAll("</TR>\n");
            }

            try writer.writeAll("</TABLE>\n");
            try writer.writeAll(">]\n");

            try writer.writeAll("}\n");
        }

        try writer.writeAll("}\n");
    }

    pub fn deinit(self: *Self, gpa: std.mem.Allocator) !void {
        self.node_set.deinit(gpa);
        self.edge_array_list.deinit(gpa);
    }

    fn make_hash(
        ty: type, //FsmState
    ) u32 {
        return Adler32.hash(ty.Name ++ "-" ++ @typeName(ty.State));
    }

    pub fn insert_edge(
        graph: *@This(),
        gpa: std.mem.Allocator,
        from: type, //FsmState
        to: type, //FsmState
        label: []const u8,
    ) !void {
        const from_id: u32 = make_hash(from);
        const to_id: u32 = make_hash(to);
        try graph.edge_array_list.append(gpa, .{ .from = from_id, .to = to_id, .label = label });
    }
    pub fn generate(graph: *@This(), gpa: std.mem.Allocator, Wit: type) void {
        graph.name = Wit.Name;
        dsp_generate(graph, gpa, Wit);
    }

    fn dsp_generate(graph: *@This(), gpa: std.mem.Allocator, Wit: type) void {
        const id: u32 = make_hash(Wit);
        if (graph.node_set.get(id)) |_| {} else {
            graph.node_set.put(gpa, id, .{
                .name = @typeName(Wit.State),
                .id = graph.node_id_counter,
            }) catch unreachable;
            graph.node_id_counter += 1;
            switch (@typeInfo(Wit.State)) {
                .@"union" => |un| {
                    inline for (un.fields) |field| {
                        const edge_label = field.name;
                        const NextWit = field.type;
                        graph.insert_edge(gpa, Wit, NextWit, edge_label) catch unreachable;
                        dsp_generate(graph, gpa, NextWit);
                    }
                },
                else => @compileError("Only support tagged union!"),
            }
        }
    }
};
