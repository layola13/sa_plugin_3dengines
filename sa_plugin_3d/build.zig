const std = @import("std");
const sa3d_airlock_gen = @import("src/sa3d_airlock_gen.zig");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});
    const sa_repo_root = b.option([]const u8, "sa-repo-root", "SA repository root used to resolve the host binary.") orelse "/home/vscode/projects/sci";
    const sa_bin = b.option([]const u8, "sa-bin", "Path to the SA host binary used for module SA tests.") orelse b.pathJoin(&.{ sa_repo_root, "zig-out/bin/sa" });
    const sax_lib = b.option([]const u8, "sax-lib", "Path to the SAX plugin dynamic library used for SA3D demo builds.") orelse "/home/vscode/projects/sa_plugins/sa_plugin_sax/zig-out/lib/libsax.so";

    const sci_root = b.option([]const u8, "sci-root", "Path to the sci checkout") orelse sa_repo_root;
    const sio_module = b.createModule(.{
        .root_source_file = .{ .cwd_relative = b.pathJoin(&.{ sci_root, "src", "sa_io.zig" }) },
        .target = target,
        .optimize = optimize,
    });

    const plugin_api = b.createModule(.{ .root_source_file = b.path("../common/plugin_api.zig"), .target = target, .optimize = optimize });
    const module_config = b.createModule(.{ .root_source_file = b.path("src/module_config.zig"), .target = target, .optimize = optimize });
    const module_plugin = b.createModule(.{ .root_source_file = b.path("../common/module_plugin.zig"), .target = target, .optimize = optimize });
    module_plugin.addImport("plugin_api", plugin_api);
    module_plugin.addImport("module_config", module_config);

    const root_module = b.createModule(.{ .root_source_file = b.path("src/plugin.zig"), .target = target, .optimize = optimize });
    root_module.addImport("plugin_api", plugin_api);
    root_module.addImport("sio", sio_module);
    root_module.addImport("module_config", module_config);
    root_module.addImport("module_plugin", module_plugin);

    const lib = b.addLibrary(.{ .name = "3d", .root_module = root_module, .linkage = .dynamic });
    b.installArtifact(lib);

    const write_files = b.addWriteFiles();
    const airlock_file = write_files.add("sa3d_airlock.js", sa3d_airlock_gen.source);
    const install_airlock = b.addInstallFile(airlock_file, "share/sa3d_airlock.js");
    b.getInstallStep().dependOn(&install_airlock.step);
    b.installFile("3d.sal", "share/3d.sal");
    b.installFile("sa3d.sai", "share/sa3d.sai");
    b.installFile("sa3d.sal", "share/sa3d.sal");
    b.installFile("demos/rotating_cube_3d.sax", "share/demos/rotating_cube_3d.sax");
    b.installFile("demos/rotating_cube_3d_decl.sax3d", "share/demos/rotating_cube_3d_decl.sax3d");
    b.installFile("demos/scene_cubes_3d.sax", "share/demos/scene_cubes_3d.sax");
    b.installFile("tools/lower_sa3d_scene.mjs", "share/tools/lower_sa3d_scene.mjs");

    const tests = b.addTest(.{ .root_module = root_module });
    const run_tests = b.addRunArtifact(tests);
    const test_step = b.step("test", "Run aggregate 3D plugin tests");
    test_step.dependOn(&run_tests.step);
    test_step.dependOn(b.getInstallStep());

    const sa_layout_test = b.addSystemCommand(&.{ sa_bin, "test", "tests/3d_aggregate_layout_test.sa" });
    sa_layout_test.addFileInput(b.path("tests/3d_aggregate_layout_test.sa"));
    sa_layout_test.addFileInput(b.path("3d.sal"));
    test_step.dependOn(&sa_layout_test.step);

    const sa3d_sidecar_test = b.addSystemCommand(&.{ sa_bin, "test", "tests/sa3d_sidecar_layout_test.sa" });
    sa3d_sidecar_test.addFileInput(b.path("tests/sa3d_sidecar_layout_test.sa"));
    sa3d_sidecar_test.addFileInput(b.path("sa3d.sai"));
    sa3d_sidecar_test.addFileInput(b.path("sa3d.sal"));
    test_step.dependOn(&sa3d_sidecar_test.step);

    const sa3d_scene_cubes_test = b.addSystemCommand(&.{ sa_bin, "test", "tests/sa3d_scene_cubes_layout_test.sa" });
    sa3d_scene_cubes_test.addFileInput(b.path("tests/sa3d_scene_cubes_layout_test.sa"));
    sa3d_scene_cubes_test.addFileInput(b.path("sa3d.sai"));
    sa3d_scene_cubes_test.addFileInput(b.path("sa3d.sal"));
    test_step.dependOn(&sa3d_scene_cubes_test.step);

    const verify_airlock = b.addSystemCommand(&.{ "node", "tools/verify_sa3d_airlock.mjs" });
    verify_airlock.addFileInput(b.path("tools/verify_sa3d_airlock.mjs"));
    verify_airlock.addFileArg(airlock_file);
    test_step.dependOn(&verify_airlock.step);

    const installed_lib = b.pathJoin(&.{ "zig-out", "lib", "lib3d.so" });
    const plugin_path = b.fmt("{s}:{s}", .{ sax_lib, installed_lib });
    const demo_input = b.path("demos/rotating_cube_3d.sax");
    const sax_lib_input: std.Build.LazyPath = .{ .cwd_relative = sax_lib };

    const demo_build = b.addSystemCommand(&.{ sa_bin, "sax", "build", "demos/rotating_cube_3d.sax", "--out-dir" });
    const demo_output = demo_build.addOutputDirectoryArg("sa3d-rotating-cube");
    demo_build.setEnvironmentVariable("SA_PLUGINS_PATH", plugin_path);
    demo_build.addFileInput(demo_input);
    demo_build.addFileInput(sax_lib_input);
    demo_build.addFileInput(lib.getEmittedBin());
    demo_build.step.dependOn(b.getInstallStep());
    test_step.dependOn(&demo_build.step);

    const verify_dist = b.addSystemCommand(&.{ "node", "tools/verify_sa3d_sax_dist.mjs" });
    verify_dist.addFileInput(b.path("tools/verify_sa3d_sax_dist.mjs"));
    verify_dist.addDirectoryArg(demo_output);
    test_step.dependOn(&verify_dist.step);

    const scene_demo_input = b.path("demos/scene_cubes_3d.sax");
    const scene_demo_build = b.addSystemCommand(&.{ sa_bin, "sax", "build", "demos/scene_cubes_3d.sax", "--out-dir" });
    const scene_demo_output = scene_demo_build.addOutputDirectoryArg("sa3d-scene-cubes");
    scene_demo_build.setEnvironmentVariable("SA_PLUGINS_PATH", plugin_path);
    scene_demo_build.addFileInput(scene_demo_input);
    scene_demo_build.addFileInput(sax_lib_input);
    scene_demo_build.addFileInput(lib.getEmittedBin());
    scene_demo_build.step.dependOn(b.getInstallStep());
    test_step.dependOn(&scene_demo_build.step);

    const verify_scene_dist = b.addSystemCommand(&.{ "node", "tools/verify_sa3d_scene_cubes_dist.mjs" });
    verify_scene_dist.addFileInput(b.path("tools/verify_sa3d_scene_cubes_dist.mjs"));
    verify_scene_dist.addDirectoryArg(scene_demo_output);
    test_step.dependOn(&verify_scene_dist.step);

    const lower_decl_scene = b.addSystemCommand(&.{ "node", "tools/lower_sa3d_scene.mjs", "demos/rotating_cube_3d_decl.sax3d" });
    lower_decl_scene.addFileInput(b.path("tools/lower_sa3d_scene.mjs"));
    lower_decl_scene.addFileInput(b.path("demos/rotating_cube_3d_decl.sax3d"));
    const lowered_scene = lower_decl_scene.addOutputFileArg("rotating_cube_3d_decl.lowered.sax");

    const verify_lowered_scene = b.addSystemCommand(&.{ "node", "tools/verify_sa3d_scene_lowering.mjs" });
    verify_lowered_scene.addFileInput(b.path("tools/verify_sa3d_scene_lowering.mjs"));
    verify_lowered_scene.addFileArg(lowered_scene);
    test_step.dependOn(&verify_lowered_scene.step);

    const check_lowered_scene = b.addSystemCommand(&.{ sa_bin, "sax", "check" });
    check_lowered_scene.addFileArg(lowered_scene);
    check_lowered_scene.setEnvironmentVariable("SA_PLUGINS_PATH", plugin_path);
    check_lowered_scene.addFileInput(sax_lib_input);
    check_lowered_scene.addFileInput(lib.getEmittedBin());
    check_lowered_scene.step.dependOn(b.getInstallStep());
    test_step.dependOn(&check_lowered_scene.step);
}
