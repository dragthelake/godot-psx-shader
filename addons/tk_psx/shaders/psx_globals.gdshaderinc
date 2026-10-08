// Stack-wide PSX parameters, set through RenderingServer.global_shader_parameter_set
// (TKLook.set_param or TKPsx). Declared in each project's [shader_globals] by
// scripts/export look, and registered at startup by the TKLook autoload when a project
// lacks them. Defaults and docs: assets/source/look/look.json.

#ifndef PSX_GLOBALS_GDSHADERINC
#define PSX_GLOBALS_GDSHADERINC

global uniform vec2 psx_snap_resolution;
global uniform bool psx_affine;
global uniform vec4 psx_fog_colour : source_color;
global uniform float psx_fog_start;
global uniform float psx_fog_end;
global uniform float psx_draw_distance;
global uniform float psx_texture_lod_distance;

#endif
