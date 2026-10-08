// Toolkit look function library. Pure functions, no uniforms, so any shader type can
// include it. The maths matches assets/source/look/fixtures/look_fixtures.py and the
// Unreal TKLook .ush library; the pixel tests hold both engines to the same fixtures.
//
// Colours are 0..1 sRGB values as stored in an 8-bit target. Screen positions are whole
// pixels from the top-left of the internal-resolution image.

#ifndef TK_LOOK_GDSHADERINC
#define TK_LOOK_GDSHADERINC

#include "res://addons/tk_look/generated/look_constants.gdshaderinc"

// Rounds to the nearest 8-bit value. Screen copies can be stored at higher or lower
// precision than the 8-bit target, so post passes snap
// what they read before quantising; otherwise values a hair off k / 255 round the
// wrong way at a step boundary.
vec3 tk_snap8(vec3 c) {
	return floor(c * 255.0 + 0.5) / 255.0;
}

// Ordered dither threshold in (-0.5, 0.5) for pixel p and Bayer size n (2, 4 or 8).
float tk_bayer_threshold(ivec2 p, int n) {
	ivec2 q = p % n;
	int v;
	if (n == 2) {
		v = TK_BAYER2[q.y * 2 + q.x];
	} else if (n == 8) {
		v = TK_BAYER8[q.y * 8 + q.x];
	} else {
		n = 4;
		v = TK_BAYER4[q.y * 4 + q.x];
	}
	return (float(v) + 0.5) / float(n * n) - 0.5;
}

// Rounds each channel to one of `levels` evenly spaced values.
vec3 tk_quantise(vec3 c, float levels) {
	float steps = max(levels - 1.0, 1.0);
	return floor(c * steps + 0.5) / steps;
}

// Quantise with an ordered dither offset of `strength` steps at pixel p.
vec3 tk_dither_quantise(vec3 c, float levels, float strength, ivec2 p, int bayer_size) {
	float steps = max(levels - 1.0, 1.0);
	float t = tk_bayer_threshold(p, bayer_size) * strength;
	return clamp(floor(c * steps + t + 0.5), 0.0, steps) / steps;
}

// Nearest colour in row `row` of a palette strip (one colour per texel), by squared RGB
// distance. Ties go to the lower index. `count` <= 0 uses the strip's width.
vec3 tk_palette_nearest(vec3 c, sampler2D palette, int row, int count) {
	int n = count > 0 ? count : textureSize(palette, 0).x;
	vec3 best = texelFetch(palette, ivec2(0, row), 0).rgb;
	vec3 d0 = c - best;
	float best_d = dot(d0, d0);
	for (int i = 1; i < n; i++) {
		vec3 p = texelFetch(palette, ivec2(i, row), 0).rgb;
		vec3 d = c - p;
		float dd = dot(d, d);
		if (dd < best_d) {
			best_d = dd;
			best = p;
		}
	}
	return best;
}

// Nearest palette colour after an ordered dither offset of `spread` (0..1 units) at p.
vec3 tk_palette_dither(vec3 c, sampler2D palette, float spread, ivec2 p, int bayer_size) {
	return tk_palette_nearest(c + tk_bayer_threshold(p, bayer_size) * spread, palette, 0, 0);
}

// Pixel position of the fragment in a canvas_item screen pass.
ivec2 tk_screen_pixel(vec2 screen_uv, vec2 screen_pixel_size) {
	return ivec2(floor(screen_uv / screen_pixel_size));
}

#endif
