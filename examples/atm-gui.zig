const std = @import("std");
const typedFsm = @import("typed-fsm");
const Witness = typedFsm.Witness;

const rl = @import("raylib");
const g = @import("raygui");

const InternalState = struct {
    pin: [4]u8,
    times: usize,
    amount: usize,
};

const resource = struct {
    const insert: Label = Label.init(100, 100, "Insert Card");
    const exit: Label = Label.init(100, 160, "Exit");
    const inputPin: Label = Label.init(100, 100, "Input pin:");
    const check: Label = Label.init(100, 360, "Check");
    const disponse: Label = Label.init(100, 230, "Disponse 10");
    const changePin: Label = Label.init(100, 280, "ChangePin");
    const eject: Label = Label.init(100, 330, "Eject");
    const change: Label = Label.init(100, 360, "Change");
};

pub fn title(st: [:0]const u8) void {
    Label.init(300, 20, st).toLabel();
}

pub fn main() anyerror!void {
    // var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    // const allocator = gpa.allocator();
    // var nlist = typedFsm.NodeList.init(allocator);
    // defer nlist.deinit();
    // var elist = typedFsm.EdgeList.init(allocator);
    // defer elist.deinit();
    // try typedFsm.graph(AtmSt, &nlist, &elist);

    // Initialization
    //--------------------------------------------------------------------------------------
    const screenWidth = 800;
    const screenHeight = 450;

    rl.initWindow(screenWidth, screenHeight, "ATM example");
    defer rl.closeWindow(); // Close window and OpenGL context

    rl.setTargetFPS(60); // Set our game to run at 60 frames-per-second
    //--------------------------------------------------------------------------------------

    var ist: InternalState = .{
        .pin = .{ 1, 2, 3, 4 },
        .times = 0,
        .amount = 10000,
    };
    const start = AtmSt.EWitness(.ready){};
    g.guiSetStyle(.default, 16, 24);
    readyHander(start, &ist);
}

const AtmSt = enum {
    exit,
    ready,
    cardInserted,
    session,
    changePin,

    pub fn EWitness(s: AtmSt) type {
        return Witness(AtmSt, .exit, s);
    }
    fn WitFn(end: AtmSt, s: AtmSt) type {
        return Witness(AtmSt, end, s);
    }

    pub fn exitMsg(_: AtmSt) type {
        return void;
    }

    pub fn readyMsg(end: AtmSt) type {
        return union(enum) {
            ExitAtm: WitFn(end, .exit),
            InsertCard: WitFn(end, .cardInserted),

            pub fn genMsg() @This() {
                while (true) {
                    rl.beginDrawing();
                    defer rl.endDrawing();
                    rl.clearBackground(rl.Color.white);
                    title("Ready");
                    if (resource.insert.toButton()) return .InsertCard;
                    if (resource.exit.toButton()) return .ExitAtm;
                    if (rl.isKeyPressed(rl.KeyboardKey.key_escape)) return .ExitAtm;
                }
            }
        };
    }

    pub fn cardInsertedMsg(end: AtmSt) type {
        return union(enum) {
            Correct: WitFn(end, .session),
            Incorrect: WitFn(end, .cardInserted),
            EjectCard: WitFn(end, .ready),

            pub fn genMsg(ist: *const InternalState) @This() {
                var tmpPin: [4]u8 = .{ 0, 0, 0, 0 };
                var index: usize = 0;
                while (true) {
                    rl.beginDrawing();
                    defer rl.endDrawing();
                    rl.clearBackground(rl.Color.white);
                    title("CardInserted");
                    resource.inputPin.toLabel();

                    for (0..tmpPin.len) |i| {
                        var tmpBuf: [10]u8 = undefined;
                        const st = std.fmt.bufPrintZ(&tmpBuf, "{d}", .{tmpPin[i]}) catch "error";
                        rl.drawText(st, 100 + @as(i32, @intCast(i)) * 60, 200, 50, rl.Color.blue);
                    }
                    rl.drawRectangle(100 + @as(i32, @intCast(index)) * 60, 260, 10, 10, rl.Color.red);
                    var tmpBuf: [40]u8 = undefined;
                    const st = std.fmt.bufPrintZ(&tmpBuf, "test times: {d}", .{ist.times}) catch "error";
                    rl.drawText(st, 100, 290, 30, rl.Color.green);

                    if (resource.check.toButton()) {
                        if (std.mem.eql(u8, &ist.pin, &tmpPin)) {
                            return .Correct;
                        } else {
                            if (ist.times == 2) return .EjectCard;
                            return .Incorrect;
                        }
                    }

                    const kcode = rl.getKeyPressed();
                    const vi: i32 = @intFromEnum(kcode) - 48;
                    switch (vi) {
                        0...9 => {
                            tmpPin[index] = @as(u8, @intCast(vi));
                            index = @mod(index + 1, 4);
                        },
                        else => {},
                    }
                }
            }
        };
    }

    pub fn sessionMsg(end: AtmSt) type {
        return union(enum) {
            Disponse: struct { v: usize, wit: WitFn(end, .session) = .{} },
            EjectCard: WitFn(end, .ready),
            ChangePin: WitFn(end, .changePin),

            pub fn genMsg(ist: *const InternalState) @This() {
                while (true) {
                    rl.beginDrawing();
                    defer rl.endDrawing();
                    rl.clearBackground(rl.Color.white);
                    title("Session");

                    var tmpBuf: [40]u8 = undefined;
                    const st = std.fmt.bufPrintZ(&tmpBuf, "amount: {d}", .{ist.amount}) catch "error";
                    rl.drawText(st, 100, 90, 30, rl.Color.green);
                    if (resource.disponse.toButton()) return .{ .Disponse = .{ .v = 10 } };
                    if (resource.changePin.toButton()) return .ChangePin;
                    if (resource.eject.toButton()) return .EjectCard;
                }
            }
        };
    }

    pub fn changePinMsg(end: AtmSt) type {
        return union(enum) {
            Update: struct { v: [4]u8, wit: WitFn(end, .ready) = .{} },

            pub fn genMsg() @This() {
                var tmpPin: [4]u8 = .{ 0, 0, 0, 0 };
                var index: usize = 0;
                while (true) {
                    rl.beginDrawing();
                    defer rl.endDrawing();
                    rl.clearBackground(rl.Color.white);
                    title("ChangePin");
                    resource.inputPin.toLabel();
                    for (0..tmpPin.len) |i| {
                        var tmpBuf: [10]u8 = undefined;
                        const st = std.fmt.bufPrintZ(&tmpBuf, "{d}", .{tmpPin[i]}) catch "error";
                        rl.drawText(st, 100 + @as(i32, @intCast(i)) * 60, 200, 50, rl.Color.blue);
                    }
                    rl.drawRectangle(100 + @as(i32, @intCast(index)) * 60, 260, 10, 10, rl.Color.red);

                    if (resource.change.toButton()) return .{ .Update = .{ .v = tmpPin } };
                    const kcode = rl.getKeyPressed();
                    const vi: i32 = @intFromEnum(kcode) - 48;
                    switch (vi) {
                        0...9 => {
                            tmpPin[index] = @as(u8, @intCast(vi));
                            index = @mod(index + 1, 4);
                        },
                        else => {},
                    }
                }
            }
        };
    }
};

const Label = struct {
    x: i32,
    y: i32,
    sx: i32,
    sy: i32,
    str: [:0]const u8,

    const fontSize = 30;

    pub fn setStr(self: *Label, str: [:0]const u8) void {
        self.str = str;
        self.sx = @as(i32, @intCast(str.len)) * (fontSize - 5);
    }
    inline fn itof(i: i32) f32 {
        return @floatFromInt(i);
    }

    pub fn toButton(self: *const Label) bool {
        const v = g.guiButton(
            .{
                .x = itof(self.x),
                .y = itof(self.y),
                .width = itof(self.sx),
                .height = itof(self.sy),
            },
            self.str,
        );
        if (v == 1) return true;
        return false;
    }

    pub fn toLabel(self: *const Label) void {
        _ = g.guiLabel(
            .{
                .x = itof(self.x),
                .y = itof(self.y),
                .width = itof(self.sx),
                .height = itof(self.sy),
            },
            self.str,
        );
    }

    pub fn init(x: i32, y: i32, str: [:0]const u8) Label {
        return .{ .x = x, .y = y, .sx = @as(i32, @intCast(str.len)) * (fontSize - 5), .sy = fontSize, .str = str };
    }
};

// ready
pub fn readyHander(comptime w: AtmSt.EWitness(.ready), ist: *InternalState) void {
    switch (w.getMsg()()) {
        .ExitAtm => |witness| {
            witness.terminal();
        },
        .InsertCard => |witness| {
            ist.times = 0;
            @call(.always_tail, cardInsertedHander, .{ witness, ist });
        },
    }
}

// cardInserted,
pub fn cardInsertedHander(comptime w: AtmSt.EWitness(.cardInserted), ist: *InternalState) void {
    switch (w.getMsg()(ist)) {
        .Correct => |wit| {
            ist.times += 1;
            @call(.always_tail, sessionHander, .{ wit, ist });
        },
        .Incorrect => |wit| {
            ist.times += 1;
            @call(.always_tail, cardInsertedHander, .{ wit, ist });
        },
        .EjectCard => |wit| {
            @call(.always_tail, readyHander, .{ wit, ist });
        },
    }
}

// session,
pub fn sessionHander(comptime w: AtmSt.EWitness(.session), ist: *InternalState) void {
    switch (w.getMsg()(ist)) {
        .Disponse => |val| {
            if (ist.amount >= val.v) {
                ist.amount -= val.v;
            } else {
                std.debug.print("insufficient balance\n", .{});
            }
            @call(.always_tail, sessionHander, .{ val.wit, ist });
        },
        .EjectCard => |wit| {
            @call(.always_tail, readyHander, .{ wit, ist });
        },
        .ChangePin => |wit| {
            switch (wit.getMsg()()) {
                .Update => |val| {
                    ist.pin = val.v;
                    @call(.always_tail, readyHander, .{ val.wit, ist });
                },
            }
        },
    }
}
