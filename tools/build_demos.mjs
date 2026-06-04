import { mkdirSync } from "node:fs";
import { dirname, join } from "node:path";
import { fileURLToPath } from "node:url";
import { spawnSync as run } from "node:child_process";

const root = dirname(dirname(fileURLToPath(import.meta.url)));
const saBin = process.env.SA_BIN || "/home/vscode/projects/sci/zig-out/bin/sa";
const saxLib = process.env.SAX_LIB || "/home/vscode/projects/sa_plugins/sa_plugin_sax/zig-out/lib/libsax.so";
const threeDLib = process.env.SA3D_LIB || join(root, "sa_plugin_3d", "zig-out", "lib", "lib3d.so");
const outRoot = process.env.SA3D_DEMO_OUT || join(root, ".zig-cache", "generated-demos");

const demos = [
  {
    name: "rotating_cube_3d",
    source: join(root, "sa_plugin_3d", "demos", "rotating_cube_3d.sax"),
    verify: ["node", join(root, "sa_plugin_3d", "tools", "verify_sa3d_sax_dist.mjs")],
  },
  {
    name: "scene_cubes_3d",
    source: join(root, "sa_plugin_3d", "demos", "scene_cubes_3d.sax"),
    verify: ["node", join(root, "sa_plugin_3d", "tools", "verify_sa3d_scene_cubes_dist.mjs")],
  },
];

function runCommand(cmd, args, options = {}) {
  const result = run(cmd, args, { stdio: "inherit", ...options });
  if (result.status !== 0) process.exit(result.status ?? 1);
}

mkdirSync(outRoot, { recursive: true });
const env = { ...process.env, SA_PLUGINS_PATH: `${saxLib}:${threeDLib}` };

for (const demo of demos) {
  const outDir = join(outRoot, demo.name);
  console.log(`[3dengines] build demo: ${demo.name}`);
  runCommand(saBin, ["sax", "build", demo.source, "--out-dir", outDir], { env });
  if (demo.verify) {
    const [cmd, ...args] = demo.verify;
    runCommand(cmd, [...args, outDir], { env });
  }
}

console.log(`[3dengines] generated ${demos.length} demo dist(s) under ${outRoot}`);
