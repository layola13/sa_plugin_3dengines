pub const plugin_name = "3d_image";
pub const skill_name = "3d.image";
pub const skill_summary = "3D image and sampler layout contracts";
pub const skill_items = [_][]const u8{
    "texture dimensions, formats, usage flags, and upload descriptors",
    "sampler addressing and filtering descriptors",
    "depends on 3d_color for image color-space constants",
};
