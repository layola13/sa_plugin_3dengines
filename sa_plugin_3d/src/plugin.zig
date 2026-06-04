const std = @import("std");
const plugin_api = @import("plugin_api");
const config = @import("module_config");
const sa3d_airlock_gen = @import("sa3d_airlock_gen.zig");

const rotating_cube_sax =
    \\<Component name="Sa3dCube">
    \\  <state>
    \\    sa3d_ctx = 0
    \\  </state>
    \\
    \\  <section class="sa3d-stage">
    \\    <h1>SA 3D Engine Cube</h1>
    \\    <canvas id="sa3d-canvas" width="1024" height="768" renderer="sa3d"></canvas>
    \\  </section>
    \\
    \\  @ffi_wrapper onMount:
    \\  L_ENTRY:
    \\    canvas = call @sax_dom_query(*SA3D_CUBE_CANVAS_SELECTOR, SA3D_CUBE_CANVAS_SELECTOR_LEN)
    \\    out_ctx = stack_alloc 8
    \\    rc_ctx = call @sa3d_request_context(canvas, *out_ctx)
    \\    ctx_h = load out_ctx+0 as i64
    \\    store state+Sa3dCube_sa3d_ctx, ctx_h as i64
    \\    ret
    \\
    \\  !sa3d_ctx
    \\</Component>
    \\
;

const declarative_cube_sax3d =
    \\<Scene3D name="Sa3dCubeScene">
    \\  <Camera id="main" />
    \\  <Mesh id="cube" primitive="cube" />
    \\  <Material id="cube_material" model="unlit" />
    \\</Scene3D>
    \\
;

const skills = [_]plugin_api.SkillSection{
    .{
        .name = config.skill_name,
        .summary = config.skill_summary,
        .items = config.skill_items[0..],
    },
    .{
        .name = "3d.browser.wgpu",
        .summary = "Browser WebGPU airlock and SAX demo assets for SA3D",
        .items = &.{
            "3d airlock [--out <path>]",
            "3d new <dir>",
            "3d check-demo <file.sax>",
            "keeps shader, mesh, scene, and frame data in SA/WASM memory",
        },
    },
};

fn cArgvToSlice(argv: [*]const [*:0]const u8, argv_len: usize, allocator: std.mem.Allocator) ![]const []const u8 {
    const slice = argv[0..argv_len];
    var out = try allocator.alloc([]const u8, slice.len);
    errdefer allocator.free(out);
    for (slice, 0..) |arg, idx| out[idx] = std.mem.span(arg);
    return out;
}

fn anyWriterFromHostStream(stream: plugin_api.HostStream, storage: *plugin_api.HostStream) ?std.io.AnyWriter {
    if (stream.write_all == null) return null;
    storage.* = stream;
    return .{ .context = storage, .writeFn = struct {
        fn write(ctx: *const anyopaque, bytes: []const u8) anyerror!usize {
            const hs = @as(*const plugin_api.HostStream, @ptrCast(@alignCast(ctx)));
            const write_all = hs.write_all orelse return error.WriteFailed;
            if (write_all(hs.ctx, bytes.ptr, bytes.len) != @intFromEnum(plugin_api.AbiStatus.ok)) return error.WriteFailed;
            return bytes.len;
        }
    }.write };
}

fn ensureParentDir(path: []const u8) !void {
    if (std.fs.path.dirname(path)) |dir| {
        if (dir.len != 0) try std.fs.cwd().makePath(dir);
    }
}

fn writeAllFile(path: []const u8, bytes: []const u8) !void {
    try ensureParentDir(path);
    var file = try std.fs.cwd().createFile(path, .{ .truncate = true });
    defer file.close();
    try file.writeAll(bytes);
}

fn readSource(allocator: std.mem.Allocator, path: []const u8) ![]u8 {
    return std.fs.cwd().readFileAlloc(allocator, path, 16 * 1024 * 1024) catch |err| switch (err) {
        error.FileNotFound => return error.FileNotFound,
        error.AccessDenied => return error.AccessDenied,
        error.IsDir => return error.NotDir,
        else => return error.InvalidPath,
    };
}

fn writeInfo(stdout: std.io.AnyWriter) !void {
    try stdout.print("{s}\n", .{config.plugin_name});
    try stdout.print("skill: {s}\n", .{config.skill_name});
    try stdout.print("summary: {s}\n", .{config.skill_summary});
}

fn writeSkills(stdout: std.io.AnyWriter) !void {
    for (skills) |skill| {
        try stdout.print("{s}: {s}\n", .{ skill.name, skill.summary });
        for (skill.items) |item| try stdout.print("- {s}\n", .{item});
    }
}

fn writeCheck(stdout: std.io.AnyWriter) !void {
    try stdout.print("3D aggregate check passed: {s}\n", .{config.plugin_name});
    try stdout.print("descriptor abi: {d}\n", .{plugin_api.abi_version});
    try stdout.print("skills: {d}\n", .{skills.len});
    try stdout.print("airlock bytes: {d}\n", .{sa3d_airlock_gen.source.len});
}

fn writeInspectLayout(stdout: std.io.AnyWriter) !void {
    try stdout.writeAll(
        \\module: 3d
        \\sal: 3d.sal
        \\browser imports: sa3d.sai
        \\browser layouts: sa3d.sal
        \\share asset: sa3d_airlock.js
        \\contract: aggregate module bitmask plus WebGPU sidecar ABI
        \\
    );
}

fn executeAirlock(ctx: *const plugin_api.Context, argv: []const []const u8, stdout: std.io.AnyWriter) !u8 {
    var out_path: ?[]const u8 = null;
    var i: usize = 3;
    while (i < argv.len) : (i += 1) {
        if (std.mem.eql(u8, argv[i], "--out") or std.mem.eql(u8, argv[i], "-o")) {
            if (i + 1 >= argv.len) return error.MissingSourcePath;
            if (out_path != null) return error.UnexpectedArgument;
            out_path = argv[i + 1];
            i += 1;
            continue;
        }
        return error.UnexpectedArgument;
    }

    var generator = sa3d_airlock_gen.AirlockGenerator.init(ctx.allocator);
    const js = try generator.generate();
    defer js.deinit();

    if (out_path) |path| {
        try writeAllFile(path, js.items);
        try stdout.print("SA3D airlock written: {s}\n", .{path});
    } else {
        try stdout.writeAll(js.items);
    }
    return 0;
}

fn sourceLooksLikeSa3dDemo(source: []const u8) bool {
    return std.mem.containsAtLeast(u8, source, 1, "renderer=\"sa3d\"") or
        std.mem.containsAtLeast(u8, source, 1, "sa3d_request_context") or
        std.mem.containsAtLeast(u8, source, 1, "sa3d_wgpu_request_renderer") or
        std.mem.containsAtLeast(u8, source, 1, "<Scene3D");
}

fn sourceKeepsKernelOutOfJs(source: []const u8) bool {
    return std.mem.indexOf(u8, source, "<script") == null and
        std.mem.indexOf(u8, source, "navigator.gpu") == null and
        std.mem.indexOf(u8, source, "createShaderModule") == null;
}

fn executeCheckDemo(ctx: *const plugin_api.Context, sax_file: []const u8, stdout: std.io.AnyWriter, stderr: std.io.AnyWriter) !u8 {
    const source = try readSource(ctx.allocator, sax_file);
    defer ctx.allocator.free(source);

    if (!sourceLooksLikeSa3dDemo(source)) {
        try stderr.print("error[SA-3D-CHECK]: {s} does not declare an SA3D SAX surface\n", .{sax_file});
        return 1;
    }
    if (!sourceKeepsKernelOutOfJs(source)) {
        try stderr.print("error[SA-3D-CHECK]: {s} embeds browser WebGPU or script code; keep kernel material in SA/WASM\n", .{sax_file});
        return 1;
    }

    try stdout.print("SA3D demo check passed: {s}\n", .{sax_file});
    return 0;
}

fn executeNew(ctx: *const plugin_api.Context, project_name: []const u8, stdout: std.io.AnyWriter) !u8 {
    try std.fs.cwd().makePath(project_name);

    const sax_path = try std.fs.path.join(ctx.allocator, &.{ project_name, "app.sax" });
    defer ctx.allocator.free(sax_path);
    try writeAllFile(sax_path, rotating_cube_sax);

    const decl_path = try std.fs.path.join(ctx.allocator, &.{ project_name, "scene.sax3d" });
    defer ctx.allocator.free(decl_path);
    try writeAllFile(decl_path, declarative_cube_sax3d);

    const package_path = try std.fs.path.join(ctx.allocator, &.{ project_name, "package.json" });
    defer ctx.allocator.free(package_path);
    const package_json = try std.fmt.allocPrint(ctx.allocator,
        \\{{
        \\  "name": "{s}",
        \\  "private": true,
        \\  "type": "module",
        \\  "scripts": {{
        \\    "check": "sa 3d check-demo app.sax",
        \\    "build": "sa sax build app.sax --out-dir dist"
        \\  }}
        \\}}
        \\
    , .{project_name});
    defer ctx.allocator.free(package_json);
    try writeAllFile(package_path, package_json);

    try stdout.print("SA3D project created: {s}\n", .{project_name});
    try stdout.print("  app.sax: {s}\n", .{sax_path});
    try stdout.print("  scene.sax3d: {s}\n", .{decl_path});
    try stdout.print("  package.json: {s}\n", .{package_path});
    return 0;
}

fn writeUsage(writer: std.io.AnyWriter) !void {
    try writer.writeAll("usage: sa 3d <info|skills|check|inspect-layout|airlock|new|check-demo> ...\n");
}

fn run3dCommandImpl(ctx: *const plugin_api.Context, argv: []const []const u8, stdout: std.io.AnyWriter, stderr: std.io.AnyWriter) anyerror!?u8 {
    if (argv.len < 2) return null;
    if (!std.mem.eql(u8, argv[1], "3d")) return null;
    if (argv.len < 3) {
        try writeUsage(stderr);
        return 2;
    }

    const sub = argv[2];
    if (std.mem.eql(u8, sub, "info")) {
        if (argv.len != 3) return error.UnexpectedArgument;
        try writeInfo(stdout);
        return 0;
    }
    if (std.mem.eql(u8, sub, "skills")) {
        if (argv.len != 3) return error.UnexpectedArgument;
        try writeSkills(stdout);
        return 0;
    }
    if (std.mem.eql(u8, sub, "check")) {
        if (argv.len != 3) return error.UnexpectedArgument;
        try writeCheck(stdout);
        return 0;
    }
    if (std.mem.eql(u8, sub, "inspect-layout")) {
        if (argv.len != 3) return error.UnexpectedArgument;
        try writeInspectLayout(stdout);
        return 0;
    }
    if (std.mem.eql(u8, sub, "airlock")) return try executeAirlock(ctx, argv, stdout);
    if (std.mem.eql(u8, sub, "new")) {
        if (argv.len != 4) return if (argv.len < 4) error.MissingSourcePath else error.UnexpectedArgument;
        return try executeNew(ctx, argv[3], stdout);
    }
    if (std.mem.eql(u8, sub, "check-demo")) {
        if (argv.len != 4) return if (argv.len < 4) error.MissingSourcePath else error.UnexpectedArgument;
        return try executeCheckDemo(ctx, argv[3], stdout, stderr);
    }
    return error.UnknownCommand;
}

fn is3dCliError(err: anyerror) bool {
    return switch (err) {
        error.MissingSourcePath,
        error.UnexpectedArgument,
        error.UnknownCommand,
        error.InvalidPath,
        error.FileNotFound,
        error.NotDir,
        error.AccessDenied,
        => true,
        else => false,
    };
}

fn cliExitCode(err: anyerror) u8 {
    return switch (err) {
        error.UnknownCommand,
        error.MissingSourcePath,
        error.UnexpectedArgument,
        => 2,
        error.InvalidPath,
        error.FileNotFound,
        error.NotDir,
        error.AccessDenied,
        => 3,
        else => 1,
    };
}

fn writeCliError(writer: std.io.AnyWriter, err: anyerror) !void {
    const message = switch (err) {
        error.MissingSourcePath => "missing required SA3D operand",
        error.UnexpectedArgument => "unexpected SA3D argument",
        error.UnknownCommand => "unknown SA3D subcommand",
        error.InvalidPath => "invalid SA3D path",
        error.FileNotFound => "SA3D file or directory not found",
        error.NotDir => "SA3D path is not a directory",
        error.AccessDenied => "SA3D path access denied",
        else => @errorName(err),
    };
    try writer.print("error[SA-3D-CLI]: {s}\n", .{message});
    try writeUsage(writer);
}

fn run3dCommandAbi(ctx: *const plugin_api.Context, argv: [*]const [*:0]const u8, argv_len: usize, stdout: plugin_api.HostStream, stderr: plugin_api.HostStream, out_code: *u8) callconv(.c) u32 {
    out_code.* = 0;
    const args = cArgvToSlice(argv, argv_len, ctx.allocator) catch return @intFromEnum(plugin_api.AbiStatus.failed);
    defer ctx.allocator.free(args);

    var stdout_storage = stdout;
    var stderr_storage = stderr;
    const stdout_writer = anyWriterFromHostStream(stdout, &stdout_storage) orelse return @intFromEnum(plugin_api.AbiStatus.failed);
    const stderr_writer = anyWriterFromHostStream(stderr, &stderr_storage) orelse return @intFromEnum(plugin_api.AbiStatus.failed);

    const result = run3dCommandImpl(ctx, args, stdout_writer, stderr_writer) catch |err| {
        if (!is3dCliError(err)) return @intFromEnum(plugin_api.AbiStatus.failed);
        writeCliError(stderr_writer, err) catch return @intFromEnum(plugin_api.AbiStatus.failed);
        out_code.* = cliExitCode(err);
        return @intFromEnum(plugin_api.AbiStatus.ok);
    };
    if (result) |code| {
        out_code.* = code;
        return @intFromEnum(plugin_api.AbiStatus.ok);
    }
    return @intFromEnum(plugin_api.AbiStatus.unknown_command);
}

const descriptor = plugin_api.PluginDescriptor{
    .abi_version = plugin_api.abi_version,
    .descriptor_size = @as(u32, @intCast(@sizeOf(plugin_api.PluginDescriptor))),
    .name = config.plugin_name,
    .init = null,
    .prebuild = null,
    .postbuild = null,
    .handle_command = run3dCommandAbi,
    .skills_ptr = skills[0..].ptr,
    .skills_len = skills.len,
};

pub export const saasm_plugin_descriptor_v1: plugin_api.PluginDescriptor = descriptor;

pub export fn saasm_plugin_descriptor_v1_fn(out: *plugin_api.PluginDescriptor) callconv(.c) void {
    out.* = descriptor;
}

const CaptureStream = struct {
    buffer: *std.ArrayList(u8),
};

fn captureWriteAll(ctx: ?*anyopaque, bytes: [*]const u8, len: usize) callconv(.c) u32 {
    const stream = @as(*CaptureStream, @ptrCast(@alignCast(ctx orelse return @intFromEnum(plugin_api.AbiStatus.failed))));
    stream.buffer.appendSlice(bytes[0..len]) catch return @intFromEnum(plugin_api.AbiStatus.failed);
    return @intFromEnum(plugin_api.AbiStatus.ok);
}

fn captureHostStream(ctx: *CaptureStream) plugin_api.HostStream {
    return .{ .ctx = ctx, .write_all = captureWriteAll };
}

fn dupeZArgs(allocator: std.mem.Allocator, argv: []const []const u8) ![][*:0]const u8 {
    var out = try allocator.alloc([*:0]const u8, argv.len);
    errdefer allocator.free(out);
    var copied: usize = 0;
    errdefer {
        for (out[0..copied]) |arg| allocator.free(std.mem.sliceTo(arg, 0));
    }
    for (argv, 0..) |arg, idx| {
        out[idx] = try allocator.dupeZ(u8, arg);
        copied += 1;
    }
    return out;
}

fn freeZArgs(allocator: std.mem.Allocator, argv: [][*:0]const u8) void {
    for (argv) |arg| allocator.free(std.mem.sliceTo(arg, 0));
    allocator.free(argv);
}

fn invokeForTest(argv: []const []const u8, stdout_buffer: *std.ArrayList(u8), stderr_buffer: *std.ArrayList(u8)) !u8 {
    var ctx = plugin_api.Context{ .allocator = std.testing.allocator };
    var stdout_ctx = CaptureStream{ .buffer = stdout_buffer };
    var stderr_ctx = CaptureStream{ .buffer = stderr_buffer };
    const c_argv = try dupeZArgs(std.testing.allocator, argv);
    defer freeZArgs(std.testing.allocator, c_argv);
    var out_code: u8 = 255;
    const status = run3dCommandAbi(&ctx, c_argv.ptr, c_argv.len, captureHostStream(&stdout_ctx), captureHostStream(&stderr_ctx), &out_code);
    try std.testing.expectEqual(@as(u32, @intFromEnum(plugin_api.AbiStatus.ok)), status);
    return out_code;
}

test "3D aggregate descriptor exposes commands and skills" {
    try std.testing.expectEqualStrings("3d", std.mem.span(descriptor.name));
    try std.testing.expectEqual(@as(usize, 2), descriptor.skills_len);
    try std.testing.expect(descriptor.handle_command != null);
}

test "3D aggregate airlock command emits broker source" {
    var stdout_buf = std.ArrayList(u8).init(std.testing.allocator);
    defer stdout_buf.deinit();
    var stderr_buf = std.ArrayList(u8).init(std.testing.allocator);
    defer stderr_buf.deinit();
    const code = try invokeForTest(&.{ "sa", "3d", "airlock" }, &stdout_buf, &stderr_buf);
    try std.testing.expectEqual(@as(u8, 0), code);
    try std.testing.expect(std.mem.containsAtLeast(u8, stdout_buf.items, 1, "export const sax_sa3d_airlock"));
    try std.testing.expectEqual(@as(usize, 0), stderr_buf.items.len);
}

test "3D aggregate check-demo accepts bundled demo" {
    var original_cwd = try std.fs.cwd().openDir(".", .{});
    defer original_cwd.close();
    var tmp = std.testing.tmpDir(.{ .iterate = true });
    defer tmp.cleanup();
    try tmp.dir.setAsCwd();
    defer original_cwd.setAsCwd() catch {};
    try writeAllFile("app.sax", rotating_cube_sax);

    var stdout_buf = std.ArrayList(u8).init(std.testing.allocator);
    defer stdout_buf.deinit();
    var stderr_buf = std.ArrayList(u8).init(std.testing.allocator);
    defer stderr_buf.deinit();
    const code = try invokeForTest(&.{ "sa", "3d", "check-demo", "app.sax" }, &stdout_buf, &stderr_buf);
    try std.testing.expectEqual(@as(u8, 0), code);
    try std.testing.expect(std.mem.containsAtLeast(u8, stdout_buf.items, 1, "SA3D demo check passed"));
    try std.testing.expectEqual(@as(usize, 0), stderr_buf.items.len);
}

test "3D aggregate new writes demo scaffold" {
    var original_cwd = try std.fs.cwd().openDir(".", .{});
    defer original_cwd.close();
    var tmp = std.testing.tmpDir(.{ .iterate = true });
    defer tmp.cleanup();
    try tmp.dir.setAsCwd();
    defer original_cwd.setAsCwd() catch {};

    var stdout_buf = std.ArrayList(u8).init(std.testing.allocator);
    defer stdout_buf.deinit();
    var stderr_buf = std.ArrayList(u8).init(std.testing.allocator);
    defer stderr_buf.deinit();
    const code = try invokeForTest(&.{ "sa", "3d", "new", "demo" }, &stdout_buf, &stderr_buf);
    try std.testing.expectEqual(@as(u8, 0), code);
    try std.testing.expectEqual(@as(usize, 0), stderr_buf.items.len);

    const app = try std.fs.cwd().readFileAlloc(std.testing.allocator, "demo/app.sax", 1024 * 1024);
    defer std.testing.allocator.free(app);
    try std.testing.expect(std.mem.containsAtLeast(u8, app, 1, "renderer=\"sa3d\""));

    const scene = try std.fs.cwd().readFileAlloc(std.testing.allocator, "demo/scene.sax3d", 1024 * 1024);
    defer std.testing.allocator.free(scene);
    try std.testing.expect(std.mem.containsAtLeast(u8, scene, 1, "Scene3D"));
}
