pub const plugin_name = "3d_camera";
pub const skill_name = "3d.camera";
pub const skill_summary = "3D camera projection and uniform layout contracts";
pub const skill_items = [_][]const u8{
    "perspective and orthographic camera record layouts",
    "view-projection uniform layout for WebGPU render backends",
    "depends on 3d_math and 3d_transform",
};

