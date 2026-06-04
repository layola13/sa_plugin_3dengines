# Bevy Parity Audit

This is the strict evidence log for rebuilding `sa_plugin_3dengines`. A module is not considered complete because it has layout constants, descriptor records, or passing local smoke tests. Each accepted behavior must point to Bevy source and have SA `@test` coverage.

## Current Finding

The current 3D engine modules are no longer all empty, but many implementations are still shallow or local inventions. Passing `zig build test` proves only that the current ABI and tests are self-consistent. It does not prove Bevy parity.

## Math Module Audit

SA module: `sa_plugin_3d_math`

Bevy references:

- `/home/vscode/projects/bevy/crates/bevy_math/src/lib.rs`
  - `bevy_math` re-exports `glam::*`, including `Vec2`, `Vec3`, `Vec4`, `Quat`, and `Mat4`.
- `/home/vscode/projects/bevy/crates/bevy_math/src/ray.rs`
  - `Ray3d { origin: Vec3, direction: Dir3 }`
  - `Ray3d::new(origin, direction)` stores both fields.
  - `Ray3d::get_point(distance)` returns `origin + *direction * distance`.
  - `Ray3d::intersect_plane` uses `denominator = plane.normal.dot(*direction)`, epsilon rejection, then `(plane_origin - origin).dot(*plane.normal) / denominator` and rejects non-positive distances.
- `/home/vscode/projects/bevy/crates/bevy_math/src/bounding/bounded3d/mod.rs`
  - `Aabb3d { min: Vec3A, max: Vec3A }`.
  - `Aabb3d::new(center, half_size)` stores `min = center - half_size`, `max = center + half_size`.
  - `Aabb3d::from_min_max(min, max)` stores the extents directly.
  - `BoundingVolume for Aabb3d::center` returns `(min + max) / 2`.
  - `BoundingVolume for Aabb3d::half_size` returns `(max - min) / 2`.
  - `contains` checks `other.min >= self.min` and `other.max <= self.max` component-wise.
  - `merge` returns component-wise min and max.

Current mismatch:

- Existing `sa3d_vec*` arithmetic uses `i32`, including tests that treat small integers as coordinates. This is useful as deterministic smoke coverage but is not Bevy/glam parity.
- Layouts use 4-byte lanes and Bevy-like column-major `Mat4` offsets. This is acceptable as ABI layout evidence, but not enough.
- `SA3D_AABB_SIZE = 32` stores two padded vec3 lanes, which corresponds more closely to Bevy `Aabb3d` using `Vec3A` than to plain `Vec3`.
- Missing Bevy-backed `f32` behavior: `Vec3` add/sub/dot/cross, `Ray3d::get_point`, and `Aabb3d::new/center/half_size/merge/contains`.

Required first fix:

- Add explicit `f32` SA functions for the Bevy-backed subset above.
- Add SA `@test` cases that call those functions with real `f32` values.
- Keep the older integer helpers temporarily only as compatibility shims until dependent modules are audited.

Resolution note:

- Direct `.sal` floating point arithmetic currently fails through the `sa test` LLVM/bc2sa path, so the accepted `f32` behavior is implemented as native plugin ABI in `sa_plugin_3d_math/src/plugin.zig` and covered from SA through `sa3d_math_selftest()`.

## Transform Module Audit

SA module: `sa_plugin_3d_transform`

Bevy references:

- `/home/vscode/projects/bevy/crates/bevy_transform/src/components/transform.rs`
  - `Transform { translation: Vec3, rotation: Quat, scale: Vec3 }`.
  - `Transform::IDENTITY` is zero translation, `Quat::IDENTITY`, one scale.
  - `from_xyz`, `from_translation`, `from_rotation`, and `from_scale` are constructor variants over `IDENTITY`.
  - `Transform::to_matrix` delegates to `Mat4::from_scale_rotation_translation(self.scale, self.rotation, self.translation)`.
- `/home/vscode/projects/bevy/crates/bevy_transform/src/components/global_transform.rs`
  - `GlobalTransform` wraps `Affine3A` and `IDENTITY` maps points to themselves.
  - `impl From<Transform> for GlobalTransform` uses `transform.compute_affine()`.
  - `impl Mul<Transform> for GlobalTransform` delegates to `mul_transform`.
- `/home/vscode/projects/bevy/crates/bevy_transform/src/systems.rs`
  - `sync_simple_transforms` assigns `*global_transform = GlobalTransform::from(*transform)` for changed roots or orphaned roots.
  - hierarchy propagation computes child global transform with `parent.mul_transform(*transform)`.

Current mismatch:

- Existing `.sal` implementation only handles integer bit patterns and effectively assumes no rotation.
- Existing parent-child propagation covers scale/translation composition but is not a Bevy `Affine3A` equivalent and does not cover quaternion rotation.
- There is no native f32 ABI or SA-callable native selftest proving Bevy formulas.

Required first fix:

- Add native `f32` Transform/GlobalTransform ABI with 16-byte padded vector layout matching the SA layout.
- Implement identity/from_xyz/from_translation/from_rotation/from_scale/to_matrix/global_from_transform/global_mul_transform for Bevy's SRT model.
- Add a native selftest called from SA `@test`; keep existing `.sal` tests as layout and compatibility coverage.

## Time Module Audit

SA module: `sa_plugin_3d_time`

Bevy references:

- `/home/vscode/projects/bevy/crates/bevy_time/src/time.rs`
  - `Time<T>` stores `delta`, `elapsed`, wrapped elapsed, and a default one-hour wrap period.
  - `advance_by(delta)` updates `delta`, adds to `elapsed`, and recomputes wrapped elapsed modulo `wrap_period`.
  - `advance_to(elapsed)` advances by `elapsed - self.elapsed` and must not move backwards.
- `/home/vscode/projects/bevy/crates/bevy_time/src/timer.rs`
  - `Timer::tick(delta)` ignores paused timers, clears `times_finished_this_tick`, and clears `finished` for repeating timers while paused.
  - Once timers clamp elapsed to duration and remain finished after completion; later ticks clear only `just_finished`.
  - Repeating timers wrap elapsed by duration and set `times_finished_this_tick` to elapsed / duration.
  - Repeating zero-duration timers return `u32::MAX` completions and leave elapsed at zero.
- `/home/vscode/projects/bevy/crates/bevy_time/src/fixed.rs`
  - `Time<Fixed>` default timestep is `Duration::from_micros(15625)` (64 Hz).
  - `accumulate_overstep(delta)` adds to overstep; `expend()` consumes one timestep at a time, advances elapsed/delta by exactly the timestep, and leaves residual overstep.

Current mismatch:

- Existing `.sal` timer behavior is close for normal once/repeating timers, but repeating zero-duration returns `1` instead of Bevy's `u32::MAX`.
- Existing fixed-time compatibility layout uses millisecond integers and defaults invalid input to `16ms`; Bevy's default fixed timestep is `15625us` and the clock consumes steps one at a time.
- Existing frame clock lacks Bevy's one-hour wrapped elapsed behavior.

Required first fix:

- Add native Bevy-backed time ABI using nanosecond integer durations for exact `Duration` parity.
- Cover `Time::advance_by`, wrapped elapsed, once/repeating timer edge cases, and fixed timestep expenditure.
- Expose `sa3d_time_selftest()` and call it from SA `@test`; keep `.sal` millisecond compatibility tests until dependent modules are audited.
