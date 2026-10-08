// Post pass: quantise to look_colour_levels per channel with ordered dither.
// With 32 levels this is the PSX 15-bit look.
shader_type canvas_item;
render_mode blend_disabled;

#include "res://addons/tk_look/shaders/look.gdshaderinc"
#include "res://addons/tk_look/shaders/look_globals.gdshaderinc"

uniform sampler2D screen_texture : hint_screen_texture, filter_nearest;

void fragment() {
	vec3 c = tk_snap8(texture(screen_texture, SCREEN_UV).rgb);
	ivec2 p = tk_screen_pixel(SCREEN_UV, SCREEN_PIXEL_SIZE);
	COLOR = vec4(tk_dither_quantise(c, look_colour_levels, look_dither_strength, p, look_bayer_size), 1.0);
}
