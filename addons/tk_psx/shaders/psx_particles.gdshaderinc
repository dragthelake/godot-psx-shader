// Particle material for the PSX stack: camera-facing squares of whole pixels on the snap
// grid, with PSX per-vertex fog and draw distance, colour quantised to the stack's colour
// depth (or a palette), fade as an ordered dither or in a few alpha steps. Use it through
// PsxParticlesMaterial3D, on CPUParticles3D or GPUParticles3D drawing a QuadMesh.
//
// The particle's centre is projected and its size in pixels worked out from its world
// size (particle scale times world_size), rounded, at least min_pixels. The square is
// then laid on the psx_snap_resolution grid (the viewport's pixels when snapping is off),
// so it is always whole pixels and moves a pixel at a time, like vertex snap.
//
// Particle colours are sRGB, as picked in the inspector. Fog is mixed in sRGB before the
// quantise, so fogged particles stay on the colour grid.
render_mode unshaded, cull_disabled, depth_draw_opaque, shadows_disabled, fog_disabled
#if defined(PSX_PARTICLES_BLEND)
	, blend_mix
#endif
	;

#include "res://addons/tk_look/shaders/look_particles.gdshaderinc"
#include "res://addons/tk_look/shaders/look_globals.gdshaderinc"
#include "res://addons/tk_psx/shaders/psx.gdshaderinc"
#include "res://addons/tk_psx/shaders/psx_globals.gdshaderinc"

// N x 1 palette strip from tk_look/generated/palettes (TKLook.palette).
uniform sampler2D palette : filter_nearest, repeat_disable;
// On: nearest palette colour. Off: each channel quantised to look_colour_levels.
uniform bool use_palette = false;
// TK_FADE_CUT or TK_FADE_DITHER here; TK_FADE_STEPS needs the blend variant.
#if defined(PSX_PARTICLES_BLEND)
uniform int fade_mode : hint_range(0, 2) = 1;
#else
uniform int fade_mode : hint_range(0, 2) = 2;
#endif
uniform int fade_steps : hint_range(1, 8) = 3;
// Particle size in metres at scale 1.
uniform float world_size : hint_range(0.0, 4.0) = 0.1;
// Smallest size in pixels, so far particles do not vanish.
uniform float min_pixels : hint_range(1.0, 8.0) = 1.0;
uniform float max_pixels : hint_range(1.0, 64.0) = 16.0;

varying float psx_fog;

void vertex() {
	// MODEL_MATRIX includes the particle's own transform: its origin is the centre.
	vec4 view = VIEW_MATRIX * vec4(MODEL_MATRIX[3].xyz, 1.0);
	float dist = length(view.xyz);
	psx_fog = psx_fog_factor(dist, psx_fog_start, psx_fog_end);
	vec4 clip = PROJECTION_MATRIX * view;
	if (psx_beyond_draw_distance(dist, psx_draw_distance) || clip.w <= 0.0) {
		POSITION = psx_culled_position();
	} else {
		vec2 res = psx_snap_resolution;
		if (res.x <= 0.0 || res.y <= 0.0) {
			res = VIEWPORT_SIZE;
		}
		float metres = world_size * length(MODEL_MATRIX[0].xyz);
		// abs: the Compatibility renderer flips y in the projection when drawing to a texture.
		float pixels = metres * abs(PROJECTION_MATRIX[1][1]) * 0.5 * res.y / clip.w;
		float size = clamp(floor(pixels + 0.5), min_pixels, max_pixels);
		vec2 centre = (clip.xy / clip.w * 0.5 + 0.5) * res;
		vec2 corner = tk_particle_origin(centre, size) + UV * size;
		POSITION = vec4((corner / res * 2.0 - 1.0) * clip.w, clip.z, clip.w);
	}
}

void fragment() {
	vec3 c = mix(COLOR.rgb, psx_fog_colour.rgb, psx_fog);
	if (use_palette) {
		c = tk_palette_nearest(c, palette, 0, 0);
	} else {
		c = tk_quantise(c, look_colour_levels);
	}
	float a = tk_fade_alpha(COLOR.a, fade_mode, fade_steps, ivec2(floor(FRAGCOORD.xy)), look_bayer_size);
	if (a <= 0.0) {
		discard;
	}
	// Colours are sRGB. The Compatibility renderer writes ALBEDO as sRGB; Forward+ and
	// Mobile expect linear.
	ALBEDO = OUTPUT_IS_SRGB ? c : psx_srgb_to_linear(c);
#if defined(PSX_PARTICLES_BLEND)
	ALPHA = a;
#endif
}
