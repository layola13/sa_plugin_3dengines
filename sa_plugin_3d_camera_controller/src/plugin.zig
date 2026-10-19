const std = @import("std");

const module_plugin = @import("module_plugin");
pub const saasm_plugin_descriptor_v1 = module_plugin.saasm_plugin_descriptor_v1;
pub const saasm_plugin_descriptor_v1_fn = module_plugin.saasm_plugin_descriptor_v1_fn;
comptime {
    _ = module_plugin;
}

pub const State = extern struct {
    mode: i32,
    flags: i32,
    camera_handle: i64,
    target_x: i32,
    target_y: i32,
    target_z: i32,
    yaw: i32,
    pitch: i32,
    distance: i32,
    move_speed: i32,
    look_speed: i32,
    input_bindings: i64,
    input_bindings_len: i64,
};

pub const Input = extern struct {
    pan_x: i32,
    pan_y: i32,
    orbit_x: i32,
    orbit_y: i32,
    zoom: i32,
    forward: i32,
    right: i32,
    up: i32,
};

const ORBIT: i32 = 1;
const FLY: i32 = 2;
const FIRST_PERSON: i32 = 3;
const MIN_PITCH: i32 = -89000;
const MAX_PITCH: i32 = 89000;
const MIN_DISTANCE: i32 = 1;

fn clampPitch(pitch: i32) i32 {
    if (pitch < MIN_PITCH) return MIN_PITCH;
    if (pitch > MAX_PITCH) return MAX_PITCH;
    return pitch;
}

fn clampDistance(distance: i32) i32 {
    if (distance < MIN_DISTANCE) return MIN_DISTANCE;
    return distance;
}

fn initOrbit(state: *State) void {
    state.* = .{
        .mode = ORBIT,
        .flags = 0,
        .camera_handle = 0,
        .target_x = 0,
        .target_y = 0,
        .target_z = 0,
        .yaw = 0,
        .pitch = 0,
        .distance = 1065353216,
        .move_speed = 1065353216,
        .look_speed = 1065353216,
        .input_bindings = 0,
        .input_bindings_len = 0,
    };
}

fn initFly(state: *State) void {
    state.* = .{
        .mode = FLY,
        .flags = 0,
        .camera_handle = 0,
        .target_x = 0,
        .target_y = 0,
        .target_z = 0,
        .yaw = 0,
        .pitch = 0,
        .distance = 0,
        .move_speed = 1065353216,
        .look_speed = 1065353216,
        .input_bindings = 0,
        .input_bindings_len = 0,
    };
}

fn orbitUpdate(state: *State, input: *const Input) void {
    state.yaw += input.orbit_x;
    state.pitch = clampPitch(state.pitch + input.orbit_y);
    state.distance = clampDistance(state.distance + input.zoom);
}

fn flyUpdate(state: *State, input: *const Input) void {
    const speed = state.move_speed;
    state.target_x += input.right * speed;
    state.target_y += input.up * speed;
    state.target_z += input.forward * speed;
    state.yaw += input.right * speed;
    state.pitch = clampPitch(state.pitch + input.up * speed);
}

pub export fn sa3d_camera_controller_selftest() callconv(.c) i32 {
    var orbit: State = undefined;
    initOrbit(&orbit);
    if (orbit.mode != ORBIT or orbit.distance != 1065353216) return 1;

    var fly: State = undefined;
    initFly(&fly);
    if (fly.mode != FLY or fly.distance != 0) return 2;

    var input: Input = .{
        .pan_x = 0,
        .pan_y = 0,
        .orbit_x = 10,
        .orbit_y = 90000,
        .zoom = -2000000000,
        .forward = 0,
        .right = 0,
        .up = 0,
    };
    orbit.camera_handle = 77;
    orbit.target_x = 1;
    orbit.target_y = 2;
    orbit.target_z = 3;
    orbitUpdate(&orbit, &input);
    if (orbit.camera_handle != 77 or orbit.yaw != 10 or orbit.pitch != MAX_PITCH or orbit.distance != MIN_DISTANCE) return 3;

    fly.move_speed = 4;
    fly.target_x = 10;
    fly.target_y = 20;
    fly.target_z = 30;
    input = .{
        .pan_x = 0,
        .pan_y = 0,
        .orbit_x = 0,
        .orbit_y = 0,
        .zoom = 0,
        .forward = 2,
        .right = 3,
        .up = -4,
    };
    flyUpdate(&fly, &input);
    if (fly.yaw != 12 or fly.pitch != -16 or fly.target_x != 22 or fly.target_y != 4 or fly.target_z != 38) return 4;

    orbit.mode = 99;
    if (orbit.mode == ORBIT or orbit.mode == FLY or orbit.mode == FIRST_PERSON) return 5;
    return 0;
}

test "camera controller native selftest matches SA controller behavior" {
    try std.testing.expectEqual(@as(i32, 0), sa3d_camera_controller_selftest());
}
