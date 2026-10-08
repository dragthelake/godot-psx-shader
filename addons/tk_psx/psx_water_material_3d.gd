@tool
class_name PsxWaterMaterial3D
extends ShaderMaterial
## PSX water material: the PSX surface shader (vertex snap, affine mapping, per-vertex
## fog and lighting, draw distance, texture LOD from the psx_* globals) with vertex waves
## and two world-space texture layers scrolling different ways, alpha blended. Picks
## shaders/water/psx_water_{lit,unlit}.gdshader and forwards the fields to its uniforms.
##
## Waves move vertices, so give it a mesh with vertices to move: PsxWater3D makes one.
## Set time_override to 0 or more to freeze the water, for captures and tests.

enum Shading { LIT, UNLIT }

const SHADER_DIR := "res://addons/tk_psx/shaders/water/"
## Seed of the default texture.
const DEFAULT_SEED := 7

static var _default_texture: ImageTexture

## LIT is per-vertex Lambert lighting, so the waves catch the light; UNLIT shows albedo.
@export var shading := Shading.LIT:
	set(value):
		shading = value
		_update_shader()
## Mapped in world space, sampled nearest and repeating. Null uses default_texture().
@export var albedo_texture: Texture2D:
	set(value):
		albedo_texture = value
		set_shader_parameter(&"albedo_texture", value if value else default_texture())
## Multiplies the texture. Alpha is the water's opacity.
@export var albedo_colour := Color(0.8, 0.9, 1.0, 0.75):
	set(value):
		albedo_colour = value
		set_shader_parameter(&"albedo_colour", value)
## Negative runs on the engine clock. 0 or more freezes the water at that time.
@export var time_override := -1.0:
	set(value):
		time_override = value
		set_shader_parameter(&"time_override", value)

@export_group("Waves")
## Largest rise or fall of the surface, in metres.
@export var wave_height := 0.15:
	set(value):
		wave_height = value
		set_shader_parameter(&"wave_height", value)
## Length of the longer wave, in metres. The second wave is 1.9 times shorter.
@export var wave_length := 6.0:
	set(value):
		wave_length = value
		set_shader_parameter(&"wave_length", value)
@export var wave_speed := 1.0:
	set(value):
		wave_speed = value
		set_shader_parameter(&"wave_speed", value)
## Direction of the longer wave across the water, as world (x, z).
@export var wave_direction := Vector2(1.0, 0.35):
	set(value):
		wave_direction = value
		set_shader_parameter(&"wave_direction", value)
## Extra brightness at the top of a crest.
@export_range(0.0, 2.0) var crest_brightness := 0.35:
	set(value):
		crest_brightness = value
		set_shader_parameter(&"crest_brightness", value)

@export_group("Texture")
## Metres covered by one repeat of the texture.
@export var texture_size := 4.0:
	set(value):
		texture_size = value
		set_shader_parameter(&"texture_size", value)
## Scroll of the first layer, in texture repeats per second.
@export var scroll_a := Vector2(0.03, 0.012):
	set(value):
		scroll_a = value
		set_shader_parameter(&"scroll_a", value)
## Scroll of the second layer, which is also scaled by layer_b_scale and turned.
@export var scroll_b := Vector2(-0.018, 0.026):
	set(value):
		scroll_b = value
		set_shader_parameter(&"scroll_b", value)
@export var layer_b_scale := 1.37:
	set(value):
		layer_b_scale = value
		set_shader_parameter(&"layer_b_scale", value)


func _init() -> void:
	_update_shader()


## res:// path of the shader for a shading mode.
static func shader_path(p_shading: Shading) -> String:
	return SHADER_DIR + "psx_water_%s.gdshader" % ["lit", "unlit"][p_shading]


## The time the water shows: time_override when set, else the engine clock.
func current_time() -> float:
	if time_override >= 0.0:
		return time_override
	return Time.get_ticks_msec() / 1000.0


## Height of the surface above its rest plane at world (x, z) and time t, in metres.
## Same sum of sines as the shader, for floating things.
func height(xz: Vector2, t: float) -> float:
	var d1 := wave_direction.normalized()
	var d2 := Vector2(-d1.y, d1.x) * 0.6 + d1 * 0.8
	var k1 := TAU / maxf(wave_length, 0.01)
	var k2 := k1 * 1.9
	return wave_height * (0.65 * sin(d1.dot(xz) * k1 - t * wave_speed * 1.7) \
			+ 0.35 * sin(d2.dot(xz) * k2 - t * wave_speed * 2.6 + 1.3))


## The default water texture: 32x32, blue with light ripple streaks placed from a seeded
## PCG32 stream, so it is the same on every run.
static func default_texture() -> ImageTexture:
	if not _default_texture:
		_default_texture = ImageTexture.create_from_image(make_texture_image(DEFAULT_SEED))
	return _default_texture


## A 32x32 water texture: base blue, darker troughs and short light streaks that wrap at
## the edges, so it tiles.
static func make_texture_image(p_seed: int) -> Image:
	const N := 32
	var base := Color(0.2, 0.42, 0.62)
	var dark := Color(0.13, 0.3, 0.5)
	var light := Color(0.42, 0.68, 0.84)
	var bright := Color(0.78, 0.93, 1.0)
	var img := Image.create_empty(N, N, false, Image.FORMAT_RGBA8)
	img.fill(base)
	var rng := TKPcg32.new(p_seed, "psx_water")
	for i in 14:
		var x := rng.next_range(0, N - 1)
		var y := rng.next_range(0, N - 1)
		var length := rng.next_range(4, 9)
		for j in length:
			img.set_pixel((x + j) % N, y, dark)
			img.set_pixel((x + j + 1) % N, (y + 1) % N, dark)
	for i in 18:
		var x := rng.next_range(0, N - 1)
		var y := rng.next_range(0, N - 1)
		var length := rng.next_range(2, 7)
		for j in length:
			img.set_pixel((x + j) % N, y, light)
		if length >= 5:
			img.set_pixel((x + length / 2) % N, y, bright)
	return img


func _update_shader() -> void:
	var next := load(shader_path(shading)) as Shader
	if shader == next:
		return
	shader = next
	# Set every field again so the new shader's uniforms pick them up.
	for prop in ["albedo_texture", "albedo_colour", "time_override", "wave_height", "wave_length", "wave_speed", "wave_direction", "crest_brightness", "texture_size", "scroll_a", "scroll_b", "layer_b_scale"]:
		set(prop, get(prop))


func _validate_property(property: Dictionary) -> void:
	# The shader follows the fields; editing it by hand would be undone on the next change.
	if property.name == "shader":
		property.usage |= PROPERTY_USAGE_READ_ONLY
