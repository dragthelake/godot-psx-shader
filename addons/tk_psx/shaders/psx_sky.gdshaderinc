// PSX sky functions. Pure functions, no uniforms. The gradient and its banding match
// assets/source/look/fixtures/look_fixtures.py (sky fixtures); the pixel tests hold the
// engines to the same values.
//
// Elevation is the sine of the view elevation: the y of the unit view direction, from -1
// (straight down) through 0 (the horizon) to 1 (straight up). Colours are 0..1 sRGB.

#ifndef PSX_SKY_GDSHADERINC
#define PSX_SKY_GDSHADERINC

#include "res://addons/tk_look/shaders/look.gdshaderinc"

// How far a gradient has moved from the horizon colour towards the far colour, 0..1, at
// `d` past the horizon over a span of `span`: 1 - (1 - d / span) ^ sharpness. Sharpness
// 1 is linear; higher keeps the horizon colour in a thinner band.
float psx_sky_weight(float d, float span, float sharpness) {
	float t = clamp(d / max(span, 1e-4), 0.0, 1.0);
	return 1.0 - pow(1.0 - t, max(sharpness, 1e-3));
}

// The sky gradient at `elevation`. The horizon sits at `horizon_height` (same units);
// above it the colour runs from `horizon` to `zenith` at elevation 1, below it from
// `horizon` to `ground` at elevation -1.
vec3 psx_sky_gradient(float elevation, vec3 zenith, vec3 horizon, vec3 ground, float horizon_height, float sharpness) {
	float d = elevation - horizon_height;
	if (d >= 0.0) {
		return mix(horizon, zenith, psx_sky_weight(d, 1.0 - horizon_height, sharpness));
	}
	return mix(horizon, ground, psx_sky_weight(-d, 1.0 + horizon_height, sharpness));
}

// A sky colour quantised to `levels` per channel with an ordered dither of `strength`
// steps at screen pixel p, exactly as the tk_look quantise pass would draw it: snapped
// to 8 bits first (what the pass reads from an 8-bit target), and the result snapped to
// 8 bits so the 3D target stores it unchanged.
vec3 psx_sky_band(vec3 c, float levels, float strength, ivec2 p, int bayer_size) {
	return tk_snap8(tk_dither_quantise(tk_snap8(c), levels, strength, p, bayer_size));
}

// psx_sky_band of the gradient at `elevation`.
vec3 psx_sky_banded(float elevation, vec3 zenith, vec3 horizon, vec3 ground, float horizon_height, float sharpness, float levels, float strength, ivec2 p, int bayer_size) {
	return psx_sky_band(psx_sky_gradient(elevation, zenith, horizon, ground, horizon_height, sharpness), levels, strength, p, bayer_size);
}

// Azimuth of a view direction as 0..1 around the horizon: 0 and 1 face -z (Godot's
// forward), 0.25 faces +x.
float psx_sky_azimuth(vec3 dir) {
	return fract(atan(dir.x, -dir.z) / 6.28318530718 + 1.0);
}

// The texel of a `size` texture wrapped `repeats` times around the horizon, for a
// direction at azimuth `u` (0..1) and row position `v` (0 bottom, 1 top), moved `scroll`
// whole texels along the azimuth. Whole texels only, so nothing is filtered.
ivec2 psx_sky_texel(float u, float v, ivec2 size, float repeats, float scroll) {
	int x = int(floor(u * float(size.x) * repeats + scroll));
	int y = int(floor((1.0 - clamp(v, 0.0, 0.9999)) * float(size.y)));
	return ivec2(((x % size.x) + size.x) % size.x, y);
}

#endif
