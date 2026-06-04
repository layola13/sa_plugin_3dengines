import { spawnSync } from "node:child_process";
import { join } from "node:path";

const root = new URL("..", import.meta.url).pathname.replace(/\/$/, "");
const modules = [
  "sa_plugin_3d_time",
  "sa_plugin_3d_app",
  "sa_plugin_3d_math",
  "sa_plugin_3d_color",
  "sa_plugin_3d_shader",
  "sa_plugin_3d_image",
  "sa_plugin_3d_transform",
  "sa_plugin_3d_geometry",
  "sa_plugin_3d_camera",
  "sa_plugin_3d_input",
  "sa_plugin_3d_camera_controller",
  "sa_plugin_3d_material",
  "sa_plugin_3d_pbr",
  "sa_plugin_3d_light",
  "sa_plugin_3d_scene",
  "sa_plugin_3d_animation",
  "sa_plugin_3d_gizmos",
  "sa_plugin_3d_render_wgpu",
  "sa_plugin_3d_particle",
  "sa_plugin_3d_gltf",
  "sa_plugin_3d_xml",
  "sa_plugin_3d_yaml",
  "sa_plugin_3d_ecs",
  "sa_plugin_3d",
];

for (const dir of modules) {
  console.log(`[3dengines] zig build test: ${dir}`);
  const result = spawnSync("zig", ["build", "test", "--summary", "all"], {
    cwd: join(root, dir),
    stdio: "inherit",
    env: process.env,
  });
  if (result.status !== 0) {
    process.exit(result.status ?? 1);
  }
}

console.log(`[3dengines] built ${modules.length} modules`);
