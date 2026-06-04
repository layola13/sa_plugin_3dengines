import { existsSync, readFileSync, statSync } from "node:fs";
import { join } from "node:path";

const root = new URL("..", import.meta.url).pathname.replace(/\/$/, "");

const modules = [
  { dir: "sa_plugin_3d_time", name: "3d_time", sal: "3d_time.sal", test: "3d_time_layout_test.sa", deps: [] },
  { dir: "sa_plugin_3d_app", name: "3d_app", sal: "3d_app.sal", test: "3d_app_layout_test.sa", deps: ["3d_time"] },
  { dir: "sa_plugin_3d_math", name: "3d_math", sal: "3d_math.sal", test: "3d_math_layout_test.sa", deps: [] },
  { dir: "sa_plugin_3d_color", name: "3d_color", sal: "3d_color.sal", test: "3d_color_layout_test.sa", deps: [] },
  { dir: "sa_plugin_3d_shader", name: "3d_shader", sal: "3d_shader.sal", test: "3d_shader_layout_test.sa", deps: [] },
  { dir: "sa_plugin_3d_image", name: "3d_image", sal: "3d_image.sal", test: "3d_image_layout_test.sa", deps: ["3d_color"] },
  { dir: "sa_plugin_3d_transform", name: "3d_transform", sal: "3d_transform.sal", test: "3d_transform_layout_test.sa", deps: ["3d_math"] },
  { dir: "sa_plugin_3d_geometry", name: "3d_geometry", sal: "3d_geometry.sal", test: "3d_geometry_layout_test.sa", deps: ["3d_math"] },
  { dir: "sa_plugin_3d_camera", name: "3d_camera", sal: "3d_camera.sal", test: "3d_camera_layout_test.sa", deps: ["3d_math", "3d_transform"] },
  { dir: "sa_plugin_3d_camera_controller", name: "3d_camera_controller", sal: "3d_camera_controller.sal", test: "3d_camera_controller_layout_test.sa", deps: ["3d_camera", "3d_input", "3d_time", "3d_transform"] },
  { dir: "sa_plugin_3d_material", name: "3d_material", sal: "3d_material.sal", test: "3d_material_layout_test.sa", deps: ["3d_color", "3d_image", "3d_math", "3d_shader"] },
  { dir: "sa_plugin_3d_pbr", name: "3d_pbr", sal: "3d_pbr.sal", test: "3d_pbr_layout_test.sa", deps: ["3d_color", "3d_image", "3d_material", "3d_shader"] },
  { dir: "sa_plugin_3d_light", name: "3d_light", sal: "3d_light.sal", test: "3d_light_layout_test.sa", deps: ["3d_math", "3d_transform"] },
  { dir: "sa_plugin_3d_scene", name: "3d_scene", sal: "3d_scene.sal", test: "3d_scene_layout_test.sa", deps: ["3d_math", "3d_transform", "3d_geometry", "3d_camera", "3d_material", "3d_light"] },
  { dir: "sa_plugin_3d_input", name: "3d_input", sal: "3d_input.sal", test: "3d_input_layout_test.sa", deps: [] },
  { dir: "sa_plugin_3d_animation", name: "3d_animation", sal: "3d_animation.sal", test: "3d_animation_layout_test.sa", deps: ["3d_math", "3d_time", "3d_transform"] },
  { dir: "sa_plugin_3d_gizmos", name: "3d_gizmos", sal: "3d_gizmos.sal", test: "3d_gizmos_layout_test.sa", deps: ["3d_camera", "3d_color", "3d_math"] },
  { dir: "sa_plugin_3d_render_wgpu", name: "3d_render_wgpu", sal: "3d_render_wgpu.sal", sai: "3d_render_wgpu.sai", test: "3d_render_wgpu_layout_test.sa", deps: ["3d_image", "3d_pbr", "3d_scene", "3d_shader", "sax", "wgpu"] },
  { dir: "sa_plugin_3d_particle", name: "3d_particle", sal: "3d_particle.sal", test: "3d_particle_layout_test.sa", deps: ["3d_math", "3d_transform", "3d_scene"] },
  { dir: "sa_plugin_3d_gltf", name: "3d_gltf", sal: "3d_gltf.sal", test: "3d_gltf_layout_test.sa", deps: ["3d_animation", "3d_geometry", "3d_image", "3d_material", "3d_pbr", "3d_scene"] },
  { dir: "sa_plugin_3d_xml", name: "3d_xml", sal: "3d_xml.sal", test: "3d_xml_layout_test.sa", deps: [] },
  { dir: "sa_plugin_3d_yaml", name: "3d_yaml", sal: "3d_yaml.sal", test: "3d_yaml_layout_test.sa", deps: [] },
  { dir: "sa_plugin_3d_ecs", name: "3d_ecs", sal: "3d_ecs.sal", test: "3d_ecs_layout_test.sa", deps: [] },
  { dir: "sa_plugin_3d", name: "3d", sal: "3d.sal", test: "3d_aggregate_layout_test.sa", deps: ["3d_animation", "3d_app", "3d_camera", "3d_camera_controller", "3d_color", "3d_ecs", "3d_geometry", "3d_gizmos", "3d_gltf", "3d_image", "3d_input", "3d_light", "3d_material", "3d_math", "3d_particle", "3d_pbr", "3d_render_wgpu", "3d_scene", "3d_shader", "3d_time", "3d_transform", "3d_xml", "3d_yaml"] },
];

function requireFile(path) {
  if (!existsSync(path) || !statSync(path).isFile()) {
    throw new Error(`missing file: ${path}`);
  }
}

function readJson(path) {
  return JSON.parse(readFileSync(path, "utf8"));
}

for (const mod of modules) {
  const dir = join(root, mod.dir);
  requireFile(join(dir, "build.zig"));
  requireFile(join(dir, "sap.json"));
  requireFile(join(dir, "src", "plugin.zig"));
  requireFile(join(dir, "src", "module_config.zig"));
  requireFile(join(dir, mod.sal));
  requireFile(join(dir, "tests", mod.test));
  if (mod.sai) requireFile(join(dir, mod.sai));
  if (mod.name === "3d") {
    requireFile(join(dir, "sa3d.sai"));
    requireFile(join(dir, "sa3d.sal"));
    requireFile(join(dir, "src", "sa3d_airlock_gen.zig"));
    requireFile(join(dir, "src", "sa3d_airlock_runtime.js"));
    requireFile(join(dir, "tests", "sa3d_sidecar_layout_test.sa"));
    requireFile(join(dir, "tests", "sa3d_scene_cubes_layout_test.sa"));
    requireFile(join(dir, "demos", "rotating_cube_3d.sax"));
    requireFile(join(dir, "demos", "rotating_cube_3d_decl.sax3d"));
    requireFile(join(dir, "demos", "scene_cubes_3d.sax"));
    requireFile(join(dir, "tools", "lower_sa3d_scene.mjs"));
    requireFile(join(dir, "tools", "verify_sa3d_airlock.mjs"));
    requireFile(join(dir, "tools", "verify_sa3d_scene_lowering.mjs"));
    requireFile(join(dir, "tools", "verify_sa3d_sax_dist.mjs"));
    requireFile(join(dir, "tools", "verify_sa3d_scene_cubes_dist.mjs"));
  }

  const manifest = readJson(join(dir, "sap.json"));
  if (manifest.name !== mod.name) throw new Error(`${mod.dir}: manifest name mismatch`);
  if (!manifest.artifacts?.["linux-x86_64"]?.path?.endsWith(`lib${mod.name}.so`)) {
    throw new Error(`${mod.dir}: artifact path does not match module name`);
  }
  if (manifest.interfaces?.sal?.path !== mod.sal) {
    throw new Error(`${mod.dir}: missing sal interface declaration`);
  }
  if (mod.sai) {
    const wasmImports = manifest.interfaces?.wasm_imports ?? [];
    if (!wasmImports.some((entry) => entry.path === mod.sai)) {
      throw new Error(`${mod.dir}: missing wasm import interface declaration`);
    }
  }
  const deps = Object.keys(manifest.dependencies ?? {}).sort();
  const expected = [...mod.deps].sort();
  if (deps.join("\0") !== expected.join("\0")) {
    throw new Error(`${mod.dir}: dependency mismatch, got ${deps.join(",")}, expected ${expected.join(",")}`);
  }
}

console.log(`verified ${modules.length} 3D engine plugin modules`);
