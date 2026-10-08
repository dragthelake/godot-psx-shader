@tool
class_name LookPass
extends Resource
## One full-screen pass in a LookPost chain: a canvas_item material that reads
## hint_screen_texture and writes the processed pixel.

@export var enabled := true:
	set(value):
		enabled = value
		emit_changed()
@export var material: ShaderMaterial:
	set(value):
		material = value
		emit_changed()


static func from_shader(shader: Shader, params := {}) -> LookPass:
	var p := LookPass.new()
	var m := ShaderMaterial.new()
	m.shader = shader
	for key in params:
		m.set_shader_parameter(key, params[key])
	p.material = m
	return p
