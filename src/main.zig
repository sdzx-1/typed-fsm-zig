const std = @import("std");

pub fn main() !void {
    var k: i64 = 0;
    _ = f1(k1, &k);
}

const S = enum {
    s0,
    s1,
    s2,
    s3,
    pub fn MT(s: S, b: S) type {
        return switch (s) {
            .s0 => unreachable,
            .s1 => Msgs1(b),
            .s2 => Msgs2(b),
            .s3 => Msgs3(b),
        };
    }
};

pub fn Msgs1(end: S) type {
    return union(enum) {
        s1Tos2: ST(S, .s2, end),

        pub fn getMsg() @This() {
            return .{ .s1Tos2 = .{} };
        }
    };
}

pub fn Msgs2(end: S) type {
    return union(enum) {
        s2Tos3: ST(S, .s3, end),
        s2Tos2: ST(S, .s2, end),
        s2Tos0: ST(S, .s0, end),

        pub fn getMsg() @This() {
            return .{ .s2Tos3 = .{} };
        }
    };
}

pub fn Msgs3(end: S) type {
    return union(enum) {
        s3Tos0: ST(S, .s0, end),
        s3Tos1: ST(S, .s1, end),

        pub fn getMsg() @This() {
            return .{ .s3Tos1 = .{} };
        }
    };
}

pub fn ST(T: type, a: T, b: T) type {
    return struct {
        pub fn getMsg(self: @This()) a.MT(b) {
            _ = self;
            return a.MT(b).getMsg();
        }
    };
}

fn f1(comptime val: ST(S, .s1, .s0), ref: *i64) void {
    if (@mod(ref.*, 1_000_000_000) == 0)
        std.debug.print("f1: {d}\n", .{ref.*});
    switch (val.getMsg()) {
        .s1Tos2 => |next| {
            ref.* += 1;
            @call(.always_tail, f2, .{ next, ref });
        },
    }
}

fn f2(comptime val: ST(S, .s2, .s0), ref: *i64) void {
    // std.debug.print("f2: {d}\n", .{ref.*});
    switch (val.getMsg()) {
        .s2Tos3 => |next| {
            ref.* += 1;
            @call(.always_tail, f3, .{ next, ref });
        },
        .s2Tos2 => |next| {
            ref.* += 1;
            @call(.always_tail, f2, .{ next, ref });
        },
        .s2Tos0 => |_| return {},
    }
}

fn f3(comptime val: ST(S, .s3, .s0), ref: *i64) void {
    // std.debug.print("f3: {d}\n", .{ref.*});
    switch (val.getMsg()) {
        .s3Tos0 => |_| {},
        .s3Tos1 => |next| {
            ref.* += 1;
            @call(.always_tail, f1, .{ next, ref });
        },
    }
}

const k1 = ST(S, .s1, .s0){};
