#!/usr/bin/env node
import { readFileSync } from "node:fs";

const [, , loweredPath] = process.argv;

if (!loweredPath) {
  console.error("usage: verify_sa3d_scene_lowering.mjs <lowered.sax>");
  process.exit(2);
}

const source = readFileSync(loweredPath, "utf8");

function requireText(text) {
  if (!source.includes(text)) {
    console.error(`missing lowered scene text: ${text}`);
    process.exit(1);
  }
}

function rejectText(text) {
  if (source.includes(text)) {
    console.error(`unexpected unlowered scene text: ${text}`);
    process.exit(1);
  }
}

rejectText("<Scene3D");
rejectText("<PerspectiveCamera");
rejectText("<UnlitMaterial");
rejectText("<CubeMesh");

requireText('<Component name="Sa3dCube">');
requireText('<canvas id="sa3d-canvas" width="1024" height="768" renderer="sa3d"></canvas>');
requireText("renderer = 0");
requireText("mesh = 0");
requireText("material = 0");
requireText("@ffi_wrapper onMount:");
requireText("@ffi_wrapper frame:");
requireText("call @sa3d_wgpu_request_renderer");
requireText("call @sa3d_wgpu_configure_renderer");
requireText("call @sa3d_wgpu_upload_mesh");
requireText("call @sa3d_wgpu_upload_material");
requireText("call @sa3d_wgpu_render_frame");
requireText("SA3D_UNIT_CUBE_P3N3UV2_VERTICES");
requireText("SA3D_UNIT_CUBE_MODEL_FRAMES");
requireText("SA3D_WGPU_DRAW_ITEM_transform_frame_stride");
requireText("SA3D_WGPU_DRAW_ITEM_transform_frame_count");
requireText("!renderer !mesh !material !frame");

rejectText("call @sa3d_request_context");
rejectText("call @sa3d_create_cube_pipeline");
rejectText("call @sa3d_submit_cube_frame");
rejectText("SA3D_CUBE_SHADER");
rejectText("ptr_add &SA3D_UNIT_CUBE_MODEL_FRAMES");
rejectText("raw_cast *SA3D_UNIT_CUBE_MODEL_FRAMES");

console.log(`verified SA3D Scene3D lowering: ${loweredPath}`);
