import { readFileSync, statSync } from "node:fs";
import { join } from "node:path";

const dir = process.argv[2];
if (!dir) {
  console.error("usage: node tools/verify_sa3d_sax_dist.mjs <dist-dir>");
  process.exit(2);
}

for (const name of ["app.sa", "app.wasm", "airlock.js", "sa3d_airlock.js", "index.html"]) {
  const path = join(dir, name);
  if (!statSync(path).isFile()) {
    console.error(`missing ${name}`);
    process.exit(1);
  }
}

const wasm = readFileSync(join(dir, "app.wasm"));
if (wasm.length < 8 || wasm.subarray(0, 8).toString("hex") !== "0061736d01000000") {
  console.error("app.wasm is not a WebAssembly module");
  process.exit(1);
}

const appSa = readFileSync(join(dir, "app.sa"), "utf8");
for (const needle of ["SA3D_CUBE_SHADER", "struct Uniforms", "SA3D_CUBE_VERTICES", "sa3d_submit_cube_frame"]) {
  if (!appSa.includes(needle)) {
    console.error(`app.sa missing SA-owned SA3D token: ${needle}`);
    process.exit(1);
  }
}

const airlock = readFileSync(join(dir, "airlock.js"), "utf8");
for (const needle of ["const SAX_SA3D_REQUIRED = true;", "await import(\"./sa3d_airlock.js\")", "sax_sa3d_bind_wasm(instance, _mem)"]) {
  if (!airlock.includes(needle)) {
    console.error(`airlock.js missing SA3D integration token: ${needle}`);
    process.exit(1);
  }
}

const sidecar = readFileSync(join(dir, "sa3d_airlock.js"), "utf8");
for (const needle of ["sa3d_wgpu_request_renderer", "sa3d_wgpu_upload_mesh", "sa3d_wgpu_upload_material", "sa3d_wgpu_render_frame", "drawItemsPtr"]) {
  if (!sidecar.includes(needle)) {
    console.error(`sa3d_airlock.js missing generic renderer token: ${needle}`);
    process.exit(1);
  }
}
for (const forbidden of ["SA3D_CUBE_VERTICES", "SA3D_CUBE_SHADER", "struct Uniforms", "cube_vertices"]) {
  if (sidecar.includes(forbidden)) {
    console.error(`sa3d_airlock.js contains SA-owned token: ${forbidden}`);
    process.exit(1);
  }
}
