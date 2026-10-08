// Uniforms and varyings of the PSX surface body (psx_body.gdshaderinc), which includes
// this file. A shader that fills the body's hooks includes it first, so the hooks can
// read the uniforms. Depends on the PSX_SCISSOR and PSX_SPRITE defines.

#ifndef PSX_BODY_UNIFORMS_GDSHADERINC
#define PSX_BODY_UNIFORMS_GDSHADERINC

uniform sampler2D albedo_texture : source_color, filter_nearest, repeat_enable, hint_default_white;
uniform vec4 albedo_colour : source_color = vec4(1.0);
uniform vec2 uv_scale = vec2(1.0);
uniform vec2 uv_offset = vec2(0.0);
// Box projection in world space: each vertex takes its UV from world position on the
// plane its normal faces most, one texture repeat per metre (times uv_scale). For
// greybox geometry with no authored UVs. Per vertex, so affine mapping still applies.
uniform bool world_uv = false;
// Share of its distance the surface is drawn nearer the camera, for decals a few
// millimetres off a wall: vertex snap shifts the wall's depth by more than that, by an
// amount that grows with distance.
uniform float depth_lift : hint_range(0.0, 0.1, 0.001) = 0.0;
#if defined(PSX_SPRITE)
// BaseMaterial3D.BillboardMode: 0 none, 1 faces the camera, 2 turns about y only. Keeps
// the node's scale.
uniform int billboard_mode = 2;
#endif
#if defined(PSX_SCISSOR)
uniform float alpha_scissor : hint_range(0.0, 1.0, 0.01) = 0.5;
#endif

// Instance uniforms of one mesh share its slots across its material, overlay and next
// passes, so every 3D toolkit shader gives each name a fixed instance_index: tk_flash 0,
// tk_flash_colour 1 (as in tk_look's flash_3d.gdshader), tk_dissolve 2, tk_xray_colour 3,
// tk_xray_dither 4.
#if defined(PSX_XRAY)
instance uniform vec4 tk_xray_colour : source_color, instance_index(3) = vec4(0.545, 0.608, 0.706, 1.0);
// Share of the silhouette's pixels left out by a 4x4 Bayer pattern on the screen.
instance uniform float tk_xray_dither : hint_range(0.0, 1.0), instance_index(4) = 0.0;
#elif defined(PSX_XRAY_MARK)
instance uniform float tk_flash : hint_range(0.0, 1.0), instance_index(0) = 0.0;
instance uniform vec4 tk_flash_colour : source_color, instance_index(1) = vec4(1.0);
#else
// Dissolve pattern (tk_dissolve_level): 0 ordered, 1 hashed per texel, 2 or more blobs
// about that many texels across.
uniform int dissolve_cell : hint_range(0, 16) = 4;
// Texels within this many texels of a dissolved texel draw in the edge colour.
uniform int dissolve_edge_width : hint_range(0, 3) = 1;
uniform vec4 dissolve_edge_colour : source_color = vec4(0.996, 0.682, 0.204, 1.0);
// Texels per UV unit the dissolve works in; 0 uses albedo_texture's size.
uniform vec2 dissolve_texels = vec2(0.0);
instance uniform float tk_dissolve : hint_range(0.0, 1.0), instance_index(2) = 0.0;
#endif

// Clip-space w of the vertex when affine mapping is on, else 1. UV is multiplied by it
// in vertex() and divided by the interpolated value in fragment(), which cancels the
// perspective correction the rasteriser applies.
varying float psx_w;
varying float psx_fog;
varying flat int psx_lod;

#endif
