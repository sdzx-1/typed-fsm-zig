const std = @import("std");

// Although this function looks imperative, note that its job is to
// declaratively construct a build graph that will be executed by an external
// runner.
pub fn build(b: *std.Build) void {
    // Standard target options allows the person running `zig build` to choose
    // what target to build for. Here we do not override the defaults, which
    // means any target is allowed, and the default is native. Other options
    // for restricting supported target set are available.
    const target = b.standardTargetOptions(.{});

    // Standard optimization options allow the person running `zig build` to select
    // between Debug, ReleaseSafe, ReleaseFast, and ReleaseSmall. Here we do not
    // set a preferred release mode, allowing the user to decide how to optimize.
    const optimize = b.standardOptimizeOption(.{});

    {
        const exe = b.addExecutable(.{
            .name = "counter",
            .root_source_file = b.path("examples/counter.zig"),
            .target = target,
            .optimize = optimize,
        });
        const @"typed-fsm" = @This().getModule(b, target, optimize);
        exe.root_module.addImport("typed-fsm", @"typed-fsm");
        b.installArtifact(exe);
        const run_cmd = b.addRunArtifact(exe);
        run_cmd.step.dependOn(b.getInstallStep());
        if (b.args) |args| {
            run_cmd.addArgs(args);
        }
        const run_step = b.step("counter", "Run the app");
        run_step.dependOn(&run_cmd.step);
    }

    {
        const exe = b.addExecutable(.{
            .name = "atm-tui",
            .root_source_file = b.path("examples/atm-tui.zig"),
            .target = target,
            .optimize = optimize,
        });
        const @"typed-fsm" = @This().getModule(b, target, optimize);
        exe.root_module.addImport("typed-fsm", @"typed-fsm");
        b.installArtifact(exe);
        const run_cmd = b.addRunArtifact(exe);
        run_cmd.step.dependOn(b.getInstallStep());
        if (b.args) |args| {
            run_cmd.addArgs(args);
        }
        const run_step = b.step("atm-tui", "Run the app");
        run_step.dependOn(&run_cmd.step);
    }

    {
        const exe = b.addExecutable(.{
            .name = "atm-gui",
            .root_source_file = b.path("examples/atm-gui.zig"),
            .target = target,
            .optimize = optimize,
        });
        const @"typed-fsm" = @This().getModule(b, target, optimize);
        exe.root_module.addImport("typed-fsm", @"typed-fsm");
        b.installArtifact(exe);
        const run_cmd = b.addRunArtifact(exe);
        run_cmd.step.dependOn(b.getInstallStep());
        if (b.args) |args| {
            run_cmd.addArgs(args);
        }
        const run_step = b.step("atm-gui", "Run the app");
        run_step.dependOn(&run_cmd.step);
    }
}

fn getModule(
    b: *std.Build,
    target: std.Build.ResolvedTarget,
    optimize: std.builtin.OptimizeMode,
) *std.Build.Module {
    if (b.modules.contains("typed-fsm")) {
        return b.modules.get("typed-fsm").?;
    }
    return b.addModule("typed-fsm", .{
        .root_source_file = b.path("src/typed-fsm.zig"),
        .target = target,
        .optimize = optimize,
    });
}
