// Inverted hull outline for meshes. Goes on GeometryInstance3D.material_overlay (or a
// surface material's next_pass). Width is in internal-resolution pixels, so the line
// stays the same thickness at any distance.
shader_type spatial;
render_mode unshaded, cull_front, depth_draw_opaque, fog_disabled;

uniform vec4 outline_colour : source_color = vec4(0.094, 0.078, 0.145, 1.0);
uniform float width_pixels : hint_range(0.0, 8.0) = 1.0;

void vertex() {
	vec4 clip = PROJECTION_MATRIX * MODELVIEW_MATRIX * vec4(VERTEX, 1.0);
	vec3 clip_normal = mat3(PROJECTION_MATRIX) * (MODELVIEW_NORMAL_MATRIX * NORMAL);
	vec2 offset = normalize(clip_normal.xy) / VIEWPORT_SIZE * width_pixels * 2.0 * clip.w;
	clip.xy += offset;
	POSITION = clip;
}

void fragment() {
	ALBEDO = outline_colour.rgb;
}
