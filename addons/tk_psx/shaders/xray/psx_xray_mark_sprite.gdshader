// PSX x-ray, first pass, for sprites: as psx_xray_mark.gdshader, billboarded and cut out
// like the PSX sprite shaders. TKPsx.set_xray chains it after the sprite's material.
shader_type spatial;

#define PSX_XRAY_MARK
#define PSX_SCISSOR
#define PSX_DOUBLE_SIDED
#define PSX_SPRITE

#include "res://addons/tk_psx/shaders/psx_body.gdshaderinc"
