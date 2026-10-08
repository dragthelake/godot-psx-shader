// Screen transitions. Ported from Universal Transition Shader by cashew-olddew,
// https://github.com/cashew-olddew/Universal-Transition-Shader, CC0 1.0.
// Toolkit changes, marked "game-toolkit": transition types 4 (Dissolve) and 5 (Wipe),
// aspect, which keeps Shape and Clock round on a wide screen, and pixel_grid, which
// snaps UV to the internal-resolution pixel grid so edges stay pixel-sized at any
// window size. TKLook.transition_out and transition_in drive it.
shader_type canvas_item;

uniform bool use_sprite_alpha = true;
uniform bool use_transition_texture = false;
uniform sampler2D transition_texture;
uniform int transition_type: hint_enum("Basic", "Mask", "Shape", "Clock", "Dissolve", "Wipe") = 0;
// game-toolkit: internal-resolution size of the covered area; 0 leaves UV unsnapped.
uniform vec2 pixel_grid = vec2(0.0);
// game-toolkit: width over height of the covered area, so Shape and Clock stay round.
uniform float aspect = 1.0;

group_uniforms positioning;
uniform vec2 position = vec2(0,0);
uniform bool invert = false;
uniform vec2 grid_size = vec2(1.0, 1.0);
uniform float rotation_angle = 0.0;

group_uniforms positioning.mirror;
uniform bool global_x_mirror = false;
uniform bool global_y_mirror = false;
uniform bool local_x_mirror = false;
uniform bool local_y_mirror = false;

group_uniforms positioning.stagger;
uniform vec2 stagger = vec2(0.0, 0.0);
uniform bool cumulative_stagger_flip = false;
uniform vec2 cumulative_stagger = vec2(0, 0);
uniform ivec2 stagger_frequency = ivec2(2, 2);
uniform ivec2 flip_frequency = ivec2(1, 1);

group_uniforms basic_transition_controls;
uniform float basic_feather = 0.0;

group_uniforms mask_transition_controls;
uniform sampler2D mask_texture;
uniform bool use_mask_size = false;
uniform vec2 mask_size = vec2(100.0);

group_uniforms shape_transition_controls;
uniform int edges : hint_range(3, 64) = 6; // default hexagon
uniform float shape_feather : hint_range(0.0, 10.0) = 0.1;

group_uniforms clock_transition_controls;
uniform int sectors : hint_range(1, 128) = 1;
uniform float clock_feather : hint_range(0.0, 16.0) = 0.0;

group_uniforms animation;
uniform float progress = 0.0;
uniform vec2 progress_bias = vec2(0.0);

varying vec4 modulate;

vec2 use_actual_texture_size(vec2 uv, vec2 texture_size, vec2 raw_uv_deriv) {
	uv -= 0.5;
	float screen_ratio = raw_uv_deriv.x / raw_uv_deriv.y;
	float texture_ratio = texture_size.x / texture_size.y;
	float mixed_ratio = texture_ratio * screen_ratio;

	if (screen_ratio > texture_ratio) {
		uv.x /= mixed_ratio;
	} else {
		uv.y *= mixed_ratio;
	}

	return uv + 0.5;
}

vec2 get_stagger_offset(vec2 grid) {
	vec2 cells = floor(grid);
	float offset_row = mod(cells.y, float(stagger_frequency.x)) == 0.0 ? 0.5 : 0.0;
	float offset_col = mod(cells.x, float(stagger_frequency.y)) == 0.0 ? 0.5 : 0.0;

	float row_index = cumulative_stagger_flip ? (grid_size.y - 1.0 - cells.y) : cells.y;
	float col_index = cumulative_stagger_flip ? (grid_size.x - 1.0 - cells.x) : cells.x;

	return vec2(
		offset_row * (stagger.x + row_index * cumulative_stagger.x),
		offset_col * (stagger.y + col_index * cumulative_stagger.y)
	);
}

vec2 get_grid_flip(vec2 grid) {
	vec2 cells = floor(grid);
	float flip_row = mod(cells.y, float(flip_frequency.x)) == 0.0 ? 1.0 : -1.0;
	float flip_col = mod(cells.x, float(flip_frequency.y)) == 0.0 ? 1.0 : -1.0;

	return vec2(
		flip_row * grid.x,
		flip_col * grid.y
	);
}

vec2 rotate(vec2 v, float angle) {
	return mat2(
		vec2(cos(angle), sin(angle)),
		vec2(-sin(angle), cos(angle))
		) * v;
}

vec2 get_edges(float center, float width) {
	float half_width = width * 0.5;
	float edge0 = center - half_width;
	float edge1 = center + half_width + 1e-5;
	return vec2(edge0, edge1);
}

float get_local_progress(vec2 grid) {
    vec2 cell = floor(grid);
	// Easier to control bias values
	vec2 pretty_bias = progress_bias / 10.0;
    float offset = dot(cell, pretty_bias);
    return progress - offset;
}

vec2 apply_mirror(vec2 uv, bool mirror_x, bool mirror_y) {
    vec2 mirrored = 0.5 - abs(uv - 0.5);
    vec2 toggle = vec2(float(mirror_x), float(mirror_y));
    return mix(uv, mirrored, toggle);
}

void vertex() {
	modulate = COLOR;
}

// game-toolkit: stable per-cell noise for the dissolve.
float cell_hash(vec2 cell) {
	vec3 p = fract(vec3(cell.xyx) * 0.1031);
	p += dot(p, p.yzx + 33.33);
	return fract((p.x + p.y) * p.z);
}

void fragment() {
	// game-toolkit: snap to the pixel grid, sampling at pixel centres.
	vec2 base_uv = UV;
	if (pixel_grid.x > 0.0 && pixel_grid.y > 0.0) {
		base_uv = (floor(UV * pixel_grid) + 0.5) / pixel_grid;
	}
	vec2 uv_deriv = fwidth(base_uv); // derivate used for keeping mask texture size regardless of sprite ratio

	vec2 mirrored_uv = apply_mirror(base_uv, global_x_mirror, global_y_mirror);

	vec2 grid = mirrored_uv * grid_size;
	vec2 offset_uv = grid + get_stagger_offset(grid);
	vec2 grid_flipped_uv = get_grid_flip(offset_uv);
	vec2 tiled_uv = fract(grid_flipped_uv);

	tiled_uv = apply_mirror(tiled_uv, local_x_mirror, local_y_mirror);

	vec2 uv = (tiled_uv - position) * 2.0;
	uv = rotate(uv, radians(rotation_angle));

	float local_progress = get_local_progress(grid);

	COLOR = texture(TEXTURE, base_uv) * modulate;
	float alpha = COLOR.a;
	float transition_progress = 0.0;

	// game-toolkit: aspect-corrected before rotating, so shapes stay regular.
	vec2 round_uv = rotate(vec2((tiled_uv.x - position.x) * aspect, tiled_uv.y - position.y) * 2.0, radians(rotation_angle));

	if (transition_type == 1) {
		vec2 mask_zoom_uv = uv / local_progress;
		vec2 mask_zoom_uv_01 = mask_zoom_uv * 0.5 + 0.5;
		mask_zoom_uv_01 = use_mask_size ? use_actual_texture_size(mask_zoom_uv_01, mask_size, uv_deriv) : mask_zoom_uv_01;

		transition_progress = texture(mask_texture, mask_zoom_uv_01).r;

	} else if(transition_type == 2) {
    	float radius = length(round_uv);
	    float angle = atan(round_uv.y, round_uv.x);
		float sector_angle = 2.0 * PI / float(edges);
		float half_sector = sector_angle / 2.0;
		// Define polygon sectors using the power of trigonometry
		float d = cos(half_sector) / cos(mod(angle + half_sector, sector_angle) - half_sector);

		vec2 smooth_edges = get_edges(local_progress, shape_feather);
		transition_progress = smoothstep(smooth_edges.x, smooth_edges.y, radius / d);

	} else if (transition_type == 3) {
		float radius = length(round_uv);
		float angle = atan(round_uv.y, round_uv.x);
		float sector_angle = 2.0 * PI / float(sectors);
		float half_sector = sector_angle / 2.0;
		angle = mod(angle - half_sector, sector_angle);

		float progress_angle = local_progress * 2.0 * PI / float(sectors);
		float smooth_angle = smoothstep(0.0, clock_feather, progress_angle - angle);
		transition_progress = smooth_angle;

	} else if (transition_type == 4) {
		// game-toolkit: dissolve. Each grid cell (or pixel) turns over at its own noise value.
		vec2 cell = pixel_grid.x > 0.0 ? floor(base_uv * pixel_grid) : floor(grid * 64.0);
		transition_progress = step(local_progress, cell_hash(cell));

	} else if (transition_type == 5) {
		// game-toolkit: wipe along rotation_angle, uncovering from the leading edge.
		float extent = abs(cos(radians(rotation_angle))) + abs(sin(radians(rotation_angle)));
		vec2 smooth_edges = get_edges((local_progress * 2.0 - 1.0) * extent, basic_feather);
		transition_progress = smoothstep(smooth_edges.x, smooth_edges.y, uv.x);

	} else {
		vec2 smooth_edges = get_edges(local_progress, basic_feather);

		float separation_x = smoothstep(smooth_edges.x, smooth_edges.y, abs(uv.x));
		float separation_y = smoothstep(smooth_edges.x, smooth_edges.y, abs(uv.y));
		transition_progress = max(separation_x, separation_y);
	}

	alpha = invert ? 1.0 - transition_progress : transition_progress;
	alpha = use_sprite_alpha ? min(COLOR.a, alpha) : alpha;

	vec4 transition_color = texture(transition_texture, base_uv);

	if (use_transition_texture) {
		vec4 chosen_color = mix(transition_color, COLOR, alpha);
		COLOR = chosen_color;
	} else {
		COLOR.a = alpha;
	}
}
