const std = @import("std");

pub fn Witness(T: type, end: T, start: T) type {
    switch (@typeInfo(T)) {
        .@"enum" => |tenum| {
            const i: usize = @intFromEnum(start);
            const ename = tenum.fields[i].name;
            const stru = @field(T, ename ++ "Msg")(end);
            return struct {
                pub const witness_spec_type = T;
                pub const witness_spec_start = start;
                pub const witness_spec_end = end;
                pub fn getMsg(_: @This()) @TypeOf(stru.genMsg) {
                    if (end == start) @compileError("Can't getMsg");
                    return stru.genMsg;
                }

                pub fn terminal(_: @This()) void {
                    if (end != start) @compileError("Can't terminal");
                    return {};
                }
            };
        },
        else => @compileError("The type not support, it must be enum"),
    }
}

pub const Node = struct {
    name: [:0]const u8,
    id: usize,
};
pub const Edge = struct {
    name: [:0]const u8,
    start: usize,
    end: usize,
};

pub const NodeList = std.ArrayList(Node);
pub const EdgeList = std.ArrayList(Edge);
const Allocator = std.mem.Allocator;

const wstart = "witness_spec_start";

pub fn graph(T: type, nlist: *NodeList, elist: *EdgeList) !void {
    switch (@typeInfo(T)) {
        .@"enum" => |e| {
            inline for (e.fields) |f| {
                const fname = f.name;
                try nlist.append(.{ .name = f.name, .id = f.value });
                const tfun = @field(T, fname ++ "Msg");
                const field = @field(T, fname);
                const vt = tfun(field);
                switch (@typeInfo(vt)) {
                    .@"union" => |u| {
                        inline for (0..u.fields.len) |i| {
                            const t0 = u.fields[i].type;
                            const tname = u.fields[i].name;
                            if (@hasDecl(t0, wstart)) {
                                const RT = @field(t0, wstart);
                                const ii = @intFromEnum(RT);
                                try elist.append(.{ .name = tname, .start = f.value, .end = ii });
                            } else blk: {
                                switch (@typeInfo(t0)) {
                                    .@"struct" => |st1| {
                                        inline for (st1.fields) |fd| {
                                            switch (@typeInfo(fd.type)) {
                                                .@"struct" => {
                                                    if (@hasDecl(fd.type, wstart)) {
                                                        const RT = @field(fd.type, wstart);
                                                        const ii = @intFromEnum(RT);
                                                        try elist.append(.{ .name = tname, .start = f.value, .end = ii });
                                                        break :blk;
                                                    }
                                                },
                                                else => {},
                                            }
                                        }
                                        unreachable;
                                    },
                                    else => unreachable,
                                }
                            }
                        }
                    },
                    .void => {},
                    else => unreachable,
                }
            }
        },
        else => unreachable,
    }

    const dir = std.fs.cwd();

    const file = try dir.createFile("graph_tmp.dot", .{});
    const writer = file.writer();
    try writer.print("digraph G {s}\n", .{"{"});
    for (nlist.items) |it| {
        try writer.print("{d} [label = \"{s}\"];\n", .{ it.id, it.name });
    }
    for (elist.items) |it| {
        try writer.print("{d} -> {d} [label = \"{s}\"];\n", .{ it.start, it.end, it.name });
    }
    try writer.print("{s}", .{"}"});
    file.close();

    // dot -Tpng tmp.dot -o tmp.png
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    const allocator = gpa.allocator();
    const cmd = [_][]const u8{ "dot", "-Tpng", "graph_tmp.dot", "-o", "graph_tmp.png" };
    var cp = std.process.Child.init(&cmd, allocator);
    try cp.spawn();

    const cmd1 = [_][]const u8{ "eog", "graph_tmp.png" };
    var cp1 = std.process.Child.init(&cmd1, allocator);
    try cp1.spawn();
    _ = try cp1.wait();

    try dir.deleteFile("graph_tmp.dot");
    try dir.deleteFile("graph_tmp.png");
}
