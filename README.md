
# Building and using
## In an existing project
Download and add type-fsm-zig as a dependency by running the following command in your project root:
```shell
zig fetch --save git+https://github.com/sdzx-1/typed-fsm-zig.git
```

Then add typed-fsm-zig as a dependency and import its modules and artifact in your build.zig:

```zig
    const typed_fsm = b.dependency("typed_fsm", .{
        .target = target,
        .optimize = optimize,
    });

```

Now add the modules to your module as you would normally:

```zig
    exe_mod.addImport("typed_fsm", typed_fsm.module("root"));
```

# Examples

[typed-fsm-examples](https://github.com/sdzx-1/typed-fsm-examples)

# Discord

https://discord.gg/zUK2Zk9m


