const std = @import("std");
const type1 = @import("type.zig");
const ST = type1.S.ST;

pub fn main() !void {
    var k: i64 = 0;
    const k1 = ST(.s1){};
    _ = f1(k1, &k);
}

fn f1(comptime val: ST(.s1), ref: *i64) void {
    std.debug.print("f1: {d}\n", .{ref.*});
    switch (val.getMsg()()) {
        .Tos2 => |witness| {
            ref.* += 1;
            @call(.always_tail, f2, .{ witness, ref });
        },
    }
}

fn f2(comptime val: ST(.s2), ref: *i64) void {
    switch (val.getMsg()()) {
        .Tos3 => |witness| {
            ref.* += 1;
            @call(.always_tail, f3, .{ witness, ref });
        },
        .Tos2 => |witness| {
            ref.* += 1;
            @call(.always_tail, f2, .{ witness, ref });
        },
    }
}

fn f3(comptime val: ST(.s3), ref: *i64) void {
    switch (val.getMsg()(ref)) {
        .Tos1 => |witness| {
            ref.* += 1;
            @call(.always_tail, f1, .{ witness, ref });
        },
        .Exit => |witness| witness.terminal(),
    }
}
