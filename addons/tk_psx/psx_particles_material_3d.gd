@tool
class_name PsxParticlesMaterial3D
extends ShaderMaterial
## Particle material for the PSX stack: camera-facing squares of whole pixels on the
## psx_snap_resolution grid, with PSX fog and draw distance, colour quantised to
## look_colour_levels or a palette, fade as an ordered dither or in a few alpha steps.
## For CPUParticles3D and GPUParticles3D drawing a QuadMesh; PsxParticles3D sets one up.
## Materials are shared: use shared() rather than new() per emitter.

## How particle alpha (from colour and colour ramp) shows. Same values as
## PixelParticlesMaterial2D.Fade.
enum Fade {
	## Alpha cut at 0.5. Opaque shader.
	CUT,
	## Alpha rounded up to one of fade_steps levels. Alpha blended shader.
	STEPS,
	## Ordered dither: the share of opaque pixels follows alpha. Opaque shader.
	DITHER,
}

const SHADER := preload("res://addons/tk_psx/shaders/psx_particles.gdshader")
const SHADER_BLEND := preload("res://addons/tk_psx/shaders/psx_particles_blend.gdshader")

static var _shared: Dictionary[String, PsxParticlesMaterial3D] = {}

## N x 1 palette strip (TKLook.palette). Null quantises each channel to
## look_colour_levels instead.
@export var palette: Texture2D:
	set(value):
		palette = value
		set_shader_parameter(&"palette", value)
		set_shader_parameter(&"use_palette", value != null)
@export var fade := Fade.DITHER:
	set(value):
		fade = value
		shader = SHADER_BLEND if value == Fade.STEPS else SHADER
		_forward()
## Alpha levels for Fade.STEPS.
@export_range(1, 8) var fade_steps := 3:
	set(value):
		fade_steps = value
		set_shader_parameter(&"fade_steps", value)
## Particle size in metres at particle scale 1.
@export_range(0.0, 4.0, 0.01, "suffix:m") var world_size := 0.1:
	set(value):
		world_size = value
		set_shader_parameter(&"world_size", value)
## Smallest size in pixels, so far particles do not vanish.
@export_range(1, 8) var min_pixels := 1:
	set(value):
		min_pixels = value
		set_shader_parameter(&"min_pixels", float(value))
## Largest size in pixels, so a particle at the camera does not fill the screen.
@export_range(1, 64) var max_pixels := 16:
	set(value):
		max_pixels = value
		set_shader_parameter(&"max_pixels", float(value))


func _init() -> void:
	fade = fade


## One material per combination of values, made on first use. Takes the palette by name
## (tk_look/generated/palettes); "" or "none" quantises instead.
static func shared(palette_name := TKLookDefaults.PALETTE_PSX_DEFAULT, p_fade := Fade.DITHER, p_fade_steps := 3, p_world_size := 0.1) -> PsxParticlesMaterial3D:
	var key := "%s/%d/%d/%.4f" % [palette_name, p_fade, p_fade_steps, p_world_size]
	if not _shared.has(key):
		var m := PsxParticlesMaterial3D.new()
		if palette_name != "" and palette_name != "none":
			m.palette = TKLook.palette(palette_name)
		m.fade = p_fade
		m.fade_steps = p_fade_steps
		m.world_size = p_world_size
		_shared[key] = m
	return _shared[key]


# Sets every field again, so a new shader variant picks them up.
func _forward() -> void:
	set_shader_parameter(&"palette", palette)
	set_shader_parameter(&"use_palette", palette != null)
	set_shader_parameter(&"fade_mode", int(fade))
	set_shader_parameter(&"fade_steps", fade_steps)
	set_shader_parameter(&"world_size", world_size)
	set_shader_parameter(&"min_pixels", float(min_pixels))
	set_shader_parameter(&"max_pixels", float(max_pixels))


func _validate_property(property: Dictionary) -> void:
	if property.name == "shader":
		property.usage |= PROPERTY_USAGE_READ_ONLY
