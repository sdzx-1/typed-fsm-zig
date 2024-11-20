const std = @import("std");
const typedFsm = @import("typed-fsm");
const Witness = typedFsm.Witness;

pub fn main() !void {
    var k: i64 = 0;
    const k1 = S.ST(.s1){};
    _ = f1(k1, &k);
}

pub const S = enum {
    s1,
    s2,
    s3,
    s0,

    pub fn ST(s: S) type {
        return Witness(S, .s0, s);
    }

    pub fn s1Msg(end: S) type {
        return union(enum) {
            Tos2: Witness(S, end, .s2),

            pub fn getMsg() @This() {
                return .Tos2;
            }
        };
    }

    pub fn s2Msg(end: S) type {
        return union(enum) {
            Tos3: Witness(S, end, .s3),
            Tos2: Witness(S, end, .s2),
            Exit: Witness(S, end, .s0),

            pub fn getMsg() @This() {
                return .Tos3;
            }
        };
    }

    pub fn s3Msg(end: S) type {
        return union(enum) {
            Tos1: Witness(S, end, .s1),
            Exit: Witness(S, end, .s0),

            pub fn getMsg(ref: *i64) @This() {
                if (ref.* > 3000) return .Exit;
                return .Tos1;
            }
        };
    }
    pub fn s0Msg(_: S) type {
        return void;
    }
};

fn f1(comptime val: S.ST(.s1), ref: *i64) void {
    std.debug.print("f1: {d}\n", .{ref.*});
    switch (val.getMsg()()) {
        .Tos2 => |witness| {
            ref.* += 1;
            @call(.always_tail, f2, .{ witness, ref });
        },
    }
}

fn f2(comptime val: S.ST(.s2), ref: *i64) void {
    switch (val.getMsg()()) {
        .Tos3 => |witness| {
            ref.* += 1;
            @call(.always_tail, f3, .{ witness, ref });
        },
        .Tos2 => |witness| {
            ref.* += 1;
            @call(.always_tail, f2, .{ witness, ref });
        },
        .Exit => |witness| witness.terminal(),
    }
}

fn f3(comptime val: S.ST(.s3), ref: *i64) void {
    switch (val.getMsg()(ref)) {
        .Tos1 => |witness| {
            ref.* += 1;
            @call(.always_tail, f1, .{ witness, ref });
        },
        .Exit => |witness| witness.terminal(),
    }
}
