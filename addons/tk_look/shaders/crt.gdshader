// CRT display pass: a material for the node that draws the internal-resolution image
// to the screen (a SubViewportContainer or a TextureRect showing the world viewport).
// Unlike the post chain it runs at screen resolution, because a scanline gap and an
// aperture grille are smaller than one game pixel. Parameters: look_crt_* globals.
shader_type canvas_item;
render_mode blend_disabled;

#include "res://addons/tk_look/shaders/crt.gdshaderinc"
#include "res://addons/tk_look/shaders/look_globals.gdshaderinc"

vec3 row_colour(sampler2D tex, vec2 size, float row, float x) {
	row = clamp(row, 0.0, size.y - 1.0);
	// Horizontal: mostly nearest, with a short ramp at texel edges so pixels keep their
	// shape but neighbours bleed a little, as a beam sweeping across would.
	float px = x * size.x - 0.5;
	float left = floor(px);
	float t = smoothstep(0.35, 0.65, px - left);
	vec3 a = texture(tex, (vec2(left, row) + 0.5) / size).rgb;
	vec3 b = texture(tex, (vec2(min(left + 1.0, size.x - 1.0), row) + 0.5) / size).rgb;
	return mix(a, b, t);
}

vec3 crt(sampler2D tex, vec2 uv, vec2 frag) {
	vec2 size = vec2(textureSize(tex, 0));
	vec2 curved = tk_crt_curve(uv, look_crt_curvature);
	if (tk_crt_off_tube(curved)) {
		return vec3(0.0);
	}
	float y = curved.y * size.y - 0.5;
	float row = floor(y);
	float d = y - row;
	vec3 c0 = row_colour(tex, size, row, curved.x);
	vec3 c1 = row_colour(tex, size, row + 1.0, curved.x);
	vec3 nearest = mix(c0, c1, step(0.5, d));
	vec3 beams = tk_crt_beam(c0, d, look_crt_bloom) + tk_crt_beam(c1, 1.0 - d, look_crt_bloom);
	// A gaussian beam of width w averages w * sqrt(2 pi) across a row: about 0.7 for a
	// mid-grey row, so lift to keep brightness.
	vec3 c = mix(nearest, beams * 1.45, look_crt_scanline);
	c *= tk_crt_mask(frag.x, look_crt_mask);
	c *= tk_crt_vignette(curved, look_crt_vignette);
	return clamp(c, 0.0, 1.0);
}

void fragment() {
	COLOR = vec4(crt(TEXTURE, UV, FRAGCOORD.xy), 1.0);
}
