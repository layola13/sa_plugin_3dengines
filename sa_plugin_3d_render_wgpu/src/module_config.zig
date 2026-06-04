pub const plugin_name = "3d_render_wgpu";
pub const skill_name = "3d.render.wgpu";
pub const skill_summary = "WebGPU backend contracts for the 3D engine";
pub const skill_items = [_][]const u8{
    "WebGPU render target, frame, pass, and draw item layouts",
    "scene submission descriptor, shader/image/PBR integration points, and browser-only wasm import surface for SAX scene demos",
    "depends on scene, shader, image, PBR, sax, and wgpu",
};
