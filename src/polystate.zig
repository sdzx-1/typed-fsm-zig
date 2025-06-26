const std = @import("std");
const Adler32 = std.hash.Adler32;

pub const Exit = union(enum) {};

pub fn Witness(Context: type, enter_fn: ?fn (*Context, type, type) void, Current: type) type {
    if (Current == Exit) {
        return struct {
            pub const CST = Current;
            pub inline fn handler(_: *Context) void {}

            pub fn conthandler(_: *Context) ContResult(Context) {
                return .Exit;
            }
        };
    } else {
        return struct {
            pub const CST = Current;

            pub fn handler_normal(ctx: *Context) void {
                switch (Current.handler(ctx)) {
                    inline else => |wit, tag| {
                        _ = tag;
                        if (enter_fn) |fun| fun(ctx, Current, @TypeOf(wit).CST);
                        @call(.auto, @TypeOf(wit).handler, .{ctx});
                    },
                }
            }

            pub fn handler(ctx: *Context) void {
                switch (Current.handler(ctx)) {
                    inline else => |wit, tag| {
                        _ = tag;
                        if (enter_fn) |fun| fun(ctx, Current, @TypeOf(wit).CST);
                        @call(.always_tail, @TypeOf(wit).handler, .{ctx});
                    },
                }
            }

            pub fn conthandler(ctx: *Context) ContResult(Context) {
                const contFun: fn (*Context) NextState(Current) = Current.conthandler;
                switch (contFun(ctx)) {
                    inline .Exit => return .Exit,
                    inline .NoTrasition => return .NoTrasition,
                    inline .Next => |wit0| {
                        switch (wit0) {
                            inline else => |wit, tag| {
                                _ = tag;
                                if (enter_fn) |fun| fun(ctx, Current, @TypeOf(wit).CST);
                                return .{ .Next = @TypeOf(wit).conthandler };
                            },
                        }
                    },
                    inline .Current => |wit0| {
                        switch (wit0) {
                            inline else => |wit, tag| {
                                _ = tag;
                                if (enter_fn) |fun| fun(ctx, Current, @TypeOf(wit).CST);
                                return .{ .Current = @TypeOf(wit).conthandler };
                            },
                        }
                    },
                }
            }
        };
    }
}

pub fn ContResult(Context: type) type {
    return union(enum) {
        Exit: void,
        NoTrasition: void,
        Next: *const fn (*Context) ContResult(Context),
        Current: *const fn (*Context) ContResult(Context),
    };
}

pub fn NextState(State: type) type {
    return union(enum) {
        Exit: void,
        NoTrasition: void,
        Next: State,
        Current: State,
    };
}

pub const Graph = struct {
    node_set: std.AutoHashMapUnmanaged(u32, []const u8),
    edge_array_list: std.ArrayListUnmanaged(Edge),

    pub const Edge = struct {
        from: u32,
        to: u32,
        label: []const u8,
    };

    const Self = @This();

    pub const init: Self = .{ .node_set = .empty, .edge_array_list = .empty };

    pub fn format(
        val: @This(),
        comptime _: []const u8,
        options: std.fmt.FormatOptions,
        writer: anytype,
    ) !void {
        try writer.writeAll("digraph G {\n");
        var node_set_iter = val.node_set.iterator();
        while (node_set_iter.next()) |entry| {
            try std.fmt.formatIntValue(entry.key_ptr.*, "d", options, writer);
            try writer.writeAll(" [label = \"");
            try writer.writeAll(entry.value_ptr.*);
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

    pub fn deinit(self: *Self, gpa: std.mem.Allocator) !void {
        self.node_set.deinit(gpa);
        self.edge_array_list.deinit(gpa);
    }

    pub fn insert_edge(
        graph: *@This(),
        gpa: std.mem.Allocator,
        from: type,
        to: type,
        label: []const u8,
    ) !void {
        const from_id: u32 = Adler32.hash(@typeName(from));
        const to_id: u32 = Adler32.hash(@typeName(to));
        try graph.edge_array_list.append(gpa, .{ .from = from_id, .to = to_id, .label = label });
    }

    pub fn generate(graph: *@This(), gpa: std.mem.Allocator, Wit: type) !void {
        const exit_str = @typeName(Exit);
        const id: u32 = Adler32.hash(exit_str);
        try graph.node_set.put(gpa, id, exit_str);
        dsp_generate(graph, gpa, Wit);
    }

    fn dsp_generate(graph: *@This(), gpa: std.mem.Allocator, Wit: type) void {
        const Current = Wit.CST;
        const from_str = @typeName(Current);
        const id: u32 = Adler32.hash(from_str);
        if (graph.node_set.get(id)) |_| {} else {
            graph.node_set.put(gpa, id, from_str) catch unreachable;
            switch (@typeInfo(Current)) {
                .@"union" => |un| {
                    inline for (un.fields) |field| {
                        const edge_label = field.name;
                        const NextWit = field.type;
                        graph.insert_edge(gpa, Current, NextWit.CST, edge_label) catch unreachable;
                        dsp_generate(graph, gpa, NextWit);
                    }
                },
                else => @compileError("Only support tagged union!"),
            }
        }
    }
};
