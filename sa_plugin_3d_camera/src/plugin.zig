const module_plugin = @import("module_plugin");
pub const saasm_plugin_descriptor_v1 = module_plugin.saasm_plugin_descriptor_v1;
pub const saasm_plugin_descriptor_v1_fn = module_plugin.saasm_plugin_descriptor_v1_fn;
comptime {
    _ = module_plugin;
}

pub const ProjectionKind = enum(i32) {
    perspective = 0,
    orthographic = 1,
};

pub const CameraDesc = extern struct {
    projection: i32,
    fovy_radians: f32,
    aspect: f32,
    near: f32,
    far: f32,
    ortho_height: f32,
};

pub const Mat4f = extern struct {
    data: [16]f32,
};

pub const Vec3f = extern struct {
    x: f32,
    y: f32,
    z: f32,
};

pub const CameraUniform = extern struct {
    view: Mat4f,
    proj: Mat4f,
    view_proj: Mat4f,
    position: Vec3f,
    _pad: f32,
};

pub const CameraViewport = extern struct {
    x: u32,
    y: u32,
    width: u32,
    height: u32,
    depth_min: f32,
    depth_max: f32,
};
pub extern fn sa3d_camera_desc_perspective(out: *CameraDesc, fovy_radians: f32, aspect: f32, near: f32, far: f32) callconv(.c) void;
pub extern fn sa3d_camera_desc_orthographic(out: *CameraDesc, ortho_height: f32, aspect: f32, near: f32, far: f32) callconv(.c) void;
pub extern fn sa3d_camera_desc_update_aspect(desc: *CameraDesc, width: f32, height: f32) callconv(.c) bool;
pub extern fn sa3d_camera_desc_validate(desc: *const CameraDesc) callconv(.c) bool;
pub extern fn sa3d_camera_viewport_init_native(out: *CameraViewport, x: u32, y: u32, width: u32, height: u32) callconv(.c) void;
pub extern fn sa3d_camera_viewport_clamp_native(viewport: *CameraViewport, target_width: u32, target_height: u32) callconv(.c) void;
pub extern fn sa3d_camera_projection_perspective(out: *Mat4f, desc: *const CameraDesc) callconv(.c) bool;
pub extern fn sa3d_camera_projection_orthographic(out: *Mat4f, desc: *const CameraDesc) callconv(.c) bool;
pub extern fn sa3d_camera_projection_matrix(out: *Mat4f, desc: *const CameraDesc) callconv(.c) bool;
pub extern fn sa3d_camera_uniform_init_native(out: *CameraUniform) callconv(.c) void;
pub extern fn sa3d_camera_uniform_update(out: *CameraUniform, view: *const Mat4f, proj: *const Mat4f, position: *const Vec3f) callconv(.c) void;
pub extern fn sa3d_camera_selftest() callconv(.c) i32;
