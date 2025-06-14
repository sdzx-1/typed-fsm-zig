## PolyState: Composable Finite State Machines

## Building and using in an existing project
Download and add ploystate as a dependency by running the following command in your project root:
```shell
zig fetch --save git+https://github.com/sdzx-1/polystate.git
```

Then add ploystate as a dependency and import its modules and artifact in your build.zig:

```zig
    const polystate = b.dependency("polystate", .{
        .target = target,
        .optimize = optimize,
    });

```

Now add the modules to your module as you would normally:

```zig
    exe_mod.addImport("polystate", typed_fsm.module("root"));
```

## Examples

[typed-fsm-examples](https://github.com/sdzx-1/typed-fsm-examples)

## Discord

https://discord.gg/zUK2Zk9m


