// Blob shadow behind PsxBlobShadow3D: a flat quad (PlaneMesh, UV 0..1 across it)
// drawing a dark disc. Coverage is tk_blob_coverage, the same as the pixel stack's blob,
// drawn by an ordered dither on internal-resolution pixels, so every drawn pixel is the
// shadow colour and the rest are clear. Vertex snap, per-vertex fog and the draw
// distance cull follow the psx_* globals like the PSX surface shaders.
//
// The quad sits a few centimetres above the ground; depth_pull also draws it a share of
// its distance nearer the camera without moving it on screen, so it does not fight the
// ground's depth where vertex snap moves the two apart.
shader_type spatial;
render_mode unshaded, blend_mix, depth_draw_never, cull_disabled, shadows_disabled, fog_disabled;

#include "res://addons/tk_psx/shaders/psx.gdshaderinc"
#include "res://addons/tk_psx/shaders/psx_globals.gdshaderinc"
#include "res://addons/tk_look/shaders/look_shadow.gdshaderinc"
#include "res://addons/tk_look/shaders/look_globals.gdshaderinc"

// sRGB, like the fog colour.
uniform vec4 colour = vec4(0.094, 0.078, 0.145, 1.0);
uniform float opacity : hint_range(0.0, 1.0) = 1.0;
// Share of the radius that fades out.
uniform float edge : hint_range(0.0, 1.0) = 0.35;
uniform float depth_pull : hint_range(0.0, 0.1) = 0.01;

varying float psx_fog;

void vertex() {
	vec4 view = MODELVIEW_MATRIX * vec4(VERTEX, 1.0);
	float dist = length(view.xyz);
	psx_fog = psx_fog_factor(dist, psx_fog_start, psx_fog_end);
	view.xyz *= 1.0 - depth_pull;
	if (psx_beyond_draw_distance(dist, psx_draw_distance)) {
		POSITION = psx_culled_position();
	} else {
		POSITION = psx_snap_clip(PROJECTION_MATRIX * view, psx_snap_resolution);
	}
}

void fragment() {
	float coverage = tk_blob_coverage(UV - 0.5, vec2(0.5), edge, opacity);
	ivec2 p = ivec2(floor(SCREEN_UV * VIEWPORT_SIZE));
	if (tk_shadow_dither(coverage, p, look_bayer_size) <= 0.0) {
		discard;
	}
	vec3 c = mix(colour.rgb, psx_fog_colour.rgb, psx_fog);
	// The Compatibility renderer writes ALBEDO as sRGB; Forward+ and Mobile expect linear.
	ALBEDO = OUTPUT_IS_SRGB ? c : psx_srgb_to_linear(c);
	ALPHA = 1.0;
}
