// Drop shadow functions shared by the pixel (canvas_item) and PSX (spatial) shadow
// shaders. Pure functions, no uniforms. Includes the look library. The maths matches
// blob() and shadow() in assets/source/look/fixtures/look_fixtures.py.

#include "res://addons/tk_look/shaders/look.gdshaderinc"

// Coverage of a blob shadow at `offset` from the centre of an ellipse of half-size
// `radii`: `opacity` inside, falling linearly to 0 over the outer `edge` share of the
// radius (0 is a hard rim), 0 on and outside the rim.
float tk_blob_coverage(vec2 offset, vec2 radii, float edge, float opacity) {
	float r = length(offset / radii);
	if (r >= 1.0) {
		return 0.0;
	}
	float fall = edge > 0.0 ? clamp((1.0 - r) / edge, 0.0, 1.0) : 1.0;
	return opacity * fall;
}

// 0 or 1: whether pixel p of a shadow with `coverage` is drawn, by an ordered dither, so
// the shadow is one solid colour with holes instead of a blend. Coverage 1 draws every
// pixel and 0 none.
float tk_shadow_dither(float coverage, ivec2 p, int bayer_size) {
	if (coverage <= 0.0) {
		return 0.0;
	}
	return step(0.5, coverage + tk_bayer_threshold(p, bayer_size));
}
