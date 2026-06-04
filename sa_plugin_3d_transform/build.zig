const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});
    const sa_repo_root = b.option([]const u8, "sa-repo-root", "SA repository root used to resolve the host binary.") orelse "/home/vscode/projects/sci";
    const sa_bin = b.option([]const u8, "sa-bin", "Path to the SA host binary used for module SA tests.") orelse b.pathJoin(&.{ sa_repo_root, "zig-out/bin/sa" });

    const plugin_api = b.createModule(.{ .root_source_file = b.path("../common/plugin_api.zig"), .target = target, .optimize = optimize });
    const module_config = b.createModule(.{ .root_source_file = b.path("src/module_config.zig"), .target = target, .optimize = optimize });
    const module_plugin = b.createModule(.{ .root_source_file = b.path("../common/module_plugin.zig"), .target = target, .optimize = optimize });
    module_plugin.addImport("plugin_api", plugin_api);
    module_plugin.addImport("module_config", module_config);

    const root_module = b.createModule(.{ .root_source_file = b.path("src/plugin.zig"), .target = target, .optimize = optimize });
    root_module.addImport("module_plugin", module_plugin);

    const lib = b.addLibrary(.{ .name = "3d_transform", .root_module = root_module, .linkage = .dynamic });
    b.installArtifact(lib);
    b.installFile("3d_transform.sal", "share/3d_transform.sal");

    const tests = b.addTest(.{ .root_module = root_module });
    const run_tests = b.addRunArtifact(tests);
    const test_step = b.step("test", "Run 3D transform plugin tests");
    test_step.dependOn(&run_tests.step);
    test_step.dependOn(b.getInstallStep());

    const sa_layout_test = b.addSystemCommand(&.{ sa_bin, "test", "tests/3d_transform_layout_test.sa" });
    const installed_lib = b.getInstallPath(.lib, "lib3d_transform.so");
    sa_layout_test.setEnvironmentVariable("SA_PLUGINS_PATH", installed_lib);
    sa_layout_test.addFileInput(b.path("tests/3d_transform_layout_test.sa"));
    sa_layout_test.addFileInput(b.path("3d_transform.sal"));
    sa_layout_test.addFileInput(b.path("../sa_plugin_3d_math/3d_math.sal"));
    sa_layout_test.addFileInput(lib.getEmittedBin());
    sa_layout_test.step.dependOn(b.getInstallStep());
    test_step.dependOn(&sa_layout_test.step);
}
