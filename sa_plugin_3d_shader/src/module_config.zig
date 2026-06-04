pub const plugin_name = "3d_shader";
pub const skill_name = "3d.shader";
pub const skill_summary = "3D shader source and reference layout contracts";
pub const skill_items = [_][]const u8{
    "WGSL shader source descriptors and validation flags",
    "ShaderRef layout for default, handle, path, and inline references",
    "shader entry points and shader definition records used by material and render modules",
};
