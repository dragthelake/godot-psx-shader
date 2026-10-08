// Hit flash for meshes. Goes on GeometryInstance3D.material_overlay, so it layers over
// any surface material. TKLook.flash(node) animates tk_flash.
shader_type spatial;
render_mode unshaded, blend_mix, depth_draw_never, depth_test_disabled, cull_back, fog_disabled;

// Fixed slots, shared with the PSX surface and x-ray shaders on the same mesh (see
// tk_psx/shaders/psx_body_uniforms.gdshaderinc).
instance uniform float tk_flash : hint_range(0.0, 1.0), instance_index(0) = 0.0;
instance uniform vec4 tk_flash_colour : source_color, instance_index(1) = vec4(1.0);

void fragment() {
	ALBEDO = tk_flash_colour.rgb;
	ALPHA = tk_flash;
}
