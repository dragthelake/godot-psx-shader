// PSX x-ray, first pass, for meshes: marks the stencil where the mesh is visible and
// draws the tk_flash hit flash there. Body: psx_body.gdshaderinc. TKPsx.set_xray puts
// it on material_overlay, with psx_xray.gdshader as its next pass.
shader_type spatial;

#define PSX_XRAY_MARK

#include "res://addons/tk_psx/shaders/psx_body.gdshaderinc"
