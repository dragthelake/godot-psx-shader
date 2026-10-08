// PSX function library. Pure functions, no uniforms, so any spatial shader can include
// it. Ported from Ultimate Retro Shader Collection (shaders/ursc/spatial/common.gdshaderinc
// and utilities.gdshaderinc), with the vertex snap reworked to snap to whole pixels of the
// snap grid. See THIRD_PARTY.md.
//
// Copyright (c) 2024-2026 Zorochase. MIT licence.

#ifndef PSX_GDSHADERINC
#define PSX_GDSHADERINC

// Snaps a clip-space position to the pixel grid of a `resolution` image: x and y land
// on pixel corners after the perspective divide. A zero axis turns snapping off.
// Positions behind the camera (w <= 0) are left alone.
vec4 psx_snap_clip(vec4 clip, vec2 resolution) {
	if (resolution.x <= 0.0 || resolution.y <= 0.0 || clip.w <= 0.0) {
		return clip;
	}
	vec2 ndc = clip.xy / clip.w;
	vec2 px = round((ndc * 0.5 + 0.5) * resolution);
	clip.xy = (px / resolution * 2.0 - 1.0) * clip.w;
	return clip;
}

// Per-vertex fog amount: 0 at `start`, 1 at `end` and beyond. Off (0) when end is not
// above start.
float psx_fog_factor(float distance, float start, float end) {
	if (end <= start) {
		return 0.0;
	}
	return clamp((distance - start) / (end - start), 0.0, 1.0);
}

// True when a vertex at `distance` is beyond the draw distance. 0 draws everything.
bool psx_beyond_draw_distance(float distance, float draw_distance) {
	return draw_distance > 0.0 && distance > draw_distance;
}

// A NaN clip position. A triangle with any NaN vertex is dropped by the rasteriser, so
// a triangle with any vertex beyond the draw distance is not drawn at all.
vec4 psx_culled_position() {
	return vec4(intBitsToFloat(0x7fc00000));
}

// True when a vertex at `distance` samples its texture at half resolution. 0 is off.
bool psx_halve_lod(float distance, float lod_distance) {
	return lod_distance > 0.0 && distance > lod_distance;
}

// UV that samples a nearest-filtered texture of `size` texels at half resolution: every
// 2x2 block of texels shows its top-left texel. Samples that texel's centre, so the
// result does not depend on how the sampler rounds at a texel edge.
vec2 psx_halve_uv(vec2 uv, vec2 size) {
	vec2 half_size = max(floor(size * 0.5), vec2(1.0));
	return (floor(uv * half_size) * 2.0 + 0.5) / size;
}

// https://gamedev.stackexchange.com/a/194038
vec3 psx_srgb_to_linear(vec3 c) {
	bvec3 cutoff = lessThan(c, vec3(0.04045));
	vec3 higher = pow((c + vec3(0.055)) / vec3(1.055), vec3(2.4));
	vec3 lower = c / vec3(12.92);
	return mix(higher, lower, cutoff);
}

#endif
