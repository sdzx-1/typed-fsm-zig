const std = @import("std");
const Adler32 = std.hash.Adler32;

pub const Exit = union(enum) {};

// FSM       : fn (type) type , Example
// State     : type           , A, B
// FSMState  : type           , Example(A), Example(B)

pub fn FSM(
    comptime name: []const u8,
    context: type,
    enter_fn: ?fn (*context, type) void,
    state: type,
) type {
    if (state == Exit) {
        return struct {
            pub const Name = name;
            pub const Context = context;
            pub const EnterFn = enter_fn;
            pub const State = state;

            pub inline fn handler(_: *Context) void {}

            pub fn conthandler(_: *Context) ContResult(Context) {
                return .exit;
            }
        };
    } else {
        return struct {
            pub const Name = name;
            pub const Context = context;
            pub const EnterFn = enter_fn;
            pub const State = state;

            pub fn handler_normal(ctx: *Context) void {
                if (enter_fn) |fun| fun(ctx, State);
                switch (State.handler(ctx)) {
                    inline else => |wit, tag| {
                        _ = tag;
                        const FSMState = @TypeOf(wit);
                        checkConsistency(FSMState.Name, Name);
                        @call(.auto, FSMState.handler, .{ctx});
                    },
                }
            }

            pub fn handler(ctx: *Context) void {
                if (enter_fn) |fun| fun(ctx, State);
                switch (State.handler(ctx)) {
                    inline else => |wit, tag| {
                        _ = tag;
                        const FSMState = @TypeOf(wit);
                        checkConsistency(FSMState.Name, Name);
                        @call(.always_tail, FSMState.handler, .{ctx});
                    },
                }
            }

            pub fn conthandler(ctx: *Context) ContResult(Context) {
                if (enter_fn) |fun| fun(ctx, State);
                const contFun: fn (*Context) NextState(State) = State.conthandler;
                switch (contFun(ctx)) {
                    inline .no_trasition => return .no_trasition,
                    inline .next => |wit0| {
                        switch (wit0) {
                            inline else => |wit, tag| {
                                _ = tag;
                                const FSMState = @TypeOf(wit);
                                checkConsistency(FSMState.Name, Name);
                                return .{ .next = FSMState.conthandler };
                            },
                        }
                    },
                    inline .current => |wit0| {
                        switch (wit0) {
                            inline else => |wit, tag| {
                                _ = tag;
                                const FSMState = @TypeOf(wit);
                                checkConsistency(FSMState.Name, Name);
                                return .{ .current = FSMState.conthandler };
                            },
                        }
                    },
                }
            }
        };
    }
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

pub fn ContResult(context: type) type {
    const Context = context;
    return union(enum) {
        exit: void,
        no_trasition: void,
        next: *const fn (*Context) ContResult(Context),
        current: *const fn (*Context) ContResult(Context),
    };
}

pub fn NextState(state: type) type {
    const State = state;
    return union(enum) {
        no_trasition: void,
        next: State,
        current: State,
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
        ty: type, //FSMState
    ) u32 {
        return Adler32.hash(ty.Name ++ "-" ++ @typeName(ty.State));
    }

    pub fn insert_edge(
        graph: *@This(),
        gpa: std.mem.Allocator,
        from: type, //FSMState
        to: type, //FSMState
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
