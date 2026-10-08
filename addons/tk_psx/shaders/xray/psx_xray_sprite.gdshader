// PSX x-ray, second pass, for sprites: as psx_xray.gdshader, billboarded and cut out.
shader_type spatial;

#define PSX_XRAY
#define PSX_SCISSOR
#define PSX_DOUBLE_SIDED
#define PSX_SPRITE

#include "res://addons/tk_psx/shaders/psx_body.gdshaderinc"
