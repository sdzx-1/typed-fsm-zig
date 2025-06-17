///Defines a generic **recursive sum type** (tagged union) called `sdzx` that represents either:
///1. A terminal value (`Term`) of some enum type `TYPE`, or
///2. A function application (`Fun`) with:
///  - A function symbol (also of type `TYPE`)
///  - Arguments (a slice of recursive `sdzx(TYPE)` values)
pub fn sdzx(TYPE: type) type {
    comptime {
        switch (@typeInfo(TYPE)) {
            .@"enum" => {},
            else => @compileError(std.fmt.comptimePrint("Unspport type: {any}, Only support enum!", .{TYPE})),
        }
    }

    return union(enum) {
        Term: TYPE,
        Fun: struct { fun: TYPE, args: []const sdzx(TYPE) },

        pub fn V(term: TYPE) sdzx(TYPE) {
            return .{ .Term = term };
        }

        pub fn C(fun: TYPE, args: []const sdzx(TYPE)) sdzx(TYPE) {
            return .{ .Fun = .{ .fun = fun, .args = args } };
        }

        pub fn format(
            val: @This(),
            comptime fmt: []const u8,
            options: std.fmt.FormatOptions,
            writer: anytype,
        ) !void {
            switch (val) {
                .Term => |va| {
                    try writer.writeAll(@tagName(va));
                },
                .Fun => |v| {
                    try writer.writeAll(@tagName(v.fun));
                    try writer.writeAll("(");
                    for (v.args, 0..) |arg, i| {
                        if (i != 0) try writer.writeAll(", ");
                        try format(arg, fmt, options, writer);
                    }
                    try writer.writeAll(")");
                },
            }
        }
    };
}

///The `Witness` function is a **generic type constructor** that generates a **state witness type**
///based on a given state machine state value (`sdzx(T)`). This witness type encapsulates:
pub fn Witness(
    FST: type, //FSM Type
    GST: type, //Global State Type
    enter_fn: ?fn (sdzx(FST), *GST) void,
    val: sdzx(FST),
) type {
    return struct {
        pub const CST = sdzx_to_cst(FST, val);
        pub const WitnessCurrentState: sdzx(FST) = val;

        pub inline fn conthandler(_: @This()) *const fn (*GST) ContR(GST) {
            const tmp = struct {
                pub fn fun(gst: *GST) ContR(GST) {
                    if (enter_fn) |ef| ef(val, gst);
                    return CST.conthandler(gst);
                }
            };
            return &tmp.fun;
        }

        pub inline fn handler_normal(_: @This(), gst: *GST) void {
            if (enter_fn) |ef| ef(val, gst);
            return @call(.auto, CST.handler, .{gst});
        }

        pub inline fn handler(_: @This(), gst: *GST) void {
            if (enter_fn) |ef| ef(val, gst);
            return @call(.always_tail, CST.handler, .{gst});
        }
    };
}

/// Defines a continuation result type for state machine handlers
///
/// This type represents the possible outcomes when executing a state handler in a
/// continuation-passing style (CPS) state machine. It allows handlers to:
/// 1. Terminate cycle (Exit)
/// 2. Wait for external input (Wait)
/// 3. Continue to the next cycle (Next)
/// 4. Continue to the current cycle (Curr)
pub fn ContR(GST: type) type {
    return union(enum) {
        Exit: void,
        Wait: void,
        Next: *const fn (*GST) ContR(GST),
        Curr: *const fn (*GST) ContR(GST),
    };
}

/// Converts a symbolic expression (sdzx) to its corresponding state type (cST)
///
/// This function performs a compile-time transformation from a symbolic state representation
/// to the actual state machine type. It handles both terminal states (Term) and function
/// states (Fun) with arguments.
///
pub fn sdzx_to_cst(T: type, val: sdzx(T)) type {
    switch (val) {
        .Term => |current_st| return @field(T, @tagName(current_st) ++ "ST"),
        .Fun => |fun_stru| {
            const cSTFun = @field(T, @tagName(fun_stru.fun) ++ "ST");
            const args = fun_stru.args;
            const args_tuple = sliceToTuple(sdzx(T), args){};
            const cST = @call(.auto, cSTFun, args_tuple);
            return cST;
        },
    }
}

///Converts a tuple into a recursive `sdzx(TYPE)` structure.
pub fn val_to_sdzx(TYPE: type, comptime val: anytype) sdzx(TYPE) {
    if (@TypeOf(val) == TYPE) return .{ .Term = val };
    const args_type_info = @typeInfo(@TypeOf(val));
    switch (args_type_info) {
        .@"struct" => {},
        .enum_literal => @compileError(std.fmt.comptimePrint("Expect type: {}, actual type: enum_literal", .{TYPE})),
        else => @compileError("Need struct!"),
    }

    const fields = args_type_info.@"struct".fields;

    var fun: TYPE = undefined;
    var args: [fields.len - 1]sdzx(TYPE) = undefined;

    for (fields, 0..) |field, i| {
        const ptr: *const field.type = @ptrCast(@alignCast(field.default_value_ptr.?));

        if (i == 0) {
            if (field.type != TYPE)
                @compileError(std.fmt.comptimePrint("Expect type: {}, actual type: {}", .{ TYPE, field.type }));
            fun = ptr.*;
        } else {
            args[i - 1] = val_to_sdzx(TYPE, ptr.*);
        }
    }

    // Need const to return address
    const tmp_args: [fields.len - 1]sdzx(TYPE) = comptime args;

    return .{ .Fun = .{ .fun = fun, .args = &tmp_args } };
}
///Converts a slice of values into a Zig tuple type.
fn sliceToTuple(T: type, comptime args: []const T) type {
    var fields: [args.len]std.builtin.Type.StructField = undefined;
    for (args, 0..) |arg, i| {
        _ = arg;
        fields[i] = .{
            .name = std.fmt.comptimePrint("{d}", .{i}),
            .type = T,
            .default_value_ptr = &args[i],
            .is_comptime = true,
            .alignment = @alignOf(T),
        };
    }

    const tuple: std.builtin.Type.Struct = .{
        .layout = .auto,
        .backing_integer = null,
        .fields = &fields,
        .decls = &.{},
        .is_tuple = true,
    };
    return @Type(.{ .@"struct" = tuple });
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
        var node_set_iter = self.node_set.iterator();
        while (node_set_iter.next()) |entry| {
            gpa.free(entry.value_ptr.*);
        }
        self.node_set.deinit(gpa);

        self.edge_array_list.deinit(gpa);
    }

    pub fn insert_edge(
        graph: *@This(),
        gpa: std.mem.Allocator,
        T: type,
        from: sdzx(T),
        to: sdzx(T),
        label: []const u8,
    ) !void {
        const from_str = try std.fmt.allocPrint(gpa, "{}", .{from});
        const from_id: u32 = Adler32.hash(from_str);
        gpa.free(from_str);

        const to_str = try std.fmt.allocPrint(gpa, "{}", .{to});
        const to_id: u32 = Adler32.hash(to_str);
        gpa.free(to_str);

        try graph.edge_array_list.append(gpa, .{ .from = from_id, .to = to_id, .label = label });
    }

    ///The `generate` function constructs a state transition graph for a given enum type `T` by analyzing its associated state types (following the `<Tag>ST` naming convention). It builds the graph by:
    ///
    ///1. Discovering all valid state transitions
    ///2. Processing each enum variant's associated state type
    ///3. Delegating graph construction to `dsp_search` for complex state types
    pub fn generate(graph: *@This(), gpa: std.mem.Allocator, T: type) !void {
        const SDZX = sdzx(T);
        const T_info = @typeInfo(T);
        switch (T_info) {
            .@"enum" => {},
            else => @compileError("Need enum!"),
        }
        const fields = T_info.@"enum".fields;

        inline for (fields) |enum_field| {
            const cST_name = enum_field.name ++ "ST";
            if (@hasDecl(T, cST_name)) {
                const cST = @field(T, cST_name);
                const tag: T = @enumFromInt(enum_field.value);

                const from: SDZX = SDZX.V(tag);

                const m_union: ?type =
                    blk: switch (@typeInfo(@TypeOf(cST))) {
                        .type => {
                            break :blk cST;
                        },
                        .@"fn" => break :blk null,
                        else => @compileError("Unsupport!"),
                    };
                if (m_union) |un| {
                    dsp_search(gpa, T, from, un, graph);
                }
            }
        }
    }

    ///Recursively builds a directed graph representation of a state machine by analyzing state transitions through compile-time type introspection.
    fn dsp_search(gpa: std.mem.Allocator, T: type, from: sdzx(T), cST: type, graph: *Graph) void {
        const from_str = std.fmt.allocPrint(gpa, "{}", .{from}) catch unreachable;
        const id: u32 = Adler32.hash(from_str);
        if (graph.node_set.get(id)) |_| {
            gpa.free(from_str);
        } else {
            graph.node_set.put(gpa, id, from_str) catch unreachable;
            switch (@typeInfo(cST)) {
                .@"union" => |un| {
                    inline for (un.fields) |field| {
                        const edge_label = field.name;
                        const wit = field.type;
                        if (@hasDecl(wit, "WitnessCurrentState")) {
                            const ToST: sdzx(T) = wit.WitnessCurrentState;
                            graph.insert_edge(gpa, T, from, ToST, edge_label) catch unreachable;
                            dsp_search(gpa, T, ToST, wit.CST, graph);
                        } else blk: {
                            inline for (@typeInfo(wit).@"struct".fields) |wit_field| {
                                if (@hasDecl(wit_field.type, "WitnessCurrentState")) {
                                    const wit_wit = wit_field.type;
                                    const ToST: sdzx(T) = wit_wit.WitnessCurrentState;
                                    graph.insert_edge(gpa, T, from, ToST, edge_label) catch unreachable;
                                    dsp_search(gpa, T, ToST, wit_wit.CST, graph);
                                    break :blk;
                                }
                            }
                            @compileError("Need Witness field!");
                        }
                    }
                },
                else => @compileError("Not support!"),
            }
        }
    }
};

const std = @import("std");
const Adler32 = std.hash.Adler32;
