import { readFileSync } from "node:fs";

const path = process.argv[2];
if (!path) {
  console.error("usage: node tools/verify_sa3d_airlock.mjs <sa3d_airlock.js>");
  process.exit(2);
}

const source = readFileSync(path, "utf8");
const required = [
  "export const sax_sa3d_airlock",
  "export function sax_sa3d_bind_wasm",
  "sa3d_request_context",
  "sa3d_create_buffer",
  "sa3d_create_shader",
  "sa3d_create_cube_pipeline",
  "sa3d_write_buffer_frame",
  "sa3d_submit_cube_frame",
  "sa3d_wgpu_request_renderer",
  "sa3d_wgpu_configure_renderer",
  "sa3d_wgpu_upload_mesh",
  "sa3d_wgpu_upload_material",
  "sa3d_wgpu_render_frame",
  "sa3d_wgpu_request_frame",
  "sa3d_wgpu_cancel_frame",
  "sa3d_wgpu_last_error",
  "_ensure_generic_pipeline",
  "drawItemsPtr",
  "typeof navigator === \"undefined\" || !navigator.gpu",
  "cannot request WebGPU frame without a context handle",
  "depth24plus",
  "depthStencilAttachment",
  "GPUTextureUsage.RENDER_ATTACHMENT",
];
for (const needle of required) {
  if (!source.includes(needle)) {
    console.error(`missing SA3D broker symbol: ${needle}`);
    process.exit(1);
  }
}

const forbidden = ["SA3D_CUBE_VERTICES", "SA3D_CUBE_SHADER", "struct Uniforms", "cube_vertices"];
for (const needle of forbidden) {
  if (source.includes(needle)) {
    console.error(`broker contains SA-owned kernel/data token: ${needle}`);
    process.exit(1);
  }
}
