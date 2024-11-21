const std = @import("std");
const typedFsm = @import("typed-fsm");
const Witness = typedFsm.Witness;

const rl = @import("raylib");

const InternalState = struct {
    pin: [4]u8,
    tmpPin: [4]u8,
    index: usize = 0,
    times: usize,
    amount: usize,
    buf: [100]u8,
    resource: Resource,
};

const Resource = struct {
    title: Label = Label.init(300, 20, "State: Ready"),
    insert: Label = Label.init(100, 100, "Insert Card"),
    exit: Label = Label.init(100, 160, "Exit"),
    inputPin: Label = Label.init(100, 100, "Input pin:"),
    check: Label = Label.init(100, 360, "Check"),
    disponse: Label = Label.init(100, 230, "Disponse 10"),
    changePin: Label = Label.init(100, 280, "ChangePin"),
    eject: Label = Label.init(100, 330, "Eject"),
    change: Label = Label.init(100, 360, "Change"),
};

pub fn main() anyerror!void {
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
        .tmpPin = .{ 0, 0, 0, 0 },
        .times = 0,
        .amount = 10000,
        .buf = undefined,
        .resource = .{},
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

            pub fn genMsg(ist: *const InternalState) @This() {
                while (true) {
                    // render
                    rl.beginDrawing();
                    defer rl.endDrawing();
                    rl.clearBackground(rl.Color.white);
                    ist.resource.title.draw();
                    ist.resource.insert.draw();
                    ist.resource.exit.draw();

                    if (rl.isMouseButtonPressed(rl.MouseButton.mouse_button_left)) {
                        const x = rl.getMouseX();
                        const y = rl.getMouseY();

                        if (ist.resource.insert.posInLabel(x, y)) {
                            return .InsertCard;
                        } else if (ist.resource.exit.posInLabel(x, y)) {
                            return .ExitAtm;
                        }
                    }
                }
            }
        };
    }

    pub fn cardInsertedMsg(end: AtmSt) type {
        return union(enum) {
            PushNum: struct { v: u8, wit: W(end, .cardInserted) = .{} },
            Correct: W(end, .session),
            Incorrect: W(end, .cardInserted),
            EjectCard: W(end, .ready),

            pub fn genMsg(ist: *const InternalState) @This() {
                while (true) {

                    // render
                    rl.beginDrawing();
                    defer rl.endDrawing();
                    rl.clearBackground(rl.Color.white);
                    ist.resource.title.draw();
                    ist.resource.inputPin.draw();
                    for (0..ist.tmpPin.len) |i| {
                        var tmpBuf: [10]u8 = undefined;
                        const st = std.fmt.bufPrintZ(&tmpBuf, "{d}", .{ist.tmpPin[i]}) catch "error";
                        rl.drawText(st, 100 + @as(i32, @intCast(i)) * 60, 200, 50, rl.Color.blue);
                    }
                    rl.drawRectangle(100 + @as(i32, @intCast(ist.index)) * 60, 260, 10, 10, rl.Color.red);
                    var tmpBuf: [40]u8 = undefined;
                    const st = std.fmt.bufPrintZ(&tmpBuf, "test times: {d}", .{ist.times}) catch "error";
                    rl.drawText(st, 100, 290, 30, rl.Color.green);
                    ist.resource.check.draw();

                    const kcode = rl.getKeyPressed();
                    const vi: i32 = @intFromEnum(kcode) - 48;

                    switch (vi) {
                        0...9 => return .{ .PushNum = .{ .v = @as(u8, @intCast(vi)) } },
                        else => {},
                    }

                    if (rl.isMouseButtonPressed(rl.MouseButton.mouse_button_left)) {
                        const x = rl.getMouseX();
                        const y = rl.getMouseY();

                        if (ist.resource.check.posInLabel(x, y)) {
                            if (std.mem.eql(u8, &ist.pin, &ist.tmpPin)) {
                                return .Correct;
                            } else {
                                if (ist.times == 2) return .EjectCard;
                                return .Incorrect;
                            }
                        }
                    }
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

            pub fn genMsg(ist: *const InternalState) @This() {
                while (true) {

                    // render
                    rl.beginDrawing();
                    defer rl.endDrawing();
                    rl.clearBackground(rl.Color.white);
                    ist.resource.title.draw();

                    var tmpBuf: [40]u8 = undefined;
                    const st = std.fmt.bufPrintZ(&tmpBuf, "amount: {d}", .{ist.amount}) catch "error";
                    rl.drawText(st, 100, 90, 30, rl.Color.green);
                    ist.resource.disponse.draw();
                    ist.resource.changePin.draw();
                    ist.resource.eject.draw();

                    if (rl.isMouseButtonPressed(rl.MouseButton.mouse_button_left)) {
                        const x = rl.getMouseX();
                        const y = rl.getMouseY();

                        if (ist.resource.disponse.posInLabel(x, y)) {
                            return .{ .Disponse = .{ .v = 10 } };
                        } else if (ist.resource.changePin.posInLabel(x, y)) {
                            return .ChangePin;
                        } else if (ist.resource.eject.posInLabel(x, y)) {
                            return .EjectCard;
                        }
                    }
                }
            }
        };
    }

    pub fn changePinMsg(end: AtmSt) type {
        return union(enum) {
            PushNum: struct { v: u8, wit: W(end, .changePin) = .{} },
            Update: W(end, .ready),

            pub fn genMsg(ist: *const InternalState) @This() {
                while (true) {

                    // render
                    rl.beginDrawing();
                    defer rl.endDrawing();
                    rl.clearBackground(rl.Color.white);
                    ist.resource.title.draw();

                    ist.resource.inputPin.draw();
                    for (0..ist.tmpPin.len) |i| {
                        var tmpBuf: [10]u8 = undefined;
                        const st = std.fmt.bufPrintZ(&tmpBuf, "{d}", .{ist.tmpPin[i]}) catch "error";
                        rl.drawText(st, 100 + @as(i32, @intCast(i)) * 60, 200, 50, rl.Color.blue);
                    }
                    rl.drawRectangle(100 + @as(i32, @intCast(ist.index)) * 60, 260, 10, 10, rl.Color.red);
                    ist.resource.change.draw();

                    const kcode = rl.getKeyPressed();
                    const vi: i32 = @intFromEnum(kcode) - 48;
                    switch (vi) {
                        0...9 => return .{ .PushNum = .{ .v = @as(u8, @intCast(vi)) } },
                        else => {},
                    }
                    if (rl.isMouseButtonPressed(rl.MouseButton.mouse_button_left)) {
                        const x = rl.getMouseX();
                        const y = rl.getMouseY();

                        if (ist.resource.change.posInLabel(x, y)) {
                            return .Update;
                        }
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

    pub fn init(x: i32, y: i32, str: [:0]const u8) Label {
        return .{ .x = x, .y = y, .sx = @as(i32, @intCast(str.len)) * (fontSize - 5), .sy = fontSize, .str = str };
    }

    pub fn posInLabel(self: *const Label, posX: i32, posY: i32) bool {
        return posX > self.x and posX < self.x + self.sx and
            posY > self.y and posY < self.y + self.sy;
    }

    pub fn draw(self: *const Label) void {
        rl.drawRectangle(self.x, self.y, self.sx, self.sy, rl.Color.gray);
        if (self.posInLabel(rl.getMouseX(), rl.getMouseY())) {
            rl.drawText(self.str, self.x, self.y, fontSize + 4, rl.Color.red);
        } else {
            rl.drawText(self.str, self.x, self.y, fontSize, rl.Color.black);
        }
    }
};

// ready
pub fn readyHander(comptime w: AtmSt.T(.ready), ist: *InternalState) void {
    ist.resource.title.setStr("Ready");
    switch (w.getMsg()(ist)) {
        .ExitAtm => |witness| {
            witness.terminal();
        },
        .InsertCard => |witness| {
            ist.times = 0;
            ist.index = 0;
            ist.tmpPin = .{ 0, 0, 0, 0 };
            @call(.always_tail, cardInsertedHander, .{ witness, ist });
        },
    }
}

// cardInserted,
pub fn cardInsertedHander(comptime w: AtmSt.T(.cardInserted), ist: *InternalState) void {
    ist.resource.title.setStr("CardInserted");
    switch (w.getMsg()(ist)) {
        .PushNum => |val| {
            ist.tmpPin[ist.index] = val.v;
            ist.index = @mod(ist.index + 1, 4);
            @call(.always_tail, cardInsertedHander, .{ val.wit, ist });
        },
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
pub fn sessionHander(comptime w: AtmSt.T(.session), ist: *InternalState) void {
    ist.resource.title.setStr("Session");
    switch (w.getMsg()(ist)) {
        .GetAmount => |wit| {
            @call(.always_tail, sessionHander, .{ wit, ist });
        },

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
            ist.tmpPin = .{ 0, 0, 0, 0 };
            @call(.always_tail, changePinHander, .{ wit, ist });
        },
    }
}
pub fn changePinHander(comptime w: AtmSt.T(.changePin), ist: *InternalState) void {
    ist.resource.title.setStr("ChangePin");
    switch (w.getMsg()(ist)) {
        .Update => |wit1| {
            ist.pin = ist.tmpPin;
            @call(.always_tail, readyHander, .{ wit1, ist });
        },

        .PushNum => |val| {
            ist.tmpPin[ist.index] = val.v;
            ist.index = @mod(ist.index + 1, 4);
            @call(.always_tail, changePinHander, .{ val.wit, ist });
        },
    }
}
