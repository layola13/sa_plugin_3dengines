pub const plugin_name = "3d_input";
pub const skill_name = "3d.input";
pub const skill_summary = "3D input events plus Bevy-style button state behavior";
pub const skill_items = [_][]const u8{
    "keyboard, pointer, wheel, and gamepad event records",
    "ButtonInput-style pressed, just_pressed, and just_released state transitions",
    "per-frame clear, single input reset, and release_all behavior",
    "renderer-independent interaction data for camera controllers and tools",
};
