const std = @import("std");
const typedFsm = @import("typed_fsm");

pub fn main() !void {
    var gpa_instance = std.heap.GeneralPurposeAllocator(.{}){};
    const gpa = gpa_instance.allocator();

    var graph = typedFsm.Graph.init;
    try typedFsm.generate_graph(gpa, Example, &graph);

    std.debug.print("{}\n", .{graph});

    std.debug.print("----------------------------\n", .{});
    var st: Example.State = .{};
    const wa = Example.EWit(.a){};
    wa.handler_normal(&st);
    std.debug.print("----------------------------\n", .{});
}

///Example
const Example = enum {
    exit,
    a,
    b,
    select,

    pub const State = struct {
        counter_a: i64 = 0,
        counter_b: i64 = 0,
    };

    fn prinet_enter_state(
        val: typedFsm.sdzx(Example),
        gst: *const Example.State,
    ) void {
        std.debug.print("{} ", .{val});
        std.debug.print("gst: {any}\n", .{gst.*});
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
    pub const bST = b_st;
    pub const aST = a_st;
    pub fn selectST(sa: typedFsm.sdzx(@This()), sb: typedFsm.sdzx(@This())) type {
        return select_st(@This(), .select, sa, sb, State);
    }
};

pub const a_st = union(enum) {
    AddOneThenToB: Example.EWit(.b),
    Exit: Example.EWitFn(.{ Example.select, .{ Example.select, Example.exit, Example.a }, Example.a }),

    pub fn handler(ist: *Example.State) void {
        switch (genMsg(ist)) {
            .AddOneThenToB => |wit| {
                ist.counter_a += 1;
                wit.handler(ist);
            },
            .Exit => |wit| wit.handler(ist),
        }
    }

    fn genMsg(ist: *Example.State) @This() {
        if (ist.counter_a > 3) return .Exit;
        return .AddOneThenToB;
    }
};

pub const b_st = union(enum) {
    AddOneThenToA: Example.EWit(Example.a),

    pub fn handler(ist: *Example.State) void {
        switch (genMsg()) {
            .AddOneThenToA => |wit| {
                ist.counter_b += 1;
                wit.handler(ist);
            },
        }
    }

    fn genMsg() @This() {
        return .AddOneThenToA;
    }
};

pub fn select_st(
    T: type,
    current_st: T,
    a: typedFsm.sdzx(T),
    b: typedFsm.sdzx(T),
    State: type,
) type {
    return union(enum) {
        SelectA: RWit(a),
        SelectB: RWit(b),
        Retry: RWit(typedFsm.sdzx(T).C(current_st, &.{ a, b })),

        fn RWit(val: typedFsm.sdzx(T)) type {
            return typedFsm.Witness(T, val, State, null);
        }

        pub fn handler(ist: *State) void {
            switch (genMsg()) {
                .SelectA => |wit| wit.handler(ist),
                .SelectB => |wit| wit.handler(ist),
                .Retry => |wit| wit.handler(ist),
            }
        }

        const stdIn = std.io.getStdIn().reader();
        var buf: [10]u8 = @splat(0);

        fn genMsg() @This() {
            std.debug.print(
                \\Input your select:
                \\y={}, n={}
                \\
            ,
                .{ a, b },
            );

            const st = stdIn.readUntilDelimiter(&buf, '\n') catch |err| {
                std.debug.print("Input error: {any}, retry\n", .{err});
                return .Retry;
            };

            if (std.mem.eql(u8, st, "y")) {
                return .SelectA;
            } else if (std.mem.eql(u8, st, "n")) {
                return .SelectB;
            } else {
                std.debug.print(
                    \\Error input: {s}
                    \\You cant input: y={}, n={}
                    \\
                , .{ st, a, b });
                return .Retry;
            }
        }
    };
}
