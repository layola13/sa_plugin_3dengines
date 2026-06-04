pub const plugin_name = "3d_color";
pub const skill_name = "3d.color";
pub const skill_summary = "3D color layouts plus Bevy-style RGBA conversion behavior";
pub const skill_items = [_][]const u8{
    "linear sRGB, sRGB, OKLab, and HDR color space constants",
    "RGBA/HSVA float plus RGBA u8/u16 layouts",
    "RGBA u8 packing, alpha operations, and sRGB/linear fixed-point conversion",
    "gradient stop records for materials and debug drawing",
};
