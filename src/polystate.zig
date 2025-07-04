const std = @import("std");
const Adler32 = std.hash.Adler32;
const AVL = @import("avl.zig").AVL;

pub const Exit = union(enum) {};

// FSM       : fn (type) type , Example
// State     : type           , A, B
// FsmState  : type           , Example(A), Example(B)

pub const Mode = enum {
    no_suspendable,
    suspendable,
};

pub const Method = enum {
    next,
    current,
};

// FsmState(State)
// Transition

pub fn FSM(
    comptime name: []const u8,
    mode: Mode,
    context: type,
    // enter_fn args type is State
    enter_fn: ?fn (*context, type) void,
    transition_method: if (mode == .no_suspendable) void else Method,
    state: type,
) type {
    return struct {
        pub const Name = name;
        pub const Mode = mode;
        pub const Context = context;
        pub const EnterFn = enter_fn;
        pub const TransitionMethod = transition_method;
        pub const State = state;
    };
}

pub fn StateMap(max_len: usize) type {
    return struct {
        root: i32 = -1,
        avl: AVL(max_len, struct { type, usize }) = .{}, // the type is State

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
            const State = fsm_state.State;
            const state_hash = Adler32.hash(@typeName(State));
            const Name = fsm_state.Name;
            if (self.avl.search(self.root, state_hash)) |_| {
                return;
            } else {
                const idx = self.avl.len;
                self.root = self.avl.insert(self.root, state_hash, .{ State, idx });
                switch (@typeInfo(State)) {
                    .@"union" => |un| {
                        inline for (un.fields) |field| {
                            const next_fsm_state = field.type;
                            if (fsm_state.Mode != next_fsm_state.Mode) {
                                @compileError("The Modes of the two fsm_states are inconsistent!");
                            }
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

pub fn collect_state(max_len: usize, fsm_state: type) StateMap(max_len) {
    @setEvalBranchQuota(10_000_000);
    var state_map: StateMap(max_len) = .{};
    state_map.collect(fsm_state);
    return state_map;
}

pub fn Runner(max_len: usize, is_inline: bool, fsm_state: type) type {
    const Context = fsm_state.Context;
    const enter_fn = fsm_state.EnterFn;

    return struct {
        pub const state_map = collect_state(max_len, fsm_state);
        pub const StateId = std.math.IntFittingRange(0, state_map.avl.len);
        const RetType = if (fsm_state.Mode == .no_suspendable) void else ?StateId;

        pub fn state_to_id(State: type) StateId {
            const key = comptime Adler32.hash(@typeName(State));
            if (comptime state_map.avl.search(state_map.root, key)) |mdata| {
                const id: StateId = @intCast(mdata.@"1");
                return id;
            } else {
                @compileError(std.fmt.comptimePrint(
                    "Can't find State {s}",
                    .{@typeName(State)},
                ));
            }
        }

        pub fn run_handler(curr_id: StateId, ctx: *Context) RetType {
            @setEvalBranchQuota(10_000_000);
            sw: switch (curr_id) {
                inline 0...state_map.avl.len - 1 => |idx| {
                    // Remove when https://github.com/ziglang/zig/issues/24323 is fixed:
                    {
                        var runtime_false = false;
                        _ = &runtime_false;
                        if (runtime_false) continue :sw 0;
                    }
                    const State = comptime state_map.avl.nodes[idx].data.@"0";
                    if (comptime State == Exit) {
                        if (comptime fsm_state.Mode == .no_suspendable) {
                            return;
                        } else {
                            return null;
                        }
                    }
                    if (enter_fn) |fun| fun(ctx, State);
                    const handler = State.handler;
                    const handle_res =
                        if (is_inline) @call(.always_inline, handler, .{ctx}) else handler(ctx);
                    switch (handle_res) {
                        inline else => |new_fsm_state_wit, tag| {
                            _ = tag;
                            const new_fsm_state = comptime @TypeOf(new_fsm_state_wit);
                            const new_id = comptime state_to_id(new_fsm_state.State);
                            if (comptime new_fsm_state.Mode == .no_suspendable) {
                                continue :sw new_id;
                            } else {
                                switch (new_fsm_state.TransitionMethod) {
                                    inline .next => return new_id,
                                    inline .current => continue :sw new_id,
                                }
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
    mode: Mode,
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
        method: ?Method,
        label: []const u8,
    };

    const Self = @This();

    pub const init: Self = .{
        .name = "",
        .mode = .no_suspendable,
        .node_set = .empty,
        .edge_array_list = .empty,
    };

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
                if (edge.method) |method| {
                    switch (method) {
                        .current => {
                            try writer.writeAll("\"");
                        },
                        .next => {
                            try writer.writeAll("\"  color=\"blue\" ");
                        },
                    }
                } else {
                    try writer.writeAll("\"");
                }

                try writer.writeAll("];\n");
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
        ty: type, //State
    ) u32 {
        return Adler32.hash(@typeName(ty));
    }

    pub fn insert_edge(
        graph: *@This(),
        gpa: std.mem.Allocator,
        from: type, //FsmState
        to: type, //FsmState
        method: ?Method,
        label: []const u8,
    ) !void {
        const from_id: u32 = make_hash(from);
        const to_id: u32 = make_hash(to);
        try graph.edge_array_list.append(
            gpa,
            .{ .from = from_id, .to = to_id, .method = method, .label = label },
        );
    }
    pub fn generate(graph: *@This(), gpa: std.mem.Allocator, fsm_state: type) void {
        graph.name = fsm_state.Name;
        graph.mode = fsm_state.Mode;
        dsp_generate(graph, gpa, fsm_state.State);
    }

    fn dsp_generate(graph: *@This(), gpa: std.mem.Allocator, state: type) void {
        const id: u32 = make_hash(state);
        if (graph.node_set.get(id)) |_| {} else {
            graph.node_set.put(gpa, id, .{
                .name = @typeName(state),
                .id = graph.node_id_counter,
            }) catch unreachable;
            graph.node_id_counter += 1;
            switch (@typeInfo(state)) {
                .@"union" => |un| {
                    inline for (un.fields) |field| {
                        const edge_label = field.name;
                        const NextFsmState = field.type;
                        const NextState = NextFsmState.State;
                        const method_val = if (NextFsmState.Mode == .no_suspendable) null else NextFsmState.TransitionMethod;

                        if (graph.mode == .no_suspendable) {
                            graph.insert_edge(gpa, state, NextState, null, edge_label) catch unreachable;
                        } else {
                            graph.insert_edge(gpa, state, NextState, method_val, edge_label) catch unreachable;
                        }
                        dsp_generate(graph, gpa, NextState);
                    }
                },
                else => @compileError("Only support tagged union!"),
            }
        }
    }
};
