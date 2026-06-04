const std = @import("std");

pub usingnamespace @import("module_plugin");

pub const ImageDimension = enum(i32) {
    d1 = 1,
    d2 = 2,
    d3 = 3,
    cube = 4,
};

pub const ImageFormat = enum(i32) {
    rgba8_unorm = 1,
    rgba8_unorm_srgb = 2,
    bgra8_unorm = 3,
    rgba16_float = 4,
    rgba32_float = 5,
    depth24_plus = 100,
};

pub const ImageUsage = enum(i32) {
    texture_binding = 1,
    copy_dst = 2,
    copy_src = 4,
    render_attachment = 8,
    storage_binding = 16,
};

pub const SamplerAddress = enum(i32) {
    clamp_to_edge = 0,
    repeat = 1,
    mirror_repeat = 2,
};

pub const SamplerFilter = enum(i32) {
    nearest = 0,
    linear = 1,
};

pub const ImageDesc = extern struct {
    width: u32,
    height: u32,
    depth_or_layers: u32,
    mip_count: u32,
    dimension: i32,
    format: i32,
    usage: i32,
    color_space: i32,
    data_ptr: ?*const anyopaque,
    data_len: u64,
    row_pitch: u64,
};

pub const SamplerDesc = extern struct {
    address_u: i32,
    address_v: i32,
    address_w: i32,
    mag_filter: i32,
    min_filter: i32,
    mipmap_filter: i32,
    lod_min: i32,
    lod_max: i32,
    compare: i32,
};

fn usageMask() i32 {
    return @intFromEnum(ImageUsage.texture_binding) |
        @intFromEnum(ImageUsage.copy_dst) |
        @intFromEnum(ImageUsage.copy_src) |
        @intFromEnum(ImageUsage.render_attachment) |
        @intFromEnum(ImageUsage.storage_binding);
}

pub export fn sa3d_image_format_is_valid_native(format: i32) callconv(.c) bool {
    return format == @intFromEnum(ImageFormat.rgba8_unorm) or
        format == @intFromEnum(ImageFormat.rgba8_unorm_srgb) or
        format == @intFromEnum(ImageFormat.bgra8_unorm) or
        format == @intFromEnum(ImageFormat.rgba16_float) or
        format == @intFromEnum(ImageFormat.rgba32_float) or
        format == @intFromEnum(ImageFormat.depth24_plus);
}

pub export fn sa3d_image_dimension_is_valid_native(dimension: i32) callconv(.c) bool {
    return dimension == @intFromEnum(ImageDimension.d1) or
        dimension == @intFromEnum(ImageDimension.d2) or
        dimension == @intFromEnum(ImageDimension.d3) or
        dimension == @intFromEnum(ImageDimension.cube);
}

pub export fn sa3d_image_format_bytes_per_pixel_native(format: i32) callconv(.c) u64 {
    if (format == @intFromEnum(ImageFormat.rgba16_float)) return 8;
    if (format == @intFromEnum(ImageFormat.rgba32_float)) return 16;
    if (format == @intFromEnum(ImageFormat.rgba8_unorm) or
        format == @intFromEnum(ImageFormat.rgba8_unorm_srgb) or
        format == @intFromEnum(ImageFormat.bgra8_unorm) or
        format == @intFromEnum(ImageFormat.depth24_plus)) return 4;
    return 0;
}

pub export fn sa3d_image_format_srgb_view_native(format: i32) callconv(.c) i32 {
    if (format == @intFromEnum(ImageFormat.rgba8_unorm)) return @intFromEnum(ImageFormat.rgba8_unorm_srgb);
    return 0;
}

pub export fn sa3d_image_format_is_srgb_native(format: i32) callconv(.c) bool {
    return format == @intFromEnum(ImageFormat.rgba8_unorm_srgb);
}

pub export fn sa3d_image_desc_init_native(desc: *ImageDesc) callconv(.c) void {
    desc.* = .{
        .width = 1,
        .height = 1,
        .depth_or_layers = 1,
        .mip_count = 1,
        .dimension = @intFromEnum(ImageDimension.d2),
        .format = @intFromEnum(ImageFormat.rgba8_unorm_srgb),
        .usage = @intFromEnum(ImageUsage.texture_binding) | @intFromEnum(ImageUsage.copy_dst) | @intFromEnum(ImageUsage.copy_src),
        .color_space = 1,
        .data_ptr = null,
        .data_len = 4,
        .row_pitch = 4,
    };
}

pub export fn sa3d_image_desc_new_uninit_native(desc: *ImageDesc, width: u32, height: u32, depth_or_layers: u32, dimension: i32, format: i32) callconv(.c) bool {
    if (!sa3d_image_dimension_is_valid_native(dimension) or !sa3d_image_format_is_valid_native(format)) return false;
    if (width == 0 or height == 0 or depth_or_layers == 0) return false;
    desc.* = .{
        .width = width,
        .height = height,
        .depth_or_layers = depth_or_layers,
        .mip_count = 1,
        .dimension = dimension,
        .format = format,
        .usage = @intFromEnum(ImageUsage.texture_binding) | @intFromEnum(ImageUsage.copy_dst) | @intFromEnum(ImageUsage.copy_src),
        .color_space = if (sa3d_image_format_is_srgb_native(format)) 1 else 0,
        .data_ptr = null,
        .data_len = 0,
        .row_pitch = sa3d_image_desc_row_pitch_native(width, format),
    };
    return true;
}

pub export fn sa3d_image_desc_new_fill_native(desc: *ImageDesc, width: u32, height: u32, depth_or_layers: u32, dimension: i32, format: i32, data_ptr: ?*const anyopaque, data_len: u64) callconv(.c) bool {
    if (!sa3d_image_desc_new_uninit_native(desc, width, height, depth_or_layers, dimension, format)) return false;
    const expected = sa3d_image_desc_compute_data_len_native(desc);
    if (expected == 0 or data_len != expected or data_ptr == null) return false;
    desc.data_ptr = data_ptr;
    desc.data_len = data_len;
    return true;
}

pub export fn sa3d_image_desc_new_target_texture_native(desc: *ImageDesc, width: u32, height: u32, format: i32, srgb_view: bool) callconv(.c) bool {
    if (!sa3d_image_desc_new_uninit_native(desc, width, height, 1, @intFromEnum(ImageDimension.d2), format)) return false;
    desc.usage = @intFromEnum(ImageUsage.texture_binding) | @intFromEnum(ImageUsage.copy_dst) | @intFromEnum(ImageUsage.render_attachment);
    desc.data_len = sa3d_image_desc_compute_data_len_native(desc);
    desc.color_space = if (srgb_view and sa3d_image_format_srgb_view_native(format) != 0) 1 else desc.color_space;
    return desc.data_len != 0;
}

pub export fn sa3d_image_desc_set_size_native(desc: *ImageDesc, width: u32, height: u32, depth_or_layers: u32) callconv(.c) bool {
    if (width == 0 or height == 0 or depth_or_layers == 0) return false;
    desc.width = width;
    desc.height = height;
    desc.depth_or_layers = depth_or_layers;
    desc.row_pitch = sa3d_image_desc_row_pitch_native(width, desc.format);
    if (desc.data_len != 0) desc.data_len = sa3d_image_desc_compute_data_len_native(desc);
    return true;
}

pub export fn sa3d_image_desc_reinterpret_size_native(desc: *ImageDesc, width: u32, height: u32, depth_or_layers: u32) callconv(.c) bool {
    if (width == 0 or height == 0 or depth_or_layers == 0) return false;
    const old_pixels = @as(u64, desc.width) * @as(u64, desc.height) * @as(u64, desc.depth_or_layers);
    const new_pixels = @as(u64, width) * @as(u64, height) * @as(u64, depth_or_layers);
    if (old_pixels != new_pixels) return false;
    desc.width = width;
    desc.height = height;
    desc.depth_or_layers = depth_or_layers;
    desc.row_pitch = sa3d_image_desc_row_pitch_native(width, desc.format);
    return true;
}

pub export fn sa3d_image_desc_row_pitch_native(width: u32, format: i32) callconv(.c) u64 {
    return @as(u64, width) * sa3d_image_format_bytes_per_pixel_native(format);
}

pub export fn sa3d_image_desc_compute_row_pitch_native(desc: *const ImageDesc) callconv(.c) u64 {
    return sa3d_image_desc_row_pitch_native(desc.width, desc.format);
}

pub export fn sa3d_image_desc_compute_data_len_native(desc: *const ImageDesc) callconv(.c) u64 {
    const bpp = sa3d_image_format_bytes_per_pixel_native(desc.format);
    return @as(u64, desc.width) * @as(u64, desc.height) * @as(u64, desc.depth_or_layers) * bpp;
}

pub export fn sa3d_image_desc_validate_native(desc: *const ImageDesc) callconv(.c) bool {
    if (desc.width == 0 or desc.height == 0 or desc.depth_or_layers == 0 or desc.mip_count == 0) return false;
    if (!sa3d_image_dimension_is_valid_native(desc.dimension) or !sa3d_image_format_is_valid_native(desc.format)) return false;
    if (desc.usage == 0 or (desc.usage & ~usageMask()) != 0) return false;
    if (desc.dimension == @intFromEnum(ImageDimension.cube) and desc.depth_or_layers % 6 != 0) return false;
    if (desc.row_pitch != 0 and desc.row_pitch < sa3d_image_desc_compute_row_pitch_native(desc)) return false;
    if (desc.data_len != 0 and desc.data_len < sa3d_image_desc_compute_data_len_native(desc)) return false;
    return true;
}

pub export fn sa3d_sampler_address_is_valid_native(address: i32) callconv(.c) bool {
    return address == @intFromEnum(SamplerAddress.clamp_to_edge) or
        address == @intFromEnum(SamplerAddress.repeat) or
        address == @intFromEnum(SamplerAddress.mirror_repeat);
}

pub export fn sa3d_sampler_filter_is_valid_native(filter: i32) callconv(.c) bool {
    return filter == @intFromEnum(SamplerFilter.nearest) or filter == @intFromEnum(SamplerFilter.linear);
}

pub export fn sa3d_sampler_desc_default_native(desc: *SamplerDesc) callconv(.c) void {
    desc.* = .{
        .address_u = @intFromEnum(SamplerAddress.clamp_to_edge),
        .address_v = @intFromEnum(SamplerAddress.clamp_to_edge),
        .address_w = @intFromEnum(SamplerAddress.clamp_to_edge),
        .mag_filter = @intFromEnum(SamplerFilter.nearest),
        .min_filter = @intFromEnum(SamplerFilter.nearest),
        .mipmap_filter = @intFromEnum(SamplerFilter.nearest),
        .lod_min = 0,
        .lod_max = 32,
        .compare = 0,
    };
}

pub export fn sa3d_sampler_desc_linear_native(desc: *SamplerDesc) callconv(.c) void {
    sa3d_sampler_desc_default_native(desc);
    desc.mag_filter = @intFromEnum(SamplerFilter.linear);
    desc.min_filter = @intFromEnum(SamplerFilter.linear);
    desc.mipmap_filter = @intFromEnum(SamplerFilter.linear);
}

pub export fn sa3d_sampler_desc_nearest_native(desc: *SamplerDesc) callconv(.c) void {
    sa3d_sampler_desc_default_native(desc);
}

pub export fn sa3d_sampler_desc_validate_native(desc: *const SamplerDesc) callconv(.c) bool {
    if (!sa3d_sampler_address_is_valid_native(desc.address_u) or !sa3d_sampler_address_is_valid_native(desc.address_v) or !sa3d_sampler_address_is_valid_native(desc.address_w)) return false;
    if (!sa3d_sampler_filter_is_valid_native(desc.mag_filter) or !sa3d_sampler_filter_is_valid_native(desc.min_filter) or !sa3d_sampler_filter_is_valid_native(desc.mipmap_filter)) return false;
    if (desc.lod_min > desc.lod_max) return false;
    return true;
}

pub export fn sa3d_image_native_selftest() callconv(.c) i32 {
    var image: ImageDesc = undefined;
    sa3d_image_desc_init_native(&image);
    if (image.width != 1 or image.height != 1 or image.depth_or_layers != 1) return 1;
    if (image.format != @intFromEnum(ImageFormat.rgba8_unorm_srgb)) return 2;
    if (image.data_len != 4 or image.row_pitch != 4) return 3;
    if (!sa3d_image_desc_validate_native(&image)) return 4;
    if (sa3d_image_format_srgb_view_native(@intFromEnum(ImageFormat.rgba8_unorm)) != @intFromEnum(ImageFormat.rgba8_unorm_srgb)) return 5;
    if (sa3d_image_format_srgb_view_native(@intFromEnum(ImageFormat.rgba16_float)) != 0) return 6;

    if (!sa3d_image_desc_new_uninit_native(&image, 128, 64, 2, @intFromEnum(ImageDimension.d2), @intFromEnum(ImageFormat.rgba16_float))) return 7;
    if (image.data_len != 0 or image.row_pitch != 1024) return 8;
    if (sa3d_image_desc_compute_data_len_native(&image) != 131072) return 9;
    var pixel: [16]u8 = [_]u8{ 255, 0, 0, 255 } ** 4;
    if (!sa3d_image_desc_new_fill_native(&image, 2, 2, 1, @intFromEnum(ImageDimension.d2), @intFromEnum(ImageFormat.rgba8_unorm_srgb), &pixel, 16)) return 10;
    if (image.data_ptr == null or image.data_len != 16) return 11;
    if (sa3d_image_desc_new_fill_native(&image, 2, 2, 1, @intFromEnum(ImageDimension.d2), @intFromEnum(ImageFormat.rgba8_unorm_srgb), &pixel, 15)) return 12;
    if (!sa3d_image_desc_new_target_texture_native(&image, 16, 8, @intFromEnum(ImageFormat.rgba8_unorm), true)) return 13;
    if ((image.usage & @intFromEnum(ImageUsage.render_attachment)) == 0 or image.data_len != 512) return 14;
    if (!sa3d_image_desc_reinterpret_size_native(&image, 8, 16, 1)) return 15;
    if (sa3d_image_desc_reinterpret_size_native(&image, 9, 16, 1)) return 16;
    image.usage |= 1024;
    if (sa3d_image_desc_validate_native(&image)) return 17;
    if (!sa3d_image_desc_new_uninit_native(&image, 4, 4, 6, @intFromEnum(ImageDimension.cube), @intFromEnum(ImageFormat.rgba8_unorm_srgb))) return 18;
    if (!sa3d_image_desc_validate_native(&image)) return 19;
    image.depth_or_layers = 5;
    if (sa3d_image_desc_validate_native(&image)) return 20;

    var sampler: SamplerDesc = undefined;
    sa3d_sampler_desc_default_native(&sampler);
    if (sampler.mag_filter != @intFromEnum(SamplerFilter.nearest) or sampler.lod_max != 32) return 30;
    if (!sa3d_sampler_desc_validate_native(&sampler)) return 31;
    sa3d_sampler_desc_linear_native(&sampler);
    if (sampler.mag_filter != @intFromEnum(SamplerFilter.linear) or sampler.mipmap_filter != @intFromEnum(SamplerFilter.linear)) return 32;
    sampler.lod_min = 33;
    if (sa3d_sampler_desc_validate_native(&sampler)) return 33;
    sampler.lod_min = 0;
    sampler.address_u = 99;
    if (sa3d_sampler_desc_validate_native(&sampler)) return 34;
    return 0;
}

test "image native behavior matches Bevy image descriptor basics" {
    try std.testing.expectEqual(@as(i32, 0), sa3d_image_native_selftest());
}
