const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const build_examples = b.option(bool, "examples", "build all examples") orelse false;

    const type_fsm_mod = b.createModule(.{
        .root_source_file = b.path("src/typed-fsm.zig"),
        .target = target,
        .optimize = optimize,
    });

    if (build_examples) {
        {
            const exe_mod = b.createModule(.{
                .root_source_file = b.path("examples/atm-gui.zig"),
                .target = target,
                .optimize = optimize,
            });

            const exe = b.addExecutable(.{
                .name = "atm-gui",
                .root_module = exe_mod,
            });
            exe.root_module.addImport("typed-fsm", type_fsm_mod);

            {
                { // zgui and deps
                    const zglfw = b.dependency("zglfw", .{
                        .target = target,
                    });
                    exe.root_module.addImport("zglfw", zglfw.module("root"));
                    exe.linkLibrary(zglfw.artifact("glfw"));

                    const zopengl = b.dependency("zopengl", .{});
                    exe.root_module.addImport("zopengl", zopengl.module("root"));

                    const zgui = b.dependency("zgui", .{
                        .target = target,
                        .backend = .glfw_opengl3,
                    });
                    exe.root_module.addImport("zgui", zgui.module("root"));
                    exe.linkLibrary(zgui.artifact("imgui"));
                }

                { //add options
                    const exe_options = b.addOptions();
                    exe.root_module.addOptions("build_options", exe_options);
                    exe_options.addOption([]const u8, "content_dir", "data/");
                }

                { // install font
                    const install_content_step = b.addInstallFile(
                        b.path("data/FiraMono.ttf"),
                        b.pathJoin(&.{ "bin", "data/FiraMono.ttf" }),
                    );
                    exe.step.dependOn(&install_content_step.step);
                }

                b.installArtifact(exe);

                const run_cmd = b.addRunArtifact(exe);

                run_cmd.step.dependOn(b.getInstallStep());

                if (b.args) |args| {
                    run_cmd.addArgs(args);
                }

                const run_step = b.step("atm-gui", "Run atm-gui");
                run_step.dependOn(&run_cmd.step);
            }
        }
    }
}
