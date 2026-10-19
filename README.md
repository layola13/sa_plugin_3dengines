# SA 3D Engines Plugins

> **Build requirement: Zig 0.17** — this plugin targets and is verified against **Zig 0.17.0**. Build and test with Zig 0.17; older toolchains such as 0.14.x are not supported.
> 本插件需使用 **Zig 0.17** 编译与测试。


This directory contains the SA 3D engine plugin family. The plugins are grouped here because they belong to the same engine stack, but each module remains independently buildable and installable through its own `sap.json`.

The engine architecture is being realigned against Bevy. The current layout contracts remain useful ABI drafts, but layout constants alone do not make a module complete. The active completion gate is [BEVY_ALIGNMENT.md](BEVY_ALIGNMENT.md): each module needs SA-callable behavior and SA behavior tests tied to the closest Bevy crate responsibility.

The current milestone has a working `sa3d` WebGPU sidecar, the first declarative `Scene3D` lowering path, and a first generic WebGPU render submission surface. The browser-facing cube runtime is still intentionally narrow, but the demo batch now includes both the original rotating cube and a static multi-cube scene built through the same generic render path. Among the newly split engine modules, `sa_plugin_3d_time`, `sa_plugin_3d_input`, `sa_plugin_3d_color`, `sa_plugin_3d_geometry`, `sa_plugin_3d_scene`, and `sa_plugin_3d_light` now have behavior implemented and SA-tested beyond layout shape.

## Modules

| Plugin | Role | Direct dependencies |
| --- | --- | --- |
| `sa_plugin_3d_time` | Bevy-style frame and timer behavior | none |
| `sa_plugin_3d_app` | app/plugin/schedule ABI, behavior pending | `3d_time` |
| `sa_plugin_3d_math` | vector, matrix, quaternion, AABB ABI, behavior pending | none |
| `sa_plugin_3d_color` | RGBA packing, alpha operations, and sRGB/linear conversion | none |
| `sa_plugin_3d_shader` | shader ABI, behavior pending | none |
| `sa_plugin_3d_image` | image/sampler ABI, behavior pending | `3d_color` |
| `sa_plugin_3d_transform` | transform hierarchy ABI, behavior pending | `3d_math` |
| `sa_plugin_3d_geometry` | P3N3UV2 vertex writing, mesh/submesh constructors, and AABB bounds calculation | `3d_math` |
| `sa_plugin_3d_camera` | camera projection ABI, behavior pending | `3d_math`, `3d_transform` |
| `sa_plugin_3d_input` | Bevy-style button input state machine | none |
| `sa_plugin_3d_camera_controller` | orbit/fly controller ABI with SA behavior | camera, input, time, transform |
| `sa_plugin_3d_material` | material ABI with Bevy-like alpha/opaque/transmission helpers | color, image, math, shader |
| `sa_plugin_3d_pbr` | standard PBR material ABI with Bevy alpha/render helpers | color, image, material, shader |
| `sa_plugin_3d_light` | ambient/directional/point/spot constructors and light parameter updates | `3d_math`, `3d_transform` |
| `sa_plugin_3d_scene` | scene node component masks, scene slice init, and declarative AST constructors | transform, geometry, camera, material, light |
| `sa_plugin_3d_animation` | animation ABI, behavior pending | math, time, transform |
| `sa_plugin_3d_gizmos` | gizmo ABI with SA behavior | camera, color, math |
| `sa_plugin_3d_render_wgpu` | WebGPU backend ABI and wasm import contract | image, pbr, scene, shader, sax, wgpu |
| `sa_plugin_3d_particle` | particle ABI with SA behavior | math, transform, scene |
| `sa_plugin_3d_gltf` | glTF import ABI, behavior pending | animation, geometry, image, material, pbr, scene |
| `sa_plugin_3d_xml` | XML importer helper ABI, behavior pending | none |
| `sa_plugin_3d_yaml` | YAML importer helper ABI, behavior pending | none |
| `sa_plugin_3d_ecs` | ECS ABI, lowest-priority behavior pending | none |
| `sa_plugin_3d` | aggregate plugin for the family | all modules |

The aggregate plugin also installs the SAX sidecar assets:

- `sa3d.sai`: browser WASM import surface for the aggregate runtime.
- `sa3d.sal`: aggregate runtime ABI constants, including `SA3D_WGPU_*` scene submission layouts and SA-owned cube shader, geometry, index, and uniform-frame constants for the first acceptance demo.
- `sa3d_airlock.js`: browser broker generated from `src/sa3d_airlock_gen.zig`.
- `demos/rotating_cube_3d.sax`: first SAX/WebGPU 3D demo.
- `demos/scene_cubes_3d.sax`: static three-cube scene using the generic WebGPU renderer.
- `demos/rotating_cube_3d_decl.sax3d`: first declarative `Scene3D` input fixture.
- `tools/lower_sa3d_scene.mjs`: first-stage `Scene3D -> SAX` lowerer owned by the aggregate 3D plugin.

## Build And Test

Run all module builds and tests:

```bash
cd /home/vscode/projects/sa_plugins/sa_plugin_3dengines
node tools/verify_3d_modules.mjs
node tools/build_all.mjs
node tools/build_demos.mjs
```

Each module's `zig build test` runs two layers:

- Zig descriptor test: verifies the plugin descriptor and advertised skill.
- SA unit test: runs `sa test tests/*_layout_test.sa` against the module `.sal` and, for `3d_render_wgpu` and aggregate `3d`, the `.sai` wasm import surface. These files now contain both layout checks and behavior checks where the module has crossed the Bevy alignment gate.

The aggregate `sa_plugin_3d` test also lowers `demos/rotating_cube_3d_decl.sax3d` to ordinary SAX, verifies the lowered source no longer contains engine-only tags, and runs `sa sax check` on the result with `SA_PLUGINS_PATH` pointing at `sax` and `3d`.

For one module:

```bash
cd /home/vscode/projects/sa_plugins/sa_plugin_3dengines/sa_plugin_3d_math
zig build test
/home/vscode/projects/sci/zig-out/bin/sa test tests/3d_math_layout_test.sa
```

## SA Test Rule

The SA tests must validate behavior, not only layout. Layout checks still allocate records, write through named `#def` offsets, read through raw byte offsets, and check sizes/enums. Behavior checks call SA functions from the module `.sal` and assert state transitions or derived values.

Current examples: `sa_plugin_3d_time/tests/3d_time_layout_test.sa` calls `sa3d_time_frame_advance`, `sa3d_timer_tick`, `sa3d_timer_pause`, `sa3d_timer_unpause`, `sa3d_timer_is_finished`, and `sa3d_timer_just_finished`, matching the core Bevy timer semantics for once and repeating timers. `sa_plugin_3d_input/tests/3d_input_layout_test.sa` calls `sa3d_input_press`, `sa3d_input_release`, `sa3d_input_clear`, `sa3d_input_clear_just_pressed`, `sa3d_input_clear_just_released`, `sa3d_input_reset`, and `sa3d_input_release_all`, matching Bevy `ButtonInput` state transitions. `sa_plugin_3d_color/tests/3d_color_layout_test.sa` calls RGBA u8 pack/unpack, alpha replacement, and fixed-point sRGB/linear conversion functions backed by a Bevy gamma LUT suitable for renderer inputs. `sa_plugin_3d_geometry/tests/3d_geometry_layout_test.sa` now writes P3N3UV2 vertices, initializes mesh and submesh descriptors, and computes mesh AABB bounds from vertex positions. `sa_plugin_3d_scene/tests/3d_scene_layout_test.sa` now verifies entity generation fields, node component add/remove behavior, scene slice pointer wiring, and declarative node/attribute constructors. `sa_plugin_3d_light/tests/3d_light_layout_test.sa` now verifies ambient/directional/point/spot constructors, enabled state, color, position, direction, range, intensity, and spot-angle updates.

The tests intentionally avoid browser/WebGPU calls and avoid native f32 arithmetic in `sa test`; float fields are tested with integer bit patterns until the math module provides a verified numeric path.

`3d_scene` now also publishes a declarative AST layout (`SA3D_SCENE_DECL_*`) so scene authoring tools can represent engine-only tags without coupling that schema to browser DOM nodes. `3d_render_wgpu` publishes `SA3D_RENDER_SCENE_DESC_*` and draw-item layouts; aggregate `sa3d.sal` mirrors the browser runtime subset as `SA3D_WGPU_*` to keep generated SAX self-contained.

## Installation Shape

Each subdirectory has its own `sap.json` and installs:

- `zig-out/lib/lib<name>.so`
- module `.sal` under `current/sa/` and `current/share/`
- `3d_render_wgpu.sai` as `interfaces.wasm_imports` for the backend contract
- aggregate `sa3d.sai`, `sa3d.sal`, `sa3d_airlock.js`, and `demos/rotating_cube_3d.sax` under `installed/3d/current/share/`

The aggregate `sa_plugin_3d` declares dependencies on all modules. Installing it in dev mode brings the whole engine family into a plugin home and lets SAX discover `installed/3d/current/share/sa3d_airlock.js` through its `sa3d` sidecar lookup.

The aggregate install also includes the declarative source fixture and lowerer under `installed/3d/current/share/demos/` and `installed/3d/current/share/tools/`.

## Scene3D Lowering

The first `Scene3D` milestone is a plugin-owned pre-lowering step. It accepts a SAX-shaped component with a declarative engine block:

```xml
<Scene3D canvas="#sa3d-canvas" backend="webgpu">
  <PerspectiveCamera fovy="45" near="0.1" far="100" position="0 0 5" />
  <UnlitMaterial id="cube_material" color="1 0.62 0.24 1" />
  <CubeMesh id="cube" geometry="cube" material="cube_material" rotation="y" />
</Scene3D>
```

Lower it manually when needed:

```bash
cd /home/vscode/projects/sa_plugins/sa_plugin_3dengines/sa_plugin_3d
node tools/lower_sa3d_scene.mjs demos/rotating_cube_3d_decl.sax3d /tmp/rotating_cube_3d.lowered.sax
SA_PLUGINS_PATH=/home/vscode/projects/sa_plugins/sa_plugin_sax/zig-out/lib/libsax.so:zig-out/lib/lib3d.so \
  /home/vscode/projects/sci/zig-out/bin/sa sax check /tmp/rotating_cube_3d.lowered.sax
```

Current limits are explicit: one `Scene3D`, one `PerspectiveCamera`, one material, and one `CubeMesh`, targeting the existing `Sa3dCube` runtime. This gives the engine a tested declarative lowering boundary before the renderer grows into generalized scene, material, light, and particle submission.

## Generic WebGPU Submission

The aggregate sidecar now implements the `sa3d_wgpu_*` browser imports declared by `sa3d.sai` and `3d_render_wgpu.sai`:

- `sa3d_wgpu_request_renderer` / `sa3d_wgpu_configure_renderer`
- `sa3d_wgpu_upload_mesh` for `SA3D_VERTEX_P3N3UV2` triangle-list meshes
- `sa3d_wgpu_upload_material` for base-color material records
- `sa3d_wgpu_render_frame` for a frame descriptor pointing at a scene descriptor and draw-item list
- `sa3d_wgpu_request_frame` / `sa3d_wgpu_cancel_frame`

This is the first real move away from the cube-only submit function. The current generic backend has a built-in unlit/lit fallback shader, supports one vertex layout (`P3N3UV2`), consumes camera `view_proj` from the camera uniform at offset `+128`, and ignores light records for now. The next renderer step is feeding these descriptors from `Scene3D` lowering instead of the old `sa3d_submit_cube_frame` path.

## Demo Generation

Build the first batch of demo browser distributions:

```bash
cd /home/vscode/projects/sa_plugins/sa_plugin_3dengines
node tools/build_demos.mjs
```

The generated rotating cube demo is written to:

- `.zig-cache/generated-demos/rotating_cube_3d/index.html`
- `.zig-cache/generated-demos/rotating_cube_3d/app.wasm`
- `.zig-cache/generated-demos/rotating_cube_3d/airlock.js`
- `.zig-cache/generated-demos/rotating_cube_3d/sa3d_airlock.js`
- `.zig-cache/generated-demos/rotating_cube_3d/app.sa`

The generated three-cube scene demo is written to:

- `.zig-cache/generated-demos/scene_cubes_3d/index.html`
- `.zig-cache/generated-demos/scene_cubes_3d/app.wasm`
- `.zig-cache/generated-demos/scene_cubes_3d/airlock.js`
- `.zig-cache/generated-demos/scene_cubes_3d/sa3d_airlock.js`
- `.zig-cache/generated-demos/scene_cubes_3d/app.sa`

The demo canvas is fixed at `1024 x 768`. Serve the output with any static server that provides `.wasm` as `application/wasm`.

## Next Phase

The next phase is wiring `Scene3D` lowering into the generic `sa3d_wgpu_*` submission path. After that, broaden the backend beyond one mesh layout and add light-buffer consumption, material variants, particle draw submission, and batch demo generation.
