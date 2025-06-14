const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const typed_fsm_mod = b.addModule("root", .{
        .root_source_file = b.path("src/polystate.zig"),
        .target = target,
        .optimize = optimize,
    });

    const lib = b.addStaticLibrary(.{
        .name = "polystate",
        .root_module = typed_fsm_mod,
    });

    b.installArtifact(lib);
}
