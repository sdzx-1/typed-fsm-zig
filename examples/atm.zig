const std = @import("std");
const typedFsm = @import("typed-fsm");
const Witness = typedFsm.Witness;

pub fn main() !void {
    var ist: InternalState = .{
        .pin = 1234,
        .times = 0,
        .amount = 10000,
        .buf = undefined,
    };
    const start = AtmSt.T(.ready){};
    readyHander(start, &ist);
}

const AtmSt = enum {
    exit,
    ready,
    cardInserted,
    session,
    changePin,

    pub fn T(s: AtmSt) type {
        return Witness(AtmSt, .exit, s);
    }
    fn W(end: AtmSt, s: AtmSt) type {
        return Witness(AtmSt, end, s);
    }

    pub fn exitMsg(_: AtmSt) type {
        return void;
    }

    const input = std.io.getStdIn().reader();

    pub fn readyMsg(end: AtmSt) type {
        return union(enum) {
            ExitAtm: W(end, .exit),
            InsertCard: W(end, .cardInserted),

            pub fn getMsg(buf: []u8) @This() {
                while (true) {
                    std.debug.print("insert or exit: ", .{});
                    const res = input.readUntilDelimiterOrEof(buf, '\n') catch blk: {
                        break :blk null;
                    };
                    if (res) |line| {
                        if (std.mem.eql(u8, line, "insert")) {
                            return .InsertCard;
                        } else if (std.mem.eql(u8, line, "exit")) {
                            return .ExitAtm;
                        }
                    }

                    std.debug.print("input error\n", .{});
                }
            }
        };
    }

    pub fn cardInsertedMsg(end: AtmSt) type {
        return union(enum) {
            Correct: W(end, .session),
            Incorrect: W(end, .cardInserted),
            EjectCard: W(end, .ready),

            pub fn getMsg(buf: []u8, ist: *const InternalState) @This() {
                while (true) {
                    std.debug.print("input pin: ", .{});
                    const res = input.readUntilDelimiterOrEof(buf, '\n') catch blk: {
                        break :blk null;
                    };
                    if (res) |line| {
                        const pres = std.fmt.parseInt(usize, line, 10) catch blk1: {
                            break :blk1 null;
                        };

                        if (pres) |v| {
                            if (ist.pin == v) {
                                return .Correct;
                            } else {
                                if (ist.times == 2) return .EjectCard;
                                return .Incorrect;
                            }
                        }
                    }

                    std.debug.print("input error\n", .{});
                }
            }
        };
    }

    pub fn sessionMsg(end: AtmSt) type {
        return union(enum) {
            GetAmount: W(end, .session),
            Disponse: struct { v: usize, wit: W(end, .session) = .{} },
            EjectCard: W(end, .ready),
            ChangePin: W(end, .changePin),

            pub fn getMsg(buf: []u8, _: *const InternalState) @This() {
                while (true) {
                    std.debug.print("getAmount or disponse or eject or changePin: ", .{});
                    const res = input.readUntilDelimiterOrEof(buf, '\n') catch blk: {
                        break :blk null;
                    };
                    if (res) |line| {
                        if (std.mem.eql(u8, line, "changePin")) {
                            return .ChangePin;
                        } else if (std.mem.eql(u8, line, "getAmount")) {
                            return .GetAmount;
                        } else if (std.mem.eql(u8, line, "eject")) {
                            return .EjectCard;
                        } else {
                            const pres = std.fmt.parseInt(usize, line, 10) catch blk1: {
                                break :blk1 null;
                            };
                            if (pres) |v| return .{ .Disponse = .{ .v = v } };
                        }
                    }

                    std.debug.print("input error\n", .{});
                }
            }
        };
    }

    pub fn changePinMsg(end: AtmSt) type {
        return union(enum) {
            Update: struct { v: usize, wit: W(end, .session) = .{} },

            pub fn getMsg(buf: []u8) @This() {
                while (true) {
                    std.debug.print("input new pin: ", .{});
                    const res = input.readUntilDelimiterOrEof(buf, '\n') catch blk: {
                        break :blk null;
                    };

                    if (res) |line| {
                        const pres = std.fmt.parseInt(usize, line, 10) catch blk1: {
                            break :blk1 null;
                        };
                        if (pres) |v| return .{ .Update = .{ .v = v } };
                    }

                    std.debug.print("input error\n", .{});
                }
            }
        };
    }
};

const InternalState = struct {
    pin: usize,
    times: usize,
    amount: usize,
    buf: [100]u8,
};

// ready
pub fn readyHander(comptime w: AtmSt.T(.ready), ist: *InternalState) void {
    std.debug.print("current state: ready\n", .{});
    switch (w.getMsg()(&ist.buf)) {
        .ExitAtm => |witness| {
            std.debug.print("Exit ATM!\n", .{});
            witness.terminal();
        },
        .InsertCard => |witness| {
            ist.times = 0;
            @call(.always_tail, cardInsertedHander, .{ witness, ist });
        },
    }
}

// cardInserted,
pub fn cardInsertedHander(comptime w: AtmSt.T(.cardInserted), ist: *InternalState) void {
    std.debug.print("current state: cardInserted\n", .{});
    switch (w.getMsg()(&ist.buf, ist)) {
        .Correct => |wit| {
            ist.times += 1;
            std.debug.print("The pin correct, goto session!\n", .{});
            @call(.always_tail, sessionHander, .{ wit, ist });
        },
        .Incorrect => |wit| {
            ist.times += 1;
            std.debug.print("The pin incorrect, goto cardInserted!\n", .{});
            @call(.always_tail, cardInsertedHander, .{ wit, ist });
        },
        .EjectCard => |wit| {
            std.debug.print("Test times great than 3, eject card!\n", .{});
            @call(.always_tail, readyHander, .{ wit, ist });
        },
    }
}

// session,
pub fn sessionHander(comptime w: AtmSt.T(.session), ist: *InternalState) void {
    std.debug.print("current state: session\n", .{});
    switch (w.getMsg()(&ist.buf, ist)) {
        .GetAmount => |wit| {
            std.debug.print("amount: {d}\n", .{ist.amount});
            @call(.always_tail, sessionHander, .{ wit, ist });
        },

        .Disponse => |val| {
            if (ist.amount >= val.v) {
                ist.amount -= val.v;
                std.debug.print("disponse: {d}\n", .{val.v});
                std.debug.print("new amount: {d}\n", .{ist.amount});
            } else {
                std.debug.print("insufficient balance\n", .{});
            }
            @call(.always_tail, sessionHander, .{ val.wit, ist });
        },
        .EjectCard => |wit| {
            std.debug.print("eject card\n", .{});
            @call(.always_tail, readyHander, .{ wit, ist });
        },
        .ChangePin => |wit| {
            switch (wit.getMsg()(&ist.buf)) {
                .Update => |val| {
                    ist.pin = val.v;
                    @call(.always_tail, sessionHander, .{ val.wit, ist });
                },
            }
        },
    }
}
