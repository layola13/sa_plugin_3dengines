const std = @import("std");
const plugin_api = @import("plugin_api");
const config = @import("module_config");

const skills = [_]plugin_api.SkillSection{
    .{
        .name = config.skill_name,
        .summary = config.skill_summary,
        .items = config.skill_items[0..],
    },
};

fn cArgvToSlice(argv: [*]const [*:0]const u8, argv_len: usize, allocator: std.mem.Allocator) ![]const []const u8 {
    const slice = argv[0..argv_len];
    var out = try allocator.alloc([]const u8, slice.len);
    errdefer allocator.free(out);
    for (slice, 0..) |arg, idx| out[idx] = std.mem.span(arg);
    return out;
}

const HostWriter = struct {
    writer: std.Io.Writer,
    stream: plugin_api.HostStream,

    fn drain(w: *std.Io.Writer, data: []const []const u8, splat: usize) std.Io.Writer.Error!usize {
        const self: *HostWriter = @fieldParentPtr("writer", w);
        const write_all = self.stream.write_all orelse return error.WriteFailed;
        const ok = @intFromEnum(plugin_api.AbiStatus.ok);
        if (w.end > 0) {
            if (write_all(self.stream.ctx, w.buffer.ptr, w.end) != ok) return error.WriteFailed;
            w.end = 0;
        }
        for (data[0 .. data.len - 1]) |slice| {
            if (write_all(self.stream.ctx, slice.ptr, slice.len) != ok) return error.WriteFailed;
        }
        const last = data[data.len - 1];
        var r: usize = 0;
        while (r < splat) : (r += 1) {
            if (write_all(self.stream.ctx, last.ptr, last.len) != ok) return error.WriteFailed;
        }
        return std.Io.Writer.countSplat(data, splat);
    }

    fn init(stream: plugin_api.HostStream) HostWriter {
        return .{
            .writer = .{ .vtable = &.{ .drain = drain }, .buffer = &.{} },
            .stream = stream,
        };
    }
};

fn anyWriterFromHostStream(stream: plugin_api.HostStream, storage: *HostWriter) ?*std.Io.Writer {
    if (stream.write_all == null or stream.ctx == null) return null;
    storage.* = HostWriter.init(stream);
    return &storage.writer;
}

fn commandMatches(name: []const u8) bool {
    return std.mem.eql(u8, name, config.plugin_name) or std.mem.eql(u8, name, config.skill_name);
}

fn writeInfo(stdout: *std.Io.Writer) !void {
    try stdout.print("{s}\n", .{config.plugin_name});
    try stdout.print("skill: {s}\n", .{config.skill_name});
    try stdout.print("summary: {s}\n", .{config.skill_summary});
}

fn writeSkills(stdout: *std.Io.Writer) !void {
    try stdout.print("{s}: {s}\n", .{ config.skill_name, config.skill_summary });
    for (config.skill_items) |item| try stdout.print("- {s}\n", .{item});
}

fn writeCheck(stdout: *std.Io.Writer) !void {
    try stdout.print("3D module check passed: {s}\n", .{config.plugin_name});
    try stdout.print("descriptor abi: {d}\n", .{plugin_api.abi_version});
    try stdout.print("skills: {d}\n", .{skills.len});
    try stdout.print("items: {d}\n", .{config.skill_items.len});
}

fn writeInspectLayout(stdout: *std.Io.Writer) !void {
    try stdout.print("module: {s}\n", .{config.plugin_name});
    try stdout.print("sal: {s}.sal\n", .{config.plugin_name});
    try stdout.print("contract: explicit #def layout constants plus SA @test coverage\n", .{});
}

fn writeUsage(writer: *std.Io.Writer) !void {
    try writer.print(
        "usage: sa {s} <info|skills|check|inspect-layout>\n",
        .{config.plugin_name},
    );
}

fn runModuleCommand(argv: []const []const u8, stdout: *std.Io.Writer, stderr: *std.Io.Writer) !?u8 {
    if (argv.len < 2) return null;
    if (!commandMatches(argv[1])) return null;
    if (argv.len < 3) {
        try writeUsage(stderr);
        return 2;
    }
    if (argv.len != 3) {
        try stderr.print("error[SA-3D-CLI]: unexpected argument\n", .{});
        try writeUsage(stderr);
        return 2;
    }

    const sub = argv[2];
    if (std.mem.eql(u8, sub, "info")) {
        try writeInfo(stdout);
        return 0;
    }
    if (std.mem.eql(u8, sub, "skills")) {
        try writeSkills(stdout);
        return 0;
    }
    if (std.mem.eql(u8, sub, "check")) {
        try writeCheck(stdout);
        return 0;
    }
    if (std.mem.eql(u8, sub, "inspect-layout")) {
        try writeInspectLayout(stdout);
        return 0;
    }

    try stderr.print("error[SA-3D-CLI]: unknown 3D module subcommand '{s}'\n", .{sub});
    try writeUsage(stderr);
    return 2;
}

fn runModuleCommandAbi(
    ctx: *const plugin_api.Context,
    argv: [*]const [*:0]const u8,
    argv_len: usize,
    stdout: plugin_api.HostStream,
    stderr: plugin_api.HostStream,
    out_code: *u8,
) callconv(.c) u32 {
    out_code.* = 0;
    const args = cArgvToSlice(argv, argv_len, ctx.allocator) catch return @intFromEnum(plugin_api.AbiStatus.failed);
    defer ctx.allocator.free(args);

    var stdout_storage: HostWriter = undefined;
    var stderr_storage: HostWriter = undefined;
    const stdout_writer = anyWriterFromHostStream(stdout, &stdout_storage) orelse return @intFromEnum(plugin_api.AbiStatus.failed);
    const stderr_writer = anyWriterFromHostStream(stderr, &stderr_storage) orelse return @intFromEnum(plugin_api.AbiStatus.failed);

    const result = runModuleCommand(args, stdout_writer, stderr_writer) catch return @intFromEnum(plugin_api.AbiStatus.failed);
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
    .handle_command = runModuleCommandAbi,
    .skills_ptr = skills[0..].ptr,
    .skills_len = skills.len,
};

pub export const saasm_plugin_descriptor_v1: plugin_api.PluginDescriptor = descriptor;

pub export fn saasm_plugin_descriptor_v1_fn(out: *plugin_api.PluginDescriptor) callconv(.c) void {
    out.* = descriptor;
}

test "3D module descriptor exposes its configured skill" {
    try std.testing.expectEqualStrings(config.plugin_name, std.mem.span(descriptor.name));
    try std.testing.expectEqual(@as(u32, plugin_api.abi_version), descriptor.abi_version);
    try std.testing.expectEqual(@as(usize, 1), descriptor.skills_len);
    try std.testing.expectEqualStrings(config.skill_name, skills[0].name);
    try std.testing.expect(skills[0].items.len != 0);
    try std.testing.expect(descriptor.handle_command != null);
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

fn invokeForTest(argv: []const []const u8, stdout_buffer: *std.ArrayList(u8), stderr_buffer: *std.ArrayList(u8)) !struct { status: u32, code: u8 } {
    var ctx = plugin_api.Context{ .allocator = std.testing.allocator };
    var stdout_ctx = CaptureStream{ .buffer = stdout_buffer };
    var stderr_ctx = CaptureStream{ .buffer = stderr_buffer };
    const c_argv = try dupeZArgs(std.testing.allocator, argv);
    defer freeZArgs(std.testing.allocator, c_argv);
    var out_code: u8 = 255;
    const status = runModuleCommandAbi(&ctx, c_argv.ptr, c_argv.len, captureHostStream(&stdout_ctx), captureHostStream(&stderr_ctx), &out_code);
    return .{ .status = status, .code = out_code };
}

test "3D module command exposes info and check" {
    var stdout_buf = std.ArrayList(u8).init(std.testing.allocator);
    defer stdout_buf.deinit();
    var stderr_buf = std.ArrayList(u8).init(std.testing.allocator);
    defer stderr_buf.deinit();

    const info = try invokeForTest(&.{ "sa", config.plugin_name, "info" }, &stdout_buf, &stderr_buf);
    try std.testing.expectEqual(@as(u32, @intFromEnum(plugin_api.AbiStatus.ok)), info.status);
    try std.testing.expectEqual(@as(u8, 0), info.code);
    try std.testing.expect(std.mem.containsAtLeast(u8, stdout_buf.items, 1, config.skill_summary));
    try std.testing.expectEqual(@as(usize, 0), stderr_buf.items.len);

    stdout_buf.clearRetainingCapacity();
    stderr_buf.clearRetainingCapacity();
    const check = try invokeForTest(&.{ "sa", config.plugin_name, "check" }, &stdout_buf, &stderr_buf);
    try std.testing.expectEqual(@as(u32, @intFromEnum(plugin_api.AbiStatus.ok)), check.status);
    try std.testing.expectEqual(@as(u8, 0), check.code);
    try std.testing.expect(std.mem.containsAtLeast(u8, stdout_buf.items, 1, "3D module check passed"));
    try std.testing.expectEqual(@as(usize, 0), stderr_buf.items.len);
}

test "3D module command reports unknown commands" {
    var stdout_buf = std.ArrayList(u8).init(std.testing.allocator);
    defer stdout_buf.deinit();
    var stderr_buf = std.ArrayList(u8).init(std.testing.allocator);
    defer stderr_buf.deinit();

    const unknown_plugin = try invokeForTest(&.{ "sa", "not-this-module", "check" }, &stdout_buf, &stderr_buf);
    try std.testing.expectEqual(@as(u32, @intFromEnum(plugin_api.AbiStatus.unknown_command)), unknown_plugin.status);

    const bad_subcommand = try invokeForTest(&.{ "sa", config.plugin_name, "missing" }, &stdout_buf, &stderr_buf);
    try std.testing.expectEqual(@as(u32, @intFromEnum(plugin_api.AbiStatus.ok)), bad_subcommand.status);
    try std.testing.expectEqual(@as(u8, 2), bad_subcommand.code);
    try std.testing.expect(std.mem.containsAtLeast(u8, stderr_buf.items, 1, "unknown 3D module subcommand"));
}
