const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const polystate = b.addModule("root", .{
        .root_source_file = b.path("src/polystate.zig"),
        .target = target,
        .optimize = optimize,
    });

    const lib = b.addStaticLibrary(.{
        .name = "polystate",
        .root_module = polystate,
    });

    b.installArtifact(lib);

    const mod_tests = b.addTest(.{
        .root_module = polystate,
    });
    const run_mod_tests = b.addRunArtifact(mod_tests);
    const test_step = b.step("test", "Run tests");
    test_step.dependOn(&run_mod_tests.step);
}
