Writing this document was more difficult than I imagined. Although I have been writing and using this library for a while, it is not easy to explain it clearly to others.

If you have any questions after reading the documentation, please do not hesitate to ask me. I will be happy to answer your questions!

You can contact me via issues, Discord, or email.

The finite state machine is a very powerful programming pattern. When combined with composability and type safety, it becomes an ideal programming paradigm.

`polystate` is a library designed to achieve this effect. It relies on a few programming conventions to work.

But please believe me, these conventions are very simple and completely worth it.

The core design philosophy of `polystate`:
1.  Record the state of the state machine at the type level.
2.  Achieve composite state machines by composing types.

The actual effects achieved:
1.  The overall behavior of the program can be determined through compositional declarations. This means we have the ability to define the program's overall behavior at the type level. This greatly improves the correctness of imperative program structures. At the same time, this programming style encourages us to redesign the program's state from the perspective of types and composition, thereby enhancing code composability.
2.  Complex state machines can be built by composing simple states. Here, for the first time, we have achieved semantic-level code reuse through type composition. In other words, we have found a type-level expression for semantic-level code reuse. This approach achieves a threefold effect: simplicity, correctness, and safety.

This is a great advancement in imperative programming.

Since the overall program behavior is determined by declarations, `polystate` provides the ability to automatically generate state diagrams.

This allows users to intuitively understand the program's overall behavior through state diagrams.

The following sections will explain the two core design philosophies and the two actual effects mentioned above in detail.

Let's start with a concrete example of a simple state machine. I will introduce the core design concepts of this library in detail through comments in the code.

```zig
const std = @import("std");
const polystate = @import("polystate");

pub fn main() !void {
    var st: GST = .{};
    /// Determine an initial state
    const wa = Example.Wit(Example.a){};
    /// Start executing the state machine with the message handler of this initial state.
    /// As for why handler_normal is used here, it is related to tail call optimization, which I will explain in detail later.
    wa.handler_normal(&st);
}

pub const GST = struct {
    counter_a: i64 = 0,
    counter_b: i64 = 0,
};

/// `polystate` has two core state types: FST (FSM Type) and GST (Global State Type).
/// FST can only be an enum type. In this example, the FST is `Example`, which defines all the states of our state machine,
/// or rather, it defines the set of states we will track at the type level.
/// GST is the global data. The GST for this example is defined above, with two fields: `counter_a` and `counter_b`,
/// representing the data needed by state `a` and state `b` respectively.
/// When we compose states, what we really want is to compose state handler functions. This implies a requirement for global data.
/// Therefore, the first programming convention is: the handler function of any state has access to the GST (i.e., global data),
/// but the user should try to only use the data corresponding to the current state.
/// For example, in the handler for state `a`, only the `counter_a` data should be used.
/// This can be easily achieved through some naming conventions, and generic functions for this purpose can be easily created with metaprogramming,
/// but the specific implementation is outside the scope of `polystate`.
const Example = enum {
    /// Three concrete states are defined here.
    exit,
    a,
    b,

    /// `Wit` is a core concept in `polystate`, short for Witness. The term comes from [Haskell](https://serokell.io/blog/haskell-type-level-witness),
    /// where it is called a 'type witness' or 'runtime evidence'.
    /// A finite state machine has four core components: state, message, message handler, and message generator.
    /// I will detail these parts in the example below.
    /// The purpose of the `Wit` function is to specify the state information contained in a message.
    pub fn Wit(val: anytype) type {
        return polystate.Witness(@This(), GST, null, polystate.val_to_sdzx(@This(), val));
    }

    /// This is the second programming convention: The FST needs to have a public declaration containing the specific content of the state.
    /// By appending `ST` to the state name, the state is implicitly associated with its specific content.
    /// In this example, this corresponds to the public declarations below:
    /// exit ~ exitST
    /// a    ~ aST
    /// b    ~ bST
    /// Here, `exitST` describes the four parts for the `exit` state: state, message, message handler, and message generator.
    /// Since the `exit` state has no messages, it also has no message generator.
    /// This is the third programming convention: The implementation of the state's specific content must contain a function: `pub fn handler(*GST) void` or `pub fn conthandler(*GST) ContR`.
    /// They represent the message handler function. The former indicates that the state machine fully owns the control flow.
    /// The latter indicates that a continuation function is returned, letting the caller invoke it and transferring control flow to the caller.
    pub const exitST = union(enum) {
        pub fn handler(ist: *GST) void {
            std.debug.print("exit\n", .{});
            std.debug.print("st: {any}\n", .{ist.*});
        }
    };
    pub const aST = a_st;
    pub const bST = b_st;
};

/// This describes the four parts for being in state `a`: state, message, message handler, and message generator.
/// 1. State
/// The state here is `a`.
pub const a_st = union(enum) {
    /// 2. Message
    /// A tagged union is used here to describe messages. `Wit` is used to describe the state we are about to transition to.
    AddOneThenToB: Example.Wit(Example.b),
    Exit: Example.Wit(Example.exit),

    /// 3. Message Handler
    /// Handles all messages generated by `genMsg`.
    pub fn handler(ist: *GST) void {
        switch (genMsg(ist)) {
            .AddOneThenToB => |wit| {
                ist.counter_a += 1;
                /// This is the fourth programming convention: At the end of a message handling block,
                /// you must include `wit.handler(ist)` or similar code.
                /// This indicates that the message handler for the new state will be executed.
                /// The new state is controlled by the message's `Wit` function.
                wit.handler(ist);
            },
            .Exit => |wit| wit.handler(ist),
        }
    }

    /// 4. Message Generator
    /// If the value of `counter_a` is greater than 3, return `.Exit`.
    /// Otherwise, return `.AddOneThenToB`.
    /// The messages generated and handled here are defined in part 2 above.
    fn genMsg(ist: *GST) @This() {
        if (ist.counter_a > 3) return .Exit;
        return .AddOneThenToB;
    }
};

pub const b_st = union(enum) {
    AddOneThenToA: Example.Wit(Example.a),

    pub fn handler(ist: *GST) void {
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

```
The example above shows how to build a simple state machine with `polystate`.

This example does not demonstrate the most powerful feature of `polystate`: composability.

Let me modify the above example to add a new state, `yes_or_no`, to demonstrate composability.

I will omit some of the code that is identical to the above. The specific code for this example can be [found here](https://github.com/sdzx-1/polystate-examples/blob/main/src/exe-counter.zig).

```zig
const std = @import("std");
const polystate = @import("polystate");

pub fn main() !void {
   ...
}

pub const GST = struct {
  ...
  buf: [10] u8 = @splat(0),
};

///Example
const Example = enum {
    exit,
    a,
    b,
    /// A new state `yes_or_no` is defined here.
    yes_or_no,

    pub fn Wit(val: anytype) type {
        ...
    }

    pub const exitST = union(enum) {
      ...
    };
    pub const aST = a_st;
    pub const bST = b_st;

    /// The implementation of the new state is a function that depends on two state parameters: `yes` and `no`.
    /// Its semantic is to provide an interactive choice for the user: if the user chooses 'yes', it transitions to the state corresponding to `yes`,
    /// and if the user chooses 'no', it transitions to the state corresponding to `no`.
    /// The `sdzx` function here turns a regular enum type into a new, composable type.
    /// For example, I can use: `polystate.sdzx(Example).C(.yes_or_no, &.{ .a, .b })` to represent the state `(yes_or_no, a, b)`.
    /// I usually write this type as `yes_or_no(a, b)`, which indicates that `yes_or_no` is a special kind of state that requires two concrete state parameters.
    /// Semantically, `yes_or_no(exit, a)` means: user confirmation is required before exiting. If the user chooses 'yes', it will enter the `exit` state; if 'no', it will enter the `a` state.
    /// Similarly, `yes_or_no(yes_or_no(exit, a), a)` means: user needs to confirm twice before exiting. The user must choose 'yes' both times to exit.
    /// This is the meaning of composability. Make sure you understand this part.
    pub fn yes_or_noST(yes: polystate.sdzx(@This()), no: polystate.sdzx(@This())) type {
        return yes_or_no_st(@This(), yes, no, GST);
    }
};

pub const a_st = union(enum) {
    AddOneThenToB: Example.Wit(Example.b),
    /// This shows how to build and use composite messages in the code.
    /// For a composite message, it needs to be placed in a tuple. The first element is the function-like state, and the rest are its state parameters.
    /// Here, `.{ Example.yes_or_no, Example.exit, Example.a }` represents the state: `yes_or_no(exit, a)`.
    Exit: Example.Wit(.{ Example.yes_or_no, Example.exit, Example.a }),
    /// Similarly, `.{ Example.yes_or_no, .{Example.yes_or_no, Example.exit, Example.a}, Example.a }` can be used to represent the state: `yes_or_no(yes_or_no(exit, a), a)`.
    ...
};

pub const b_st = union(enum) {
  ...
};

/// Specific implementation of the `yes_or_no` state.
/// First, it is a function that takes four parameters: FST, GST1, yes, and no. Note that it does not require any information from `Example`.
/// This means its implementation is completely independent of `Example`, making it a generic implementation that can be used in any state machine.
/// I will again explain this code in four parts: state, message, message handler, and message generator.
pub fn yes_or_no_st(
    FST: type,
    GST1: type,
    yes: polystate.sdzx(FST),
    no: polystate.sdzx(FST),
) type {
    /// 1. State
    /// Its specific state is: `polystate.sdzx(FST).C(FST.yes_or_no, &.{ yes, no })`.
    /// It requires two parameters, `yes` and `no`, and also ensures that `FST` must have `yes_or_no`.
    return union(enum) {
        /// 2. Message
        /// There are three messages here. Of particular note is `Retry`, which represents the semantic of re-entering due to an input error.
        Yes: Wit(yes),
        No: Wit(no),
        /// Note the state constructed here; it points to itself.
        Retry: Wit(polystate.sdzx(FST).C(FST.yes_or_no, &.{ yes, no })),

        fn Wit(val: polystate.sdzx(FST)) type {
            return polystate.Witness(FST, GST1, null, val);
        }

        /// 3. Message Handler
        pub fn handler(gst: *GST1) void {
            switch (genMsg(gst)) {
                .Yes => |wit| wit.handler(gst),
                .No => |wit| wit.handler(gst),
                .Retry => |wit| wit.handler(gst),
            }
        }

        const stdIn = std.io.getStdIn().reader();

        /// 4. Message Generator
        /// Reads a string from stdIn. If the string is "y", it returns the message `.Yes`. If it is "n", it returns `.No`.
        /// In other cases, it returns `.Retry`.
        fn genMsg(gst: *GST) @This() {
            std.debug.print(
                \\Yes Or No:
                \\y={}, n={}
                \\
            ,
                .{ yes, no },
            );

            const st = stdIn.readUntilDelimiter(&gst.buf, '\n') catch |err| {
                std.debug.print("Input error: {any}, retry\n", .{err});
                return .Retry;
            };

            if (std.mem.eql(u8, st, "y")) {
                return .Yes;
            } else if (std.mem.eql(u8, st, "n")) {
                return .No;
            } else {
                std.debug.print("Error input: {s}\n", .{st});
                return .Retry;
            }
        }
    };
}
```
This example should illustrate how to achieve a composite state machine by composing types.

Next, I will show two examples of `polystate` in practical use.

First: [atm](https://github.com/sdzx-1/polystate-examples/blob/main/src/exe-atm.zig)

There is an ATM. When we are in the `checkPin` state, we ask the user to input a PIN from an external source. Then we check if the PIN is correct. If it is correct, we transition to the state corresponding to `Successed`. If it's wrong, we go to the `Failed` state.

A common requirement is: the user can try to enter the PIN at most three times. If all three attempts fail, the card should be ejected, and the machine should return to the initial screen.

This "three times" is a crucial security parameter and should not be changed.

We can naturally implement this effect through state composition. By designing `checkPin` as a generic state, we can then precisely describe this behavior on specific messages through state composition.

```zig
  pub fn checkPinST(success: polystate.sdzx(Atm), failed: polystate.sdzx(Atm)) type {
        return union(enum) {
            Successed: polystate.Witness(Atm, GST, null, success),
            Failed: polystate.Witness(Atm, GST, null, failed),

            ...
            ...
        }
  }

    pub const readyST = union(enum) {
        /// By nesting the declaration of `checkPin` three times, we ensure that the PIN check action occurs at most three times.
        /// This precisely describes our desired behavior.
        /// This demonstrates determining the program's overall behavior through compositional declarations.
        InsertCard: Wit(.{ Atm.checkPin, Atm.session, .{ Atm.checkPin, Atm.session, .{ Atm.checkPin, Atm.session, Atm.ready } } }),
        Exit: Wit(.{ Atm.are_you_sure, Atm.exit, Atm.ready }),

        ...
    }

```

Second: [select](https://github.com/sdzx-1/ray-game/blob/master/src/select.zig)

I used raylib to implement a generic semantic: selection via mouse (hereinafter referred to as "selection").

```zig

pub fn selectST(
    FST: type,
    GST: type,
    enter_fn: ?fn (polystate.sdzx(FST), *GST) void,
    back: polystate.sdzx(FST),
    selected: polystate.sdzx(FST),
) type {
    const cst = polystate.sdzx_to_cst(FST, selected);
    const SDZX = polystate.sdzx(FST);

    return union(enum) {
        // zig fmt: off
        ToBack  : polystate.Witness(FST, GST, enter_fn, back),
        ToInside: polystate.Witness(FST, GST, enter_fn, SDZX.C(FST.inside, &.{ back, selected })),
        // zig fmt: on
       ...
    };
}

pub fn insideST(
    FST: type,
    GST: type,
    enter_fn: ?fn (polystate.sdzx(FST), *GST) void,
    back: polystate.sdzx(FST),
    selected: polystate.sdzx(FST),
) type {
    const cst = polystate.sdzx_to_cst(FST, selected);
    const SDZX = polystate.sdzx(FST);

    return union(enum) {
        // zig fmt: off
        ToBack    : polystate.Witness(FST, GST, enter_fn, back),
        ToOutside : polystate.Witness(FST, GST, enter_fn, SDZX.C(FST.select, &.{ back, selected })),
        ToHover   : polystate.Witness(FST, GST, enter_fn, SDZX.C(FST.hover, &.{ back, selected })),
        ToSelected: polystate.Witness(FST, GST, enter_fn, selected),
        // zig fmt: on
       ...
    };
}

pub fn hoverST(
    FST: type,
    GST: type,
    enter_fn: ?fn (polystate.sdzx(FST), *GST) void,
    back: polystate.sdzx(FST),
    selected: polystate.sdzx(FST),
) type {
    const cst = polystate.sdzx_to_cst(FST, selected);
    const SDZX = polystate.sdzx(FST);

    return union(enum) {
        // zig fmt: off
        ToBack    : polystate.Witness(FST, GST, enter_fn, back),
        ToOutside : polystate.Witness(FST, GST, enter_fn, SDZX.C(FST.select, &.{ back, selected })),
        ToInside  : polystate.Witness(FST, GST, enter_fn, SDZX.C(FST.inside, &.{ back, selected })),
        ToSelected: polystate.Witness(FST, GST, enter_fn, selected),
        // zig fmt: on

       ...
    };
}

```
The specific behavior of selection is composed of three generic states and ten messages.

These states and messages implement the selection of an element with the mouse, as well as how to respond on mouse hover.

In the `ray-game` project, the selection semantic is reused at least eight times, which greatly reduces code and improves correctness.

An interesting example from this project: you need to select a building to place on a grid. I call this a two-stage selection.

It requires two selections: first, select a building, and second, select a location. The choice of building also constrains the choice of location. ![select_twice](data/select_twice.gif)

This semantic is expressed as:
```zig
pub const placeST = union(enum) {
    ToPlay: Wit(.{ Example.select, Example.play, .{ Example.select, Example.play, Example.place } }),
    ...
};

```
This code very concisely describes our intent, but if you look at the state diagram, you will find that its actual state is very complex.

![graph](data/graph.png)

Through a simple declaration, we have nestedly reused complex selection semantics code. This is a huge victory!!

[The complete code for all this is right here](https://github.com/sdzx-1/ray-game/blob/587f1698cb717c393c3680060a057ac8b02d89c2/src/play.zig#L33), about 130 lines of code. 