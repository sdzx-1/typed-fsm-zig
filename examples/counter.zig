const std = @import("std");

pub fn main() !void {
    var val: i32 = 0;
    const s1Wit = Witness(Exmaple, .exit, .s1){};
    _ = s1Handler(s1Wit, &val);
}

pub fn Witness(T: type, b: T, a: T) type {
    return struct {
        pub fn getMsg(self: @This()) @TypeOf(a.STM(b).getMsg) {
            if (b == a) @compileError("Can't getMsg!");
            _ = self;
            return a.STM(b).getMsg;
        }

        pub fn terminal(_: @This()) void {
            if (b != a) @compileError("Can't terminal!");
            return {};
        }
    };
}
const Exmaple = enum {
    exit,
    s1,
    s2,

    // State to Message
    pub fn STM(s: Exmaple, b: Exmaple) type {
        return switch (s) {
            .exit => exitMsg(b),
            .s1 => s1Msg(b),
            .s2 => s2Msg(b),
        };
    }
};

pub fn exitMsg(_: Exmaple) void {
    return {};
}

pub fn s1Msg(end: Exmaple) type {
    return union(enum) {
        Exit: Witness(Exmaple, end, .exit),
        S1Tos2: Witness(Exmaple, end, .s2),
        pub fn getMsg(ref: *const i32) @This() {
            if (ref.* > 20) return .Exit;
            return .S1Tos2;
        }
    };
}
pub fn s2Msg(end: Exmaple) type {
    return union(enum) {
        S2Tos1: Witness(Exmaple, end, .s1),
        pub fn getMsg() @This() {
            return .S2Tos1;
        }
    };
}

fn s1Handler(val: Witness(Exmaple, .exit, .s1), ref: *i32) void {
    std.debug.print("val: {d}\n", .{ref.*});
    switch (val.getMsg()(ref)) {
        .Exit => |wit| wit.terminal(),
        .S1Tos2 => |wit| {
            ref.* += 1;
            s2Handler(wit, ref);
        },
    }
}
fn s2Handler(val: Witness(Exmaple, .exit, .s2), ref: *i32) void {
    switch (val.getMsg()()) {
        .S2Tos1 => |wit| {
            ref.* += 2;
            s1Handler(wit, ref);
        },
    }
}
