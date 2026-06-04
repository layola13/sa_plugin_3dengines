# Bevy Alignment For SA 3D Engines

This file is the working gate for `sa_plugin_3dengines`. A module is not complete when it only exports layout constants or descriptor records. Completion requires SA-callable behavior that matches the closest Bevy crate responsibility, plus SA unit tests that prove the behavior.

## Reference Order

The module order follows Bevy's `DefaultPlugins` and `MinimalPlugins` setup:

1. `app`, `ecs`
2. `time`
3. `transform`
4. `input`
5. asset-facing data modules: `image`, `shader`, `geometry`/mesh, `camera`, `light`, `scene`
6. render stack: `render_wgpu`, core pipeline shape, `material`, `pbr`
7. content and tools: `gltf`, `animation`, `gizmos`
8. text import helpers requested for the SA engine family: `xml`, `yaml`

Primary Bevy reference files:

- `/home/vscode/projects/bevy/crates/bevy_internal/src/default_plugins.rs`
- `/home/vscode/projects/bevy/crates/bevy_app/src/app.rs`
- `/home/vscode/projects/bevy/crates/bevy_ecs/src/lib.rs`
- `/home/vscode/projects/bevy/crates/bevy_time/src/timer.rs`
- `/home/vscode/projects/bevy/crates/bevy_transform/src/components/transform.rs`
- `/home/vscode/projects/bevy/crates/bevy_transform/src/systems.rs`
- `/home/vscode/projects/bevy/crates/bevy_input/src/button_input.rs`
- `/home/vscode/projects/bevy/crates/bevy_image/src/image.rs`
- `/home/vscode/projects/bevy/crates/bevy_shader/src/shader.rs`
- `/home/vscode/projects/bevy/crates/bevy_mesh/src/mesh.rs`
- `/home/vscode/projects/bevy/crates/bevy_camera/src/projection.rs`
- `/home/vscode/projects/bevy/crates/bevy_light/src/lib.rs`
- `/home/vscode/projects/bevy/crates/bevy_render/src/lib.rs`
- `/home/vscode/projects/bevy/crates/bevy_pbr/src/pbr_material.rs`
- `/home/vscode/projects/bevy/crates/bevy_gltf/src/loader/mod.rs`
- `/home/vscode/projects/bevy/crates/bevy_animation/src/lib.rs`
- `/home/vscode/projects/bevy/crates/bevy_gizmos/src/gizmos.rs`

## Completion Gate

Every module needs all of the following before it is called complete:

- A Bevy reference file or crate section listed in this document.
- A small SA ABI that performs real state change, validation, derivation, parsing, or conversion.
- At least one SA behavior test that calls the module functions and proves the state or result changed correctly.
- Layout tests are still required, but they only prove ABI shape.
- Dependencies must follow Bevy's dependency direction. A later module cannot make an earlier module depend on it.

## Module Matrix

| SA module | Bevy reference | Minimum real behavior required | Current status |
| --- | --- | --- | --- |
| `sa_plugin_3d_app` | `bevy_app` | plugin registration, schedule stage ordering, run-once schedule dispatch over system descriptors | ABI layout only |
| `sa_plugin_3d_ecs` | `bevy_ecs` | entity allocation with generation, component descriptor registry, query-term matching over compact component masks | ABI layout only, lowest priority |
| `sa_plugin_3d_time` | `bevy_time` | frame advance, timer init/reset/pause/unpause, once/repeating `tick`, `is_finished`, `just_finished` | behavior implemented and SA-tested |
| `sa_plugin_3d_math` | `bevy_math`/`glam` | integer-bit-safe Vec/Mat storage helpers, vector dot/cross in fixed-point or verified native-backed math, AABB merge/contains | partial behavior implemented and SA-tested: native Vec2/Vec3/Vec4, Quat, Mat4, Ray3d plane intersection, Aabb3d, BoundingSphere basics |
| `sa_plugin_3d_color` | `bevy_color` | RGBA u8/f32 packing, alpha operations, linear/srgb conversion path appropriate for renderer inputs | behavior implemented and SA-tested |
| `sa_plugin_3d_transform` | `bevy_transform` | identity transform, translate/scale setters, local-to-world matrix, parent propagation with dirty state | partial behavior implemented and SA-tested: native Transform constructors, SRT matrix, point transform, rotation helpers, GlobalTransform point transform, node link/reparent/local-to-world propagation |
| `sa_plugin_3d_input` | `bevy_input` | press/release state machine, `pressed`, `just_pressed`, `just_released`, per-frame clear | behavior implemented and SA-tested |
| `sa_plugin_3d_camera_controller` | `bevy_camera_controller` | orbit/fly input accumulation into camera transform parameters with dt from `time` | behavior implemented and SA-tested for orbit/fly state, validation, and clamp/update helpers; Bevy free/pan parity still pending |
| `sa_plugin_3d_image` | `bevy_image` | image descriptor validation, row pitch calculation, sampler defaulting, srgb view mapping for supported formats | behavior implemented and SA-tested: image format/dimension validation, bytes-per-pixel, row pitch/data length derivation, size reinterpretation, target texture setup, usage validation, sampler defaults, and native selftest coverage |
| `sa_plugin_3d_shader` | `bevy_shader` | WGSL source validation surface, import path fallback, shader def record validation/lookup, stable shader ref resolution | partial behavior implemented and SA-tested: WGSL format/source/path/import-path validation, ShaderDefVal record helpers for bool/int/uint, name lookup over contiguous def tables, and shader ref/entry pair validation |
| `sa_plugin_3d_geometry` | `bevy_mesh` | mesh descriptor validation, vertex count from stride, AABB calculation from positions, primitive/index validation, Bevy `dim3` primitive mesh builders one by one | partial behavior implemented and SA-tested: native P3N3UV2 vertices, mesh descriptors, draw/triangle/byte counts, count_vertices min rule, position AABB, primitive and index validation, mesh validation helpers, checked count helpers; `CuboidMeshBuilder` vertex order, normals, UVs, U32 indices, bounds and triangle count are implemented and SA-tested; `PlaneMeshBuilder` dynamic vertex/index counts, X/Z subdivisions, normalized normal validation, `Quat::from_rotation_arc(Vec3::Y, normal)` positioning, normals, UVs, U32 indices, bounds and triangle count are implemented and SA-tested; `SphereMeshBuilder::uv` sectors/stacks vertex generation, normals, UVs, U32 indices, bounds and triangle count are implemented and SA-tested; `SphereMeshBuilder::ico` Bevy `sphere.rs` behavior is implemented against `hexasphere::IcoSphere` source parity: 12 initial points, 20 main triangles, 30 shared edges, geometric slerp edge/interior point generation, `TriangleContents`-style interior allocation, `get_indices` order, spherical UV callback, U32 indices, 79-subdivision upper bound, bounds and triangle count are implemented and SA-tested; `CylinderMeshBuilder` resolution, height segments, caps on/off, top/bottom cap winding, UVs, MidPoint/Top/Bottom anchor offsets, U32 indices, bounds and triangle count are implemented and SA-tested; `ConicalFrustumMeshBuilder` top/bottom radii, height segments, lateral rings, side normal slope normalization, top/bottom cap UVs and winding, U32 indices, bounds and triangle count are implemented and SA-tested; `ConeMeshBuilder` tip/lateral/base vertices, zero tip normal, side normal slope normalization, polar UVs, base UVs, lateral/base winding, MidPoint/Tip/Base anchor offsets, U32 indices, bounds and triangle count are implemented and SA-tested; `Capsule3dMeshBuilder` rings, longitudes, latitudes, Aspect/Uniform/Fixed UV profiles, polar/hemi/equator/cylinder vertices, normals, UVs, U32 indices, bounds and triangle count are implemented and SA-tested; `TorusMeshBuilder` inner/outer radius conversion, major/minor resolution, angle range, normals, UVs, U32 indices, bounds and triangle count are implemented and SA-tested; `Triangle3dMeshBuilder` Bevy vertex order, U32 indices, zero normal fallback for degenerate triangles, and `uv_coords` left/acute/right branches are implemented and SA-tested; `TetrahedronMeshBuilder` Bevy `faces()` order, signed-volume negative-orientation face reversal, per-face Triangle3d normals/UVs, non-shared vertices and U32 index sequence are implemented and SA-tested; `Segment3dMeshBuilder` LineList topology, two positions, and U32 `[0, 1]` indices are implemented and SA-tested; `Polyline3dMeshBuilder` LineList topology, cloned positions, and adjacent-pair U32 indices `[i, i + 1]` are implemented and SA-tested. `/home/vscode/projects/gpu-curtains/src/extras/geometries/SphereGeometry.ts` was checked and only provides Three.js-style UV sphere generation, so it was not used for ico alignment. |
| `sa_plugin_3d_camera` | `bevy_camera` | viewport clamp, perspective/orthographic projection matrix, view-projection uniform update | partial behavior implemented and SA-tested: native camera descriptors, viewport clamp, perspective infinite reverse RH projection, centered orthographic projection, uniform view-projection update |
| `sa_plugin_3d_light` | `bevy_light` | light descriptor validation, default ambient, point/spot range and angle checks, Bevy default/attenuation helpers, simple cluster/list packing | behavior implemented and SA-tested: light descriptor init/clear, enablement, color/position/direction updates, kind/positional/range/spot validation, point influence checks, Bevy ambient/directional/point/spot defaults, spot clamping, attenuation, textures, shadow maps, and sun disk helpers |
| `sa_plugin_3d_scene` | `bevy_scene` | scene node creation, component mask mutation, parent/child relation validation, draw-item extraction input | ABI layout only plus declarative lowering fixture |
| `sa_plugin_3d_material` | `bevy_material`/`bevy_pbr::Material` | material defaults, texture slot checks, shader ref selection, alpha mode flags, depth bias, opaque render method, transmission read flags | partial behavior implemented and SA-tested: material defaults, texture slot checks, shader ref selection, alpha mode flags, alpha/transparent checks, diffuse/specular transmission, depth bias, and opaque render method override |
| `sa_plugin_3d_pbr` | `bevy_pbr::StandardMaterial` | standard material defaults, material flag derivation, alpha mode classification, Bevy AlphaMode extension coverage, opaque render method derivation, view transmission read flag, glTF material conversion inputs | partial behavior implemented and SA-tested: standard material defaults, material flag derivation, alpha mode classification, texture slots, alpha-cutoff checks, Bevy AlphaMode extensions, opaque render method derivation, and view transmission read flag |
| `sa_plugin_3d_render_wgpu` | `bevy_render` | render schedule phases, renderer/mesh/material resource state, scene submission validation, WebGPU sidecar bridge | partial behavior implemented and SA-tested: target/frame/scene/pass/draw/material descriptor validation, renderable scene and draw-call counting, scene/pass clear color helpers, direct dependency on shared `sa_plugin_wgpu`, P3N3UV2 vertex layout conversion into `WGPU_RENDER_PIPELINE_DESC`, mesh/pass conversion into `WGPU_DRAW_DESC`, and shared WGPU descriptor validation. This aligns with Bevy's first `RenderDevice::create_render_pipeline`, buffer upload, `RenderContext` render pass, queue submit path. Not complete yet: Bevy `RenderSystems` scheduling, extract/prepare/queue phases, render graph nodes, texture/material bind groups beyond one uniform buffer, PBR specialization, batching, and multi-pass composition. |
| `sa_plugin_3d_animation` | `bevy_animation` | clip/player time advance, repeating/clamped playback, channel sampler lookup, linear/step interpolation | behavior implemented and SA-tested: clip metadata setters/getters, sampler and channel validation, player flags, seek/tick/play/pause/stop/repeat, keyframe indexing, and per-target curve progress helpers |
| `sa_plugin_3d_gizmos` | `bevy_gizmos` | line buffer append/clear/swap, retained gizmo count, shape-to-line expansion for supported shapes | behavior implemented and SA-tested: line desc init/setters, validation, bounds, list totals, and shape-derived helpers |
| `sa_plugin_3d_particle` | Bevy render/scene patterns | emitter tick, spawn budget from rate and dt, particle lifetime update, dead particle compaction | behavior implemented and SA-tested: particle init/tick/alive, emitter validation/spawn budget, and spawn particle helpers |
| `sa_plugin_3d_gltf` | `bevy_gltf` | loader settings validation, load flag filtering, glTF JSON/GLB header validation, counts for scenes/meshes/materials | ABI layout only |
| `sa_plugin_3d_xml` | importer helper | minimal token scanner for tags/attrs/text and node count validation | ABI layout only |
| `sa_plugin_3d_yaml` | importer helper | minimal scalar/sequence/mapping scanner and node count validation | ABI layout only |
| `sa_plugin_3d` | Bevy `DefaultPlugins` aggregate | deterministic module bitmask, dependency gate, aggregate sidecar paths, declarative scene lowering into real render submission | aggregate bitmask plus cube sidecar path |

## Immediate Implementation Sequence

1. Finish core low-dependency behavior: `time`, `input`, `math`, `color`.
2. Implement transform propagation and camera projection before expanding demos.
3. Implement mesh/image/shader validation before PBR and render submission growth.
4. Move the current cube lowering from cube-specific data into mesh/material/scene/render descriptors.
5. Only then generate the next demo batch.
