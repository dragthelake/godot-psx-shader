// PSX sky: a vertical gradient (or a low-resolution panorama) that meets psx_fog_colour at
// the horizon, an optional sun disc and an optional band of whole-texel clouds, quantised
// to the stack's colour depth with an ordered dither in screen space, like the tk_look
// quantise pass. Use it through PsxSkyMaterial and TKPsx.make_sky or TKPsx.apply_sky.
//
// Colours are sRGB, as picked in the inspector. The Compatibility renderer writes the sky
// colour as sRGB, which is what this shader is written and tested for.
shader_type sky;

#include "res://addons/tk_look/shaders/look_globals.gdshaderinc"
#include "res://addons/tk_psx/shaders/psx_globals.gdshaderinc"
#include "res://addons/tk_psx/shaders/psx_sky.gdshaderinc"

// 0: gradient. 1: panorama above the horizon.
uniform int sky_mode : hint_range(0, 1) = 0;
uniform vec4 zenith_colour = vec4(0.149, 0.169, 0.267, 1.0);
uniform vec4 horizon_colour = vec4(0.227, 0.267, 0.4, 1.0);
uniform vec4 ground_colour = vec4(0.227, 0.267, 0.4, 1.0);
// On: the horizon (and the ground, with ground_follows_fog) is psx_fog_colour, so fully
// fogged geometry meets the sky with no seam.
uniform bool horizon_follows_fog = true;
uniform bool ground_follows_fog = true;
uniform float horizon_height : hint_range(-0.5, 0.5) = 0.0;
uniform float sharpness : hint_range(0.25, 16.0) = 2.0;

// Quantise to band_levels per channel (0: look_colour_levels), dithered by
// look_dither_strength when dither is on.
uniform bool banding = true;
uniform float band_levels : hint_range(0.0, 256.0) = 0.0;
uniform bool dither = true;

uniform bool sun_enabled = false;
// Towards the sun. Ignored when sun_follows_light and a DirectionalLight3D is on.
uniform vec3 sun_direction = vec3(0.0, 0.5, -1.0);
uniform bool sun_follows_light = false;
// Angular radius in degrees.
uniform float sun_size : hint_range(0.0, 30.0) = 3.0;
uniform vec4 sun_colour = vec4(1.0, 0.933, 0.737, 1.0);
// A ring as wide as the disc around it, this far towards sun_colour.
uniform float sun_halo : hint_range(0.0, 1.0) = 0.25;

uniform bool clouds_enabled = false;
// Opaque texels (alpha 0.5 and up) are cloud, tinted by cloud_colour. Bottom row at
// cloud_low, top row at cloud_high.
uniform sampler2D cloud_texture : filter_nearest, repeat_enable;
uniform vec4 cloud_colour = vec4(1.0);
uniform float cloud_low : hint_range(-0.5, 1.0) = 0.06;
uniform float cloud_high : hint_range(-0.5, 1.0) = 0.3;
// Times the texture wraps around the horizon.
uniform float cloud_repeats : hint_range(1.0, 16.0) = 3.0;
// Texels per second along the horizon, in whole-texel steps.
uniform float cloud_speed : hint_range(-32.0, 32.0) = 2.0;

// Covers the horizon (bottom row) to the zenith (top row) all around, sampled nearest on
// a panorama_resolution grid (0: the texture's own size).
uniform sampler2D panorama : filter_nearest, repeat_enable;
uniform ivec2 panorama_resolution = ivec2(0);
// Elevation over which the panorama fades in from the horizon colour. 0 is a hard edge.
uniform float panorama_fade : hint_range(0.0, 0.5) = 0.08;
// Below the horizon in panorama mode. 0: the ground gradient. 1: the panorama mirrored.
uniform int panorama_below : hint_range(0, 1) = 0;

// 0 or more freezes cloud scrolling at that time; negative follows TIME.
uniform float time_override = -1.0;

vec3 panorama_at(float u, float elevation_angle, float horizon_angle) {
	ivec2 tex_size = textureSize(panorama, 0);
	ivec2 grid = panorama_resolution.x > 0 && panorama_resolution.y > 0 ? panorama_resolution : tex_size;
	float v = (elevation_angle - horizon_angle) / max(1.5707963 - horizon_angle, 1e-3);
	ivec2 cell = psx_sky_texel(u, v, grid, 1.0, 0.0);
	ivec2 texel = (cell * tex_size) / grid;
	return texelFetch(panorama, texel, 0).rgb;
}

void sky() {
	vec3 dir = normalize(EYEDIR);
	float e = dir.y;
	vec3 horizon = horizon_follows_fog ? psx_fog_colour.rgb : horizon_colour.rgb;
	vec3 ground = ground_follows_fog ? psx_fog_colour.rgb : ground_colour.rgb;
	vec3 c = psx_sky_gradient(e, zenith_colour.rgb, horizon, ground, horizon_height, sharpness);
	float d = e - horizon_height;
	float u = psx_sky_azimuth(dir);

	if (sky_mode == 1) {
		float a = asin(clamp(e, -1.0, 1.0));
		float ah = asin(clamp(horizon_height, -0.99, 0.99));
		float fade = panorama_fade > 0.0 ? clamp(abs(d) / panorama_fade, 0.0, 1.0) : 1.0;
		if (d >= 0.0) {
			c = mix(horizon, panorama_at(u, a, ah), fade);
		} else if (panorama_below == 1) {
			c = mix(horizon, panorama_at(u, 2.0 * ah - a, ah), fade);
		}
	}

	if (sun_enabled) {
		vec3 to_sun = sun_follows_light && LIGHT0_ENABLED ? LIGHT0_DIRECTION : sun_direction;
		float cos_angle = dot(dir, normalize(to_sun));
		float r = radians(sun_size);
		if (cos_angle >= cos(r)) {
			c = sun_colour.rgb;
		} else if (cos_angle >= cos(2.0 * r)) {
			c = mix(c, sun_colour.rgb, sun_halo);
		}
	}

	if (clouds_enabled && e >= cloud_low && e < cloud_high) {
		float t = time_override >= 0.0 ? time_override : TIME;
		float v = (e - cloud_low) / max(cloud_high - cloud_low, 1e-4);
		ivec2 size = textureSize(cloud_texture, 0);
		vec4 cloud = texelFetch(cloud_texture, psx_sky_texel(u, v, size, cloud_repeats, floor(t * cloud_speed)), 0);
		if (cloud.a >= 0.5) {
			c = cloud.rgb * cloud_colour.rgb;
		}
	}

	// The radiance cubemap gets the smooth colour; only the screen is banded. Unbanded,
	// the colour is still snapped to 8 bits: the 3D target stores 8-bit values exactly but
	// can round others the other way, which would move them across a quantise step.
	if (AT_CUBEMAP_PASS) {
		COLOR = c;
	} else if (banding) {
		float levels = band_levels > 0.0 ? band_levels : look_colour_levels;
		float strength = dither ? look_dither_strength : 0.0;
		COLOR = psx_sky_band(c, levels, strength, ivec2(floor(FRAGCOORD.xy)), look_bayer_size);
	} else {
		COLOR = tk_snap8(c);
	}
}
