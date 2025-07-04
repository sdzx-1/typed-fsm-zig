const std = @import("std");
const Adler32 = std.hash.Adler32;
const AVL = @import("avl.zig").AVL;

pub const Exit = union(enum) {};

// FSM       : fn (type) type , Example
// State     : type           , A, B
// FsmState  : type           , Example(A), Example(B)

pub const Mode = enum {
    not_suspendable,
    suspendable,
};

pub const Method = enum {
    next,
    current,
};

// FsmState(State)
// Transition

pub fn FSM(
    comptime name_: []const u8,
    comptime mode_: Mode,
    comptime Context_: type,
    // enter_fn args type is State
    comptime enter_fn_: ?fn (*Context_, type) void,
    comptime transition_method_: if (mode_ == .not_suspendable) void else Method,
    comptime State_: type,
) type {
    return struct {
        pub const name = name_;
        pub const mode = mode_;
        pub const Context = Context_;
        pub const enter_fn = enter_fn_;
        pub const transition_method: Method = if (mode_ == .not_suspendable) .current else transition_method_;
        pub const State = State_;
    };
}

pub fn StateMap(comptime max_len: usize) type {
    return struct {
        root: i32 = -1,
        avl: AVL(max_len, struct { type, usize }) = .{}, // the type is State
        StateId: type,

        const Self = @This();

        pub fn init(comptime FsmState: type) Self {
            comptime {
                var res: Self = .{
                    .root = -1,
                    .avl = .{},
                    .StateId = undefined,
                };

                res.collect(FsmState);

                const state_count = res.avl.len;

                res.StateId = @Type(.{
                    .@"enum" = .{
                        .tag_type = std.math.IntFittingRange(0, state_count - 1),
                        .fields = inner: {
                            var fields: [state_count]std.builtin.Type.EnumField = undefined;

                            for (&fields, res.avl.nodes[0..state_count]) |*field, node| {
                                const State, const state_int = node.data;

                                field.* = .{
                                    .name = @typeName(State),
                                    .value = state_int,
                                };
                            }

                            const fields_const = fields;
                            break :inner &fields_const;
                        },
                        .decls = &.{},
                        .is_exhaustive = true,
                    },
                });

                return res;
            }
        }

        pub fn StateFromId(comptime self: *const Self, comptime state_id: self.StateId) type {
            return self.avl.nodes[@intFromEnum(state_id)].data[0];
        }

        pub fn idFromState(comptime self: *const Self, comptime State: type) self.StateId {
            return @field(self.StateId, @typeName(State));
        }

        fn checkConsistency(comptime b: []const u8, comptime a: []const u8) void {
            if (comptime !std.mem.eql(u8, b, a)) {
                const error_str = std.fmt.comptimePrint(
                    \\The state machine name are inconsistent.
                    \\You used the state of state machine [{s}] in state machine [{s}]."
                , .{ b, a });
                @compileError(error_str);
            }
        }

        fn collect(comptime self: *Self, comptime FsmState: type) void {
            const State = FsmState.State;
            const state_hash = Adler32.hash(@typeName(State));
            const name = FsmState.name;
            if (self.avl.search(self.root, state_hash)) |_| {
                return;
            } else {
                const idx = self.avl.len;
                self.root = self.avl.insert(self.root, state_hash, .{ State, idx });
                switch (@typeInfo(State)) {
                    .@"union" => |un| {
                        inline for (un.fields) |field| {
                            const NextFsmState = field.type;
                            if (FsmState.mode != NextFsmState.mode) {
                                @compileError("The Modes of the two fsm_states are inconsistent!");
                            }
                            const new_name = NextFsmState.name;
                            checkConsistency(new_name, name);
                            self.collect(NextFsmState);
                        }
                    },
                    else => @compileError("Only support tagged union!"),
                }
            }
        }
    };
}

pub fn Runner(
    comptime max_len: usize,
    comptime is_inline: bool,
    comptime FsmState: type,
) type {
    return struct {
        pub const Context = FsmState.Context;
        pub const state_map: StateMap(max_len) = .init(FsmState);
        pub const StateId = state_map.StateId;
        pub const RetType =
            switch (FsmState.mode) {
                .suspendable => ?StateId,
                .not_suspendable => void,
            };

        pub fn idFromState(comptime State: type) StateId {
            return state_map.idFromState(State);
        }

        pub fn StateFromId(comptime state_id: StateId) type {
            return state_map.StateFromId(state_id);
        }

        pub fn runHandler(curr_id: StateId, ctx: *Context) RetType {
            @setEvalBranchQuota(10_000_000);
            sw: switch (curr_id) {
                inline else => |state_id| {
                    // Remove when https://github.com/ziglang/zig/issues/24323 is fixed:
                    {
                        var runtime_false = false;
                        _ = &runtime_false;
                        if (runtime_false) continue :sw @enumFromInt(0);
                    }

                    const State = StateFromId(state_id);

                    if (State == Exit) {
                        return switch (FsmState.mode) {
                            .suspendable => null,
                            .not_suspendable => {},
                        };
                    }

                    if (FsmState.enter_fn) |fun| fun(ctx, State);

                    const handle_res = @call(
                        if (is_inline) .always_inline else .auto,
                        State.handler,
                        .{ctx},
                    );
                    switch (handle_res) {
                        inline else => |new_fsm_state_wit| {
                            const NewFsmState = @TypeOf(new_fsm_state_wit);
                            const new_id = comptime idFromState(NewFsmState.State);

                            switch (NewFsmState.transition_method) {
                                .next => return new_id,
                                .current => continue :sw new_id,
                            }
                        },
                    }
                },
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
        .mode = .not_suspendable,
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

    fn makeHash(
        Ty: type, //State
    ) u32 {
        return Adler32.hash(@typeName(Ty));
    }

    pub fn insertEdge(
        graph: *@This(),
        gpa: std.mem.Allocator,
        From: type, //FsmState
        To: type, //FsmState
        method: ?Method,
        label: []const u8,
    ) !void {
        const from_id: u32 = makeHash(From);
        const to_id: u32 = makeHash(To);
        try graph.edge_array_list.append(
            gpa,
            .{ .from = from_id, .to = to_id, .method = method, .label = label },
        );
    }
    pub fn generate(graph: *@This(), gpa: std.mem.Allocator, FsmState: type) void {
        graph.name = FsmState.name;
        graph.mode = FsmState.mode;
        dspGenerate(graph, gpa, FsmState.State);
    }

    fn dspGenerate(graph: *@This(), gpa: std.mem.Allocator, State: type) void {
        const id: u32 = makeHash(State);
        if (graph.node_set.get(id)) |_| {} else {
            graph.node_set.put(gpa, id, .{
                .name = @typeName(State),
                .id = graph.node_id_counter,
            }) catch unreachable;
            graph.node_id_counter += 1;
            switch (@typeInfo(State)) {
                .@"union" => |un| {
                    inline for (un.fields) |field| {
                        const edge_label = field.name;
                        const NextFsmState = field.type;
                        const NextState = NextFsmState.State;
                        const method_val = if (NextFsmState.mode == .not_suspendable) null else NextFsmState.transition_method;

                        if (graph.mode == .not_suspendable) {
                            graph.insertEdge(gpa, State, NextState, null, edge_label) catch unreachable;
                        } else {
                            graph.insertEdge(gpa, State, NextState, method_val, edge_label) catch unreachable;
                        }
                        dspGenerate(graph, gpa, NextState);
                    }
                },
                else => @compileError("Only support tagged union!"),
            }
        }
    }
};
