// PSX sprite shader: lit, scissor, double sided, billboard. Body: psx_body.gdshaderinc.
// Set on a sprite by TKPsx.apply_to_sprite, which keeps albedo_texture on the current frame.
shader_type spatial;

#define PSX_SCISSOR
#define PSX_DOUBLE_SIDED
#define PSX_SPRITE

#include "res://addons/tk_psx/shaders/psx_body.gdshaderinc"
