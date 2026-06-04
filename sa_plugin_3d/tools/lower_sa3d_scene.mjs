#!/usr/bin/env node
import { readFileSync, writeFileSync } from "node:fs";

const [, , inputPath, outputPath] = process.argv;

if (!inputPath || !outputPath) {
  console.error("usage: lower_sa3d_scene.mjs <input.sax3d> <output.sax>");
  process.exit(2);
}

function die(message) {
  console.error(`error[SA3D-SCENE-LOWER]: ${message}`);
  process.exit(1);
}

function parseAttrs(text) {
  const attrs = new Map();
  const re = /([A-Za-z_][A-Za-z0-9_:-]*)\s*=\s*"([^"]*)"/g;
  for (const match of text.matchAll(re)) attrs.set(match[1], match[2]);
  return attrs;
}

function singleMatch(source, re, label) {
  const matches = [...source.matchAll(re)];
  if (matches.length === 0) die(`missing ${label}`);
  if (matches.length > 1) die(`only one ${label} is supported in this milestone`);
  return matches[0];
}

function optionalTagAttrs(source, tag) {
  const selfClosing = new RegExp(`<${tag}\\b([^>]*)\\/>`, "g");
  const normal = new RegExp(`<${tag}\\b([^>]*)>\\s*</${tag}>`, "g");
  const matches = [...source.matchAll(selfClosing), ...source.matchAll(normal)];
  if (matches.length === 0) return null;
  if (matches.length > 1) die(`only one <${tag}> is supported in a Scene3D block`);
  return parseAttrs(matches[0][1]);
}

function assertKnownSceneTags(sceneBody) {
  let stripped = sceneBody;
  for (const tag of ["PerspectiveCamera", "UnlitMaterial", "PbrMaterial", "CubeMesh", "DirectionalLight", "PointLight"]) {
    stripped = stripped.replace(new RegExp(`<${tag}\\b[^>]*\\/>`, "g"), "");
    stripped = stripped.replace(new RegExp(`<${tag}\\b[^>]*>\\s*</${tag}>`, "g"), "");
  }
  const unknown = stripped.match(/<\/?([A-Z][A-Za-z0-9_]*)\b/);
  if (unknown) die(`unknown Scene3D tag <${unknown[1]}>`);
  if (stripped.trim().length !== 0) die("Scene3D currently supports only declarative 3D tags and whitespace");
}

function requireAttr(attrs, name, owner) {
  const value = attrs.get(name);
  if (!value) die(`${owner} requires attribute '${name}'`);
  return value;
}

function parseFloatList(text, expected, owner) {
  const values = String(text ?? "").trim().split(/\s+/).filter(Boolean).map((part) => Number(part));
  if (values.length !== expected || values.some((value) => !Number.isFinite(value))) {
    die(`${owner} requires ${expected} numeric values`);
  }
  return values;
}

function f32Bits(value) {
  const buf = new ArrayBuffer(4);
  const view = new DataView(buf);
  view.setFloat32(0, Number(value), true);
  return view.getInt32(0, true);
}

function lower(source) {
  const component = singleMatch(source, /<Component\b([^>]*)>([\s\S]*)<\/Component>/g, "<Component>");
  const componentAttrs = parseAttrs(component[1]);
  const componentName = requireAttr(componentAttrs, "name", "Component");
  if (componentName !== "Sa3dCube") {
    die('this first Scene3D lowerer requires Component name="Sa3dCube" so the generated frame handler matches the current SAX export name');
  }

  const body = component[2];
  const scene = singleMatch(body, /<Scene3D\b([^>]*)>([\s\S]*?)<\/Scene3D>/g, "<Scene3D>");
  const sceneAttrs = parseAttrs(scene[1]);
  const sceneBody = scene[2];
  assertKnownSceneTags(sceneBody);

  const canvasSelector = sceneAttrs.get("canvas") ?? "#sa3d-canvas";
  if (canvasSelector !== "#sa3d-canvas") die('this runtime milestone requires Scene3D canvas="#sa3d-canvas"');
  const backend = sceneAttrs.get("backend") ?? sceneAttrs.get("renderer") ?? "webgpu";
  if (backend !== "webgpu" && backend !== "sa3d") die("Scene3D backend must be 'webgpu' or 'sa3d'");

  const camera = optionalTagAttrs(sceneBody, "PerspectiveCamera");
  if (!camera) die("Scene3D requires one <PerspectiveCamera />");
  const material = optionalTagAttrs(sceneBody, "UnlitMaterial") ?? optionalTagAttrs(sceneBody, "PbrMaterial");
  if (!material) die("Scene3D requires one material tag");
  const cube = optionalTagAttrs(sceneBody, "CubeMesh");
  if (!cube) die("this milestone supports one <CubeMesh />");
  if ((cube.get("geometry") ?? "cube") !== "cube") die("CubeMesh geometry must be 'cube'");
  const materialId = material.get("id") ?? "material";
  if ((cube.get("material") ?? materialId) !== materialId) die("CubeMesh material must reference the declared material id");
  const color = parseFloatList(material.get("color") ?? material.get("baseColor") ?? material.get("base_color") ?? "1 1 1 1", 4, "material color");

  const strippedBody = body
    .replace(/<state>[\s\S]*?<\/state>/g, "")
    .replace(scene[0], "")
    .trim();

  if (!/id="sa3d-canvas"/.test(strippedBody)) die('lowered DOM must include <canvas id="sa3d-canvas" ...>');
  if (!/renderer="sa3d"/.test(strippedBody)) die('the Scene3D canvas must include renderer="sa3d" so SAX loads the SA3D sidecar');

  return `<Component name="Sa3dCube">
  <state>
    renderer = 0
    mesh = 0
    material = 0
    frame = 0
  </state>

${indentBlock(strippedBody, "  ")}

${runtimeHandlers(color)}
</Component>
`;
}

function indentBlock(text, prefix) {
  return text.split("\n").map((line) => line.length === 0 ? line : `${prefix}${line}`).join("\n");
}

function runtimeHandlers(color) {
  const clearColor = [0.02, 0.025, 0.03, 1.0].map(f32Bits);
  const colorBits = color.map(f32Bits);
  return `  @ffi_wrapper onMount:
  L_ENTRY:
    canvas = call @sax_dom_query(*SA3D_WGPU_CANVAS_SELECTOR, SA3D_WGPU_CANVAS_SELECTOR_LEN)
    out_renderer = stack_alloc 8
    rc_renderer = call @sa3d_wgpu_request_renderer(canvas, *out_renderer)
    renderer_h = load out_renderer+0 as i64
    store state+Sa3dCube_renderer, renderer_h as i64
    has_ctx = ne renderer_h, 0
    br has_ctx -> L_REQUEST_FRAME, L_MOUNT_DONE

  L_REQUEST_FRAME:
    rc_frame = call @sa3d_wgpu_request_frame(renderer_h, *SA3D_WGPU_FRAME_HANDLER, SA3D_WGPU_FRAME_HANDLER_LEN, ctx)
    ret

  L_MOUNT_DONE:
    ret

  @ffi_wrapper onUnmount:
  L_ENTRY:
    renderer_h = load state+Sa3dCube_renderer as i64
    rc_cancel = call @sa3d_wgpu_cancel_frame(renderer_h)
    ret

  @ffi_wrapper frame:
  L_ENTRY:
    renderer_h = load state+Sa3dCube_renderer as i64
    has_ctx = ne renderer_h, 0
    br has_ctx -> L_CHECK_INIT, L_DONE

  L_CHECK_INIT:
    mesh_h = load state+Sa3dCube_mesh as i64
    has_mesh = ne mesh_h, 0
    br has_mesh -> L_CHECK_MATERIAL, L_INIT

  L_CHECK_MATERIAL:
    material_h = load state+Sa3dCube_material as i64
    has_material = ne material_h, 0
    br has_material -> L_DRAW, L_INIT

  L_INIT:
    canvas = call @sax_dom_query(*SA3D_WGPU_CANVAS_SELECTOR, SA3D_WGPU_CANVAS_SELECTOR_LEN)
    target_desc = stack_alloc SA3D_WGPU_RENDER_TARGET_SIZE
    store target_desc+SA3D_WGPU_RENDER_TARGET_canvas, canvas as i64
    store target_desc+SA3D_WGPU_RENDER_TARGET_width, 1024 as i32
    store target_desc+SA3D_WGPU_RENDER_TARGET_height, 768 as i32
    store target_desc+SA3D_WGPU_RENDER_TARGET_sample_count, 1 as i32
    rc_config = call @sa3d_wgpu_configure_renderer(renderer_h, *target_desc)

    mesh_desc = stack_alloc SA3D_WGPU_MESH_DESC_SIZE
    store mesh_desc+SA3D_WGPU_MESH_DESC_vertex_ptr, &SA3D_UNIT_CUBE_P3N3UV2_VERTICES as ptr
    store mesh_desc+SA3D_WGPU_MESH_DESC_vertex_len, SA3D_UNIT_CUBE_P3N3UV2_VERTEX_BYTES as i64
    store mesh_desc+SA3D_WGPU_MESH_DESC_vertex_stride, SA3D_WGPU_VERTEX_P3N3UV2_SIZE as i64
    store mesh_desc+SA3D_WGPU_MESH_DESC_index_ptr, &SA3D_UNIT_CUBE_INDICES as ptr
    store mesh_desc+SA3D_WGPU_MESH_DESC_index_len, SA3D_UNIT_CUBE_INDEX_BYTES as i64
    store mesh_desc+SA3D_WGPU_MESH_DESC_index_format, SA3D_WGPU_INDEX_U16 as i32
    store mesh_desc+SA3D_WGPU_MESH_DESC_primitive, SA3D_WGPU_PRIMITIVE_TRIANGLE_LIST as i32
    out_mesh = stack_alloc 8
    rc_mesh = call @sa3d_wgpu_upload_mesh(renderer_h, *mesh_desc, *out_mesh)
    mesh_h = load out_mesh+0 as i64
    has_uploaded_mesh = ne mesh_h, 0
    br has_uploaded_mesh -> L_UPLOAD_MATERIAL, L_WAIT_MESH

  L_UPLOAD_MATERIAL:
    store state+Sa3dCube_mesh, mesh_h as i64
    material_desc = stack_alloc SA3D_WGPU_MATERIAL_DESC_SIZE
    store material_desc+SA3D_WGPU_MATERIAL_DESC_model, SA3D_WGPU_MATERIAL_MODEL_UNLIT as i32
    store material_desc+SA3D_WGPU_MATERIAL_DESC_flags, 0 as i32
    store material_desc+8, ${colorBits[0]} as i32
    store material_desc+12, ${colorBits[1]} as i32
    store material_desc+16, ${colorBits[2]} as i32
    store material_desc+20, ${colorBits[3]} as i32
    store material_desc+SA3D_WGPU_MATERIAL_DESC_metallic, 0 as i32
    store material_desc+SA3D_WGPU_MATERIAL_DESC_roughness, 1065353216 as i32
    out_material = stack_alloc 8
    rc_material = call @sa3d_wgpu_upload_material(renderer_h, *material_desc, *out_material)
    material_h = load out_material+0 as i64
    has_uploaded_material = ne material_h, 0
    br has_uploaded_material -> L_STORE_MATERIAL, L_WAIT_MATERIAL

  L_STORE_MATERIAL:
    store state+Sa3dCube_material, material_h as i64
    ret

  L_WAIT_MESH:
    ret

  L_WAIT_MATERIAL:
    ret

  L_DRAW:
    mesh_h = load state+Sa3dCube_mesh as i64
    material_h = load state+Sa3dCube_material as i64
    frame_idx = load state+Sa3dCube_frame as i64

    draw_item = stack_alloc SA3D_WGPU_DRAW_ITEM_SIZE
    store draw_item+SA3D_WGPU_DRAW_ITEM_mesh, mesh_h as i64
    store draw_item+SA3D_WGPU_DRAW_ITEM_submesh, 0 as i64
    store draw_item+SA3D_WGPU_DRAW_ITEM_material, material_h as i64
    store draw_item+SA3D_WGPU_DRAW_ITEM_transform, &SA3D_UNIT_CUBE_MODEL_FRAMES as ptr
    store draw_item+SA3D_WGPU_DRAW_ITEM_sort_key, 0 as i64
    store draw_item+SA3D_WGPU_DRAW_ITEM_transform_frame_stride, SA3D_UNIT_CUBE_MODEL_FRAME_BYTES as i64
    store draw_item+SA3D_WGPU_DRAW_ITEM_transform_frame_count, SA3D_UNIT_CUBE_FRAME_COUNT as i64

    scene_desc = stack_alloc SA3D_WGPU_RENDER_SCENE_SIZE
    store scene_desc+SA3D_WGPU_RENDER_SCENE_draw_items_ptr, draw_item as ptr
    store scene_desc+SA3D_WGPU_RENDER_SCENE_draw_items_len, 1 as i64
    store scene_desc+SA3D_WGPU_RENDER_SCENE_camera_uniform, &SA3D_UNIT_CUBE_CAMERA_UNIFORM as ptr
    store scene_desc+SA3D_WGPU_RENDER_SCENE_lights_ptr, 0 as i64
    store scene_desc+SA3D_WGPU_RENDER_SCENE_lights_len, 0 as i64
    store scene_desc+40, ${clearColor[0]} as i32
    store scene_desc+44, ${clearColor[1]} as i32
    store scene_desc+48, ${clearColor[2]} as i32
    store scene_desc+52, ${clearColor[3]} as i32

    frame_desc = stack_alloc SA3D_WGPU_RENDER_FRAME_SIZE
    store frame_desc+SA3D_WGPU_RENDER_FRAME_renderer, renderer_h as i64
    store frame_desc+SA3D_WGPU_RENDER_FRAME_scene, scene_desc as ptr
    store frame_desc+SA3D_WGPU_RENDER_FRAME_camera, 0 as i64
    store frame_desc+SA3D_WGPU_RENDER_FRAME_delta_ms, 16 as i64
    store frame_desc+SA3D_WGPU_RENDER_FRAME_frame_index, frame_idx as i64
    rc_render = call @sa3d_wgpu_render_frame(renderer_h, *frame_desc)
    next_frame = add frame_idx, 1
    should_wrap = eq next_frame, SA3D_UNIT_CUBE_FRAME_COUNT
    br should_wrap -> L_RESET_FRAME, L_STORE_FRAME

  L_STORE_FRAME:
    store state+Sa3dCube_frame, next_frame as i64
    ret

  L_RESET_FRAME:
    store state+Sa3dCube_frame, 0 as i64
    ret

  L_DONE:
    ret

  !renderer !mesh !material !frame`;
}

const source = readFileSync(inputPath, "utf8");
writeFileSync(outputPath, lower(source));
