// Styled particle functions shared by the pixel (canvas_item) and PSX (spatial) particle
// shaders. Pure functions, no uniforms. Includes the look library.

#include "res://addons/tk_look/shaders/look.gdshaderinc"

// Fade modes, matching PixelParticlesMaterial2D.Fade and PsxParticlesMaterial3D.Fade.
const int TK_FADE_CUT = 0;
const int TK_FADE_STEPS = 1;
const int TK_FADE_DITHER = 2;

// Integer hash to 0..1, so a particle's random size comes from its instance index and
// is the same on every run and every GPU.
float tk_hash01(uint n) {
	n = (n << 13u) ^ n;
	n = n * (n * n * 15731u + 789221u) + 1376312589u;
	return float(n & 0x7fffffffu) / 2147483647.0;
}

// Whole-pixel particle size. `base` plus 0 to `variation` pixels picked by `id`, scaled
// from 1 at birth to `end_scale` at death by `life` (0..1), rounded, at least 1.
float tk_particle_pixels(int base, int variation, float end_scale, int id, float life) {
	float size = float(base + int(floor(tk_hash01(uint(id)) * float(variation + 1))));
	size = min(size, float(base + variation));
	return max(1.0, floor(size * mix(1.0, end_scale, clamp(life, 0.0, 1.0)) + 0.5));
}

// Lower-left (or top-left) pixel corner of a square of `size` pixels centred on `centre`,
// in pixel coordinates. Whole pixels, so the square moves a pixel at a time.
vec2 tk_particle_origin(vec2 centre, float size) {
	return floor(centre - size * 0.5 + 0.5);
}

// Alpha after the fade: TK_FADE_CUT cuts at 0.5, TK_FADE_STEPS rounds up to one of
// `steps` levels, TK_FADE_DITHER gives 0 or 1 by an ordered dither at pixel p.
float tk_fade_alpha(float a, int mode, int steps, ivec2 p, int bayer_size) {
	a = clamp(a, 0.0, 1.0);
	if (mode == TK_FADE_STEPS) {
		float n = float(max(steps, 1));
		return ceil(a * n - 0.001) / n;
	} else if (mode == TK_FADE_DITHER) {
		return step(0.5, a + tk_bayer_threshold(p, bayer_size));
	}
	return step(0.5, a);
}
