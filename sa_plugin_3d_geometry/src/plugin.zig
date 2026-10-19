const std = @import("std");

const module_plugin = @import("module_plugin");
pub const saasm_plugin_descriptor_v1 = module_plugin.saasm_plugin_descriptor_v1;
pub const saasm_plugin_descriptor_v1_fn = module_plugin.saasm_plugin_descriptor_v1_fn;
comptime {
    _ = module_plugin;
}

pub const PrimitiveTopology = enum(i32) {
    triangle_list = 0,
    triangle_strip = 1,
    line_list = 2,
    point_list = 3,
};

pub const IndexFormat = enum(i32) {
    none = 0,
    u16 = 1,
    u32 = 2,
};

pub const CylinderAnchor = enum(i32) {
    midpoint = 0,
    top = 1,
    bottom = 2,
};

pub const ConeAnchor = enum(i32) {
    midpoint = 0,
    tip = 1,
    base = 2,
};

pub const CapsuleUvProfile = enum(i32) {
    aspect = 0,
    uniform = 1,
    fixed = 2,
};

pub const Vec2f = extern struct {
    x: f32,
    y: f32,
};

pub const Vec3f = extern struct {
    x: f32,
    y: f32,
    z: f32,
};

pub const Vec3Af = extern struct {
    x: f32,
    y: f32,
    z: f32,
    w: f32,
};

pub const Aabb3f = extern struct {
    min: Vec3Af,
    max: Vec3Af,
};

pub const VertexP3N3Uv2 = extern struct {
    position: Vec3f,
    normal: Vec3f,
    uv: Vec2f,
};

pub const MeshDesc = extern struct {
    vertex_ptr: ?[*]const VertexP3N3Uv2,
    vertex_len: u64,
    vertex_stride: u64,
    index_ptr: ?*const anyopaque,
    index_len: u64,
    index_format: i32,
    primitive: i32,
    bounds: Aabb3f,
};

pub const Submesh = extern struct {
    start_index: u32,
    index_count: u32,
    base_vertex: i32,
    material: u64,
};

pub const CUBOID_VERTEX_COUNT: u64 = 24;
pub const CUBOID_INDEX_COUNT: u64 = 36;

fn vec3a(v: Vec3f) Vec3Af {
    return .{ .x = v.x, .y = v.y, .z = v.z, .w = 0.0 };
}

fn aabbZero() Aabb3f {
    return .{ .min = .{ .x = 0.0, .y = 0.0, .z = 0.0, .w = 0.0 }, .max = .{ .x = 0.0, .y = 0.0, .z = 0.0, .w = 0.0 } };
}

fn approxEq(a: f32, b: f32) bool {
    return @abs(a - b) <= 0.00001;
}

fn vec3Length(v: Vec3f) f32 {
    return @sqrt(v.x * v.x + v.y * v.y + v.z * v.z);
}

fn vec3Normalize(v: Vec3f) ?Vec3f {
    const len = vec3Length(v);
    if (!std.math.isFinite(len) or len <= 0.000001) return null;
    return .{ .x = v.x / len, .y = v.y / len, .z = v.z / len };
}

fn vec3Dot(a: Vec3f, b: Vec3f) f32 {
    return a.x * b.x + a.y * b.y + a.z * b.z;
}

fn vec3Cross(a: Vec3f, b: Vec3f) Vec3f {
    return .{
        .x = a.y * b.z - a.z * b.y,
        .y = a.z * b.x - a.x * b.z,
        .z = a.x * b.y - a.y * b.x,
    };
}

fn vec3Scale(v: Vec3f, s: f32) Vec3f {
    return .{ .x = v.x * s, .y = v.y * s, .z = v.z * s };
}

fn vec3Add(a: Vec3f, b: Vec3f) Vec3f {
    return .{ .x = a.x + b.x, .y = a.y + b.y, .z = a.z + b.z };
}

fn vec3Sub(a: Vec3f, b: Vec3f) Vec3f {
    return .{ .x = a.x - b.x, .y = a.y - b.y, .z = a.z - b.z };
}

fn vec3Distance(a: Vec3f, b: Vec3f) f32 {
    return vec3Length(vec3Sub(a, b));
}

const Quatf = struct {
    x: f32,
    y: f32,
    z: f32,
    w: f32,
};

fn quatNormalize(q: Quatf) Quatf {
    const len = @sqrt(q.x * q.x + q.y * q.y + q.z * q.z + q.w * q.w);
    return .{ .x = q.x / len, .y = q.y / len, .z = q.z / len, .w = q.w / len };
}

fn quatFromAxisAngle(axis: Vec3f, angle: f32) Quatf {
    const half = angle * 0.5;
    const s = @sin(half);
    return .{ .x = axis.x * s, .y = axis.y * s, .z = axis.z * s, .w = @cos(half) };
}

fn vec3AnyOrthonormalVector(v: Vec3f) Vec3f {
    const sign: f32 = if (std.math.signbit(v.z)) -1.0 else 1.0;
    const a = -1.0 / (sign + v.z);
    const b = v.x * v.y * a;
    return .{ .x = b, .y = sign + v.y * v.y * a, .z = -v.y };
}

fn quatFromRotationArc(from: Vec3f, to: Vec3f) Quatf {
    const dot = vec3Dot(from, to);
    const one_minus_eps = 1.0 - 2.0 * std.math.floatEps(f32);
    if (dot > one_minus_eps) return .{ .x = 0.0, .y = 0.0, .z = 0.0, .w = 1.0 };
    if (dot < -one_minus_eps) return quatFromAxisAngle(vec3AnyOrthonormalVector(from), std.math.pi);
    const c = vec3Cross(from, to);
    return quatNormalize(.{ .x = c.x, .y = c.y, .z = c.z, .w = 1.0 + dot });
}

fn quatRotateVec3(q: Quatf, v: Vec3f) Vec3f {
    const qv = Vec3f{ .x = q.x, .y = q.y, .z = q.z };
    const t = vec3Scale(vec3Cross(qv, v), 2.0);
    return vec3Add(v, vec3Add(vec3Scale(t, q.w), vec3Cross(qv, t)));
}

pub export fn sa3d_geometry_vertex_p3n3uv2_set(out: *VertexP3N3Uv2, px: f32, py: f32, pz: f32, nx: f32, ny: f32, nz: f32, u: f32, v: f32) callconv(.c) void {
    out.* = .{ .position = .{ .x = px, .y = py, .z = pz }, .normal = .{ .x = nx, .y = ny, .z = nz }, .uv = .{ .x = u, .y = v } };
}

pub export fn sa3d_geometry_index_stride(index_format: i32) callconv(.c) u64 {
    if (index_format == @intFromEnum(IndexFormat.u16)) return 2;
    if (index_format == @intFromEnum(IndexFormat.u32)) return 4;
    return 0;
}

pub export fn sa3d_geometry_primitive_draw_multiple(primitive: i32) callconv(.c) u64 {
    if (primitive == @intFromEnum(PrimitiveTopology.triangle_list)) return 3;
    if (primitive == @intFromEnum(PrimitiveTopology.line_list)) return 2;
    return 1;
}

pub export fn sa3d_geometry_submesh_init(out: *Submesh, start_index: u32, index_count: u32, base_vertex: i32, material: u64) callconv(.c) void {
    out.* = .{ .start_index = start_index, .index_count = index_count, .base_vertex = base_vertex, .material = material };
}

pub export fn sa3d_geometry_submesh_end_index(submesh: *const Submesh) callconv(.c) u32 {
    return submesh.start_index + submesh.index_count;
}

pub export fn sa3d_geometry_mesh_compute_bounds_p3n3uv2(out: *Aabb3f, vertices: [*]const VertexP3N3Uv2, vertex_len: u64) callconv(.c) bool {
    if (vertex_len == 0) {
        out.* = aabbZero();
        return false;
    }
    var min = vertices[0].position;
    var max = vertices[0].position;
    var i: u64 = 1;
    while (i < vertex_len) : (i += 1) {
        const p = vertices[i].position;
        min.x = @min(min.x, p.x);
        min.y = @min(min.y, p.y);
        min.z = @min(min.z, p.z);
        max.x = @max(max.x, p.x);
        max.y = @max(max.y, p.y);
        max.z = @max(max.z, p.z);
    }
    out.* = .{ .min = vec3a(min), .max = vec3a(max) };
    return true;
}

pub export fn sa3d_geometry_mesh_desc_init(out: *MeshDesc, vertices: [*]const VertexP3N3Uv2, vertex_len: u64, indices: ?*const anyopaque, index_len: u64, index_format: i32, primitive: i32) callconv(.c) void {
    out.* = .{
        .vertex_ptr = vertices,
        .vertex_len = vertex_len,
        .vertex_stride = @sizeOf(VertexP3N3Uv2),
        .index_ptr = indices,
        .index_len = index_len,
        .index_format = index_format,
        .primitive = primitive,
        .bounds = aabbZero(),
    };
    _ = sa3d_geometry_mesh_compute_bounds_p3n3uv2(&out.bounds, vertices, vertex_len);
}

pub export fn sa3d_geometry_mesh_has_indices(mesh: *const MeshDesc) callconv(.c) bool {
    return mesh.index_format != @intFromEnum(IndexFormat.none) and mesh.index_len > 0 and mesh.index_ptr != null;
}

pub export fn sa3d_geometry_mesh_draw_count(mesh: *const MeshDesc) callconv(.c) u64 {
    if (sa3d_geometry_mesh_has_indices(mesh)) return mesh.index_len;
    return mesh.vertex_len;
}

pub export fn sa3d_geometry_mesh_triangle_count(mesh: *const MeshDesc) callconv(.c) u64 {
    const count = sa3d_geometry_mesh_draw_count(mesh);
    if (mesh.primitive == @intFromEnum(PrimitiveTopology.triangle_list)) return count / 3;
    if (mesh.primitive == @intFromEnum(PrimitiveTopology.triangle_strip) and count >= 3) return count - 2;
    return 0;
}

pub export fn sa3d_geometry_mesh_vertex_byte_len(mesh: *const MeshDesc) callconv(.c) u64 {
    return mesh.vertex_len * mesh.vertex_stride;
}

pub export fn sa3d_geometry_mesh_index_byte_len(mesh: *const MeshDesc) callconv(.c) u64 {
    return mesh.index_len * sa3d_geometry_index_stride(mesh.index_format);
}

pub export fn sa3d_geometry_mesh_count_vertices(position_len: u64, normal_len: u64, uv_len: u64) callconv(.c) u64 {
    var count = position_len;
    if (normal_len < count) count = normal_len;
    if (uv_len < count) count = uv_len;
    return count;
}

pub export fn sa3d_geometry_mesh_validate(mesh: *const MeshDesc) callconv(.c) bool {
    if (mesh.vertex_ptr == null or mesh.vertex_len == 0) return false;
    if (mesh.vertex_stride < @sizeOf(VertexP3N3Uv2)) return false;
    if (mesh.primitive < @intFromEnum(PrimitiveTopology.triangle_list) or mesh.primitive > @intFromEnum(PrimitiveTopology.point_list)) return false;
    if (mesh.index_format < @intFromEnum(IndexFormat.none) or mesh.index_format > @intFromEnum(IndexFormat.u32)) return false;
    if (mesh.index_len > 0 and (mesh.index_ptr == null or mesh.index_format == @intFromEnum(IndexFormat.none))) return false;
    const draw_count = sa3d_geometry_mesh_draw_count(mesh);
    if (mesh.primitive == @intFromEnum(PrimitiveTopology.triangle_list) and draw_count % 3 != 0) return false;
    if (mesh.primitive == @intFromEnum(PrimitiveTopology.line_list) and draw_count % 2 != 0) return false;
    if (mesh.primitive == @intFromEnum(PrimitiveTopology.triangle_strip) and draw_count < 3) return false;
    return true;
}

fn maxIndexU16(indices: [*]const u16, index_len: u64) u32 {
    var max_index: u32 = 0;
    var i: u64 = 0;
    while (i < index_len) : (i += 1) max_index = @max(max_index, indices[i]);
    return max_index;
}

fn maxIndexU32(indices: [*]const u32, index_len: u64) u32 {
    var max_index: u32 = 0;
    var i: u64 = 0;
    while (i < index_len) : (i += 1) max_index = @max(max_index, indices[i]);
    return max_index;
}

pub export fn sa3d_geometry_mesh_indices_in_range(mesh: *const MeshDesc) callconv(.c) bool {
    if (!sa3d_geometry_mesh_has_indices(mesh)) return true;
    const ptr = mesh.index_ptr orelse return false;
    const max_index = if (mesh.index_format == @intFromEnum(IndexFormat.u16))
        maxIndexU16(@as([*]const u16, @ptrCast(@alignCast(ptr))), mesh.index_len)
    else if (mesh.index_format == @intFromEnum(IndexFormat.u32))
        maxIndexU32(@as([*]const u32, @ptrCast(@alignCast(ptr))), mesh.index_len)
    else
        return false;
    return max_index < mesh.vertex_len;
}

pub export fn sa3d_geometry_cuboid_vertex_count() callconv(.c) u64 {
    return CUBOID_VERTEX_COUNT;
}

pub export fn sa3d_geometry_cuboid_index_count() callconv(.c) u64 {
    return CUBOID_INDEX_COUNT;
}

fn writeVertex(out: *VertexP3N3Uv2, px: f32, py: f32, pz: f32, nx: f32, ny: f32, nz: f32, u: f32, v: f32) void {
    out.* = .{ .position = .{ .x = px, .y = py, .z = pz }, .normal = .{ .x = nx, .y = ny, .z = nz }, .uv = .{ .x = u, .y = v } };
}

const ICO_MAX_SUBDIVISIONS: u32 = 79;
const ICO_EDGE_COUNT: usize = 30;
const ICO_TRIANGLE_COUNT: usize = 20;
const ICO_GRID_SIDE: usize = ICO_MAX_SUBDIVISIONS + 2;

const IcoTriangle = struct {
    a: u32,
    b: u32,
    c: u32,
    ab_edge: usize,
    bc_edge: usize,
    ca_edge: usize,
};

const IcoEdge = struct {
    a: u32,
    b: u32,
    assigned: bool,
    done: bool,
};

const IcoEdgeRuntime = struct {
    points: []u32,
    done: bool,
};

const IcoContentKind = enum {
    none,
    one,
    three,
    six,
    more,
};

const IcoContent = struct {
    kind: IcoContentKind = .none,
    a: u32 = 0,
    b: u32 = 0,
    c: u32 = 0,
    ab: u32 = 0,
    bc: u32 = 0,
    ca: u32 = 0,
    sides: []u32 = &.{},
    side_len: u32 = 0,
    child: ?*IcoContent = null,
};

const IcoTriangleRuntime = struct {
    base: IcoTriangle,
    ab_forward: bool = false,
    bc_forward: bool = false,
    ca_forward: bool = false,
    content: IcoContent = .{},
};

const ICO_POINTS = [_]Vec3f{
    .{ .x = 0.0, .y = 1.0, .z = 0.0 },
    .{ .x = 0.8944271909999159, .y = 0.4472135954999579, .z = 0.0 },
    .{ .x = 0.27639320225002106, .y = 0.4472135954999579, .z = 0.8506508083520399 },
    .{ .x = -0.7236067977499788, .y = 0.4472135954999579, .z = 0.5257311121191337 },
    .{ .x = -0.723606797749979, .y = 0.4472135954999579, .z = -0.5257311121191335 },
    .{ .x = 0.27639320225002084, .y = 0.4472135954999579, .z = -0.85065080835204 },
    .{ .x = 0.7236067977499787, .y = -0.4472135954999579, .z = -0.5257311121191339 },
    .{ .x = 0.723606797749979, .y = -0.4472135954999579, .z = 0.5257311121191334 },
    .{ .x = -0.27639320225002073, .y = -0.4472135954999579, .z = 0.85065080835204 },
    .{ .x = -0.8944271909999159, .y = -0.4472135954999579, .z = 0.0 },
    .{ .x = -0.2763932022500214, .y = -0.4472135954999579, .z = -0.8506508083520398 },
    .{ .x = 0.0, .y = -1.0, .z = 0.0 },
};

const ICO_TRIANGLES = [_]IcoTriangle{
    .{ .a = 0, .b = 2, .c = 1, .ab_edge = 0, .bc_edge = 5, .ca_edge = 4 },
    .{ .a = 0, .b = 3, .c = 2, .ab_edge = 1, .bc_edge = 6, .ca_edge = 0 },
    .{ .a = 0, .b = 4, .c = 3, .ab_edge = 2, .bc_edge = 7, .ca_edge = 1 },
    .{ .a = 0, .b = 5, .c = 4, .ab_edge = 3, .bc_edge = 8, .ca_edge = 2 },
    .{ .a = 0, .b = 1, .c = 5, .ab_edge = 4, .bc_edge = 9, .ca_edge = 3 },
    .{ .a = 5, .b = 1, .c = 6, .ab_edge = 9, .bc_edge = 10, .ca_edge = 15 },
    .{ .a = 1, .b = 2, .c = 7, .ab_edge = 5, .bc_edge = 11, .ca_edge = 16 },
    .{ .a = 2, .b = 3, .c = 8, .ab_edge = 6, .bc_edge = 12, .ca_edge = 17 },
    .{ .a = 3, .b = 4, .c = 9, .ab_edge = 7, .bc_edge = 13, .ca_edge = 18 },
    .{ .a = 4, .b = 5, .c = 10, .ab_edge = 8, .bc_edge = 14, .ca_edge = 19 },
    .{ .a = 5, .b = 6, .c = 10, .ab_edge = 15, .bc_edge = 20, .ca_edge = 14 },
    .{ .a = 1, .b = 7, .c = 6, .ab_edge = 16, .bc_edge = 21, .ca_edge = 10 },
    .{ .a = 2, .b = 8, .c = 7, .ab_edge = 17, .bc_edge = 22, .ca_edge = 11 },
    .{ .a = 3, .b = 9, .c = 8, .ab_edge = 18, .bc_edge = 23, .ca_edge = 12 },
    .{ .a = 4, .b = 10, .c = 9, .ab_edge = 19, .bc_edge = 24, .ca_edge = 13 },
    .{ .a = 10, .b = 6, .c = 11, .ab_edge = 20, .bc_edge = 26, .ca_edge = 25 },
    .{ .a = 6, .b = 7, .c = 11, .ab_edge = 21, .bc_edge = 27, .ca_edge = 26 },
    .{ .a = 7, .b = 8, .c = 11, .ab_edge = 22, .bc_edge = 28, .ca_edge = 27 },
    .{ .a = 8, .b = 9, .c = 11, .ab_edge = 23, .bc_edge = 29, .ca_edge = 28 },
    .{ .a = 9, .b = 10, .c = 11, .ab_edge = 24, .bc_edge = 25, .ca_edge = 29 },
};

fn sphericalUv(p: Vec3f) Vec2f {
    const inclination = std.math.acos(p.y);
    const azimuth = std.math.atan2(p.z, p.x);
    return .{ .x = 0.5 - azimuth / (2.0 * std.math.pi), .y = inclination / std.math.pi };
}

fn geometricSlerp(a: Vec3f, b: Vec3f, p: f32) Vec3f {
    const angle = std.math.acos(vec3Dot(a, b));
    const sin_angle = @sin(angle);
    if (@abs(sin_angle) <= 0.000001) return vec3Normalize(vec3Add(vec3Scale(a, 1.0 - p), vec3Scale(b, p))).?;
    const inv = 1.0 / sin_angle;
    return vec3Add(vec3Scale(a, @sin((1.0 - p) * angle) * inv), vec3Scale(b, @sin(p * angle) * inv));
}

fn checkedIcoSphereVertexCount(subdivisions: u32) ?u64 {
    if (subdivisions > ICO_MAX_SUBDIVISIONS) return null;
    const side = @as(u64, subdivisions) + 1;
    const side_sq = std.math.mul(u64, side, side) catch return null;
    const scaled = std.math.mul(u64, side_sq, 10) catch return null;
    return std.math.add(u64, scaled, 2) catch null;
}

fn checkedIcoSphereIndexCount(subdivisions: u32) ?u64 {
    if (subdivisions > ICO_MAX_SUBDIVISIONS) return null;
    const side = @as(u64, subdivisions) + 1;
    const side_sq = std.math.mul(u64, side, side) catch return null;
    const triangles = std.math.mul(u64, side_sq, ICO_TRIANGLE_COUNT) catch return null;
    return std.math.mul(u64, triangles, 3) catch null;
}

fn icoSetVertex(vertices: [*]VertexP3N3Uv2, index: u32, point: Vec3f, radius: f32) void {
    const uv = sphericalUv(point);
    writeVertex(&vertices[index], point.x * radius, point.y * radius, point.z * radius, point.x, point.y, point.z, uv.x, uv.y);
}

fn icoEdgeIndex(edges: *const [ICO_EDGE_COUNT]IcoEdge, edge_points: *const [ICO_EDGE_COUNT][ICO_MAX_SUBDIVISIONS]u32, edge_id: usize, from: u32, to: u32, step: u32, subdivisions: u32) u32 {
    const edge = edges[edge_id];
    if (edge.a == from and edge.b == to) return edge_points[edge_id][step - 1];
    return edge_points[edge_id][subdivisions - step];
}

fn icoLocalIndex(edges: *const [ICO_EDGE_COUNT]IcoEdge, edge_points: *const [ICO_EDGE_COUNT][ICO_MAX_SUBDIVISIONS]u32, grid: *const [ICO_GRID_SIDE][ICO_GRID_SIDE]u32, tri: IcoTriangle, i: u32, j: u32, side: u32, subdivisions: u32) u32 {
    if (i == 0 and j == 0) return tri.a;
    if (i == side and j == 0) return tri.b;
    if (i == 0 and j == side) return tri.c;
    if (j == 0) return icoEdgeIndex(edges, edge_points, tri.ab_edge, tri.a, tri.b, i, subdivisions);
    if (i == 0) return icoEdgeIndex(edges, edge_points, tri.ca_edge, tri.a, tri.c, j, subdivisions);
    if (i + j == side) return icoEdgeIndex(edges, edge_points, tri.bc_edge, tri.b, tri.c, j, subdivisions);
    return grid[j][i];
}

fn contentDeinit(allocator: std.mem.Allocator, content: *IcoContent) void {
    if (content.child) |child| {
        contentDeinit(allocator, child);
        allocator.destroy(child);
        content.child = null;
    }
    if (content.sides.len > 0) {
        allocator.free(content.sides);
        content.sides = &.{};
    }
}

fn contentSubdivide(allocator: std.mem.Allocator, content: *IcoContent, next_index: *u32) !void {
    switch (content.kind) {
        .none => {
            content.kind = .one;
            content.a = next_index.*;
            next_index.* += 1;
        },
        .one => {
            content.kind = .three;
            content.b = next_index.*;
            content.c = next_index.* + 1;
            next_index.* += 2;
        },
        .three => {
            content.kind = .six;
            content.ab = next_index.*;
            content.bc = next_index.* + 1;
            content.ca = next_index.* + 2;
            next_index.* += 3;
        },
        .six => {
            const old_ab = content.ab;
            const old_bc = content.bc;
            const old_ca = content.ca;
            content.kind = .more;
            content.sides = try allocator.alloc(u32, 3);
            content.sides[0] = old_ab;
            content.sides[1] = old_bc;
            content.sides[2] = old_ca;
            content.side_len = 1;
            content.child = try allocator.create(IcoContent);
            content.child.?.* = .{};
            try contentSubdivide(allocator, content, next_index);
        },
        .more => {
            const old_len = content.sides.len;
            content.sides = try allocator.realloc(content.sides, old_len + 3);
            content.sides[old_len + 0] = next_index.*;
            content.sides[old_len + 1] = next_index.* + 1;
            content.sides[old_len + 2] = next_index.* + 2;
            content.side_len += 1;
            next_index.* += 3;
            try contentSubdivide(allocator, content.child.?, next_index);
        },
    }
}

fn sliceAt(values: []const u32, forward: bool, index: usize) u32 {
    return if (forward) values[index] else values[values.len - 1 - index];
}

fn interpolateMultiple(points: []Vec3f, a: Vec3f, b: Vec3f, indices: []const u32) void {
    const angle = std.math.acos(vec3Dot(a, b));
    const sin_angle = @sin(angle);
    var i: usize = 0;
    while (i < indices.len) : (i += 1) {
        const percent = @as(f32, @floatFromInt(i + 1)) / @as(f32, @floatFromInt(indices.len + 1));
        const point = if (@abs(sin_angle) <= 0.000001)
            vec3Normalize(vec3Add(vec3Scale(a, 1.0 - percent), vec3Scale(b, percent))).?
        else blk: {
            const inv = 1.0 / sin_angle;
            break :blk vec3Add(vec3Scale(a, @sin((1.0 - percent) * angle) * inv), vec3Scale(b, @sin(percent * angle) * inv));
        };
        points[indices[i]] = point;
    }
}

fn contentIdxAb(content: *const IcoContent, index: usize) u32 {
    return switch (content.kind) {
        .one => content.a,
        .three => if (index == 0) content.a else content.b,
        .six => switch (index) {
            0 => content.a,
            1 => content.ab,
            else => content.b,
        },
        .more => blk: {
            const len = @as(usize, content.side_len);
            if (index == 0) break :blk content.a;
            if (index == len + 1) break :blk content.b;
            break :blk content.sides[index - 1];
        },
        .none => unreachable,
    };
}

fn contentIdxBc(content: *const IcoContent, index: usize) u32 {
    return switch (content.kind) {
        .one => content.a,
        .three => if (index == 0) content.b else content.c,
        .six => switch (index) {
            0 => content.b,
            1 => content.bc,
            else => content.c,
        },
        .more => blk: {
            const len = @as(usize, content.side_len);
            if (index == 0) break :blk content.b;
            if (index == len + 1) break :blk content.c;
            break :blk content.sides[len + index - 1];
        },
        .none => unreachable,
    };
}

fn contentIdxCa(content: *const IcoContent, index: usize) u32 {
    return switch (content.kind) {
        .one => content.a,
        .three => if (index == 0) content.c else content.a,
        .six => switch (index) {
            0 => content.c,
            1 => content.ca,
            else => content.a,
        },
        .more => blk: {
            const len = @as(usize, content.side_len);
            if (index == 0) break :blk content.c;
            if (index == len + 1) break :blk content.a;
            break :blk content.sides[len * 2 + index - 1];
        },
        .none => unreachable,
    };
}

fn contentCalculate(content: *IcoContent, ab: []const u32, ab_forward: bool, bc: []const u32, bc_forward: bool, ca: []const u32, ca_forward: bool, points: []Vec3f) void {
    switch (content.kind) {
        .none => unreachable,
        .one => {
            const p1 = points[sliceAt(ab, ab_forward, 0)];
            const p2 = points[sliceAt(bc, bc_forward, 1)];
            points[content.a] = geometricSlerp(p1, p2, 0.5);
        },
        .three => {
            const ab_mid = points[sliceAt(ab, ab_forward, 1)];
            const bc_mid = points[sliceAt(bc, bc_forward, 1)];
            const ca_mid = points[sliceAt(ca, ca_forward, 1)];
            points[content.a] = geometricSlerp(ab_mid, ca_mid, 0.5);
            points[content.b] = geometricSlerp(bc_mid, ab_mid, 0.5);
            points[content.c] = geometricSlerp(ca_mid, bc_mid, 0.5);
        },
        .six => {
            const aba = points[sliceAt(ab, ab_forward, 1)];
            const abb = points[sliceAt(ab, ab_forward, 2)];
            const bcb = points[sliceAt(bc, bc_forward, 1)];
            const bcc = points[sliceAt(bc, bc_forward, 2)];
            const cac = points[sliceAt(ca, ca_forward, 1)];
            const caa = points[sliceAt(ca, ca_forward, 2)];
            points[content.a] = geometricSlerp(aba, caa, 0.5);
            points[content.b] = geometricSlerp(abb, bcb, 0.5);
            points[content.c] = geometricSlerp(bcc, cac, 0.5);
            points[content.ab] = geometricSlerp(points[content.a], points[content.b], 0.5);
            points[content.bc] = geometricSlerp(points[content.b], points[content.c], 0.5);
            points[content.ca] = geometricSlerp(points[content.c], points[content.a], 0.5);
        },
        .more => {
            const side_len = @as(usize, content.side_len);
            const outer_len = ab.len;
            const aba = points[sliceAt(ab, ab_forward, 1)];
            const abb = points[sliceAt(ab, ab_forward, outer_len - 2)];
            const bcb = points[sliceAt(bc, bc_forward, 1)];
            const bcc = points[sliceAt(bc, bc_forward, outer_len - 2)];
            const cac = points[sliceAt(ca, ca_forward, 1)];
            const caa = points[sliceAt(ca, ca_forward, outer_len - 2)];
            points[content.a] = geometricSlerp(aba, caa, 0.5);
            points[content.b] = geometricSlerp(abb, bcb, 0.5);
            points[content.c] = geometricSlerp(bcc, cac, 0.5);
            const inner_ab = content.sides[0..side_len];
            const inner_bc = content.sides[side_len .. side_len * 2];
            const inner_ca = content.sides[side_len * 2 .. side_len * 3];
            interpolateMultiple(points, points[content.a], points[content.b], inner_ab);
            interpolateMultiple(points, points[content.b], points[content.c], inner_bc);
            interpolateMultiple(points, points[content.c], points[content.a], inner_ca);
            contentCalculate(content.child.?, inner_ab, true, inner_bc, true, inner_ca, true, points);
        },
    }
}

fn pushTri(indices: [*]u32, index_i: *usize, a: u32, b: u32, c: u32) void {
    indices[index_i.* + 0] = a;
    indices[index_i.* + 1] = b;
    indices[index_i.* + 2] = c;
    index_i.* += 3;
}

fn addIndicesTriangular(indices: [*]u32, index_i: *usize, a: u32, b: u32, c: u32, ab: []const u32, ab_forward: bool, bc: []const u32, bc_forward: bool, ca: []const u32, ca_forward: bool, content: *const IcoContent) void {
    const subdivisions = ab.len;
    if (subdivisions == 0) {
        pushTri(indices, index_i, a, b, c);
        return;
    }
    if (subdivisions == 1) {
        pushTri(indices, index_i, a, sliceAt(ab, ab_forward, 0), sliceAt(ca, ca_forward, 0));
        pushTri(indices, index_i, b, sliceAt(bc, bc_forward, 0), sliceAt(ab, ab_forward, 0));
        pushTri(indices, index_i, c, sliceAt(ca, ca_forward, 0), sliceAt(bc, bc_forward, 0));
        pushTri(indices, index_i, sliceAt(ab, ab_forward, 0), sliceAt(bc, bc_forward, 0), sliceAt(ca, ca_forward, 0));
        return;
    }
    if (subdivisions == 2) {
        pushTri(indices, index_i, a, sliceAt(ab, ab_forward, 0), sliceAt(ca, ca_forward, 1));
        pushTri(indices, index_i, b, sliceAt(bc, bc_forward, 0), sliceAt(ab, ab_forward, 1));
        pushTri(indices, index_i, c, sliceAt(ca, ca_forward, 0), sliceAt(bc, bc_forward, 1));
        pushTri(indices, index_i, sliceAt(ab, ab_forward, 1), contentIdxAb(content, 0), sliceAt(ab, ab_forward, 0));
        pushTri(indices, index_i, sliceAt(bc, bc_forward, 1), contentIdxAb(content, 0), sliceAt(bc, bc_forward, 0));
        pushTri(indices, index_i, sliceAt(ca, ca_forward, 1), contentIdxAb(content, 0), sliceAt(ca, ca_forward, 0));
        pushTri(indices, index_i, sliceAt(ab, ab_forward, 0), contentIdxAb(content, 0), sliceAt(ca, ca_forward, 1));
        pushTri(indices, index_i, sliceAt(bc, bc_forward, 0), contentIdxAb(content, 0), sliceAt(ab, ab_forward, 1));
        pushTri(indices, index_i, sliceAt(ca, ca_forward, 0), contentIdxAb(content, 0), sliceAt(bc, bc_forward, 1));
        return;
    }

    const last_idx = subdivisions - 1;
    pushTri(indices, index_i, a, sliceAt(ab, ab_forward, 0), sliceAt(ca, ca_forward, last_idx));
    pushTri(indices, index_i, b, sliceAt(bc, bc_forward, 0), sliceAt(ab, ab_forward, last_idx));
    pushTri(indices, index_i, c, sliceAt(ca, ca_forward, 0), sliceAt(bc, bc_forward, last_idx));
    pushTri(indices, index_i, sliceAt(ab, ab_forward, 0), contentIdxAb(content, 0), sliceAt(ca, ca_forward, last_idx));
    pushTri(indices, index_i, sliceAt(bc, bc_forward, 0), contentIdxBc(content, 0), sliceAt(ab, ab_forward, last_idx));
    pushTri(indices, index_i, sliceAt(ca, ca_forward, 0), contentIdxCa(content, 0), sliceAt(bc, bc_forward, last_idx));

    var i: usize = 0;
    while (i < last_idx - 1) : (i += 1) {
        pushTri(indices, index_i, sliceAt(ab, ab_forward, i), sliceAt(ab, ab_forward, i + 1), contentIdxAb(content, i));
        pushTri(indices, index_i, sliceAt(ab, ab_forward, i + 1), contentIdxAb(content, i + 1), contentIdxAb(content, i));
        pushTri(indices, index_i, sliceAt(bc, bc_forward, i), sliceAt(bc, bc_forward, i + 1), contentIdxBc(content, i));
        pushTri(indices, index_i, sliceAt(bc, bc_forward, i + 1), contentIdxBc(content, i + 1), contentIdxBc(content, i));
        pushTri(indices, index_i, sliceAt(ca, ca_forward, i), sliceAt(ca, ca_forward, i + 1), contentIdxCa(content, i));
        pushTri(indices, index_i, sliceAt(ca, ca_forward, i + 1), contentIdxCa(content, i + 1), contentIdxCa(content, i));
    }

    pushTri(indices, index_i, sliceAt(ab, ab_forward, last_idx), contentIdxAb(content, last_idx - 1), sliceAt(ab, ab_forward, last_idx - 1));
    pushTri(indices, index_i, sliceAt(bc, bc_forward, last_idx), contentIdxBc(content, last_idx - 1), sliceAt(bc, bc_forward, last_idx - 1));
    pushTri(indices, index_i, sliceAt(ca, ca_forward, last_idx), contentIdxCa(content, last_idx - 1), sliceAt(ca, ca_forward, last_idx - 1));
}

fn contentAddIndices(indices: [*]u32, index_i: *usize, content: *const IcoContent) void {
    switch (content.kind) {
        .none, .one => {},
        .three => pushTri(indices, index_i, content.a, content.b, content.c),
        .six => {
            pushTri(indices, index_i, content.a, content.ab, content.ca);
            pushTri(indices, index_i, content.ab, content.b, content.bc);
            pushTri(indices, index_i, content.bc, content.c, content.ca);
            pushTri(indices, index_i, content.ab, content.bc, content.ca);
        },
        .more => {
            const side_len = @as(usize, content.side_len);
            const inner_ab = content.sides[0..side_len];
            const inner_bc = content.sides[side_len .. side_len * 2];
            const inner_ca = content.sides[side_len * 2 .. side_len * 3];
            addIndicesTriangular(indices, index_i, content.a, content.b, content.c, inner_ab, true, inner_bc, true, inner_ca, true, content.child.?);
            contentAddIndices(indices, index_i, content.child.?);
        },
    }
}

pub export fn sa3d_geometry_cuboid_write(vertices: [*]VertexP3N3Uv2, indices: [*]u32, half_x: f32, half_y: f32, half_z: f32) callconv(.c) bool {
    const min_x = -half_x;
    const min_y = -half_y;
    const min_z = -half_z;
    const max_x = half_x;
    const max_y = half_y;
    const max_z = half_z;

    // Matches Bevy's CuboidMeshBuilder vertex order, normals, UVs and indices.
    writeVertex(&vertices[0], min_x, min_y, max_z, 0.0, 0.0, 1.0, 0.0, 0.0);
    writeVertex(&vertices[1], max_x, min_y, max_z, 0.0, 0.0, 1.0, 1.0, 0.0);
    writeVertex(&vertices[2], max_x, max_y, max_z, 0.0, 0.0, 1.0, 1.0, 1.0);
    writeVertex(&vertices[3], min_x, max_y, max_z, 0.0, 0.0, 1.0, 0.0, 1.0);

    writeVertex(&vertices[4], min_x, max_y, min_z, 0.0, 0.0, -1.0, 1.0, 0.0);
    writeVertex(&vertices[5], max_x, max_y, min_z, 0.0, 0.0, -1.0, 0.0, 0.0);
    writeVertex(&vertices[6], max_x, min_y, min_z, 0.0, 0.0, -1.0, 0.0, 1.0);
    writeVertex(&vertices[7], min_x, min_y, min_z, 0.0, 0.0, -1.0, 1.0, 1.0);

    writeVertex(&vertices[8], max_x, min_y, min_z, 1.0, 0.0, 0.0, 0.0, 0.0);
    writeVertex(&vertices[9], max_x, max_y, min_z, 1.0, 0.0, 0.0, 1.0, 0.0);
    writeVertex(&vertices[10], max_x, max_y, max_z, 1.0, 0.0, 0.0, 1.0, 1.0);
    writeVertex(&vertices[11], max_x, min_y, max_z, 1.0, 0.0, 0.0, 0.0, 1.0);

    writeVertex(&vertices[12], min_x, min_y, max_z, -1.0, 0.0, 0.0, 1.0, 0.0);
    writeVertex(&vertices[13], min_x, max_y, max_z, -1.0, 0.0, 0.0, 0.0, 0.0);
    writeVertex(&vertices[14], min_x, max_y, min_z, -1.0, 0.0, 0.0, 0.0, 1.0);
    writeVertex(&vertices[15], min_x, min_y, min_z, -1.0, 0.0, 0.0, 1.0, 1.0);

    writeVertex(&vertices[16], max_x, max_y, min_z, 0.0, 1.0, 0.0, 1.0, 0.0);
    writeVertex(&vertices[17], min_x, max_y, min_z, 0.0, 1.0, 0.0, 0.0, 0.0);
    writeVertex(&vertices[18], min_x, max_y, max_z, 0.0, 1.0, 0.0, 0.0, 1.0);
    writeVertex(&vertices[19], max_x, max_y, max_z, 0.0, 1.0, 0.0, 1.0, 1.0);

    writeVertex(&vertices[20], max_x, min_y, max_z, 0.0, -1.0, 0.0, 0.0, 0.0);
    writeVertex(&vertices[21], min_x, min_y, max_z, 0.0, -1.0, 0.0, 1.0, 0.0);
    writeVertex(&vertices[22], min_x, min_y, min_z, 0.0, -1.0, 0.0, 1.0, 1.0);
    writeVertex(&vertices[23], max_x, min_y, min_z, 0.0, -1.0, 0.0, 0.0, 1.0);

    const bevy_indices = [_]u32{
        0,  1,  2,  2,  3,  0,
        4,  5,  6,  6,  7,  4,
        8,  9,  10, 10, 11, 8,
        12, 13, 14, 14, 15, 12,
        16, 17, 18, 18, 19, 16,
        20, 21, 22, 22, 23, 20,
    };
    var i: usize = 0;
    while (i < bevy_indices.len) : (i += 1) indices[i] = bevy_indices[i];
    return true;
}

pub export fn sa3d_geometry_cuboid_mesh_desc(out: *MeshDesc, vertices: [*]VertexP3N3Uv2, indices: [*]u32, half_x: f32, half_y: f32, half_z: f32) callconv(.c) bool {
    if (!sa3d_geometry_cuboid_write(vertices, indices, half_x, half_y, half_z)) return false;
    sa3d_geometry_mesh_desc_init(out, vertices, CUBOID_VERTEX_COUNT, indices, CUBOID_INDEX_COUNT, @intFromEnum(IndexFormat.u32), @intFromEnum(PrimitiveTopology.triangle_list));
    return true;
}

pub export fn sa3d_geometry_plane_vertex_count(subdivisions_x: u32, subdivisions_z: u32) callconv(.c) u64 {
    return (@as(u64, subdivisions_x) + 2) * (@as(u64, subdivisions_z) + 2);
}

pub export fn sa3d_geometry_plane_index_count(subdivisions_x: u32, subdivisions_z: u32) callconv(.c) u64 {
    return (@as(u64, subdivisions_x) + 1) * (@as(u64, subdivisions_z) + 1) * 6;
}

fn checkedPlaneVertexCount(subdivisions_x: u32, subdivisions_z: u32) ?u64 {
    const x_count = @as(u64, subdivisions_x) + 2;
    const z_count = @as(u64, subdivisions_z) + 2;
    return std.math.mul(u64, x_count, z_count) catch null;
}

fn checkedPlaneIndexCount(subdivisions_x: u32, subdivisions_z: u32) ?u64 {
    const x_quads = @as(u64, subdivisions_x) + 1;
    const z_quads = @as(u64, subdivisions_z) + 1;
    const quads = std.math.mul(u64, x_quads, z_quads) catch return null;
    return std.math.mul(u64, quads, 6) catch null;
}

pub export fn sa3d_geometry_uv_sphere_vertex_count(sectors: u32, stacks: u32) callconv(.c) u64 {
    return (@as(u64, sectors) + 1) * (@as(u64, stacks) + 1);
}

pub export fn sa3d_geometry_uv_sphere_index_count(sectors: u32, stacks: u32) callconv(.c) u64 {
    if (stacks == 0) return 0;
    return @as(u64, sectors) * @as(u64, stacks - 1) * 6;
}

pub export fn sa3d_geometry_ico_sphere_vertex_count(subdivisions: u32) callconv(.c) u64 {
    return checkedIcoSphereVertexCount(subdivisions) orelse 0;
}

pub export fn sa3d_geometry_ico_sphere_index_count(subdivisions: u32) callconv(.c) u64 {
    return checkedIcoSphereIndexCount(subdivisions) orelse 0;
}

fn checkedUvSphereVertexCount(sectors: u32, stacks: u32) ?u64 {
    const sector_count = @as(u64, sectors) + 1;
    const stack_count = @as(u64, stacks) + 1;
    return std.math.mul(u64, sector_count, stack_count) catch null;
}

fn checkedUvSphereIndexCount(sectors: u32, stacks: u32) ?u64 {
    if (stacks == 0) return 0;
    const strips = @as(u64, stacks - 1);
    const quads = std.math.mul(u64, @as(u64, sectors), strips) catch return null;
    return std.math.mul(u64, quads, 6) catch null;
}

pub export fn sa3d_geometry_cylinder_vertex_count(resolution: u32, segments: u32, caps: bool) callconv(.c) u64 {
    return (@as(u64, segments) + 1) * (@as(u64, resolution) + 1) + if (caps) @as(u64, resolution) * 2 else 0;
}

pub export fn sa3d_geometry_cylinder_index_count(resolution: u32, segments: u32, caps: bool) callconv(.c) u64 {
    const barrel = @as(u64, segments) * @as(u64, resolution) * 6;
    const cap_indices = if (caps and resolution >= 2) @as(u64, resolution - 2) * 6 else 0;
    return barrel + cap_indices;
}

fn checkedCylinderVertexCount(resolution: u32, segments: u32, caps: bool) ?u64 {
    const rings = @as(u64, segments) + 1;
    const ring_vertices = @as(u64, resolution) + 1;
    const barrel = std.math.mul(u64, rings, ring_vertices) catch return null;
    if (!caps) return barrel;
    const cap_vertices = std.math.mul(u64, @as(u64, resolution), 2) catch return null;
    return std.math.add(u64, barrel, cap_vertices) catch null;
}

fn checkedCylinderIndexCount(resolution: u32, segments: u32, caps: bool) ?u64 {
    const barrel_faces = std.math.mul(u64, @as(u64, segments), @as(u64, resolution)) catch return null;
    const barrel = std.math.mul(u64, barrel_faces, 6) catch return null;
    if (!caps) return barrel;
    if (resolution < 2) return barrel;
    const cap_tris = std.math.mul(u64, @as(u64, resolution - 2), 6) catch return null;
    return std.math.add(u64, barrel, cap_tris) catch null;
}

pub export fn sa3d_geometry_cone_vertex_count(resolution: u32) callconv(.c) u64 {
    return @as(u64, resolution) * 2 + 1;
}

pub export fn sa3d_geometry_cone_index_count(resolution: u32) callconv(.c) u64 {
    if (resolution < 2) return 0;
    return @as(u64, resolution) * 6 - 6;
}

fn checkedConeVertexCount(resolution: u32) ?u64 {
    const doubled = std.math.mul(u64, @as(u64, resolution), 2) catch return null;
    return std.math.add(u64, doubled, 1) catch null;
}

fn checkedConeIndexCount(resolution: u32) ?u64 {
    if (resolution < 2) return 0;
    const doubled = std.math.mul(u64, @as(u64, resolution), 6) catch return null;
    return std.math.sub(u64, doubled, 6) catch null;
}

fn capsuleCounts(longitudes: u32, latitudes: u32, rings: u32) ?struct { vertices: u64, indices: u64 } {
    if (longitudes == 0 or latitudes < 4) return null;
    const half_lats = latitudes / 2;
    if (half_lats < 2) return null;
    const half_latsn1 = half_lats - 1;
    const half_latsn2 = half_lats - 2;
    const lonsp1 = @as(u64, longitudes) + 1;
    const north_hemi = @as(u64, longitudes);
    const north_equator = north_hemi + lonsp1 * @as(u64, half_latsn1);
    const cylinder = north_equator + lonsp1;
    const south_equator = if (rings > 0) cylinder + lonsp1 * @as(u64, rings) else cylinder;
    const south_hemi = south_equator + lonsp1;
    const south_polar = south_hemi + lonsp1 * @as(u64, half_latsn2);
    const south_cap = south_polar + lonsp1;
    const vertices = south_cap + @as(u64, longitudes);
    const lons3 = @as(u64, longitudes) * 3;
    const lons6 = @as(u64, longitudes) * 6;
    const hemi_lons = @as(u64, half_latsn1) * lons6;
    const indices = lons3 + hemi_lons + (@as(u64, rings) + 1) * lons6 + hemi_lons + lons3;
    return .{ .vertices = vertices, .indices = indices };
}

fn capsuleOffsets(longitudes: u32, latitudes: u32, rings: u32) ?struct {
    half_lats: u32,
    half_latsn1: u32,
    half_latsn2: u32,
    ringsp1: u32,
    lonsp1: u32,
    north_hemi: u32,
    north_equator: u32,
    cylinder: u32,
    south_equator: u32,
    south_hemi: u32,
    south_polar: u32,
    south_cap: u32,
    tri_north_hemi: u32,
    tri_cylinder: u32,
    tri_south_hemi: u32,
    tri_south_cap: u32,
} {
    const counts = capsuleCounts(longitudes, latitudes, rings) orelse return null;
    if (counts.vertices > std.math.maxInt(u32) or counts.indices > std.math.maxInt(u32)) return null;
    const half_lats = latitudes / 2;
    const half_latsn1 = half_lats - 1;
    const half_latsn2 = half_lats - 2;
    const ringsp1 = rings + 1;
    const lonsp1 = longitudes + 1;
    const north_hemi = longitudes;
    const north_equator = north_hemi + lonsp1 * half_latsn1;
    const cylinder = north_equator + lonsp1;
    const south_equator = if (rings > 0) cylinder + lonsp1 * rings else cylinder;
    const south_hemi = south_equator + lonsp1;
    const south_polar = south_hemi + lonsp1 * half_latsn2;
    const south_cap = south_polar + lonsp1;
    const lons3 = longitudes * 3;
    const lons6 = longitudes * 6;
    const hemi_lons = half_latsn1 * lons6;
    const tri_north_hemi = lons3;
    const tri_cylinder = tri_north_hemi + hemi_lons;
    const tri_south_hemi = tri_cylinder + ringsp1 * lons6;
    const tri_south_cap = tri_south_hemi + hemi_lons;
    return .{
        .half_lats = half_lats,
        .half_latsn1 = half_latsn1,
        .half_latsn2 = half_latsn2,
        .ringsp1 = ringsp1,
        .lonsp1 = lonsp1,
        .north_hemi = north_hemi,
        .north_equator = north_equator,
        .cylinder = cylinder,
        .south_equator = south_equator,
        .south_hemi = south_hemi,
        .south_polar = south_polar,
        .south_cap = south_cap,
        .tri_north_hemi = tri_north_hemi,
        .tri_cylinder = tri_cylinder,
        .tri_south_hemi = tri_south_hemi,
        .tri_south_cap = tri_south_cap,
    };
}

pub export fn sa3d_geometry_capsule_vertex_count(longitudes: u32, latitudes: u32, rings: u32) callconv(.c) u64 {
    return (capsuleCounts(longitudes, latitudes, rings) orelse return 0).vertices;
}

pub export fn sa3d_geometry_capsule_index_count(longitudes: u32, latitudes: u32, rings: u32) callconv(.c) u64 {
    return (capsuleCounts(longitudes, latitudes, rings) orelse return 0).indices;
}

pub export fn sa3d_geometry_torus_vertex_count(major_resolution: u32, minor_resolution: u32) callconv(.c) u64 {
    return (@as(u64, major_resolution) + 1) * (@as(u64, minor_resolution) + 1);
}

pub export fn sa3d_geometry_torus_index_count(major_resolution: u32, minor_resolution: u32) callconv(.c) u64 {
    return @as(u64, major_resolution) * @as(u64, minor_resolution) * 6;
}

pub export fn sa3d_geometry_conical_frustum_vertex_count(resolution: u32, segments: u32) callconv(.c) u64 {
    const num_rings = @as(u64, segments) + 1;
    return @as(u64, resolution) * 2 + num_rings * (@as(u64, resolution) + 1);
}

pub export fn sa3d_geometry_conical_frustum_index_count(resolution: u32, segments: u32) callconv(.c) u64 {
    const num_rings = @as(u64, segments) + 1;
    const num_faces = @as(u64, resolution) * (num_rings - 2);
    return (2 * num_faces + 2 * (@as(u64, resolution) - 1) * 2) * 3;
}

pub export fn sa3d_geometry_triangle_vertex_count() callconv(.c) u64 {
    return 3;
}

pub export fn sa3d_geometry_triangle_index_count() callconv(.c) u64 {
    return 3;
}

pub export fn sa3d_geometry_tetrahedron_vertex_count() callconv(.c) u64 {
    return 12;
}

pub export fn sa3d_geometry_tetrahedron_index_count() callconv(.c) u64 {
    return 12;
}

pub export fn sa3d_geometry_segment_vertex_count() callconv(.c) u64 {
    return 2;
}

pub export fn sa3d_geometry_segment_index_count() callconv(.c) u64 {
    return 2;
}

pub export fn sa3d_geometry_polyline_vertex_count(vertex_len: u64) callconv(.c) u64 {
    return vertex_len;
}

pub export fn sa3d_geometry_polyline_index_count(vertex_len: u64) callconv(.c) u64 {
    if (vertex_len < 2) return 0;
    return (vertex_len - 1) * 2;
}

fn checkedTorusVertexCount(major_resolution: u32, minor_resolution: u32) ?u64 {
    const majors = @as(u64, major_resolution) + 1;
    const minors = @as(u64, minor_resolution) + 1;
    return std.math.mul(u64, majors, minors) catch null;
}

fn checkedTorusIndexCount(major_resolution: u32, minor_resolution: u32) ?u64 {
    const faces = std.math.mul(u64, @as(u64, major_resolution), @as(u64, minor_resolution)) catch return null;
    return std.math.mul(u64, faces, 6) catch null;
}

fn checkedConicalFrustumVertexCount(resolution: u32, segments: u32) ?u64 {
    if (resolution <= 2 or segments == 0) return null;
    const rings = @as(u64, segments) + 1;
    const ring_vertices = std.math.mul(u64, rings, @as(u64, resolution) + 1) catch return null;
    const cap_vertices = std.math.mul(u64, @as(u64, resolution), 2) catch return null;
    return std.math.add(u64, cap_vertices, ring_vertices) catch null;
}

fn checkedConicalFrustumIndexCount(resolution: u32, segments: u32) ?u64 {
    if (resolution <= 2 or segments == 0) return null;
    const rings = @as(u64, segments) + 1;
    const num_faces = std.math.mul(u64, @as(u64, resolution), rings - 2) catch return null;
    const lateral_faces = std.math.mul(u64, 2, num_faces) catch return null;
    const cap_faces = std.math.mul(u64, 4, @as(u64, resolution) - 1) catch return null;
    const faces = std.math.add(u64, lateral_faces, cap_faces) catch return null;
    return std.math.mul(u64, faces, 3) catch null;
}

fn checkedPolylineIndexCount(vertex_len: u64) ?u64 {
    if (vertex_len < 2) return null;
    return std.math.mul(u64, vertex_len - 1, 2) catch null;
}

pub export fn sa3d_geometry_plane_write(vertices: [*]VertexP3N3Uv2, indices: [*]u32, normal_x: f32, normal_y: f32, normal_z: f32, half_width: f32, half_height: f32, subdivisions_x: u32, subdivisions_z: u32) callconv(.c) bool {
    if (!std.math.isFinite(half_width) or !std.math.isFinite(half_height)) return false;
    const normal = vec3Normalize(.{ .x = normal_x, .y = normal_y, .z = normal_z }) orelse return false;
    const x_vertex_count = subdivisions_x + 2;
    const z_vertex_count = subdivisions_z + 2;
    const rotation = quatFromRotationArc(.{ .x = 0.0, .y = 1.0, .z = 0.0 }, normal);
    const size_x = half_width * 2.0;
    const size_z = half_height * 2.0;

    var z: u32 = 0;
    while (z < z_vertex_count) : (z += 1) {
        var x: u32 = 0;
        while (x < x_vertex_count) : (x += 1) {
            const tx = @as(f32, @floatFromInt(x)) / @as(f32, @floatFromInt(x_vertex_count - 1));
            const tz = @as(f32, @floatFromInt(z)) / @as(f32, @floatFromInt(z_vertex_count - 1));
            const local = Vec3f{ .x = (-0.5 + tx) * size_x, .y = 0.0, .z = (-0.5 + tz) * size_z };
            const pos = quatRotateVec3(rotation, local);
            const vertex_index = @as(usize, z) * @as(usize, x_vertex_count) + @as(usize, x);
            writeVertex(&vertices[vertex_index], pos.x, pos.y, pos.z, normal.x, normal.y, normal.z, tx, tz);
        }
    }

    var write_i: usize = 0;
    z = 0;
    while (z < z_vertex_count - 1) : (z += 1) {
        var x: u32 = 0;
        while (x < x_vertex_count - 1) : (x += 1) {
            const quad = z * x_vertex_count + x;
            indices[write_i + 0] = quad + x_vertex_count + 1;
            indices[write_i + 1] = quad + 1;
            indices[write_i + 2] = quad + x_vertex_count;
            indices[write_i + 3] = quad;
            indices[write_i + 4] = quad + x_vertex_count;
            indices[write_i + 5] = quad + 1;
            write_i += 6;
        }
    }
    return true;
}

pub export fn sa3d_geometry_plane_mesh_desc(out: *MeshDesc, vertices: [*]VertexP3N3Uv2, indices: [*]u32, normal_x: f32, normal_y: f32, normal_z: f32, half_width: f32, half_height: f32, subdivisions_x: u32, subdivisions_z: u32) callconv(.c) bool {
    const vertex_count = checkedPlaneVertexCount(subdivisions_x, subdivisions_z) orelse return false;
    const index_count = checkedPlaneIndexCount(subdivisions_x, subdivisions_z) orelse return false;
    if (vertex_count > std.math.maxInt(u32)) return false;
    if (!sa3d_geometry_plane_write(vertices, indices, normal_x, normal_y, normal_z, half_width, half_height, subdivisions_x, subdivisions_z)) return false;
    sa3d_geometry_mesh_desc_init(out, vertices, vertex_count, indices, index_count, @intFromEnum(IndexFormat.u32), @intFromEnum(PrimitiveTopology.triangle_list));
    return true;
}

pub export fn sa3d_geometry_uv_sphere_write(vertices: [*]VertexP3N3Uv2, indices: [*]u32, radius: f32, sectors: u32, stacks: u32) callconv(.c) bool {
    if (!std.math.isFinite(radius)) return false;

    const sectors_f32 = @as(f32, @floatFromInt(sectors));
    const stacks_f32 = @as(f32, @floatFromInt(stacks));
    const length_inv = 1.0 / radius;
    const sector_step = 2.0 * std.math.pi / sectors_f32;
    const stack_step = std.math.pi / stacks_f32;

    var vertex_i: usize = 0;
    var i: u32 = 0;
    while (i <= stacks) : (i += 1) {
        const stack_angle = std.math.pi / 2.0 - @as(f32, @floatFromInt(i)) * stack_step;
        const xy = radius * @cos(stack_angle);
        const z = radius * @sin(stack_angle);

        var j: u32 = 0;
        while (j <= sectors) : (j += 1) {
            const sector_angle = @as(f32, @floatFromInt(j)) * sector_step;
            const x = xy * @cos(sector_angle);
            const y = xy * @sin(sector_angle);
            writeVertex(&vertices[vertex_i], x, y, z, x * length_inv, y * length_inv, z * length_inv, @as(f32, @floatFromInt(j)) / sectors_f32, @as(f32, @floatFromInt(i)) / stacks_f32);
            vertex_i += 1;
        }
    }

    var index_i: usize = 0;
    i = 0;
    while (i < stacks) : (i += 1) {
        var k1 = i * (sectors + 1);
        var k2 = k1 + sectors + 1;
        var j: u32 = 0;
        while (j < sectors) : (j += 1) {
            if (i != 0) {
                indices[index_i + 0] = k1;
                indices[index_i + 1] = k2;
                indices[index_i + 2] = k1 + 1;
                index_i += 3;
            }
            if (i != stacks - 1) {
                indices[index_i + 0] = k1 + 1;
                indices[index_i + 1] = k2;
                indices[index_i + 2] = k2 + 1;
                index_i += 3;
            }
            k1 += 1;
            k2 += 1;
        }
    }
    return true;
}

pub export fn sa3d_geometry_uv_sphere_mesh_desc(out: *MeshDesc, vertices: [*]VertexP3N3Uv2, indices: [*]u32, radius: f32, sectors: u32, stacks: u32) callconv(.c) bool {
    const vertex_count = checkedUvSphereVertexCount(sectors, stacks) orelse return false;
    const index_count = checkedUvSphereIndexCount(sectors, stacks) orelse return false;
    if (vertex_count > std.math.maxInt(u32)) return false;
    if (!sa3d_geometry_uv_sphere_write(vertices, indices, radius, sectors, stacks)) return false;
    sa3d_geometry_mesh_desc_init(out, vertices, vertex_count, indices, index_count, @intFromEnum(IndexFormat.u32), @intFromEnum(PrimitiveTopology.triangle_list));
    return true;
}

pub export fn sa3d_geometry_native_ico_sphere_write(vertices: [*]VertexP3N3Uv2, indices: [*]u32, radius: f32, subdivisions_raw: u64) callconv(.c) i32 {
    if (!std.math.isFinite(radius)) return 0;
    if (subdivisions_raw > std.math.maxInt(u32)) return 0;
    const subdivisions: u32 = @intCast(subdivisions_raw);
    const vertex_count = checkedIcoSphereVertexCount(subdivisions) orelse return 0;
    const index_count = checkedIcoSphereIndexCount(subdivisions) orelse return 0;
    if (vertex_count > std.math.maxInt(u32) or index_count > std.math.maxInt(u32)) return 0;

    const allocator = std.heap.page_allocator;
    const raw_points = allocator.alloc(Vec3f, @as(usize, @intCast(vertex_count))) catch return 0;
    defer allocator.free(raw_points);
    const edge_points_flat = allocator.alloc(u32, ICO_EDGE_COUNT * @as(usize, subdivisions)) catch return 0;
    defer allocator.free(edge_points_flat);

    var p_i: usize = 0;
    while (p_i < ICO_POINTS.len) : (p_i += 1) {
        raw_points[p_i] = ICO_POINTS[p_i];
    }

    var edges: [ICO_EDGE_COUNT]IcoEdgeRuntime = undefined;
    var next_index: u32 = @as(u32, @intCast(ICO_POINTS.len));
    var edge_id: usize = 0;
    while (edge_id < ICO_EDGE_COUNT) : (edge_id += 1) {
        const start = edge_id * @as(usize, subdivisions);
        edges[edge_id] = .{
            .points = edge_points_flat[start .. start + @as(usize, subdivisions)],
            .done = false,
        };
        var s: u32 = 0;
        while (s < subdivisions) : (s += 1) {
            edges[edge_id].points[s] = next_index;
            next_index += 1;
        }
    }

    var triangles: [ICO_TRIANGLE_COUNT]IcoTriangleRuntime = undefined;
    var tri_i: usize = 0;
    while (tri_i < ICO_TRIANGLE_COUNT) : (tri_i += 1) {
        triangles[tri_i] = .{ .base = ICO_TRIANGLES[tri_i] };
        var level: u32 = 0;
        while (level < subdivisions) : (level += 1) {
            if (level >= 1) {
                contentSubdivide(allocator, &triangles[tri_i].content, &next_index) catch {
                    var cleanup_i: usize = 0;
                    while (cleanup_i <= tri_i) : (cleanup_i += 1) contentDeinit(allocator, &triangles[cleanup_i].content);
                    return 0;
                };
            }
        }
    }
    defer {
        var cleanup_i: usize = 0;
        while (cleanup_i < ICO_TRIANGLE_COUNT) : (cleanup_i += 1) contentDeinit(allocator, &triangles[cleanup_i].content);
    }

    tri_i = 0;
    while (tri_i < ICO_TRIANGLE_COUNT) : (tri_i += 1) {
        var tri = &triangles[tri_i];
        const base = tri.base;
        const edge_defs = [_]struct {
            p1: u32,
            p2: u32,
            edge: usize,
            forward: *bool,
        }{
            .{ .p1 = base.a, .p2 = base.b, .edge = base.ab_edge, .forward = &tri.ab_forward },
            .{ .p1 = base.b, .p2 = base.c, .edge = base.bc_edge, .forward = &tri.bc_forward },
            .{ .p1 = base.c, .p2 = base.a, .edge = base.ca_edge, .forward = &tri.ca_forward },
        };
        var e: usize = 0;
        while (e < edge_defs.len) : (e += 1) {
            const def = edge_defs[e];
            if (!edges[def.edge].done) {
                interpolateMultiple(raw_points, raw_points[def.p1], raw_points[def.p2], edges[def.edge].points);
                edges[def.edge].done = true;
                def.forward.* = true;
            } else {
                def.forward.* = false;
            }
        }

        if (subdivisions >= 2) {
            contentCalculate(
                &tri.content,
                edges[base.ab_edge].points,
                tri.ab_forward,
                edges[base.bc_edge].points,
                tri.bc_forward,
                edges[base.ca_edge].points,
                tri.ca_forward,
                raw_points,
            );
        }
    }

    p_i = 0;
    while (p_i < @as(usize, @intCast(vertex_count))) : (p_i += 1) {
        icoSetVertex(vertices, @as(u32, @intCast(p_i)), raw_points[p_i], radius);
    }

    var index_i: usize = 0;
    tri_i = 0;
    while (tri_i < ICO_TRIANGLE_COUNT) : (tri_i += 1) {
        const tri = &triangles[tri_i];
        const base = tri.base;
        addIndicesTriangular(
            indices,
            &index_i,
            base.a,
            base.b,
            base.c,
            edges[base.ab_edge].points,
            tri.ab_forward,
            edges[base.bc_edge].points,
            tri.bc_forward,
            edges[base.ca_edge].points,
            tri.ca_forward,
            &tri.content,
        );
        contentAddIndices(indices, &index_i, &tri.content);
    }
    return if (next_index == vertex_count and index_i == index_count) 1 else 0;
}

pub export fn sa3d_geometry_native_ico_sphere_mesh_desc(out: *MeshDesc, vertices: [*]VertexP3N3Uv2, indices: [*]u32, radius: f32, subdivisions_raw: u64) callconv(.c) i32 {
    if (subdivisions_raw > std.math.maxInt(u32)) return 0;
    const subdivisions: u32 = @intCast(subdivisions_raw);
    const vertex_count = checkedIcoSphereVertexCount(subdivisions) orelse return 0;
    const index_count = checkedIcoSphereIndexCount(subdivisions) orelse return 0;
    if (sa3d_geometry_native_ico_sphere_write(vertices, indices, radius, subdivisions) == 0) return 0;
    sa3d_geometry_mesh_desc_init(out, vertices, vertex_count, indices, index_count, @intFromEnum(IndexFormat.u32), @intFromEnum(PrimitiveTopology.triangle_list));
    return 1;
}

pub export fn sa3d_geometry_cylinder_write(vertices: [*]VertexP3N3Uv2, indices: [*]u32, radius: f32, height: f32, resolution: u32, segments: u32, caps: bool, anchor: i32) callconv(.c) bool {
    if (!std.math.isFinite(radius) or !std.math.isFinite(height)) return false;
    if (resolution <= 2 or segments == 0) return false;
    if (anchor < @intFromEnum(CylinderAnchor.midpoint) or anchor > @intFromEnum(CylinderAnchor.bottom)) return false;

    const half_height = height / 2.0;
    const step_theta = 2.0 * std.math.pi / @as(f32, @floatFromInt(resolution));
    const step_y = 2.0 * half_height / @as(f32, @floatFromInt(segments));

    var vertex_i: usize = 0;
    var ring: u32 = 0;
    while (ring <= segments) : (ring += 1) {
        const y = -half_height + @as(f32, @floatFromInt(ring)) * step_y;
        var segment: u32 = 0;
        while (segment <= resolution) : (segment += 1) {
            const theta = @as(f32, @floatFromInt(segment)) * step_theta;
            const sin = @sin(theta);
            const cos = @cos(theta);
            writeVertex(&vertices[vertex_i], radius * cos, y, radius * sin, cos, 0.0, sin, @as(f32, @floatFromInt(segment)) / @as(f32, @floatFromInt(resolution)), @as(f32, @floatFromInt(ring)) / @as(f32, @floatFromInt(segments)));
            vertex_i += 1;
        }
    }

    var index_i: usize = 0;
    var i: u32 = 0;
    while (i < segments) : (i += 1) {
        const ring_start = i * (resolution + 1);
        const next_ring = (i + 1) * (resolution + 1);
        var j: u32 = 0;
        while (j < resolution) : (j += 1) {
            indices[index_i + 0] = ring_start + j;
            indices[index_i + 1] = next_ring + j;
            indices[index_i + 2] = ring_start + j + 1;
            indices[index_i + 3] = next_ring + j;
            indices[index_i + 4] = next_ring + j + 1;
            indices[index_i + 5] = ring_start + j + 1;
            index_i += 6;
        }
    }

    if (caps) {
        const top_offset = @as(u32, @intCast(vertex_i));
        i = 0;
        while (i < resolution) : (i += 1) {
            const theta = @as(f32, @floatFromInt(i)) * step_theta;
            const sin = @sin(theta);
            const cos = @cos(theta);
            writeVertex(&vertices[vertex_i], cos * radius, half_height, sin * radius, 0.0, 1.0, 0.0, 0.5 * (cos + 1.0), 1.0 - 0.5 * (sin + 1.0));
            vertex_i += 1;
        }
        i = 1;
        while (i < resolution - 1) : (i += 1) {
            indices[index_i + 0] = top_offset;
            indices[index_i + 1] = top_offset + i + 1;
            indices[index_i + 2] = top_offset + i;
            index_i += 3;
        }

        const bottom_offset = @as(u32, @intCast(vertex_i));
        i = 0;
        while (i < resolution) : (i += 1) {
            const theta = @as(f32, @floatFromInt(i)) * step_theta;
            const sin = @sin(theta);
            const cos = @cos(theta);
            writeVertex(&vertices[vertex_i], cos * radius, -half_height, sin * radius, 0.0, -1.0, 0.0, 0.5 * (cos + 1.0), 1.0 - 0.5 * (sin + 1.0));
            vertex_i += 1;
        }
        i = 1;
        while (i < resolution - 1) : (i += 1) {
            indices[index_i + 0] = bottom_offset;
            indices[index_i + 1] = bottom_offset + i;
            indices[index_i + 2] = bottom_offset + i + 1;
            index_i += 3;
        }
    }

    const anchor_offset: f32 = if (anchor == @intFromEnum(CylinderAnchor.top)) -half_height else if (anchor == @intFromEnum(CylinderAnchor.bottom)) half_height else 0.0;
    if (anchor_offset != 0.0) {
        var v: usize = 0;
        while (v < vertex_i) : (v += 1) vertices[v].position.y += anchor_offset;
    }
    return true;
}

pub export fn sa3d_geometry_cylinder_mesh_desc(out: *MeshDesc, vertices: [*]VertexP3N3Uv2, indices: [*]u32, radius: f32, height: f32, resolution: u32, segments: u32, caps: bool, anchor: i32) callconv(.c) bool {
    const vertex_count = checkedCylinderVertexCount(resolution, segments, caps) orelse return false;
    const index_count = checkedCylinderIndexCount(resolution, segments, caps) orelse return false;
    if (vertex_count > std.math.maxInt(u32)) return false;
    if (!sa3d_geometry_cylinder_write(vertices, indices, radius, height, resolution, segments, caps, anchor)) return false;
    sa3d_geometry_mesh_desc_init(out, vertices, vertex_count, indices, index_count, @intFromEnum(IndexFormat.u32), @intFromEnum(PrimitiveTopology.triangle_list));
    return true;
}

pub export fn sa3d_geometry_conical_frustum_write(vertices: [*]VertexP3N3Uv2, indices: [*]u32, radius_top: f32, radius_bottom: f32, height: f32, resolution: u32, segments: u32) callconv(.c) bool {
    if (!std.math.isFinite(radius_top) or !std.math.isFinite(radius_bottom) or !std.math.isFinite(height)) return false;
    if (resolution <= 2 or segments == 0) return false;

    const half_height = height / 2.0;
    const step_theta = 2.0 * std.math.pi / @as(f32, @floatFromInt(resolution));
    const step_y = height / @as(f32, @floatFromInt(segments));
    const step_radius = (radius_top - radius_bottom) / @as(f32, @floatFromInt(segments));
    const normal_y = (radius_bottom - radius_top) / height;

    var vertex_i: usize = 0;
    var ring: u32 = 0;
    while (ring <= segments) : (ring += 1) {
        const y = -half_height + @as(f32, @floatFromInt(ring)) * step_y;
        const radius = radius_bottom + @as(f32, @floatFromInt(ring)) * step_radius;
        var segment: u32 = 0;
        while (segment <= resolution) : (segment += 1) {
            const theta = @as(f32, @floatFromInt(segment)) * step_theta;
            const sin = @sin(theta);
            const cos = @cos(theta);
            const normal = vec3Normalize(.{ .x = cos, .y = normal_y, .z = sin }) orelse return false;
            writeVertex(&vertices[vertex_i], radius * cos, y, radius * sin, normal.x, normal.y, normal.z, @as(f32, @floatFromInt(segment)) / @as(f32, @floatFromInt(resolution)), @as(f32, @floatFromInt(ring)) / @as(f32, @floatFromInt(segments)));
            vertex_i += 1;
        }
    }

    var index_i: usize = 0;
    var i: u32 = 0;
    while (i < segments) : (i += 1) {
        const ring_start = i * (resolution + 1);
        const next_ring = (i + 1) * (resolution + 1);
        var j: u32 = 0;
        while (j < resolution) : (j += 1) {
            indices[index_i + 0] = ring_start + j;
            indices[index_i + 1] = next_ring + j;
            indices[index_i + 2] = ring_start + j + 1;
            indices[index_i + 3] = next_ring + j;
            indices[index_i + 4] = next_ring + j + 1;
            indices[index_i + 5] = ring_start + j + 1;
            index_i += 6;
        }
    }

    const top_offset = @as(u32, @intCast(vertex_i));
    i = 0;
    while (i < resolution) : (i += 1) {
        const theta = @as(f32, @floatFromInt(i)) * step_theta;
        const sin = @sin(theta);
        const cos = @cos(theta);
        writeVertex(&vertices[vertex_i], cos * radius_top, half_height, sin * radius_top, 0.0, 1.0, 0.0, 0.5 * (cos + 1.0), 1.0 - 0.5 * (sin + 1.0));
        vertex_i += 1;
    }
    i = 1;
    while (i < resolution - 1) : (i += 1) {
        indices[index_i + 0] = top_offset;
        indices[index_i + 1] = top_offset + i + 1;
        indices[index_i + 2] = top_offset + i;
        index_i += 3;
    }

    const bottom_offset = @as(u32, @intCast(vertex_i));
    i = 0;
    while (i < resolution) : (i += 1) {
        const theta = @as(f32, @floatFromInt(i)) * step_theta;
        const sin = @sin(theta);
        const cos = @cos(theta);
        writeVertex(&vertices[vertex_i], cos * radius_bottom, -half_height, sin * radius_bottom, 0.0, -1.0, 0.0, 0.5 * (cos + 1.0), 1.0 - 0.5 * (sin + 1.0));
        vertex_i += 1;
    }
    i = 1;
    while (i < resolution - 1) : (i += 1) {
        indices[index_i + 0] = bottom_offset;
        indices[index_i + 1] = bottom_offset + i;
        indices[index_i + 2] = bottom_offset + i + 1;
        index_i += 3;
    }
    return true;
}

pub export fn sa3d_geometry_conical_frustum_mesh_desc(out: *MeshDesc, vertices: [*]VertexP3N3Uv2, indices: [*]u32, radius_top: f32, radius_bottom: f32, height: f32, resolution: u32, segments: u32) callconv(.c) bool {
    const vertex_count = checkedConicalFrustumVertexCount(resolution, segments) orelse return false;
    const index_count = checkedConicalFrustumIndexCount(resolution, segments) orelse return false;
    if (vertex_count > std.math.maxInt(u32)) return false;
    if (!sa3d_geometry_conical_frustum_write(vertices, indices, radius_top, radius_bottom, height, resolution, segments)) return false;
    sa3d_geometry_mesh_desc_init(out, vertices, vertex_count, indices, index_count, @intFromEnum(IndexFormat.u32), @intFromEnum(PrimitiveTopology.triangle_list));
    return true;
}

pub export fn sa3d_geometry_cone_write(vertices: [*]VertexP3N3Uv2, indices: [*]u32, radius: f32, height: f32, resolution: u32, anchor: i32) callconv(.c) bool {
    if (!std.math.isFinite(radius) or !std.math.isFinite(height)) return false;
    if (resolution <= 2) return false;
    if (anchor < @intFromEnum(ConeAnchor.midpoint) or anchor > @intFromEnum(ConeAnchor.base)) return false;

    const half_height = height / 2.0;
    const step_theta = 2.0 * std.math.pi / @as(f32, @floatFromInt(resolution));

    var vertex_i: usize = 0;
    writeVertex(&vertices[vertex_i], 0.0, half_height, 0.0, 0.0, 0.0, 0.0, 0.5, 0.5);
    vertex_i += 1;

    const normal_slope = radius / height;
    const normalization_factor = 1.0 / @sqrt(1.0 + normal_slope * normal_slope);
    var segment: u32 = 0;
    while (segment < resolution) : (segment += 1) {
        const theta = @as(f32, @floatFromInt(segment)) * step_theta;
        const sin = @sin(theta);
        const cos = @cos(theta);
        writeVertex(&vertices[vertex_i], radius * cos, -half_height, radius * sin, cos * normalization_factor, normal_slope * normalization_factor, sin * normalization_factor, 0.5 + cos * 0.5, 0.5 + sin * 0.5);
        vertex_i += 1;
    }

    var index_i: usize = 0;
    var j: u32 = 1;
    while (j < resolution) : (j += 1) {
        indices[index_i + 0] = 0;
        indices[index_i + 1] = j + 1;
        indices[index_i + 2] = j;
        index_i += 3;
    }
    indices[index_i + 0] = 0;
    indices[index_i + 1] = 1;
    indices[index_i + 2] = resolution;
    index_i += 3;

    const index_offset = @as(u32, @intCast(vertex_i));
    var i: u32 = 0;
    while (i < resolution) : (i += 1) {
        const theta = @as(f32, @floatFromInt(i)) * step_theta;
        const sin = @sin(theta);
        const cos = @cos(theta);
        writeVertex(&vertices[vertex_i], cos * radius, -half_height, sin * radius, 0.0, -1.0, 0.0, 0.5 * (cos + 1.0), 1.0 - 0.5 * (sin + 1.0));
        vertex_i += 1;
    }

    i = 1;
    while (i < resolution - 1) : (i += 1) {
        indices[index_i + 0] = index_offset;
        indices[index_i + 1] = index_offset + i;
        indices[index_i + 2] = index_offset + i + 1;
        index_i += 3;
    }

    const anchor_offset: f32 = if (anchor == @intFromEnum(ConeAnchor.tip)) -half_height else if (anchor == @intFromEnum(ConeAnchor.base)) half_height else 0.0;
    if (anchor_offset != 0.0) {
        var v: usize = 0;
        while (v < vertex_i) : (v += 1) vertices[v].position.y += anchor_offset;
    }
    return true;
}

pub export fn sa3d_geometry_cone_mesh_desc(out: *MeshDesc, vertices: [*]VertexP3N3Uv2, indices: [*]u32, radius: f32, height: f32, resolution: u32, anchor: i32) callconv(.c) bool {
    const vertex_count = checkedConeVertexCount(resolution) orelse return false;
    const index_count = checkedConeIndexCount(resolution) orelse return false;
    if (vertex_count > std.math.maxInt(u32)) return false;
    if (!sa3d_geometry_cone_write(vertices, indices, radius, height, resolution, anchor)) return false;
    sa3d_geometry_mesh_desc_init(out, vertices, vertex_count, indices, index_count, @intFromEnum(IndexFormat.u32), @intFromEnum(PrimitiveTopology.triangle_list));
    return true;
}

pub export fn sa3d_geometry_capsule_write(vertices: [*]VertexP3N3Uv2, indices: [*]u32, radius: f32, length: f32, longitudes: u32, latitudes: u32, rings: u32, uv_profile: i32) callconv(.c) bool {
    if (!std.math.isFinite(radius) or !std.math.isFinite(length)) return false;
    if (uv_profile < @intFromEnum(CapsuleUvProfile.aspect) or uv_profile > @intFromEnum(CapsuleUvProfile.fixed)) return false;
    const offsets = capsuleOffsets(longitudes, latitudes, rings) orelse return false;

    const half_length = length / 2.0;
    const summit = half_length + radius;
    const to_theta = 2.0 * std.math.pi / @as(f32, @floatFromInt(longitudes));
    const to_phi = std.math.pi / @as(f32, @floatFromInt(latitudes));
    const to_tex_horizontal = 1.0 / @as(f32, @floatFromInt(longitudes));
    const to_tex_vertical = 1.0 / @as(f32, @floatFromInt(offsets.half_lats));
    const vt_aspect_ratio: f32 = if (uv_profile == @intFromEnum(CapsuleUvProfile.aspect))
        radius / (2.0 * half_length + radius + radius)
    else if (uv_profile == @intFromEnum(CapsuleUvProfile.uniform))
        @as(f32, @floatFromInt(offsets.half_lats)) / @as(f32, @floatFromInt(offsets.ringsp1 + latitudes))
    else
        1.0 / 3.0;
    const vt_aspect_north = 1.0 - vt_aspect_ratio;
    const vt_aspect_south = vt_aspect_ratio;

    var j: u32 = 0;
    while (j < longitudes) : (j += 1) {
        const jf = @as(f32, @floatFromInt(j));
        const s_texture_polar = 1.0 - ((jf + 0.5) * to_tex_horizontal);
        writeVertex(&vertices[j], 0.0, summit, 0.0, 0.0, 1.0, 0.0, s_texture_polar, 1.0);
        writeVertex(&vertices[offsets.south_cap + j], 0.0, -summit, 0.0, 0.0, -1.0, 0.0, s_texture_polar, 0.0);
    }

    j = 0;
    while (j < offsets.lonsp1) : (j += 1) {
        const s_texture = 1.0 - @as(f32, @floatFromInt(j)) * to_tex_horizontal;
        const j_mod = j % longitudes;
        const theta = @as(f32, @floatFromInt(j_mod)) * to_theta;
        const tc_x = @cos(theta);
        const tc_y = @sin(theta);
        const rtc_x = radius * tc_x;
        const rtc_y = radius * tc_y;

        writeVertex(&vertices[offsets.north_equator + j], rtc_x, half_length, -rtc_y, tc_x, 0.0, -tc_y, s_texture, vt_aspect_north);
        writeVertex(&vertices[offsets.south_equator + j], rtc_x, -half_length, -rtc_y, tc_x, 0.0, -tc_y, s_texture, vt_aspect_south);
    }

    var i: u32 = 0;
    while (i < offsets.half_latsn1) : (i += 1) {
        const ip1f = @as(f32, @floatFromInt(i)) + 1.0;
        const phi = ip1f * to_phi;
        const sin_phi_south = @sin(phi);
        const cos_phi_south = @cos(phi);
        const cos_phi_north = sin_phi_south;
        const sin_phi_north = -cos_phi_south;
        const rho_cos_phi_north = radius * cos_phi_north;
        const rho_sin_phi_north = radius * sin_phi_north;
        const z_offset_north = half_length - rho_sin_phi_north;
        const rho_cos_phi_south = radius * cos_phi_south;
        const rho_sin_phi_south = radius * sin_phi_south;
        const z_offset_south = -half_length - rho_sin_phi_south;
        const t_tex_fac = ip1f * to_tex_vertical;
        const cmpl_tex_fac = 1.0 - t_tex_fac;
        const t_tex_north = cmpl_tex_fac + vt_aspect_north * t_tex_fac;
        const t_tex_south = cmpl_tex_fac * vt_aspect_south;
        const i_lonsp1 = i * offsets.lonsp1;
        const vert_curr_lat_north = offsets.north_hemi + i_lonsp1;
        const vert_curr_lat_south = offsets.south_hemi + i_lonsp1;

        j = 0;
        while (j < offsets.lonsp1) : (j += 1) {
            const s_texture = 1.0 - @as(f32, @floatFromInt(j)) * to_tex_horizontal;
            const j_mod = j % longitudes;
            const theta = @as(f32, @floatFromInt(j_mod)) * to_theta;
            const tc_x = @cos(theta);
            const tc_y = @sin(theta);

            writeVertex(&vertices[vert_curr_lat_north + j], rho_cos_phi_north * tc_x, z_offset_north, -rho_cos_phi_north * tc_y, cos_phi_north * tc_x, -sin_phi_north, -cos_phi_north * tc_y, s_texture, t_tex_north);
            writeVertex(&vertices[vert_curr_lat_south + j], rho_cos_phi_south * tc_x, z_offset_south, -rho_cos_phi_south * tc_y, cos_phi_south * tc_x, -sin_phi_south, -cos_phi_south * tc_y, s_texture, t_tex_south);
        }
    }

    if (rings > 0) {
        const to_fac = 1.0 / @as(f32, @floatFromInt(offsets.ringsp1));
        var idx_cyl_lat = offsets.cylinder;
        var h: u32 = 1;
        while (h < offsets.ringsp1) : (h += 1) {
            const fac = @as(f32, @floatFromInt(h)) * to_fac;
            const cmpl_fac = 1.0 - fac;
            const t_texture = cmpl_fac * vt_aspect_north + fac * vt_aspect_south;
            const y = half_length - 2.0 * half_length * fac;

            j = 0;
            while (j < offsets.lonsp1) : (j += 1) {
                const s_texture = 1.0 - @as(f32, @floatFromInt(j)) * to_tex_horizontal;
                const j_mod = j % longitudes;
                const theta = @as(f32, @floatFromInt(j_mod)) * to_theta;
                const tc_x = @cos(theta);
                const tc_y = @sin(theta);
                writeVertex(&vertices[idx_cyl_lat], radius * tc_x, y, -radius * tc_y, tc_x, 0.0, -tc_y, s_texture, t_texture);
                idx_cyl_lat += 1;
            }
        }
    }

    i = 0;
    var k: u32 = 0;
    var m = offsets.tri_south_cap;
    while (i < longitudes) : (i += 1) {
        indices[k + 0] = i;
        indices[k + 1] = offsets.north_hemi + i;
        indices[k + 2] = offsets.north_hemi + i + 1;
        indices[m + 0] = offsets.south_cap + i;
        indices[m + 1] = offsets.south_polar + i + 1;
        indices[m + 2] = offsets.south_polar + i;
        k += 3;
        m += 3;
    }

    i = 0;
    k = offsets.tri_north_hemi;
    m = offsets.tri_south_hemi;
    while (i < offsets.half_latsn1) : (i += 1) {
        const i_lonsp1 = i * offsets.lonsp1;
        const vert_curr_lat_north = offsets.north_hemi + i_lonsp1;
        const vert_next_lat_north = vert_curr_lat_north + offsets.lonsp1;
        const vert_curr_lat_south = offsets.south_equator + i_lonsp1;
        const vert_next_lat_south = vert_curr_lat_south + offsets.lonsp1;
        j = 0;
        while (j < longitudes) : (j += 1) {
            const north00 = vert_curr_lat_north + j;
            const north01 = vert_next_lat_north + j;
            const north11 = vert_next_lat_north + j + 1;
            const north10 = vert_curr_lat_north + j + 1;
            indices[k + 0] = north00;
            indices[k + 1] = north11;
            indices[k + 2] = north10;
            indices[k + 3] = north00;
            indices[k + 4] = north01;
            indices[k + 5] = north11;

            const south00 = vert_curr_lat_south + j;
            const south01 = vert_next_lat_south + j;
            const south11 = vert_next_lat_south + j + 1;
            const south10 = vert_curr_lat_south + j + 1;
            indices[m + 0] = south00;
            indices[m + 1] = south11;
            indices[m + 2] = south10;
            indices[m + 3] = south00;
            indices[m + 4] = south01;
            indices[m + 5] = south11;

            k += 6;
            m += 6;
        }
    }

    i = 0;
    k = offsets.tri_cylinder;
    while (i < offsets.ringsp1) : (i += 1) {
        const vert_curr_lat = offsets.north_equator + i * offsets.lonsp1;
        const vert_next_lat = vert_curr_lat + offsets.lonsp1;
        j = 0;
        while (j < longitudes) : (j += 1) {
            const cy00 = vert_curr_lat + j;
            const cy01 = vert_next_lat + j;
            const cy11 = vert_next_lat + j + 1;
            const cy10 = vert_curr_lat + j + 1;
            indices[k + 0] = cy00;
            indices[k + 1] = cy11;
            indices[k + 2] = cy10;
            indices[k + 3] = cy00;
            indices[k + 4] = cy01;
            indices[k + 5] = cy11;
            k += 6;
        }
    }
    return true;
}

pub export fn sa3d_geometry_capsule_mesh_desc(out: *MeshDesc, vertices: [*]VertexP3N3Uv2, indices: [*]u32, radius: f32, length: f32, longitudes: u32, latitudes: u32, rings: u32, uv_profile: i32) callconv(.c) bool {
    const counts = capsuleCounts(longitudes, latitudes, rings) orelse return false;
    if (counts.vertices > std.math.maxInt(u32)) return false;
    if (!sa3d_geometry_capsule_write(vertices, indices, radius, length, longitudes, latitudes, rings, uv_profile)) return false;
    sa3d_geometry_mesh_desc_init(out, vertices, counts.vertices, indices, counts.indices, @intFromEnum(IndexFormat.u32), @intFromEnum(PrimitiveTopology.triangle_list));
    return true;
}

pub export fn sa3d_geometry_torus_write(vertices: [*]VertexP3N3Uv2, indices: [*]u32, inner_radius: f32, outer_radius: f32, major_resolution: u32, minor_resolution: u32, start_angle: f32, end_angle: f32) callconv(.c) bool {
    if (!std.math.isFinite(inner_radius) or !std.math.isFinite(outer_radius) or !std.math.isFinite(start_angle) or !std.math.isFinite(end_angle)) return false;
    if (major_resolution == 0 or minor_resolution == 0) return false;

    const minor_radius = (outer_radius - inner_radius) / 2.0;
    const major_radius = outer_radius - minor_radius;
    const segment_stride = (end_angle - start_angle) / @as(f32, @floatFromInt(major_resolution));
    const side_stride = 2.0 * std.math.pi / @as(f32, @floatFromInt(minor_resolution));

    var vertex_i: usize = 0;
    var segment: u32 = 0;
    while (segment <= major_resolution) : (segment += 1) {
        const theta = start_angle + segment_stride * @as(f32, @floatFromInt(segment));
        const sin_theta = @sin(theta);
        const cos_theta = @cos(theta);
        var side: u32 = 0;
        while (side <= minor_resolution) : (side += 1) {
            const phi = side_stride * @as(f32, @floatFromInt(side));
            const sin_phi = @sin(phi);
            const cos_phi = @cos(phi);
            const radius = major_radius + minor_radius * cos_phi;
            const px = cos_theta * radius;
            const py = minor_radius * sin_phi;
            const pz = sin_theta * radius;
            const cx = major_radius * cos_theta;
            const cz = major_radius * sin_theta;
            const normal = vec3Normalize(.{ .x = px - cx, .y = py, .z = pz - cz }) orelse return false;
            writeVertex(&vertices[vertex_i], px, py, pz, normal.x, normal.y, normal.z, @as(f32, @floatFromInt(segment)) / @as(f32, @floatFromInt(major_resolution)), @as(f32, @floatFromInt(side)) / @as(f32, @floatFromInt(minor_resolution)));
            vertex_i += 1;
        }
    }

    var index_i: usize = 0;
    const n_vertices_per_row = minor_resolution + 1;
    segment = 0;
    while (segment < major_resolution) : (segment += 1) {
        var side: u32 = 0;
        while (side < minor_resolution) : (side += 1) {
            const lt = side + segment * n_vertices_per_row;
            const rt = side + 1 + segment * n_vertices_per_row;
            const lb = side + (segment + 1) * n_vertices_per_row;
            const rb = side + 1 + (segment + 1) * n_vertices_per_row;
            indices[index_i + 0] = lt;
            indices[index_i + 1] = rt;
            indices[index_i + 2] = lb;
            indices[index_i + 3] = rt;
            indices[index_i + 4] = rb;
            indices[index_i + 5] = lb;
            index_i += 6;
        }
    }
    return true;
}

pub export fn sa3d_geometry_torus_mesh_desc(out: *MeshDesc, vertices: [*]VertexP3N3Uv2, indices: [*]u32, inner_radius: f32, outer_radius: f32, major_resolution: u32, minor_resolution: u32, start_angle: f32, end_angle: f32) callconv(.c) bool {
    const vertex_count = checkedTorusVertexCount(major_resolution, minor_resolution) orelse return false;
    const index_count = checkedTorusIndexCount(major_resolution, minor_resolution) orelse return false;
    if (vertex_count > std.math.maxInt(u32)) return false;
    if (!sa3d_geometry_torus_write(vertices, indices, inner_radius, outer_radius, major_resolution, minor_resolution, start_angle, end_angle)) return false;
    sa3d_geometry_mesh_desc_init(out, vertices, vertex_count, indices, index_count, @intFromEnum(IndexFormat.u32), @intFromEnum(PrimitiveTopology.triangle_list));
    return true;
}

fn triangleNormal(a: Vec3f, b: Vec3f, c: Vec3f) Vec3f {
    return vec3Normalize(vec3Cross(vec3Sub(b, a), vec3Sub(c, a))) orelse .{ .x = 0.0, .y = 0.0, .z = 0.0 };
}

fn triangleUvCoords(a: Vec3f, b: Vec3f, c: Vec3f) [3]Vec2f {
    const main_length = vec3Distance(a, b);
    const x = vec3Normalize(vec3Sub(b, a)) orelse return .{
        .{ .x = 0.0, .y = 0.0 },
        .{ .x = 1.0, .y = 0.0 },
        .{ .x = 0.0, .y = 1.0 },
    };
    const y = vec3Sub(c, a);
    const offset = vec3Dot(y, x) / main_length;

    if (offset < 0.0) {
        const total_length = 1.0 - offset;
        return .{
            .{ .x = @abs(offset) / total_length, .y = 0.0 },
            .{ .x = 1.0, .y = 0.0 },
            .{ .x = 0.0, .y = 1.0 },
        };
    } else if (offset > 1.0) {
        return .{
            .{ .x = 0.0, .y = 0.0 },
            .{ .x = 1.0 / offset, .y = 0.0 },
            .{ .x = 1.0, .y = 1.0 },
        };
    } else {
        return .{
            .{ .x = 0.0, .y = 0.0 },
            .{ .x = 1.0, .y = 0.0 },
            .{ .x = offset, .y = 1.0 },
        };
    }
}

fn writeTriangleFace(vertices: [*]VertexP3N3Uv2, base: usize, a: Vec3f, b: Vec3f, c: Vec3f) void {
    const normal = triangleNormal(a, b, c);
    const uvs = triangleUvCoords(a, b, c);
    writeVertex(&vertices[base + 0], a.x, a.y, a.z, normal.x, normal.y, normal.z, uvs[0].x, uvs[0].y);
    writeVertex(&vertices[base + 1], b.x, b.y, b.z, normal.x, normal.y, normal.z, uvs[1].x, uvs[1].y);
    writeVertex(&vertices[base + 2], c.x, c.y, c.z, normal.x, normal.y, normal.z, uvs[2].x, uvs[2].y);
}

pub export fn sa3d_geometry_triangle_write(vertices: [*]VertexP3N3Uv2, indices: [*]u32, ax: f32, ay: f32, az: f32, bx: f32, by: f32, bz: f32, cx: f32, cy: f32, cz: f32) callconv(.c) bool {
    writeTriangleFace(vertices, 0, .{ .x = ax, .y = ay, .z = az }, .{ .x = bx, .y = by, .z = bz }, .{ .x = cx, .y = cy, .z = cz });
    indices[0] = 0;
    indices[1] = 1;
    indices[2] = 2;
    return true;
}

pub export fn sa3d_geometry_triangle_mesh_desc(out: *MeshDesc, vertices: [*]VertexP3N3Uv2, indices: [*]u32, ax: f32, ay: f32, az: f32, bx: f32, by: f32, bz: f32, cx: f32, cy: f32, cz: f32) callconv(.c) bool {
    if (!sa3d_geometry_triangle_write(vertices, indices, ax, ay, az, bx, by, bz, cx, cy, cz)) return false;
    sa3d_geometry_mesh_desc_init(out, vertices, sa3d_geometry_triangle_vertex_count(), indices, sa3d_geometry_triangle_index_count(), @intFromEnum(IndexFormat.u32), @intFromEnum(PrimitiveTopology.triangle_list));
    return true;
}

fn tetrahedronSignedVolume(a: Vec3f, b: Vec3f, c: Vec3f, d: Vec3f) f32 {
    return vec3Dot(vec3Sub(b, a), vec3Cross(vec3Sub(c, a), vec3Sub(d, a))) / 6.0;
}

fn writeTetrahedronFace(vertices: [*]VertexP3N3Uv2, base: usize, negative_orientation: bool, a: Vec3f, b: Vec3f, c: Vec3f) void {
    if (negative_orientation) {
        writeTriangleFace(vertices, base, c, b, a);
    } else {
        writeTriangleFace(vertices, base, a, b, c);
    }
}

pub export fn sa3d_geometry_tetrahedron_write(vertices: [*]VertexP3N3Uv2, indices: [*]u32, ax: f32, ay: f32, az: f32, bx: f32, by: f32, bz: f32, cx: f32, cy: f32, cz: f32, dx: f32, dy: f32, dz: f32) callconv(.c) bool {
    const a = Vec3f{ .x = ax, .y = ay, .z = az };
    const b = Vec3f{ .x = bx, .y = by, .z = bz };
    const c = Vec3f{ .x = cx, .y = cy, .z = cz };
    const d = Vec3f{ .x = dx, .y = dy, .z = dz };
    const negative_orientation = std.math.signbit(tetrahedronSignedVolume(a, b, c, d));

    writeTetrahedronFace(vertices, 0, negative_orientation, b, c, d);
    writeTetrahedronFace(vertices, 3, negative_orientation, d, c, a);
    writeTetrahedronFace(vertices, 6, negative_orientation, a, b, d);
    writeTetrahedronFace(vertices, 9, negative_orientation, c, b, a);

    var i: u32 = 0;
    while (i < 12) : (i += 1) indices[i] = i;
    return true;
}

pub export fn sa3d_geometry_tetrahedron_mesh_desc(out: *MeshDesc, vertices: [*]VertexP3N3Uv2, indices: [*]u32, ax: f32, ay: f32, az: f32, bx: f32, by: f32, bz: f32, cx: f32, cy: f32, cz: f32, dx: f32, dy: f32, dz: f32) callconv(.c) bool {
    if (!sa3d_geometry_tetrahedron_write(vertices, indices, ax, ay, az, bx, by, bz, cx, cy, cz, dx, dy, dz)) return false;
    sa3d_geometry_mesh_desc_init(out, vertices, sa3d_geometry_tetrahedron_vertex_count(), indices, sa3d_geometry_tetrahedron_index_count(), @intFromEnum(IndexFormat.u32), @intFromEnum(PrimitiveTopology.triangle_list));
    return true;
}

pub export fn sa3d_geometry_segment_write(vertices: [*]VertexP3N3Uv2, indices: [*]u32, ax: f32, ay: f32, az: f32, bx: f32, by: f32, bz: f32) callconv(.c) bool {
    writeVertex(&vertices[0], ax, ay, az, 0.0, 0.0, 0.0, 0.0, 0.0);
    writeVertex(&vertices[1], bx, by, bz, 0.0, 0.0, 0.0, 0.0, 0.0);
    indices[0] = 0;
    indices[1] = 1;
    return true;
}

pub export fn sa3d_geometry_segment_mesh_desc(out: *MeshDesc, vertices: [*]VertexP3N3Uv2, indices: [*]u32, ax: f32, ay: f32, az: f32, bx: f32, by: f32, bz: f32) callconv(.c) bool {
    if (!sa3d_geometry_segment_write(vertices, indices, ax, ay, az, bx, by, bz)) return false;
    sa3d_geometry_mesh_desc_init(out, vertices, sa3d_geometry_segment_vertex_count(), indices, sa3d_geometry_segment_index_count(), @intFromEnum(IndexFormat.u32), @intFromEnum(PrimitiveTopology.line_list));
    return true;
}

pub export fn sa3d_geometry_polyline_write(vertices: [*]VertexP3N3Uv2, indices: [*]u32, positions: [*]const Vec3f, vertex_len: u64) callconv(.c) bool {
    const index_count = checkedPolylineIndexCount(vertex_len) orelse return false;
    if (vertex_len > std.math.maxInt(u32)) return false;

    var v: u64 = 0;
    while (v < vertex_len) : (v += 1) {
        const p = positions[@as(usize, @intCast(v))];
        writeVertex(&vertices[@as(usize, @intCast(v))], p.x, p.y, p.z, 0.0, 0.0, 0.0, 0.0, 0.0);
    }

    var i: u64 = 0;
    while (i < vertex_len - 1) : (i += 1) {
        const out_i = @as(usize, @intCast(i * 2));
        indices[out_i + 0] = @as(u32, @intCast(i));
        indices[out_i + 1] = @as(u32, @intCast(i + 1));
    }
    _ = index_count;
    return true;
}

pub export fn sa3d_geometry_polyline_mesh_desc(out: *MeshDesc, vertices: [*]VertexP3N3Uv2, indices: [*]u32, positions: [*]const Vec3f, vertex_len: u64) callconv(.c) bool {
    const index_count = checkedPolylineIndexCount(vertex_len) orelse return false;
    if (vertex_len > std.math.maxInt(u32)) return false;
    if (!sa3d_geometry_polyline_write(vertices, indices, positions, vertex_len)) return false;
    sa3d_geometry_mesh_desc_init(out, vertices, vertex_len, indices, index_count, @intFromEnum(IndexFormat.u32), @intFromEnum(PrimitiveTopology.line_list));
    return true;
}

fn expectVertex(v: VertexP3N3Uv2, px: f32, py: f32, pz: f32, nx: f32, ny: f32, nz: f32, u: f32, vv: f32) bool {
    return approxEq(v.position.x, px) and approxEq(v.position.y, py) and approxEq(v.position.z, pz) and
        approxEq(v.normal.x, nx) and approxEq(v.normal.y, ny) and approxEq(v.normal.z, nz) and
        approxEq(v.uv.x, u) and approxEq(v.uv.y, vv);
}

pub export fn sa3d_geometry_cuboid_selftest() callconv(.c) i32 {
    if (sa3d_geometry_cuboid_vertex_count() != CUBOID_VERTEX_COUNT) return 1;
    if (sa3d_geometry_cuboid_index_count() != CUBOID_INDEX_COUNT) return 2;
    var vertices: [CUBOID_VERTEX_COUNT]VertexP3N3Uv2 = undefined;
    var indices: [CUBOID_INDEX_COUNT]u32 = undefined;
    var mesh: MeshDesc = undefined;
    if (!sa3d_geometry_cuboid_mesh_desc(&mesh, &vertices, &indices, 2.0, 3.0, 4.0)) return 3;
    if (!sa3d_geometry_mesh_validate(&mesh)) return 4;
    if (!sa3d_geometry_mesh_indices_in_range(&mesh)) return 5;
    if (sa3d_geometry_mesh_triangle_count(&mesh) != 12) return 6;
    if (!approxEq(mesh.bounds.min.x, -2.0) or !approxEq(mesh.bounds.min.y, -3.0) or !approxEq(mesh.bounds.min.z, -4.0)) return 7;
    if (!approxEq(mesh.bounds.max.x, 2.0) or !approxEq(mesh.bounds.max.y, 3.0) or !approxEq(mesh.bounds.max.z, 4.0)) return 8;
    if (!expectVertex(vertices[0], -2.0, -3.0, 4.0, 0.0, 0.0, 1.0, 0.0, 0.0)) return 9;
    if (!expectVertex(vertices[4], -2.0, 3.0, -4.0, 0.0, 0.0, -1.0, 1.0, 0.0)) return 10;
    if (!expectVertex(vertices[16], 2.0, 3.0, -4.0, 0.0, 1.0, 0.0, 1.0, 0.0)) return 11;
    if (!expectVertex(vertices[23], 2.0, -3.0, -4.0, 0.0, -1.0, 0.0, 0.0, 1.0)) return 12;
    const expected = [_]u32{
        0,  1,  2,  2,  3,  0,
        4,  5,  6,  6,  7,  4,
        8,  9,  10, 10, 11, 8,
        12, 13, 14, 14, 15, 12,
        16, 17, 18, 18, 19, 16,
        20, 21, 22, 22, 23, 20,
    };
    var i: usize = 0;
    while (i < expected.len) : (i += 1) if (indices[i] != expected[i]) return 20 + @as(i32, @intCast(i));
    return 0;
}

pub export fn sa3d_geometry_plane_selftest() callconv(.c) i32 {
    if (checkedPlaneVertexCount(std.math.maxInt(u32), std.math.maxInt(u32)) != null) return 1;
    if (sa3d_geometry_plane_vertex_count(1, 2) != 12) return 2;
    if (sa3d_geometry_plane_index_count(1, 2) != 36) return 3;

    var vertices: [12]VertexP3N3Uv2 = undefined;
    var indices: [36]u32 = undefined;
    var mesh: MeshDesc = undefined;
    if (!sa3d_geometry_plane_mesh_desc(&mesh, &vertices, &indices, 0.0, 1.0, 0.0, 2.0, 3.0, 1, 2)) return 4;
    if (!sa3d_geometry_mesh_validate(&mesh)) return 5;
    if (!sa3d_geometry_mesh_indices_in_range(&mesh)) return 6;
    if (sa3d_geometry_mesh_triangle_count(&mesh) != 12) return 7;
    if (!approxEq(mesh.bounds.min.x, -2.0) or !approxEq(mesh.bounds.min.y, 0.0) or !approxEq(mesh.bounds.min.z, -3.0)) return 8;
    if (!approxEq(mesh.bounds.max.x, 2.0) or !approxEq(mesh.bounds.max.y, 0.0) or !approxEq(mesh.bounds.max.z, 3.0)) return 9;
    if (!expectVertex(vertices[0], -2.0, 0.0, -3.0, 0.0, 1.0, 0.0, 0.0, 0.0)) return 10;
    if (!expectVertex(vertices[1], 0.0, 0.0, -3.0, 0.0, 1.0, 0.0, 0.5, 0.0)) return 11;
    if (!expectVertex(vertices[11], 2.0, 0.0, 3.0, 0.0, 1.0, 0.0, 1.0, 1.0)) return 12;
    const expected = [_]u32{
        4,  1, 3,  0, 3,  1,
        5,  2, 4,  1, 4,  2,
        7,  4, 6,  3, 6,  4,
        8,  5, 7,  4, 7,  5,
        10, 7, 9,  6, 9,  7,
        11, 8, 10, 7, 10, 8,
    };
    var i: usize = 0;
    while (i < expected.len) : (i += 1) if (indices[i] != expected[i]) return 20 + @as(i32, @intCast(i));

    var rotated_vertices: [4]VertexP3N3Uv2 = undefined;
    var rotated_indices: [6]u32 = undefined;
    if (!sa3d_geometry_plane_write(&rotated_vertices, &rotated_indices, 0.0, 0.0, 1.0, 1.0, 1.0, 0, 0)) return 60;
    if (!expectVertex(rotated_vertices[0], -1.0, 1.0, 0.0, 0.0, 0.0, 1.0, 0.0, 0.0)) return 61;
    if (!expectVertex(rotated_vertices[3], 1.0, -1.0, 0.0, 0.0, 0.0, 1.0, 1.0, 1.0)) return 62;
    if (sa3d_geometry_plane_write(&rotated_vertices, &rotated_indices, 0.0, 0.0, 0.0, 1.0, 1.0, 0, 0)) return 63;
    return 0;
}

pub export fn sa3d_geometry_uv_sphere_selftest() callconv(.c) i32 {
    if (checkedUvSphereVertexCount(std.math.maxInt(u32), std.math.maxInt(u32)) != null) return 1;
    if (sa3d_geometry_uv_sphere_vertex_count(4, 3) != 20) return 2;
    if (sa3d_geometry_uv_sphere_index_count(4, 3) != 48) return 3;

    var vertices: [20]VertexP3N3Uv2 = undefined;
    var indices: [48]u32 = undefined;
    var mesh: MeshDesc = undefined;
    if (!sa3d_geometry_uv_sphere_mesh_desc(&mesh, &vertices, &indices, 2.0, 4, 3)) return 4;
    if (!sa3d_geometry_mesh_validate(&mesh)) return 5;
    if (!sa3d_geometry_mesh_indices_in_range(&mesh)) return 6;
    if (sa3d_geometry_mesh_triangle_count(&mesh) != 16) return 7;
    if (!approxEq(mesh.bounds.min.x, -1.7320508) or !approxEq(mesh.bounds.max.x, 1.7320508)) return 8;
    if (!approxEq(mesh.bounds.min.y, -1.7320508) or !approxEq(mesh.bounds.max.y, 1.7320508)) return 9;
    if (!approxEq(mesh.bounds.min.z, -2.0) or !approxEq(mesh.bounds.max.z, 2.0)) return 10;
    if (!expectVertex(vertices[0], 0.0, 0.0, 2.0, 0.0, 0.0, 1.0, 0.0, 0.0)) return 11;
    if (!expectVertex(vertices[5], 1.7320508, 0.0, 1.0, 0.8660254, 0.0, 0.5, 0.0, 0.33333334)) return 12;
    if (!expectVertex(vertices[6], 0.0, 1.7320508, 1.0, 0.0, 0.8660254, 0.5, 0.25, 0.33333334)) return 13;
    if (!expectVertex(vertices[19], 0.0, 0.0, -2.0, 0.0, 0.0, -1.0, 1.0, 1.0)) return 14;
    const expected = [_]u32{
        1,  5,  6,
        2,  6,  7,
        3,  7,  8,
        4,  8,  9,
        5,  10, 6,
        6,  10, 11,
        6,  11, 7,
        7,  11, 12,
        7,  12, 8,
        8,  12, 13,
        8,  13, 9,
        9,  13, 14,
        10, 15, 11,
        11, 16, 12,
        12, 17, 13,
        13, 18, 14,
    };
    var i: usize = 0;
    while (i < expected.len) : (i += 1) if (indices[i] != expected[i]) return 30 + @as(i32, @intCast(i));
    return 0;
}

pub export fn sa3d_geometry_ico_sphere_selftest() callconv(.c) i32 {
    if (sa3d_geometry_ico_sphere_vertex_count(0) != 12) return 1;
    if (sa3d_geometry_ico_sphere_index_count(0) != 60) return 2;
    if (sa3d_geometry_ico_sphere_vertex_count(1) != 42) return 3;
    if (sa3d_geometry_ico_sphere_index_count(1) != 240) return 4;
    if (sa3d_geometry_ico_sphere_vertex_count(2) != 92) return 5;
    if (sa3d_geometry_ico_sphere_index_count(2) != 540) return 6;
    if (sa3d_geometry_ico_sphere_vertex_count(79) != 64002) return 7;
    if (sa3d_geometry_ico_sphere_index_count(79) != 384000) return 8;
    if (sa3d_geometry_ico_sphere_vertex_count(80) != 0) return 9;
    if (sa3d_geometry_ico_sphere_index_count(80) != 0) return 10;

    var base_vertices: [12]VertexP3N3Uv2 = undefined;
    var base_indices: [60]u32 = undefined;
    if (sa3d_geometry_native_ico_sphere_write(&base_vertices, &base_indices, 2.0, 0) == 0) return 11;
    if (!expectVertex(base_vertices[0], 0.0, 2.0, 0.0, 0.0, 1.0, 0.0, 0.5, 0.0)) return 12;
    if (!expectVertex(base_vertices[11], 0.0, -2.0, 0.0, 0.0, -1.0, 0.0, 0.5, 1.0)) return 13;
    const base_prefix = [_]u32{
        0, 2, 1,
        0, 3, 2,
        0, 4, 3,
        0, 5, 4,
        0, 1, 5,
        5, 1, 6,
        1, 2, 7,
        2, 3, 8,
    };
    var i: usize = 0;
    while (i < base_prefix.len) : (i += 1) if (base_indices[i] != base_prefix[i]) return 20 + @as(i32, @intCast(i));

    var one_vertices: [42]VertexP3N3Uv2 = undefined;
    var one_indices: [240]u32 = undefined;
    var one_mesh: MeshDesc = undefined;
    if (sa3d_geometry_native_ico_sphere_mesh_desc(&one_mesh, &one_vertices, &one_indices, 2.0, 1) == 0) return 60;
    if (!sa3d_geometry_mesh_validate(&one_mesh)) return 61;
    if (!sa3d_geometry_mesh_indices_in_range(&one_mesh)) return 62;
    if (sa3d_geometry_mesh_triangle_count(&one_mesh) != 80) return 63;
    if (!approxEq(one_mesh.bounds.min.x, -1.9021131) or !approxEq(one_mesh.bounds.max.x, 1.9021131)) return 64;
    if (!approxEq(one_mesh.bounds.min.y, -2.0) or !approxEq(one_mesh.bounds.max.y, 2.0)) return 65;
    if (!approxEq(one_mesh.bounds.min.z, -2.0) or !approxEq(one_mesh.bounds.max.z, 2.0)) return 66;
    const one_prefix = [_]u32{
        0,  12, 16,
        2,  17, 12,
        1,  16, 17,
        12, 17, 16,
    };
    i = 0;
    while (i < one_prefix.len) : (i += 1) if (one_indices[i] != one_prefix[i]) return 70 + @as(i32, @intCast(i));
    if (!approxEq(vec3Length(one_vertices[12].normal), 1.0)) return 90;
    if (!approxEq(vec3Length(one_vertices[12].position), 2.0)) return 91;

    var two_vertices: [92]VertexP3N3Uv2 = undefined;
    var two_indices: [540]u32 = undefined;
    if (sa3d_geometry_native_ico_sphere_write(&two_vertices, &two_indices, 2.0, 2) == 0) return 100;
    const two_prefix = [_]u32{
        0,  12, 21,
        2,  22, 13,
        1,  20, 23,
        13, 72, 12,
        23, 72, 22,
        21, 72, 20,
        12, 72, 21,
        22, 72, 13,
        20, 72, 23,
    };
    i = 0;
    while (i < two_prefix.len) : (i += 1) if (two_indices[i] != two_prefix[i]) return 110 + @as(i32, @intCast(i));
    if (!approxEq(vec3Length(two_vertices[72].normal), 1.0)) return 140;
    if (!approxEq(vec3Length(two_vertices[72].position), 2.0)) return 141;
    if (sa3d_geometry_native_ico_sphere_write(&two_vertices, &two_indices, 2.0, 80) != 0) return 142;
    if (sa3d_geometry_native_ico_sphere_write(&two_vertices, &two_indices, std.math.nan(f32), 1) != 0) return 143;
    return 0;
}

pub export fn sa3d_geometry_cylinder_selftest() callconv(.c) i32 {
    if (checkedCylinderVertexCount(std.math.maxInt(u32), std.math.maxInt(u32), true) != null) return 1;
    if (sa3d_geometry_cylinder_vertex_count(4, 2, true) != 23) return 2;
    if (sa3d_geometry_cylinder_index_count(4, 2, true) != 60) return 3;
    if (sa3d_geometry_cylinder_vertex_count(4, 2, false) != 15) return 4;
    if (sa3d_geometry_cylinder_index_count(4, 2, false) != 48) return 5;

    var vertices: [23]VertexP3N3Uv2 = undefined;
    var indices: [60]u32 = undefined;
    var mesh: MeshDesc = undefined;
    if (!sa3d_geometry_cylinder_mesh_desc(&mesh, &vertices, &indices, 2.0, 6.0, 4, 2, true, @intFromEnum(CylinderAnchor.midpoint))) return 6;
    if (!sa3d_geometry_mesh_validate(&mesh)) return 7;
    if (!sa3d_geometry_mesh_indices_in_range(&mesh)) return 8;
    if (sa3d_geometry_mesh_triangle_count(&mesh) != 20) return 9;
    if (!approxEq(mesh.bounds.min.x, -2.0) or !approxEq(mesh.bounds.max.x, 2.0)) return 10;
    if (!approxEq(mesh.bounds.min.y, -3.0) or !approxEq(mesh.bounds.max.y, 3.0)) return 11;
    if (!approxEq(mesh.bounds.min.z, -2.0) or !approxEq(mesh.bounds.max.z, 2.0)) return 12;
    if (!expectVertex(vertices[0], 2.0, -3.0, 0.0, 1.0, 0.0, 0.0, 0.0, 0.0)) return 13;
    if (!expectVertex(vertices[1], 0.0, -3.0, 2.0, 0.0, 0.0, 1.0, 0.25, 0.0)) return 14;
    if (!expectVertex(vertices[5], 2.0, 0.0, 0.0, 1.0, 0.0, 0.0, 0.0, 0.5)) return 15;
    if (!expectVertex(vertices[10], 2.0, 3.0, 0.0, 1.0, 0.0, 0.0, 0.0, 1.0)) return 16;
    if (!expectVertex(vertices[15], 2.0, 3.0, 0.0, 0.0, 1.0, 0.0, 1.0, 0.5)) return 17;
    if (!expectVertex(vertices[19], 2.0, -3.0, 0.0, 0.0, -1.0, 0.0, 1.0, 0.5)) return 18;
    const expected_prefix = [_]u32{
        0,  5,  1,  5,  6,  1,
        1,  6,  2,  6,  7,  2,
        2,  7,  3,  7,  8,  3,
        3,  8,  4,  8,  9,  4,
        5,  10, 6,  10, 11, 6,
        6,  11, 7,  11, 12, 7,
        7,  12, 8,  12, 13, 8,
        8,  13, 9,  13, 14, 9,
        15, 17, 16, 15, 18, 17,
        19, 20, 21, 19, 21, 22,
    };
    var i: usize = 0;
    while (i < expected_prefix.len) : (i += 1) if (indices[i] != expected_prefix[i]) return 30 + @as(i32, @intCast(i));

    var tube_vertices: [15]VertexP3N3Uv2 = undefined;
    var tube_indices: [48]u32 = undefined;
    var tube_mesh: MeshDesc = undefined;
    if (!sa3d_geometry_cylinder_mesh_desc(&tube_mesh, &tube_vertices, &tube_indices, 2.0, 6.0, 4, 2, false, @intFromEnum(CylinderAnchor.top))) return 90;
    if (!sa3d_geometry_mesh_validate(&tube_mesh)) return 91;
    if (sa3d_geometry_mesh_triangle_count(&tube_mesh) != 16) return 92;
    if (!approxEq(tube_mesh.bounds.min.y, -6.0) or !approxEq(tube_mesh.bounds.max.y, 0.0)) return 93;
    if (!expectVertex(tube_vertices[0], 2.0, -6.0, 0.0, 1.0, 0.0, 0.0, 0.0, 0.0)) return 94;
    if (!expectVertex(tube_vertices[10], 2.0, 0.0, 0.0, 1.0, 0.0, 0.0, 0.0, 1.0)) return 95;

    if (sa3d_geometry_cylinder_write(&tube_vertices, &tube_indices, 1.0, 1.0, 2, 1, true, @intFromEnum(CylinderAnchor.midpoint))) return 96;
    if (sa3d_geometry_cylinder_write(&tube_vertices, &tube_indices, 1.0, 1.0, 3, 0, true, @intFromEnum(CylinderAnchor.midpoint))) return 97;
    if (sa3d_geometry_cylinder_write(&tube_vertices, &tube_indices, 1.0, 1.0, 3, 1, true, 99)) return 98;
    return 0;
}

pub export fn sa3d_geometry_conical_frustum_selftest() callconv(.c) i32 {
    if (checkedConicalFrustumVertexCount(std.math.maxInt(u32), std.math.maxInt(u32)) != null) return 1;
    if (sa3d_geometry_conical_frustum_vertex_count(4, 2) != 23) return 2;
    if (sa3d_geometry_conical_frustum_index_count(4, 2) != 60) return 3;

    var vertices: [23]VertexP3N3Uv2 = undefined;
    var indices: [60]u32 = undefined;
    var mesh: MeshDesc = undefined;
    if (!sa3d_geometry_conical_frustum_mesh_desc(&mesh, &vertices, &indices, 1.0, 2.0, 6.0, 4, 2)) return 4;
    if (!sa3d_geometry_mesh_validate(&mesh)) return 5;
    if (!sa3d_geometry_mesh_indices_in_range(&mesh)) return 6;
    if (sa3d_geometry_mesh_triangle_count(&mesh) != 20) return 7;
    if (!approxEq(mesh.bounds.min.x, -2.0) or !approxEq(mesh.bounds.max.x, 2.0)) return 8;
    if (!approxEq(mesh.bounds.min.y, -3.0) or !approxEq(mesh.bounds.max.y, 3.0)) return 9;
    if (!approxEq(mesh.bounds.min.z, -2.0) or !approxEq(mesh.bounds.max.z, 2.0)) return 10;
    if (!expectVertex(vertices[0], 2.0, -3.0, 0.0, 0.9863939, 0.16439898, 0.0, 0.0, 0.0)) return 11;
    if (!expectVertex(vertices[1], 0.0, -3.0, 2.0, 0.0, 0.16439898, 0.9863939, 0.25, 0.0)) return 12;
    if (!expectVertex(vertices[5], 1.5, 0.0, 0.0, 0.9863939, 0.16439898, 0.0, 0.0, 0.5)) return 13;
    if (!expectVertex(vertices[10], 1.0, 3.0, 0.0, 0.9863939, 0.16439898, 0.0, 0.0, 1.0)) return 14;
    if (!expectVertex(vertices[15], 1.0, 3.0, 0.0, 0.0, 1.0, 0.0, 1.0, 0.5)) return 15;
    if (!expectVertex(vertices[19], 2.0, -3.0, 0.0, 0.0, -1.0, 0.0, 1.0, 0.5)) return 16;
    const expected_prefix = [_]u32{
        0,  5,  1,  5,  6,  1,
        1,  6,  2,  6,  7,  2,
        2,  7,  3,  7,  8,  3,
        3,  8,  4,  8,  9,  4,
        5,  10, 6,  10, 11, 6,
        6,  11, 7,  11, 12, 7,
        7,  12, 8,  12, 13, 8,
        8,  13, 9,  13, 14, 9,
        15, 17, 16, 15, 18, 17,
        19, 20, 21, 19, 21, 22,
    };
    var i: usize = 0;
    while (i < expected_prefix.len) : (i += 1) if (indices[i] != expected_prefix[i]) return 30 + @as(i32, @intCast(i));

    var cylinder_vertices: [18]VertexP3N3Uv2 = undefined;
    var cylinder_indices: [36]u32 = undefined;
    var cylinder_mesh: MeshDesc = undefined;
    if (!sa3d_geometry_conical_frustum_mesh_desc(&cylinder_mesh, &cylinder_vertices, &cylinder_indices, 2.0, 2.0, 4.0, 4, 1)) return 90;
    if (!sa3d_geometry_mesh_validate(&cylinder_mesh)) return 91;
    if (sa3d_geometry_mesh_triangle_count(&cylinder_mesh) != 12) return 92;
    if (!expectVertex(cylinder_vertices[0], 2.0, -2.0, 0.0, 1.0, 0.0, 0.0, 0.0, 0.0)) return 93;
    if (!expectVertex(cylinder_vertices[5], 2.0, 2.0, 0.0, 1.0, 0.0, 0.0, 0.0, 1.0)) return 94;
    if (sa3d_geometry_conical_frustum_write(&vertices, &indices, 1.0, 2.0, 6.0, 2, 2)) return 95;
    if (sa3d_geometry_conical_frustum_write(&vertices, &indices, 1.0, 2.0, 6.0, 4, 0)) return 96;
    return 0;
}

pub export fn sa3d_geometry_cone_selftest() callconv(.c) i32 {
    if (checkedConeVertexCount(std.math.maxInt(u32)) == null) return 1;
    if (sa3d_geometry_cone_vertex_count(4) != 9) return 2;
    if (sa3d_geometry_cone_index_count(4) != 18) return 3;

    var vertices: [9]VertexP3N3Uv2 = undefined;
    var indices: [18]u32 = undefined;
    var mesh: MeshDesc = undefined;
    if (!sa3d_geometry_cone_mesh_desc(&mesh, &vertices, &indices, 0.5, 1.0, 4, @intFromEnum(ConeAnchor.midpoint))) return 4;
    if (!sa3d_geometry_mesh_validate(&mesh)) return 5;
    if (!sa3d_geometry_mesh_indices_in_range(&mesh)) return 6;
    if (sa3d_geometry_mesh_triangle_count(&mesh) != 6) return 7;
    if (!approxEq(mesh.bounds.min.x, -0.5) or !approxEq(mesh.bounds.max.x, 0.5)) return 8;
    if (!approxEq(mesh.bounds.min.y, -0.5) or !approxEq(mesh.bounds.max.y, 0.5)) return 9;
    if (!approxEq(mesh.bounds.min.z, -0.5) or !approxEq(mesh.bounds.max.z, 0.5)) return 10;
    if (!expectVertex(vertices[0], 0.0, 0.5, 0.0, 0.0, 0.0, 0.0, 0.5, 0.5)) return 11;
    if (!expectVertex(vertices[1], 0.5, -0.5, 0.0, 0.8944272, 0.4472136, 0.0, 1.0, 0.5)) return 12;
    if (!expectVertex(vertices[2], 0.0, -0.5, 0.5, 0.0, 0.4472136, 0.8944272, 0.5, 1.0)) return 13;
    if (!expectVertex(vertices[4], 0.0, -0.5, -0.5, 0.0, 0.4472136, -0.8944272, 0.5, 0.0)) return 14;
    if (!expectVertex(vertices[5], 0.5, -0.5, 0.0, 0.0, -1.0, 0.0, 1.0, 0.5)) return 15;
    if (!expectVertex(vertices[8], 0.0, -0.5, -0.5, 0.0, -1.0, 0.0, 0.5, 1.0)) return 16;
    const expected = [_]u32{
        0, 2, 1,
        0, 3, 2,
        0, 4, 3,
        0, 1, 4,
        5, 6, 7,
        5, 7, 8,
    };
    var i: usize = 0;
    while (i < expected.len) : (i += 1) if (indices[i] != expected[i]) return 30 + @as(i32, @intCast(i));

    var tip_vertices: [9]VertexP3N3Uv2 = undefined;
    var tip_indices: [18]u32 = undefined;
    var tip_mesh: MeshDesc = undefined;
    if (!sa3d_geometry_cone_mesh_desc(&tip_mesh, &tip_vertices, &tip_indices, 0.5, 1.0, 4, @intFromEnum(ConeAnchor.tip))) return 60;
    if (!approxEq(tip_mesh.bounds.min.y, -1.0) or !approxEq(tip_mesh.bounds.max.y, 0.0)) return 61;
    if (!expectVertex(tip_vertices[0], 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.5, 0.5)) return 62;
    if (!expectVertex(tip_vertices[1], 0.5, -1.0, 0.0, 0.8944272, 0.4472136, 0.0, 1.0, 0.5)) return 63;

    var base_vertices: [9]VertexP3N3Uv2 = undefined;
    var base_indices: [18]u32 = undefined;
    var base_mesh: MeshDesc = undefined;
    if (!sa3d_geometry_cone_mesh_desc(&base_mesh, &base_vertices, &base_indices, 0.5, 1.0, 4, @intFromEnum(ConeAnchor.base))) return 70;
    if (!approxEq(base_mesh.bounds.min.y, 0.0) or !approxEq(base_mesh.bounds.max.y, 1.0)) return 71;
    if (!expectVertex(base_vertices[0], 0.0, 1.0, 0.0, 0.0, 0.0, 0.0, 0.5, 0.5)) return 72;
    if (!expectVertex(base_vertices[1], 0.5, 0.0, 0.0, 0.8944272, 0.4472136, 0.0, 1.0, 0.5)) return 73;

    if (sa3d_geometry_cone_write(&vertices, &indices, 0.5, 1.0, 2, @intFromEnum(ConeAnchor.midpoint))) return 80;
    if (sa3d_geometry_cone_write(&vertices, &indices, 0.5, 1.0, 4, 99)) return 81;
    return 0;
}

pub export fn sa3d_geometry_capsule_selftest() callconv(.c) i32 {
    const counts_no_rings = capsuleCounts(4, 4, 0) orelse return 1;
    if (counts_no_rings.vertices != 28 or counts_no_rings.indices != 96) return 2;
    if (sa3d_geometry_capsule_vertex_count(4, 4, 1) != 33) return 3;
    if (sa3d_geometry_capsule_index_count(4, 4, 1) != 120) return 4;
    if (sa3d_geometry_capsule_vertex_count(0, 4, 0) != 0) return 5;
    if (sa3d_geometry_capsule_vertex_count(4, 2, 0) != 0) return 6;

    var vertices: [28]VertexP3N3Uv2 = undefined;
    var indices: [96]u32 = undefined;
    var mesh: MeshDesc = undefined;
    if (!sa3d_geometry_capsule_mesh_desc(&mesh, &vertices, &indices, 1.0, 2.0, 4, 4, 0, @intFromEnum(CapsuleUvProfile.aspect))) return 7;
    if (!sa3d_geometry_mesh_validate(&mesh)) return 8;
    if (!sa3d_geometry_mesh_indices_in_range(&mesh)) return 9;
    if (sa3d_geometry_mesh_triangle_count(&mesh) != 32) return 10;
    if (!approxEq(mesh.bounds.min.x, -1.0) or !approxEq(mesh.bounds.max.x, 1.0)) return 11;
    if (!approxEq(mesh.bounds.min.y, -2.0) or !approxEq(mesh.bounds.max.y, 2.0)) return 12;
    if (!approxEq(mesh.bounds.min.z, -1.0) or !approxEq(mesh.bounds.max.z, 1.0)) return 13;

    if (!expectVertex(vertices[0], 0.0, 2.0, 0.0, 0.0, 1.0, 0.0, 0.875, 1.0)) return 14;
    if (!expectVertex(vertices[4], 0.70710677, 1.7071068, 0.0, 0.70710677, 0.70710677, 0.0, 1.0, 0.875)) return 15;
    if (!expectVertex(vertices[9], 1.0, 1.0, 0.0, 1.0, 0.0, 0.0, 1.0, 0.75)) return 16;
    if (!expectVertex(vertices[14], 1.0, -1.0, 0.0, 1.0, 0.0, 0.0, 1.0, 0.25)) return 17;
    if (!expectVertex(vertices[19], 0.70710677, -1.7071068, 0.0, 0.70710677, -0.70710677, 0.0, 1.0, 0.125)) return 18;
    if (!expectVertex(vertices[24], 0.0, -2.0, 0.0, 0.0, -1.0, 0.0, 0.875, 0.0)) return 19;

    const expected_prefix = [_]u32{
        0, 4,  5,
        1, 5,  6,
        2, 6,  7,
        3, 7,  8,
        4, 10, 5,
        4, 9,  10,
        5, 11, 6,
        5, 10, 11,
        6, 12, 7,
        6, 11, 12,
        7, 13, 8,
        7, 12, 13,
    };
    var i: usize = 0;
    while (i < expected_prefix.len) : (i += 1) if (indices[i] != expected_prefix[i]) return 30 + @as(i32, @intCast(i));

    const expected_suffix = [_]u32{
        24, 20, 19,
        25, 21, 20,
        26, 22, 21,
        27, 23, 22,
    };
    i = 0;
    while (i < expected_suffix.len) : (i += 1) if (indices[84 + i] != expected_suffix[i]) return 80 + @as(i32, @intCast(i));

    var ring_vertices: [33]VertexP3N3Uv2 = undefined;
    var ring_indices: [120]u32 = undefined;
    var ring_mesh: MeshDesc = undefined;
    if (!sa3d_geometry_capsule_mesh_desc(&ring_mesh, &ring_vertices, &ring_indices, 1.0, 2.0, 4, 4, 1, @intFromEnum(CapsuleUvProfile.uniform))) return 110;
    if (!sa3d_geometry_mesh_validate(&ring_mesh)) return 111;
    if (sa3d_geometry_mesh_triangle_count(&ring_mesh) != 40) return 112;
    if (!expectVertex(ring_vertices[14], 1.0, 0.0, 0.0, 1.0, 0.0, 0.0, 1.0, 0.5)) return 113;
    if (!expectVertex(ring_vertices[19], 1.0, -1.0, 0.0, 1.0, 0.0, 0.0, 1.0, 0.33333334)) return 114;

    var fixed_vertices: [28]VertexP3N3Uv2 = undefined;
    var fixed_indices: [96]u32 = undefined;
    if (!sa3d_geometry_capsule_write(&fixed_vertices, &fixed_indices, 1.0, 2.0, 4, 4, 0, @intFromEnum(CapsuleUvProfile.fixed))) return 120;
    if (!expectVertex(fixed_vertices[9], 1.0, 1.0, 0.0, 1.0, 0.0, 0.0, 1.0, 0.6666667)) return 121;
    if (!expectVertex(fixed_vertices[14], 1.0, -1.0, 0.0, 1.0, 0.0, 0.0, 1.0, 0.33333334)) return 122;
    if (sa3d_geometry_capsule_write(&fixed_vertices, &fixed_indices, 1.0, 2.0, 0, 4, 0, @intFromEnum(CapsuleUvProfile.aspect))) return 123;
    if (sa3d_geometry_capsule_write(&fixed_vertices, &fixed_indices, 1.0, 2.0, 4, 2, 0, @intFromEnum(CapsuleUvProfile.aspect))) return 124;
    if (sa3d_geometry_capsule_write(&fixed_vertices, &fixed_indices, 1.0, 2.0, 4, 4, 0, 99)) return 125;
    return 0;
}

pub export fn sa3d_geometry_torus_selftest() callconv(.c) i32 {
    if (sa3d_geometry_torus_vertex_count(4, 4) != 25) return 1;
    if (sa3d_geometry_torus_index_count(4, 4) != 96) return 2;
    if (checkedTorusVertexCount(std.math.maxInt(u32), std.math.maxInt(u32)) != null) return 3;

    var vertices: [25]VertexP3N3Uv2 = undefined;
    var indices: [96]u32 = undefined;
    var mesh: MeshDesc = undefined;
    if (!sa3d_geometry_torus_mesh_desc(&mesh, &vertices, &indices, 1.0, 3.0, 4, 4, 0.0, 2.0 * std.math.pi)) return 4;
    if (!sa3d_geometry_mesh_validate(&mesh)) return 5;
    if (!sa3d_geometry_mesh_indices_in_range(&mesh)) return 6;
    if (sa3d_geometry_mesh_triangle_count(&mesh) != 32) return 7;
    if (!approxEq(mesh.bounds.min.x, -3.0) or !approxEq(mesh.bounds.max.x, 3.0)) return 8;
    if (!approxEq(mesh.bounds.min.y, -1.0) or !approxEq(mesh.bounds.max.y, 1.0)) return 9;
    if (!approxEq(mesh.bounds.min.z, -3.0) or !approxEq(mesh.bounds.max.z, 3.0)) return 10;
    if (!expectVertex(vertices[0], 3.0, 0.0, 0.0, 1.0, 0.0, 0.0, 0.0, 0.0)) return 11;
    if (!expectVertex(vertices[1], 2.0, 1.0, 0.0, 0.0, 1.0, 0.0, 0.0, 0.25)) return 12;
    if (!expectVertex(vertices[5], 0.0, 0.0, 3.0, 0.0, 0.0, 1.0, 0.25, 0.0)) return 13;
    if (!expectVertex(vertices[24], 3.0, 0.0, 0.0, 1.0, 0.0, 0.0, 1.0, 1.0)) return 14;
    const expected_prefix = [_]u32{
        0, 1, 5, 1, 6, 5,
        1, 2, 6, 2, 7, 6,
        2, 3, 7, 3, 8, 7,
        3, 4, 8, 4, 9, 8,
    };
    var i: usize = 0;
    while (i < expected_prefix.len) : (i += 1) if (indices[i] != expected_prefix[i]) return 30 + @as(i32, @intCast(i));

    var partial_vertices: [15]VertexP3N3Uv2 = undefined;
    var partial_indices: [48]u32 = undefined;
    var partial_mesh: MeshDesc = undefined;
    if (!sa3d_geometry_torus_mesh_desc(&partial_mesh, &partial_vertices, &partial_indices, 1.0, 3.0, 2, 4, 0.0, std.math.pi)) return 70;
    if (!sa3d_geometry_mesh_validate(&partial_mesh)) return 71;
    if (sa3d_geometry_mesh_triangle_count(&partial_mesh) != 16) return 72;
    if (!expectVertex(partial_vertices[0], 3.0, 0.0, 0.0, 1.0, 0.0, 0.0, 0.0, 0.0)) return 73;
    if (!expectVertex(partial_vertices[5], 0.0, 0.0, 3.0, 0.0, 0.0, 1.0, 0.5, 0.0)) return 74;
    if (!expectVertex(partial_vertices[10], -3.0, 0.0, 0.0, -1.0, 0.0, 0.0, 1.0, 0.0)) return 75;
    if (sa3d_geometry_torus_write(&partial_vertices, &partial_indices, 1.0, 3.0, 0, 4, 0.0, std.math.pi)) return 76;
    if (sa3d_geometry_torus_write(&partial_vertices, &partial_indices, 1.0, 3.0, 4, 0, 0.0, std.math.pi)) return 77;
    return 0;
}

pub export fn sa3d_geometry_triangle_selftest() callconv(.c) i32 {
    if (sa3d_geometry_triangle_vertex_count() != 3) return 1;
    if (sa3d_geometry_triangle_index_count() != 3) return 2;

    var vertices: [3]VertexP3N3Uv2 = undefined;
    var indices: [3]u32 = undefined;
    var mesh: MeshDesc = undefined;
    if (!sa3d_geometry_triangle_mesh_desc(&mesh, &vertices, &indices, 0.0, 0.0, 0.0, 2.0, 0.0, 0.0, -1.0, 1.0, 0.0)) return 3;
    if (!sa3d_geometry_mesh_validate(&mesh)) return 4;
    if (!sa3d_geometry_mesh_indices_in_range(&mesh)) return 5;
    if (sa3d_geometry_mesh_triangle_count(&mesh) != 1) return 6;
    if (!expectVertex(vertices[0], 0.0, 0.0, 0.0, 0.0, 0.0, 1.0, 0.33333334, 0.0)) return 7;
    if (!expectVertex(vertices[1], 2.0, 0.0, 0.0, 0.0, 0.0, 1.0, 1.0, 0.0)) return 8;
    if (!expectVertex(vertices[2], -1.0, 1.0, 0.0, 0.0, 0.0, 1.0, 0.0, 1.0)) return 9;
    if (indices[0] != 0 or indices[1] != 1 or indices[2] != 2) return 10;

    if (!sa3d_geometry_triangle_write(&vertices, &indices, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 1.0, 1.0, 1.0)) return 20;
    if (!expectVertex(vertices[0], 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0)) return 21;
    if (!expectVertex(vertices[1], 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 1.0, 0.0)) return 22;
    if (!expectVertex(vertices[2], 1.0, 1.0, 1.0, 0.0, 0.0, 0.0, 0.0, 1.0)) return 23;

    if (!sa3d_geometry_triangle_write(&vertices, &indices, 0.0, 0.0, 0.0, 2.0, 0.0, 0.0, 3.0, 1.0, 0.0)) return 30;
    if (!expectVertex(vertices[0], 0.0, 0.0, 0.0, 0.0, 0.0, 1.0, 0.0, 0.0)) return 31;
    if (!expectVertex(vertices[1], 2.0, 0.0, 0.0, 0.0, 0.0, 1.0, 0.6666667, 0.0)) return 32;
    if (!expectVertex(vertices[2], 3.0, 1.0, 0.0, 0.0, 0.0, 1.0, 1.0, 1.0)) return 33;
    return 0;
}

pub export fn sa3d_geometry_tetrahedron_selftest() callconv(.c) i32 {
    if (sa3d_geometry_tetrahedron_vertex_count() != 12) return 1;
    if (sa3d_geometry_tetrahedron_index_count() != 12) return 2;

    var vertices: [12]VertexP3N3Uv2 = undefined;
    var indices: [12]u32 = undefined;
    var mesh: MeshDesc = undefined;
    if (!sa3d_geometry_tetrahedron_mesh_desc(&mesh, &vertices, &indices, 0.5, 0.5, 0.5, -0.5, 0.5, -0.5, -0.5, -0.5, 0.5, 0.5, -0.5, -0.5)) return 3;
    if (!sa3d_geometry_mesh_validate(&mesh)) return 4;
    if (!sa3d_geometry_mesh_indices_in_range(&mesh)) return 5;
    if (sa3d_geometry_mesh_triangle_count(&mesh) != 4) return 6;
    if (!approxEq(mesh.bounds.min.x, -0.5) or !approxEq(mesh.bounds.min.y, -0.5) or !approxEq(mesh.bounds.min.z, -0.5)) return 7;
    if (!approxEq(mesh.bounds.max.x, 0.5) or !approxEq(mesh.bounds.max.y, 0.5) or !approxEq(mesh.bounds.max.z, 0.5)) return 8;
    var i: usize = 0;
    while (i < indices.len) : (i += 1) if (indices[i] != i) return 20 + @as(i32, @intCast(i));
    if (!expectVertex(vertices[0], 0.5, -0.5, -0.5, -0.57735026, -0.57735026, -0.57735026, 0.0, 0.0)) return 40;
    if (!expectVertex(vertices[1], -0.5, -0.5, 0.5, -0.57735026, -0.57735026, -0.57735026, 1.0, 0.0)) return 41;
    if (!expectVertex(vertices[2], -0.5, 0.5, -0.5, -0.57735026, -0.57735026, -0.57735026, 0.5, 1.0)) return 42;
    if (!expectVertex(vertices[3], 0.5, 0.5, 0.5, 0.57735026, -0.57735026, 0.57735026, 0.0, 0.0)) return 43;
    if (!expectVertex(vertices[6], 0.5, -0.5, -0.5, 0.57735026, 0.57735026, -0.57735026, 0.0, 0.0)) return 44;
    if (!expectVertex(vertices[9], 0.5, 0.5, 0.5, -0.57735026, 0.57735026, 0.57735026, 0.0, 0.0)) return 45;

    var reversed_vertices: [12]VertexP3N3Uv2 = undefined;
    var reversed_indices: [12]u32 = undefined;
    if (!sa3d_geometry_tetrahedron_write(&reversed_vertices, &reversed_indices, 0.5, 0.5, 0.5, -0.5, 0.5, -0.5, -0.5, -0.5, 0.5, 0.5, -0.5, -0.5)) return 70;
    if (!expectVertex(reversed_vertices[0], 0.5, -0.5, -0.5, -0.57735026, -0.57735026, -0.57735026, 0.0, 0.0)) return 71;
    if (!expectVertex(reversed_vertices[1], -0.5, -0.5, 0.5, -0.57735026, -0.57735026, -0.57735026, 1.0, 0.0)) return 72;
    if (!expectVertex(reversed_vertices[2], -0.5, 0.5, -0.5, -0.57735026, -0.57735026, -0.57735026, 0.5, 1.0)) return 73;
    return 0;
}

pub export fn sa3d_geometry_segment_selftest() callconv(.c) i32 {
    if (sa3d_geometry_segment_vertex_count() != 2) return 1;
    if (sa3d_geometry_segment_index_count() != 2) return 2;

    var vertices: [2]VertexP3N3Uv2 = undefined;
    var indices: [2]u32 = undefined;
    var mesh: MeshDesc = undefined;
    if (!sa3d_geometry_segment_mesh_desc(&mesh, &vertices, &indices, -1.0, 2.0, -3.0, 4.0, -5.0, 6.0)) return 3;
    if (!sa3d_geometry_mesh_validate(&mesh)) return 4;
    if (!sa3d_geometry_mesh_indices_in_range(&mesh)) return 5;
    if (sa3d_geometry_mesh_draw_count(&mesh) != 2) return 6;
    if (sa3d_geometry_mesh_triangle_count(&mesh) != 0) return 7;
    if (!approxEq(mesh.bounds.min.x, -1.0) or !approxEq(mesh.bounds.min.y, -5.0) or !approxEq(mesh.bounds.min.z, -3.0)) return 8;
    if (!approxEq(mesh.bounds.max.x, 4.0) or !approxEq(mesh.bounds.max.y, 2.0) or !approxEq(mesh.bounds.max.z, 6.0)) return 9;
    if (!expectVertex(vertices[0], -1.0, 2.0, -3.0, 0.0, 0.0, 0.0, 0.0, 0.0)) return 10;
    if (!expectVertex(vertices[1], 4.0, -5.0, 6.0, 0.0, 0.0, 0.0, 0.0, 0.0)) return 11;
    if (indices[0] != 0 or indices[1] != 1) return 12;
    return 0;
}

pub export fn sa3d_geometry_polyline_selftest() callconv(.c) i32 {
    if (sa3d_geometry_polyline_vertex_count(4) != 4) return 1;
    if (sa3d_geometry_polyline_index_count(4) != 6) return 2;
    if (sa3d_geometry_polyline_index_count(1) != 0) return 3;

    const positions = [_]Vec3f{
        .{ .x = -1.0, .y = 0.0, .z = 2.0 },
        .{ .x = 0.0, .y = 1.0, .z = 3.0 },
        .{ .x = 4.0, .y = -2.0, .z = -5.0 },
        .{ .x = 8.0, .y = 0.5, .z = 1.0 },
    };
    var vertices: [4]VertexP3N3Uv2 = undefined;
    var indices: [6]u32 = undefined;
    var mesh: MeshDesc = undefined;
    if (!sa3d_geometry_polyline_mesh_desc(&mesh, &vertices, &indices, &positions, positions.len)) return 4;
    if (!sa3d_geometry_mesh_validate(&mesh)) return 5;
    if (!sa3d_geometry_mesh_indices_in_range(&mesh)) return 6;
    if (sa3d_geometry_mesh_draw_count(&mesh) != 6) return 7;
    if (sa3d_geometry_mesh_triangle_count(&mesh) != 0) return 8;
    if (!approxEq(mesh.bounds.min.x, -1.0) or !approxEq(mesh.bounds.min.y, -2.0) or !approxEq(mesh.bounds.min.z, -5.0)) return 9;
    if (!approxEq(mesh.bounds.max.x, 8.0) or !approxEq(mesh.bounds.max.y, 1.0) or !approxEq(mesh.bounds.max.z, 3.0)) return 10;
    if (!expectVertex(vertices[0], -1.0, 0.0, 2.0, 0.0, 0.0, 0.0, 0.0, 0.0)) return 11;
    if (!expectVertex(vertices[2], 4.0, -2.0, -5.0, 0.0, 0.0, 0.0, 0.0, 0.0)) return 12;
    const expected = [_]u32{ 0, 1, 1, 2, 2, 3 };
    var i: usize = 0;
    while (i < expected.len) : (i += 1) if (indices[i] != expected[i]) return 20 + @as(i32, @intCast(i));
    if (sa3d_geometry_polyline_write(&vertices, &indices, &positions, 1)) return 40;
    return 0;
}

pub export fn sa3d_geometry_selftest() callconv(.c) i32 {
    var vertices: [4]VertexP3N3Uv2 = undefined;
    sa3d_geometry_vertex_p3n3uv2_set(&vertices[0], -1.0, -1.0, 0.0, 0.0, 0.0, 1.0, 0.0, 1.0);
    sa3d_geometry_vertex_p3n3uv2_set(&vertices[1], 1.0, -1.0, 0.0, 0.0, 0.0, 1.0, 1.0, 1.0);
    sa3d_geometry_vertex_p3n3uv2_set(&vertices[2], 1.0, 2.0, 0.0, 0.0, 0.0, 1.0, 1.0, 0.0);
    sa3d_geometry_vertex_p3n3uv2_set(&vertices[3], -0.5, 0.0, 3.0, 0.0, 0.0, 1.0, 0.5, 0.5);
    var indices = [_]u32{ 0, 1, 2, 0, 2, 3 };
    var mesh: MeshDesc = undefined;
    sa3d_geometry_mesh_desc_init(&mesh, &vertices, vertices.len, &indices, indices.len, @intFromEnum(IndexFormat.u32), @intFromEnum(PrimitiveTopology.triangle_list));
    if (!sa3d_geometry_mesh_validate(&mesh)) return 1;
    if (!sa3d_geometry_mesh_indices_in_range(&mesh)) return 2;
    if (sa3d_geometry_mesh_draw_count(&mesh) != 6 or sa3d_geometry_mesh_triangle_count(&mesh) != 2) return 3;
    if (sa3d_geometry_mesh_vertex_byte_len(&mesh) != vertices.len * @sizeOf(VertexP3N3Uv2)) return 4;
    if (sa3d_geometry_mesh_index_byte_len(&mesh) != indices.len * 4) return 5;
    if (!approxEq(mesh.bounds.min.x, -1.0) or !approxEq(mesh.bounds.min.y, -1.0) or !approxEq(mesh.bounds.max.z, 3.0)) return 6;
    if (sa3d_geometry_mesh_count_vertices(4, 3, 2) != 2) return 7;
    var bad_indices = [_]u32{ 0, 1, 9 };
    sa3d_geometry_mesh_desc_init(&mesh, &vertices, vertices.len, &bad_indices, bad_indices.len, @intFromEnum(IndexFormat.u32), @intFromEnum(PrimitiveTopology.triangle_list));
    if (sa3d_geometry_mesh_indices_in_range(&mesh)) return 8;
    mesh.index_len = 5;
    if (sa3d_geometry_mesh_validate(&mesh)) return 9;
    var submesh: Submesh = undefined;
    sa3d_geometry_submesh_init(&submesh, 4, 9, 2, 77);
    if (sa3d_geometry_submesh_end_index(&submesh) != 13) return 10;
    if (sa3d_geometry_cuboid_selftest() != 0) return 11;
    if (sa3d_geometry_plane_selftest() != 0) return 12;
    if (sa3d_geometry_uv_sphere_selftest() != 0) return 13;
    if (sa3d_geometry_ico_sphere_selftest() != 0) return 14;
    if (sa3d_geometry_cylinder_selftest() != 0) return 15;
    if (sa3d_geometry_cone_selftest() != 0) return 16;
    if (sa3d_geometry_capsule_selftest() != 0) return 17;
    if (sa3d_geometry_torus_selftest() != 0) return 18;
    if (sa3d_geometry_triangle_selftest() != 0) return 19;
    if (sa3d_geometry_tetrahedron_selftest() != 0) return 20;
    if (sa3d_geometry_conical_frustum_selftest() != 0) return 21;
    if (sa3d_geometry_segment_selftest() != 0) return 22;
    if (sa3d_geometry_polyline_selftest() != 0) return 23;
    return 0;
}

test "geometry native mesh behavior matches Bevy mesh basics" {
    try std.testing.expectEqual(@as(i32, 0), sa3d_geometry_selftest());
}

test "geometry cuboid primitive matches Bevy cuboid builder" {
    try std.testing.expectEqual(@as(i32, 0), sa3d_geometry_cuboid_selftest());
}

test "geometry plane primitive matches Bevy plane builder" {
    try std.testing.expectEqual(@as(i32, 0), sa3d_geometry_plane_selftest());
}

test "geometry uv sphere primitive matches Bevy sphere uv builder" {
    try std.testing.expectEqual(@as(i32, 0), sa3d_geometry_uv_sphere_selftest());
}

test "geometry ico sphere primitive matches Bevy sphere ico builder" {
    try std.testing.expectEqual(@as(i32, 0), sa3d_geometry_ico_sphere_selftest());
}

test "geometry cylinder primitive matches Bevy cylinder builder" {
    try std.testing.expectEqual(@as(i32, 0), sa3d_geometry_cylinder_selftest());
}

test "geometry conical frustum primitive matches Bevy conical frustum builder" {
    try std.testing.expectEqual(@as(i32, 0), sa3d_geometry_conical_frustum_selftest());
}

test "geometry cone primitive matches Bevy cone builder" {
    try std.testing.expectEqual(@as(i32, 0), sa3d_geometry_cone_selftest());
}

test "geometry capsule primitive matches Bevy capsule builder" {
    try std.testing.expectEqual(@as(i32, 0), sa3d_geometry_capsule_selftest());
}

test "geometry torus primitive matches Bevy torus builder" {
    try std.testing.expectEqual(@as(i32, 0), sa3d_geometry_torus_selftest());
}

test "geometry triangle primitive matches Bevy triangle builder" {
    try std.testing.expectEqual(@as(i32, 0), sa3d_geometry_triangle_selftest());
}

test "geometry tetrahedron primitive matches Bevy tetrahedron builder" {
    try std.testing.expectEqual(@as(i32, 0), sa3d_geometry_tetrahedron_selftest());
}

test "geometry segment primitive matches Bevy segment builder" {
    try std.testing.expectEqual(@as(i32, 0), sa3d_geometry_segment_selftest());
}

test "geometry polyline primitive matches Bevy polyline builder" {
    try std.testing.expectEqual(@as(i32, 0), sa3d_geometry_polyline_selftest());
}
