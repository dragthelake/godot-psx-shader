// Stack-wide look parameters, set through RenderingServer.global_shader_parameter_set.
// Declared in each project's [shader_globals] by scripts/export look, and registered at
// startup by the TKLook autoload when a project lacks them. Defaults: look.json.

global uniform float look_colour_levels;
global uniform float look_dither_strength;
global uniform int look_bayer_size;
global uniform float look_crt_curvature;
global uniform float look_crt_scanline;
global uniform float look_crt_mask;
global uniform float look_crt_bloom;
global uniform float look_crt_vignette;
