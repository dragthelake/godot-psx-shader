// Hit flash for any CanvasItem. Set the per-node amount with
// set_instance_shader_parameter("tk_flash", 0..1) or TKLook.flash(node).
shader_type canvas_item;

instance uniform float tk_flash : hint_range(0.0, 1.0) = 0.0;
instance uniform vec4 tk_flash_colour : source_color = vec4(1.0);

void fragment() {
	COLOR.rgb = mix(COLOR.rgb, tk_flash_colour.rgb, tk_flash);
}
