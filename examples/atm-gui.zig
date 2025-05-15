const std = @import("std");
const typedFsm = @import("typed_fsm");
const Witness = typedFsm.Witness;
const zgui = @import("zgui");
const glfw = @import("zglfw");
const zopengl = @import("zopengl");

const content_dir = @import("build_options").content_dir;
const window_titlw = "ATM-EXAMPLE";
const gl = zopengl.bindings;

const Window = glfw.Window;

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

    const window = try glfw.Window.create(800, 400, window_titlw, null);
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
        std.math.floor(22.0 * scale_factor),
        null,
        null,
    );

    zgui.getStyle().scaleAllSizes(scale_factor);

    zgui.backend.init(window);
    defer zgui.backend.deinit();

    var ist = Atm.State.init(window);

    var graph = typedFsm.Graph.init;
    try typedFsm.generate_graph(gpa, Atm, &graph);

    std.debug.print("{}\n", .{graph});

    const wa = Atm.EWit(.ready){};
    wa.handler_normal(&ist);
}

pub const Atm = enum {
    exit,
    ready,
    checkPin, // checkPin(session, checkPin(session, checkPin(session, ready)))
    session,

    pub const State = struct {
        pin: [4]u8 = .{ 1, 2, 3, 4 },
        amount: usize = 10_0000,
        window: *Window,

        pub fn init(win: *Window) @This() {
            return .{ .window = win };
        }
    };

    fn prinet_enter_state(
        val: typedFsm.sdzx(Atm),
        gst: *const Atm.State,
    ) void {
        std.debug.print("current_st :  {}\n", .{val});
        std.debug.print("current_gst: {any}\n", .{gst.*});
    }

    pub fn EWit(t: @This()) type {
        return typedFsm.Witness(@This(), typedFsm.val_to_sdzx(@This(), t), State, prinet_enter_state);
    }
    pub fn EWitFn(val: anytype) type {
        return typedFsm.Witness(@This(), typedFsm.val_to_sdzx(@This(), val), State, prinet_enter_state);
    }

    pub const exitST = union(enum) {
        pub fn handler(ist: *State) void {
            std.debug.print("exit\n", .{});
            std.debug.print("st: {any}\n", .{ist.*});
        }
    };

    pub const readyST = union(enum) {
        InsertCard: EWitFn(.{ Atm.checkPin, Atm.session, .{ Atm.checkPin, Atm.session, .{ Atm.checkPin, Atm.session, Atm.ready } } }),
        Exit: EWit(.exit),

        pub fn handler(ist: *State) void {
            switch (genMsg(ist.window)) {
                .Exit => |wit| wit.handler(ist),
                .InsertCard => |wit| wit.handler(ist),
            }
        }

        fn genMsg(window: *Window) @This() {
            while (true) {
                init(window);
                defer {
                    zgui.backend.draw();
                    window.swapBuffers();
                }

                if (window.shouldClose() or
                    window.getKey(.q) == .press or
                    window.getKey(.escape) == .press)
                    return .{ .Exit = .{} };

                {
                    _ = zgui.begin("ready", .{ .flags = .{
                        .no_collapse = true,

                        .no_move = true,
                        .no_resize = true,
                    } });
                    defer zgui.end();
                    if (zgui.button("Isnert card", .{})) {
                        return .InsertCard;
                    }
                    if (zgui.button("Exit!", .{})) {
                        return .{ .Exit = .{} };
                    }
                }
            }
        }
    };

    pub fn checkPinST(success: typedFsm.sdzx(Atm), failed: typedFsm.sdzx(Atm)) type {
        return union(enum) {
            Successed: typedFsm.Witness(Atm, success, State, prinet_enter_state),
            Failed: typedFsm.Witness(Atm, failed, State, prinet_enter_state),

            pub fn handler(ist: *State) void {
                switch (genMsg(ist.window, &ist.pin)) {
                    .Successed => |wit| wit.handler(ist),
                    .Failed => |wit| wit.handler(ist),
                }
            }

            fn genMsg(window: *Window, pin: []const u8) @This() {
                var tmpPin: [4:0]u8 = .{ 0, 0, 0, 0 };
                while (true) {
                    init(window);
                    defer {
                        zgui.backend.draw();
                        window.swapBuffers();
                    }

                    {
                        _ = zgui.begin("CheckPin", .{ .flags = .{
                            .no_collapse = true,

                            .no_move = true,
                            .no_resize = true,
                        } });
                        defer zgui.end();

                        _ = zgui.inputText("pin", .{
                            .buf = &tmpPin,
                            .flags = .{ .password = true, .chars_decimal = true },
                        });

                        if (zgui.button("OK", .{})) {
                            for (0..4) |i| tmpPin[i] -|= 48;

                            if (std.mem.eql(u8, &tmpPin, pin)) {
                                return .Successed;
                            } else {
                                return .Failed;
                            }
                        }
                    }
                }
            }
        };
    }

    pub const sessionST = union(enum) {
        Disponse: struct { wit: EWit(.session) = .{}, v: usize },
        EjectCard: EWit(.ready),

        pub fn handler(ist: *State) void {
            switch (genMsg(ist.window, ist.amount)) {
                .Disponse => |val| {
                    if (ist.amount >= val.v) {
                        ist.amount -= val.v;
                        val.wit.handler(ist);
                    } else {
                        std.debug.print("insufficient balance\n", .{});
                        val.wit.handler(ist);
                    }
                },
                .EjectCard => |wit| wit.handler(ist),
            }
        }

        fn genMsg(window: *Window, amount: usize) @This() {
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

                    if (zgui.button("Eject card", .{})) {
                        return .EjectCard;
                    }
                }
            }
        }
    };
};
