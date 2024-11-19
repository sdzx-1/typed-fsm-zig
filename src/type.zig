const std = @import("std");

pub fn Witness(T: type, end: T, start: T) type {
    const i: usize = @intFromEnum(start);
    const st = @typeInfo(T).@"enum".fields[i].name;
    const stru = @field(T, st ++ "Msg")(end);
    return struct {
        pub fn getMsg(_: @This()) @TypeOf(stru.getMsg) {
            return stru.getMsg;
        }

        pub fn terminal(_: @This()) void {
            if (end != start) @compileError("Can't terminal");
            return {};
        }
    };
}

pub const S = enum {
    s1,
    s2,
    s3,
    s0,

    pub fn ST(s: S) type {
        return Witness(S, .s0, s);
    }

    fn s1Msg(end: S) type {
        return union(enum) {
            Tos2: Witness(S, end, .s2),

            pub fn getMsg() @This() {
                return .Tos2;
            }
        };
    }

    fn s2Msg(end: S) type {
        return union(enum) {
            Tos3: Witness(S, end, .s3),
            Tos2: Witness(S, end, .s2),

            pub fn getMsg() @This() {
                return .Tos3;
            }
        };
    }

    fn s3Msg(end: S) type {
        return union(enum) {
            Tos1: Witness(S, end, .s1),
            Exit: Witness(S, end, .s0),

            pub fn getMsg(ref: *i64) @This() {
                if (ref.* > 10) return .Exit;
                return .Tos1;
            }
        };
    }
    fn s0Msg(_: S) type {
        return void;
    }
};
