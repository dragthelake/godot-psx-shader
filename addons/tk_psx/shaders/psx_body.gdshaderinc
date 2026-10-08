// Shared body of the PSX surface shaders. Each file in variants/ is `shader_type spatial;`,
// a few defines and an include of this file:
//
//   PSX_UNLIT         unshaded; otherwise per-vertex lighting (vertex_lighting,
//                     diffuse_lambert_wrap, no specular), like URSC
//   PSX_SCISSOR       alpha scissor (cut-out) with the alpha_scissor threshold
//   PSX_BLEND         alpha blend
//   PSX_DOUBLE_SIDED  cull_disabled; otherwise cull_back
//   PSX_SPRITE        billboard_mode uniform, for Sprite3D, AnimatedSprite3D and
//                     TKSprite3D (see TKPsx.apply_to_sprite)
//   PSX_XRAY_MARK     x-ray first pass (TKPsx.set_xray): marks the stencil where the
//                     actor is visible, and draws the tk_flash hit flash there
//   PSX_XRAY          x-ray second pass: a flat tk_xray_colour silhouette where the actor
//                     is behind something (inverted depth test) and not marked
//
// Every surface variant dissolves on the tk_dissolve instance uniform (TKPsx.dissolve):
// whole texels of albedo_texture in the look_dissolve.gdshaderinc pattern, cut by the
// alpha scissor in scissor variants and discarded in the others.
//
// Two hooks let a shader add to the body instead of copying it. Define the macro and,
// before the include, the function:
//
//   PSX_CUSTOM_VERTEX  void psx_custom_vertex(inout vec3 vertex, inout vec3 normal,
//                      inout vec2 uv, inout vec4 colour, mat4 model, float time)
//                      runs first in vertex(), on the local vertex, before snap and fog
//   PSX_CUSTOM_ALBEDO  vec4 psx_custom_albedo(vec2 uv, bool half_lod, float time)
//                      replaces the sample of albedo_texture; uv is already affine
//                      corrected, half_lod is true beyond psx_texture_lod_distance
//
// A hook that reads the body's uniforms includes psx_body_uniforms.gdshaderinc first.
//
// Vertex snap, affine mapping, per-vertex fog, draw distance cull and texture LOD follow
// the psx_* global parameters (psx_globals.gdshaderinc). Ported from Ultimate Retro
// Shader Collection's common.gdshaderinc; see THIRD_PARTY.md.
//
// Copyright (c) 2024-2026 Zorochase. MIT licence.

#include "res://addons/tk_psx/shaders/psx.gdshaderinc"
#include "res://addons/tk_psx/shaders/psx_globals.gdshaderinc"
#include "res://addons/tk_look/shaders/look_dissolve.gdshaderinc"

#if defined(PSX_XRAY_MARK) || defined(PSX_XRAY)
#define PSX_XRAY_PASS
// Stencil value the x-ray passes write. Nothing else in the toolkit uses the stencil.
#define PSX_XRAY_STENCIL 64
// The x-ray passes draw this many metres nearer the camera, so the actor's own visible
// surface never counts as hidden behind itself.
#define PSX_XRAY_BIAS 0.05
render_mode
#if defined(PSX_DOUBLE_SIDED)
	cull_disabled,
#else
	cull_back,
#endif
#if defined(PSX_XRAY)
	depth_test_inverted,
#endif
	blend_mix,
	depth_draw_never,
	unshaded,
	fog_disabled,
	specular_disabled,
	shadows_disabled;
#if defined(PSX_XRAY)
stencil_mode read, write, compare_not_equal, PSX_XRAY_STENCIL;
#else
stencil_mode write, compare_always, PSX_XRAY_STENCIL;
#endif
#else
render_mode
#if defined(PSX_DOUBLE_SIDED)
	cull_disabled,
#else
	cull_back,
#endif
#if defined(PSX_BLEND)
	blend_mix,
#endif
	depth_draw_opaque,
#if defined(PSX_UNLIT)
	unshaded,
#else
	vertex_lighting,
	diffuse_lambert_wrap,
#endif
	specular_disabled,
	shadows_disabled;
#endif

#include "res://addons/tk_psx/shaders/psx_body_uniforms.gdshaderinc"

void vertex() {
#if defined(PSX_CUSTOM_VERTEX)
	psx_custom_vertex(VERTEX, NORMAL, UV, COLOR, MODEL_MATRIX, TIME);
#endif
#if defined(PSX_SPRITE)
	if (billboard_mode == 1) {
		MODELVIEW_MATRIX = VIEW_MATRIX * mat4(INV_VIEW_MATRIX[0], INV_VIEW_MATRIX[1], INV_VIEW_MATRIX[2], MODEL_MATRIX[3]);
	} else if (billboard_mode == 2) {
		MODELVIEW_MATRIX = VIEW_MATRIX * mat4(
				vec4(normalize(cross(vec3(0.0, 1.0, 0.0), INV_VIEW_MATRIX[2].xyz)), 0.0),
				vec4(0.0, 1.0, 0.0, 0.0),
				vec4(normalize(cross(INV_VIEW_MATRIX[0].xyz, vec3(0.0, 1.0, 0.0))), 0.0),
				MODEL_MATRIX[3]);
	}
	if (billboard_mode == 1 || billboard_mode == 2) {
		MODELVIEW_MATRIX = MODELVIEW_MATRIX * mat4(
				vec4(length(MODEL_MATRIX[0].xyz), 0.0, 0.0, 0.0),
				vec4(0.0, length(MODEL_MATRIX[1].xyz), 0.0, 0.0),
				vec4(0.0, 0.0, length(MODEL_MATRIX[2].xyz), 0.0),
				vec4(0.0, 0.0, 0.0, 1.0));
		MODELVIEW_NORMAL_MATRIX = mat3(MODELVIEW_MATRIX);
	}
#endif
	if (world_uv) {
		vec3 wp = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
		vec3 wn = abs(normalize(mat3(MODEL_MATRIX) * NORMAL));
		if (wn.y >= wn.x && wn.y >= wn.z) {
			UV = wp.xz;
		} else if (wn.x >= wn.z) {
			UV = vec2(wp.z, -wp.y);
		} else {
			UV = vec2(wp.x, -wp.y);
		}
	}
	UV = UV * uv_scale + uv_offset;
	vec4 view = MODELVIEW_MATRIX * vec4(VERTEX, 1.0);
	float dist = length(view.xyz);
#if defined(PSX_XRAY_PASS)
	view.xyz *= max(0.0, 1.0 - PSX_XRAY_BIAS / max(dist, 0.0001));
#endif
	// Along the view ray, so the vertex lands on the same pixel and only its depth moves.
	view.xyz *= 1.0 - depth_lift;
	psx_fog = psx_fog_factor(dist, psx_fog_start, psx_fog_end);
	psx_lod = psx_halve_lod(dist, psx_texture_lod_distance) ? 1 : 0;
	if (psx_beyond_draw_distance(dist, psx_draw_distance)) {
		POSITION = psx_culled_position();
	} else {
		POSITION = psx_snap_clip(PROJECTION_MATRIX * view, psx_snap_resolution);
	}
	psx_w = 1.0;
	if (psx_affine) {
		psx_w = abs(POSITION.w);
		UV *= psx_w;
	}
}

void fragment() {
	vec2 uv = UV / psx_w;
#if defined(PSX_XRAY_PASS)
#if defined(PSX_SPRITE)
	// Sprites keep their cut-out shape.
	if ((albedo_colour * texture(albedo_texture, uv) * COLOR).a < alpha_scissor) {
		discard;
	}
#endif
#if defined(PSX_XRAY)
	if (tk_bayer_threshold(ivec2(floor(FRAGCOORD.xy)), 4) + 0.5 < tk_xray_dither) {
		discard;
	}
	ALBEDO = tk_xray_colour.rgb;
	ALPHA = tk_xray_colour.a;
#else
	ALBEDO = tk_flash_colour.rgb;
	ALPHA = tk_flash;
#endif
#else
	vec4 tex;
#if defined(PSX_CUSTOM_ALBEDO)
	tex = psx_custom_albedo(uv, psx_lod == 1, TIME);
#else
	if (psx_lod == 1) {
		tex = texture(albedo_texture, psx_halve_uv(uv, vec2(textureSize(albedo_texture, 0))));
	} else {
		tex = texture(albedo_texture, uv);
	}
#endif
	vec4 c = albedo_colour * tex * COLOR;
	bool edge = false;
	if (tk_dissolve > 0.0) {
		vec2 texels = dissolve_texels.x > 0.0 ? dissolve_texels : vec2(textureSize(albedo_texture, 0));
		int state = tk_dissolve_state(ivec2(floor(uv * texels)), dissolve_cell, tk_dissolve, dissolve_edge_width);
		if (state == TK_DISSOLVE_GONE) {
#if defined(PSX_SCISSOR)
			c.a = 0.0;
#else
			discard;
#endif
		}
		edge = state == TK_DISSOLVE_EDGE;
	}
	ALBEDO = c.rgb;
	if (edge) {
#if defined(PSX_UNLIT)
		ALBEDO = dissolve_edge_colour.rgb;
#else
		// Unlit, like a glowing rim: no light on it, the colour as emission.
		ALBEDO = vec3(0.0);
		EMISSION = dissolve_edge_colour.rgb;
#endif
	}
#if defined(PSX_SCISSOR)
	ALPHA = c.a;
	ALPHA_SCISSOR_THRESHOLD = alpha_scissor;
#elif defined(PSX_BLEND)
	ALPHA = c.a;
#endif
	FOG = vec4(psx_srgb_to_linear(psx_fog_colour.rgb), psx_fog);
#endif
}
