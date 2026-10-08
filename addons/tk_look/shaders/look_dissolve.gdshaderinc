// Sprite and surface dissolve, shared by the pixel sprite shader and the PSX surface
// body. Pure functions, no uniforms. The maths matches
// assets/source/look/fixtures/look_fixtures.py (dissolve_* fixtures): integer hashing
// and integer value noise, so both engines give the same level for every texel.
//
// A dissolve works on whole texels of the sprite or surface texture, not on screen
// pixels, so the pattern sticks to the thing as it moves. Each texel has a threshold in
// (0, 1); at dissolve amount a, texels below a are gone, so 0 shows everything and 1
// nothing.

#ifndef TK_LOOK_DISSOLVE_GDSHADERINC
#define TK_LOOK_DISSOLVE_GDSHADERINC

#include "res://addons/tk_look/shaders/look.gdshaderinc"

// tk_dissolve_state results.
const int TK_DISSOLVE_GONE = 0;
const int TK_DISSOLVE_EDGE = 1;
const int TK_DISSOLVE_KEPT = 2;

// 32-bit integer hash (lowbias32, Chris Wellons, public domain).
uint tk_hash_u32(uint x) {
	x ^= x >> 16u;
	x *= 0x7feb352du;
	x ^= x >> 15u;
	x *= 0x846ca68bu;
	x ^= x >> 16u;
	return x;
}

// 0..255 hash of a texel or lattice point. Negative coordinates hash by their bit pattern.
int tk_hash8(ivec2 p, uint salt) {
	return int(tk_hash_u32(uint(p.x) + tk_hash_u32(uint(p.y) + salt)) >> 24u);
}

// Floor division for a positive divisor (GLSL rounds negative quotients towards zero).
int tk_floor_div(int a, int b) {
	return a >= 0 ? a / b : -((b - 1 - a) / b);
}

// Dissolve level 0..255 of a texel. `cell` picks the pattern:
//   0   ordered: 8x8 Bayer, a regular screen-door dissolve
//   1   hashed: each texel on its own, salt and pepper
//   2+  value noise with lattice points every `cell` texels plus a texel hash, so holes
//       open in blobs about `cell` texels across with a rough fringe
int tk_dissolve_level(ivec2 t, int cell) {
	if (cell <= 0) {
		ivec2 q = t & ivec2(7);
		return TK_BAYER8[q.y * 8 + q.x] * 4 + 2;
	}
	int h = tk_hash8(t, 0u);
	if (cell == 1) {
		return h;
	}
	ivec2 c = ivec2(tk_floor_div(t.x, cell), tk_floor_div(t.y, cell));
	ivec2 f = t - c * cell;
	uint salt = 0x9e3779b9u;
	int a = tk_hash8(c, salt);
	int b = tk_hash8(c + ivec2(1, 0), salt);
	int d = tk_hash8(c + ivec2(0, 1), salt);
	int e = tk_hash8(c + ivec2(1, 1), salt);
	// Bilinear weights at the texel centre, in units of 1 / (2 cell).
	int s = 2 * cell;
	int wx = 2 * f.x + 1;
	int wy = 2 * f.y + 1;
	int n = (a * (s - wx) * (s - wy) + b * wx * (s - wy) + d * (s - wx) * wy + e * wx * wy) / (s * s);
	int v = (7 * n + h) / 8;
	// Stretch by 2 about 128: averaging pulls levels to the middle.
	return clamp(2 * v - 128, 0, 255);
}

// Threshold in (0, 1) of a texel: the texel is gone once the dissolve amount passes it.
float tk_dissolve_threshold(ivec2 t, int cell) {
	return (float(tk_dissolve_level(t, cell)) + 0.5) / 256.0;
}

// Whether texel t is gone, an edge (kept, with a gone texel at most `edge` steps away
// along x and y: |dx| + |dy| <= edge) or kept, at dissolve `amount`.
int tk_dissolve_state(ivec2 t, int cell, float amount, int edge) {
	if (tk_dissolve_threshold(t, cell) < amount) {
		return TK_DISSOLVE_GONE;
	}
	if (amount > 0.0) {
		for (int y = -edge; y <= edge; y++) {
			for (int x = -edge; x <= edge; x++) {
				if (abs(x) + abs(y) <= edge && tk_dissolve_threshold(t + ivec2(x, y), cell) < amount) {
					return TK_DISSOLVE_EDGE;
				}
			}
		}
	}
	return TK_DISSOLVE_KEPT;
}

#endif
