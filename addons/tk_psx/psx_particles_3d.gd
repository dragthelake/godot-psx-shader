@tool
class_name PsxParticles3D
extends CPUParticles3D
## Styled particles for the PSX stack: few, chunky, camera-facing squares of whole pixels
## on the snap grid, with PSX fog and draw distance, colour quantised to the stack's
## colour depth, fading by ordered dither. A CPUParticles3D with a quad mesh, a
## PsxParticlesMaterial3D, a fixed seed and the same presets as PixelParticles2D.
##
## In code: PsxParticles3D.make(PsxParticles3D.Preset.SPARKS), or TKPsx.burst() for a
## one-shot effect that frees itself. In the inspector: pick a preset to load its values,
## then tune the CPUParticles3D fields. The preset is not stored; the values are.
##
## Size: world_size metres times the particle's scale (scale_amount and its curve), then
## rounded to whole pixels, at least one. Deterministic: use_fixed_seed is on, so the same
## seed gives the same particles on every run. freeze_at() holds the effect at a fixed
## time, for labs and tests.

enum Preset { CUSTOM, DUST, SPARKS, SMOKE, HIT, SPARKLE }

## Preset names, for data files and the command line.
const PRESET_NAMES := {
	"dust": Preset.DUST,
	"sparks": Preset.SPARKS,
	"smoke": Preset.SMOKE,
	"hit": Preset.HIT,
	"sparkle": Preset.SPARKLE,
}

static var _quad: QuadMesh

## Loads a preset's values into this emitter. CUSTOM changes nothing. Not stored in
## scenes: the values it sets are.
@export var preset := Preset.CUSTOM:
	set(value):
		preset = value
		if value != Preset.CUSTOM:
			apply_preset(value)
## Particle size in metres at particle scale 1.
@export_range(0.0, 4.0, 0.01, "suffix:m") var world_size := 0.1:
	set(value):
		world_size = value
		_apply_material()
## Palette from tk_look/generated/palettes. "none" quantises to look_colour_levels.
@export var palette_name := TKLookDefaults.PALETTE_PSX_DEFAULT:
	set(value):
		palette_name = value
		_apply_material()
@export var fade := PsxParticlesMaterial3D.Fade.DITHER:
	set(value):
		fade = value
		_apply_material()
## Alpha levels for Fade.STEPS.
@export_range(1, 8) var fade_steps := 3:
	set(value):
		fade_steps = value
		_apply_material()
## Frees the node when a one-shot emission finishes.
@export var free_on_finish := false

var _batch := false


func _init() -> void:
	if not _quad:
		_quad = QuadMesh.new()
	mesh = _quad
	_apply_material()
	finished.connect(_on_finished)


## A new emitter with a preset's values.
static func make(p_preset: Preset) -> PsxParticles3D:
	var p := PsxParticles3D.new()
	p.preset = p_preset
	return p


## Sets every value a preset defines: the CPUParticles3D fields, size and seed.
func apply_preset(p_preset: Preset) -> void:
	var values := preset_values(p_preset)
	_batch = true
	for key: String in values:
		set(key, values[key])
	_batch = false
	_apply_material()


## The values a preset sets, by property name. Distances in metres, sized for a 320x240
## view a few metres from the camera.
static func preset_values(p_preset: Preset) -> Dictionary:
	var common := {
		"use_fixed_seed": true,
		"fixed_fps": 30,
		"fract_delta": false,
		"local_coords": false,
		"angle_min": 0.0,
		"angle_max": 0.0,
		"angular_velocity_min": 0.0,
		"angular_velocity_max": 0.0,
		"particle_flag_align_y": false,
		"particle_flag_rotate_y": false,
		"particle_flag_disable_z": false,
		"split_scale": false,
		"randomness": 0.0,
		"lifetime_randomness": 0.0,
		"flatness": 0.0,
		"orbit_velocity_min": 0.0,
		"orbit_velocity_max": 0.0,
		"radial_accel_min": 0.0,
		"radial_accel_max": 0.0,
		"tangential_accel_min": 0.0,
		"tangential_accel_max": 0.0,
		"hue_variation_min": 0.0,
		"hue_variation_max": 0.0,
		"color": Color.WHITE,
		"color_initial_ramp": null,
		"emission_shape": CPUParticles3D.EMISSION_SHAPE_POINT,
		"scale_amount_curve": null,
	}
	var v := {}
	match p_preset:
		Preset.DUST:
			v = {
				"amount": 8, "lifetime": 0.7, "one_shot": true, "explosiveness": 1.0, "seed": 11,
				"emission_shape": CPUParticles3D.EMISSION_SHAPE_BOX, "emission_box_extents": Vector3(0.3, 0.02, 0.3),
				"direction": Vector3.UP, "spread": 80.0,
				"initial_velocity_min": 0.9, "initial_velocity_max": 1.8,
				"gravity": Vector3(0, -2.0, 0), "damping_min": 1.2, "damping_max": 1.8,
				"world_size": 0.12, "scale_amount_min": 1.0, "scale_amount_max": 1.5,
				"scale_amount_curve": _ramp_curve(1.0, 0.5),
				"color_ramp": _gradient([Color("ead4aa"), Color("c28569"), Color("8b9bb4", 0.0)], [0.0, 0.5, 1.0]),
			}
		Preset.SPARKS:
			v = {
				"amount": 10, "lifetime": 0.5, "one_shot": true, "explosiveness": 1.0, "seed": 23,
				"direction": Vector3.UP, "spread": 60.0,
				"initial_velocity_min": 3.0, "initial_velocity_max": 5.5,
				"gravity": Vector3(0, -14.0, 0), "damping_min": 1.0, "damping_max": 2.0,
				"world_size": 0.05, "scale_amount_min": 1.0, "scale_amount_max": 1.6,
				"color_ramp": _gradient([Color("fee761"), Color("feae34"), Color("f77622"), Color("e43b44", 0.0)], [0.0, 0.3, 0.6, 1.0]),
			}
		Preset.SMOKE:
			v = {
				"amount": 8, "lifetime": 1.6, "one_shot": false, "explosiveness": 0.0, "seed": 37,
				"emission_shape": CPUParticles3D.EMISSION_SHAPE_BOX, "emission_box_extents": Vector3(0.12, 0.0, 0.12),
				"direction": Vector3.UP, "spread": 15.0,
				"initial_velocity_min": 0.5, "initial_velocity_max": 0.8,
				"gravity": Vector3(0.2, 0.3, 0.0), "damping_min": 0.0, "damping_max": 0.1,
				"world_size": 0.14, "scale_amount_min": 1.0, "scale_amount_max": 1.5,
				"scale_amount_curve": _ramp_curve(1.0, 2.0),
				"color_ramp": _gradient([Color("8b9bb4"), Color("5a6988"), Color("3a4466", 0.0)], [0.0, 0.45, 1.0]),
			}
		Preset.HIT:
			v = {
				"amount": 12, "lifetime": 0.35, "one_shot": true, "explosiveness": 1.0, "seed": 19,
				"direction": Vector3.RIGHT, "spread": 180.0,
				"initial_velocity_min": 6.0, "initial_velocity_max": 7.0,
				"gravity": Vector3.ZERO, "damping_min": 16.0, "damping_max": 18.0,
				"world_size": 0.15, "scale_amount_min": 1.0, "scale_amount_max": 1.0,
				"scale_amount_curve": _ramp_curve(1.0, 0.34),
				"color_ramp": _gradient([Color("ffffff"), Color("fee761"), Color("f77622", 0.0)], [0.0, 0.35, 1.0]),
			}
		Preset.SPARKLE:
			v = {
				"amount": 10, "lifetime": 0.8, "one_shot": true, "explosiveness": 0.7, "seed": 53,
				"emission_shape": CPUParticles3D.EMISSION_SHAPE_SPHERE, "emission_sphere_radius": 0.35,
				"direction": Vector3.UP, "spread": 30.0,
				"initial_velocity_min": 0.2, "initial_velocity_max": 0.5,
				"gravity": Vector3(0, 0.5, 0), "damping_min": 0.0, "damping_max": 0.0,
				"world_size": 0.05, "scale_amount_min": 1.0, "scale_amount_max": 2.0,
				"color_ramp": _gradient([Color("ffffff"), Color("2ce8f5"), Color("0099db", 0.0)], [0.0, 0.4, 1.0]),
			}
		_:
			return {}
	common.merge(v, true)
	return common


## Shows the effect as it is `time` seconds after it starts, and holds it there:
## restarts the emitter with its seed, steps it at fixed_fps and stops time. The same
## seed and time give the same picture on every run. resume() lets time run again.
func freeze_at(time: float) -> void:
	speed_scale = 0.0
	restart(true)
	if time > 0.0:
		request_particles_process(time)


## Lets time run again after freeze_at().
func resume() -> void:
	speed_scale = 1.0


## TKPool hook: restart the effect when handed out again.
func pool_acquired() -> void:
	restart(true)


## TKPool hook: stop emitting when taken back.
func pool_released() -> void:
	emitting = false


func _apply_material() -> void:
	if _batch:
		return
	material_override = PsxParticlesMaterial3D.shared(palette_name, fade, fade_steps, world_size)


func _on_finished() -> void:
	if free_on_finish and not Engine.is_editor_hint():
		queue_free()


func _validate_property(property: Dictionary) -> void:
	match property.name:
		"preset":
			property.usage = PROPERTY_USAGE_EDITOR
		"palette_name":
			property.hint = PROPERTY_HINT_ENUM_SUGGESTION
			property.hint_string = ",".join(Array(TKLookDefaults.PALETTES) + ["none"])
		"material_override", "mesh":
			# Follow world_size, palette_name, fade and fade_steps.
			property.usage = PROPERTY_USAGE_NONE


static func _gradient(colours: Array[Color], offsets: Array[float]) -> Gradient:
	var g := Gradient.new()
	g.colors = PackedColorArray(colours)
	g.offsets = PackedFloat32Array(offsets)
	return g


static func _ramp_curve(from: float, to: float) -> Curve:
	var c := Curve.new()
	c.min_value = 0.0
	c.max_value = maxf(maxf(from, to), 1.0)
	c.add_point(Vector2(0.0, from), 0.0, 0.0, Curve.TANGENT_LINEAR, Curve.TANGENT_LINEAR)
	c.add_point(Vector2(1.0, to), 0.0, 0.0, Curve.TANGENT_LINEAR, Curve.TANGENT_LINEAR)
	return c
