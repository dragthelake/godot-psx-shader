// PSX water: the PSX surface body (psx_body.gdshaderinc) with its two hooks filled in.
// Each file in water/ is `shader_type spatial;`, optionally PSX_UNLIT, and an include of
// this file, which turns on PSX_BLEND. Use it through PsxWaterMaterial3D or PsxWater3D.
//
// - Vertex waves: two sines in world space lift each vertex before the body snaps it,
//   fogs it and culls it at the draw distance. Normals follow the slope, so the
//   per-vertex lighting rolls with the waves. Crests brighten through the vertex colour.
// - Texture: the albedo texture mapped in world space (world x and z over texture_size
//   metres), in two layers that scroll different ways and are averaged. The body's
//   affine mapping and texture LOD apply to both.
//
// The scrolling UV follows Ultimate Retro Shader Collection's uv_scroll_speed (UV plus
// speed times time); see THIRD_PARTY.md. The rest is written for the toolkit.

#include "res://addons/tk_psx/shaders/psx.gdshaderinc"
#include "res://addons/tk_psx/shaders/psx_globals.gdshaderinc"

#define PSX_BLEND
#define PSX_CUSTOM_VERTEX
#define PSX_CUSTOM_ALBEDO

#include "res://addons/tk_psx/shaders/psx_body_uniforms.gdshaderinc"

// Negative runs on the engine clock; 0 or more freezes the water at that time.
uniform float time_override = -1.0;
// Largest rise or fall of the surface, in metres.
uniform float wave_height = 0.15;
// Length of the longer wave, in metres.
uniform float wave_length = 6.0;
uniform float wave_speed = 1.0;
// Direction of the longer wave across the water (x, z).
uniform vec2 wave_direction = vec2(1.0, 0.35);
// Metres covered by one repeat of the texture.
uniform float texture_size = 4.0;
// Scroll of each texture layer, in texture repeats per second.
uniform vec2 scroll_a = vec2(0.03, 0.012);
uniform vec2 scroll_b = vec2(-0.018, 0.026);
// Repeats of layer b per repeat of layer a; layer b is also turned about 37 degrees.
uniform float layer_b_scale = 1.37;
// Extra brightness at the top of a crest, through the vertex colour.
uniform float crest_brightness = 0.35;

float psx_water_time(float engine_time) {
	return time_override >= 0.0 ? time_override : engine_time;
}

// Height of the surface above its rest plane at world (x, z). PsxWaterMaterial3D.height
// matches it.
float psx_water_height(vec2 xz, float t) {
	vec2 d1 = normalize(wave_direction);
	vec2 d2 = vec2(-d1.y, d1.x) * 0.6 + d1 * 0.8;
	float k1 = TAU / max(wave_length, 0.01);
	float k2 = k1 * 1.9;
	return wave_height * (0.65 * sin(dot(d1, xz) * k1 - t * wave_speed * 1.7)
			+ 0.35 * sin(dot(d2, xz) * k2 - t * wave_speed * 2.6 + 1.3));
}

// Gradient of psx_water_height: (d/dx, d/dz).
vec2 psx_water_slope(vec2 xz, float t) {
	vec2 d1 = normalize(wave_direction);
	vec2 d2 = vec2(-d1.y, d1.x) * 0.6 + d1 * 0.8;
	float k1 = TAU / max(wave_length, 0.01);
	float k2 = k1 * 1.9;
	return wave_height * (0.65 * k1 * cos(dot(d1, xz) * k1 - t * wave_speed * 1.7) * d1
			+ 0.35 * k2 * cos(dot(d2, xz) * k2 - t * wave_speed * 2.6 + 1.3) * d2);
}

void psx_custom_vertex(inout vec3 vertex, inout vec3 normal, inout vec2 uv, inout vec4 colour, mat4 model, float engine_time) {
	float t = psx_water_time(engine_time);
	vec3 world = (model * vec4(vertex, 1.0)).xyz;
	float h = psx_water_height(world.xz, t);
	mat3 basis = mat3(model);
	vertex += inverse(basis) * vec3(0.0, h, 0.0);
	vec2 s = psx_water_slope(world.xz, t);
	// A world normal goes back to local space through the transpose of the basis.
	normal = normalize(transpose(basis) * normalize(vec3(-s.x, 1.0, -s.y)));
	uv = world.xz / max(texture_size, 0.01);
	float crest = clamp(h / max(wave_height, 0.0001), 0.0, 1.0);
	colour = vec4(vec3(1.0 + crest * crest * crest_brightness), 1.0);
}

vec4 psx_custom_albedo(vec2 uv, bool half_lod, float engine_time) {
	float t = psx_water_time(engine_time);
	vec2 a = uv + scroll_a * t;
	vec2 b = mat2(vec2(0.8, 0.6), vec2(-0.6, 0.8)) * uv * layer_b_scale + scroll_b * t;
	if (half_lod) {
		vec2 size = vec2(textureSize(albedo_texture, 0));
		a = psx_halve_uv(a, size);
		b = psx_halve_uv(b, size);
	}
	return (texture(albedo_texture, a) + texture(albedo_texture, b)) * 0.5;
}

#include "res://addons/tk_psx/shaders/psx_body.gdshaderinc"
