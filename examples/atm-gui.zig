const std = @import("std");
const typedFsm = @import("typed_fsm");
const Witness = typedFsm.Witness;
const zgui = @import("zgui");
const glfw = @import("zglfw");
const zopengl = @import("zopengl");

const content_dir = @import("build_options").content_dir;
const window_titlw = "atm";
const gl = zopengl.bindings;

const Window = glfw.Window;

const InternalState = struct {
    pin: [4]u8,
    amount: usize,
    window: *Window,
    try_times: u8 = 0,
    verify_next: ?Next = null,
    verify_times: u8 = 0,

    pub const Next = enum {
        toSession,
        toChangePin,
    };
};

fn init(window: *Window) void {
    glfw.pollEvents();
    gl.clearBufferfv(gl.COLOR, 0, &[_]f32{ 0.2, 0.2, 0, 1.0 });
    const fb_size = window.getFramebufferSize();
    zgui.backend.newFrame(@intCast(fb_size[0]), @intCast(fb_size[1]));
    zgui.setNextWindowPos(.{ .x = 0, .y = 0 });
    zgui.setNextWindowSize(.{
        .w = @floatFromInt(fb_size[0]),
        .h = @floatFromInt(fb_size[1]),
    });
}

pub fn main() anyerror!void {
    var gpa_instance = std.heap.GeneralPurposeAllocator(.{}){};
    const gpa = gpa_instance.allocator();

    try glfw.init();
    defer glfw.terminate();

    {
        var buffer: [1024]u8 = undefined;
        const path = std.fs.selfExeDirPath(buffer[0..]) catch ".";
        std.posix.chdir(path) catch {};
    }

    const gl_major = 4;
    const gl_minor = 0;

    glfw.windowHint(.context_version_major, gl_major);
    glfw.windowHint(.context_version_minor, gl_minor);
    glfw.windowHint(.opengl_profile, .opengl_core_profile);
    glfw.windowHint(.opengl_forward_compat, true);
    glfw.windowHint(.client_api, .opengl_api);
    glfw.windowHint(.doublebuffer, true);

    const window = try glfw.Window.create(400, 400, window_titlw, null);
    defer window.destroy();

    glfw.makeContextCurrent(window);
    glfw.swapInterval(1);

    try zopengl.loadCoreProfile(glfw.getProcAddress, gl_major, gl_minor);

    zgui.init(gpa);
    defer zgui.deinit();

    const scale_factor = scale_factor: {
        const scale = window.getContentScale();
        break :scale_factor @max(scale[0], scale[1]);
    };

    _ = zgui.io.addFontFromFileWithConfig(
        content_dir ++ "FiraMono.ttf",
        std.math.floor(16.0 * scale_factor),
        null,
        null,
    );

    zgui.getStyle().scaleAllSizes(scale_factor);

    zgui.backend.init(window);
    defer zgui.backend.deinit();

    var ist: InternalState = .{
        .pin = .{ 1, 2, 3, 4 },
        .amount = 10000,
        .window = window,
    };
    // reqVerifyHandler(AtmSt.EWitness(.reqVerify){}, &ist);
    const start = AtmSt.EWitness(.ready){};
    readyHandler(start, &ist);
}

pub const AtmSt = enum {
    exit,
    ready,
    cardInserted,
    check,
    session,
    changePin,

    //request phone number
    reqPN,
    reqCode,
    verify,

    pub const verifyST = union(enum) {
        SuccessToChangePin: EWitness(.changePin),
        SuccessToSession: EWitness(.session),
        Failed: EWitness(.reqPN),
        Exit: EWitness(.exit),

        pub fn genMsg(
            lhs: [4]u8,
            rhs: [4]u8,
            next: InternalState.Next,
            verify_times: u8,
        ) @This() {
            if (std.mem.eql(u8, &lhs, &rhs)) {
                switch (next) {
                    .toSession => return .SuccessToSession,
                    .toChangePin => return .SuccessToChangePin,
                }
            } else if (verify_times >= 2) {
                return .Exit;
            } else {
                return .Failed;
            }
        }
    };

    pub const reqPNST = union(enum) {
        PhoneNumber: struct {
            wit: EWitness(.reqCode) = .{},
            v: [11]u8,
        },

        var phone_number: [11:0]u8 = @splat(0);
        pub fn genMsg(window: *Window, times: u8) @This() {
            while (true) {
                init(window);
                defer {
                    zgui.backend.draw();
                    window.swapBuffers();
                }

                {
                    _ = zgui.begin("ReqVerify", .{ .flags = .{
                        .no_collapse = true,
                        .no_saved_settings = true,
                        .no_move = true,
                        .no_resize = true,
                    } });
                    defer zgui.end();

                    zgui.text("Remaining times {d}", .{3 - times});
                    _ = zgui.inputText("phone number", .{
                        .buf = &phone_number,
                        .flags = .{ .chars_decimal = true },
                    });
                    if (zgui.button("send phone number", .{})) {
                        var tmp: [11]u8 = undefined;
                        for (&phone_number, 0..) |p, i| {
                            tmp[i] = p -| 48;
                        }
                        return .{ .PhoneNumber = .{ .v = tmp } };
                    }
                }
            }
        }
    };

    pub const reqCodeST = union(enum) {
        RecvCode: struct {
            wit: EWitness(.verify) = .{},
            v: [4]u8,
        },

        var recv_code: [4:0]u8 = @splat(0);
        pub fn genMsg(window: *Window) @This() {
            while (true) {
                init(window);
                defer {
                    zgui.backend.draw();
                    window.swapBuffers();
                }

                {
                    _ = zgui.begin("ReqVerify", .{ .flags = .{
                        .no_collapse = true,
                        .no_saved_settings = true,
                        .no_move = true,
                        .no_resize = true,
                    } });
                    defer zgui.end();

                    _ = zgui.inputText("recv doe", .{
                        .buf = &recv_code,
                        .flags = .{ .chars_decimal = true },
                    });
                    if (zgui.button("send recv code", .{})) {
                        var tmp: [4]u8 = undefined;
                        for (&recv_code, 0..) |p, i| {
                            tmp[i] = p -| 48;
                        }
                        return .{ .RecvCode = .{ .v = tmp } };
                    }
                }
            }
        }
    };

    pub fn EWitness(s: AtmSt) type {
        return Witness(AtmSt, .exit, s);
    }

    pub const exitST = union(enum) {};

    pub const readyST = union(enum) {
        ExitAtm: EWitness(.exit),
        InsertCard: EWitness(.cardInserted),

        pub fn genMsg(window: *Window) @This() {
            while (true) {
                init(window);
                defer {
                    zgui.backend.draw();
                    window.swapBuffers();
                }

                if (window.shouldClose() or
                    window.getKey(.q) == .press or
                    window.getKey(.escape) == .press) return .ExitAtm;

                {
                    _ = zgui.begin("ready", .{ .flags = .{
                        .no_collapse = true,
                        .no_saved_settings = true,
                        .no_move = true,
                        .no_resize = true,
                    } });
                    defer zgui.end();
                    if (zgui.button("Isnert card", .{})) {
                        return .InsertCard;
                    }
                    if (zgui.button("Exit!", .{})) {
                        return .ExitAtm;
                    }
                }
            }
        }
    };

    pub const cardInsertedST = union(enum) {
        CheckPin: struct { wit: EWitness(.check) = .{}, v: [4]u8 },
        VerifyPN: EWitness(.reqPN),

        pub fn genMsg(window: *Window, try_times: u8) @This() {
            var tmpPin: [4:0]u8 = .{ 0, 0, 0, 0 };
            while (true) {
                init(window);
                defer {
                    zgui.backend.draw();
                    window.swapBuffers();
                }

                {
                    _ = zgui.begin("Insert Card", .{ .flags = .{
                        .no_collapse = true,
                        .no_saved_settings = true,
                        .no_move = true,
                        .no_resize = true,
                    } });
                    defer zgui.end();

                    _ = zgui.inputText("password", .{
                        .buf = &tmpPin,
                        .flags = .{ .password = true, .chars_decimal = true },
                    });

                    if (zgui.button("Sub", .{})) {
                        for (0..4) |i| tmpPin[i] -|= 48;
                        return .{ .CheckPin = .{ .v = tmpPin } };
                    }

                    zgui.text("try times: {d}", .{try_times});

                    if (zgui.button("Login by Code", .{})) {
                        return .VerifyPN;
                    }
                }
            }
        }
    };

    pub const checkST = union(enum) {
        Correct: AtmSt.EWitness(.session),
        Incorrect: AtmSt.EWitness(.cardInserted),
        VerifyPN: AtmSt.EWitness(.reqPN),

        pub fn genMsg(
            try_times: u8,
            pin: [4]u8,
            tmpPin: [4]u8,
        ) @This() {
            if (std.mem.eql(u8, &pin, &tmpPin)) {
                return .Correct;
            } else if (try_times == 2) {
                return .VerifyPN;
            } else {
                return .Incorrect;
            }
        }
    };

    pub const sessionST = union(enum) {
        Disponse: struct { v: usize, wit: EWitness(.session) = .{} },
        EjectCard: EWitness(.ready),
        ChangePin: EWitness(.reqPN),

        pub fn genMsg(window: *Window, amount: usize) @This() {
            var dispVal: i32 = @divTrunc(@as(i32, @intCast(amount)), 2);
            while (true) {
                init(window);
                defer {
                    zgui.backend.draw();
                    window.swapBuffers();
                }

                {
                    _ = zgui.begin("Session", .{ .flags = .{
                        .no_collapse = true,
                        .no_saved_settings = true,
                        .no_move = true,
                        .no_resize = true,
                    } });
                    defer zgui.end();

                    zgui.text("amount: {d}", .{amount});
                    _ = zgui.sliderInt(
                        "disponse value",
                        .{ .v = &dispVal, .min = 0, .max = @intCast(amount) },
                    );

                    if (zgui.button("Disponse", .{})) {
                        return .{ .Disponse = .{ .v = @intCast(dispVal) } };
                    }

                    if (zgui.button("ChangePin", .{})) {
                        return .ChangePin;
                    }
                    if (zgui.button("Eject card", .{})) {
                        return .EjectCard;
                    }
                }
            }
        }
    };

    pub const changePinST = union(enum) {
        Update: struct { v: [4]u8, wit: EWitness(.ready) = .{} },

        pub fn genMsg(window: *Window) @This() {
            var tmpPin: [4:0]u8 = .{ 0, 0, 0, 0 };
            while (true) {
                init(window);
                defer {
                    zgui.backend.draw();
                    window.swapBuffers();
                }

                {
                    _ = zgui.begin("ChangePin", .{ .flags = .{
                        .no_collapse = true,
                        .no_saved_settings = true,
                        .no_move = true,
                        .no_resize = true,
                    } });
                    defer zgui.end();
                    _ = zgui.inputText("password", .{
                        .buf = &tmpPin,
                        .flags = .{ .password = true, .chars_decimal = true },
                    });

                    if (zgui.button("Sub", .{})) {
                        for (0..4) |i| tmpPin[i] -|= 48;
                        return .{ .Update = .{ .v = tmpPin } };
                    }
                }
            }
        }
    };
};

// ready
pub fn readyHandler(comptime w: AtmSt.EWitness(.ready), ist: *InternalState) void {
    switch (w.genMsg()(ist.window)) {
        .ExitAtm => |witness| {
            witness.terminal();
        },
        .InsertCard => |witness| {
            @call(.always_tail, cardInsertedHandler, .{ witness, ist });
        },
    }
}

// cardInserted,
pub fn cardInsertedHandler(comptime w: AtmSt.EWitness(.cardInserted), ist: *InternalState) void {
    switch (w.genMsg()(ist.window, ist.try_times)) {
        .VerifyPN => |wit| {
            ist.verify_next = .toSession;
            @call(.always_tail, reqPNHandler, .{ wit, ist });
        },
        .CheckPin => |val| {
            switch (val.wit.genMsg()(ist.try_times, ist.pin, val.v)) {
                .Incorrect => |wit| {
                    ist.try_times += 1;
                    @call(.always_tail, cardInsertedHandler, .{ wit, ist });
                },
                .Correct => |wit| {
                    ist.try_times = 0;
                    @call(.always_tail, sessionHandler, .{ wit, ist });
                },
                .VerifyPN => |wit| {
                    ist.try_times = 0;
                    ist.verify_next = .toChangePin;
                    @call(.always_tail, reqPNHandler, .{ wit, ist });
                },
            }
        },
    }
}

pub fn reqPNHandler(comptime w: AtmSt.EWitness(.reqPN), ist: *InternalState) void {
    switch (w.genMsg()(ist.window, ist.verify_times)) {
        .PhoneNumber => |v| {
            var prng = std.Random.DefaultPrng.init(blk: {
                var seed: u64 = undefined;
                std.posix.getrandom(std.mem.asBytes(&seed)) catch unreachable;
                break :blk seed;
            });
            const rand = prng.random();

            var random_code: [4]u8 = @splat(0);
            for (&random_code) |*ptr| {
                ptr.* = rand.intRangeAtMost(u8, 0, 9);
            }
            std.debug.print("send code: {d} to phone {d}\n", .{ random_code, v.v });

            switch (v.wit.genMsg()(ist.window)) {
                .RecvCode => |v1| {
                    switch (v1.wit.genMsg()(random_code, v1.v, ist.verify_next.?, ist.verify_times)) {
                        .Exit => |wit| {
                            std.debug.print("test 3 times, exit!", .{});
                            wit.terminal();
                        },
                        .SuccessToChangePin => |wit| {
                            ist.verify_times = 0;
                            @call(.always_tail, changePinHandler, .{ wit, ist });
                        },
                        .SuccessToSession => |wit| {
                            ist.verify_times = 0;
                            @call(.always_tail, sessionHandler, .{ wit, ist });
                        },
                        .Failed => |wit| {
                            ist.verify_times += 1;
                            std.debug.print("VERIFY FAILED, Retry\n", .{});
                            @call(.always_tail, reqPNHandler, .{ wit, ist });
                        },
                    }
                },
            }
        },
    }
}

// session,
pub fn sessionHandler(comptime w: AtmSt.EWitness(.session), ist: *InternalState) void {
    switch (w.genMsg()(ist.window, ist.amount)) {
        .Disponse => |val| {
            if (ist.amount >= val.v) {
                ist.amount -= val.v;
                @call(.always_tail, sessionHandler, .{ val.wit, ist });
            } else {
                std.debug.print("insufficient balance\n", .{});
                @call(.always_tail, sessionHandler, .{ val.wit, ist });
            }
        },
        .EjectCard => |wit| @call(.always_tail, readyHandler, .{ wit, ist }),
        .ChangePin => |wit| {
            ist.verify_next = .toChangePin;
            @call(.always_tail, reqPNHandler, .{ wit, ist });
        },
    }
}

pub fn changePinHandler(comptime w: AtmSt.EWitness(.changePin), ist: *InternalState) void {
    switch (w.genMsg()(ist.window)) {
        .Update => |val| {
            ist.pin = val.v;
            @call(.always_tail, readyHandler, .{ val.wit, ist });
        },
    }
}
