@tool
class_name PsxSkyMaterial
extends ShaderMaterial
## PSX sky material for a Sky resource: a vertical gradient from the zenith through the
## horizon to the ground, or a low-resolution panorama, with an optional sun disc and an
## optional band of scrolling whole-texel clouds, quantised to the stack's colour depth
## with an ordered dither in screen space (shaders/psx_sky.gdshader).
##
## The horizon follows psx_fog_colour by default, so geometry at full fog meets the sky
## with no seam. Colours are sRGB. TKPsx.make_sky and TKPsx.apply_sky put one on an
## Environment. Set time_override to 0 or more to freeze the clouds, for captures and
## tests.

enum Mode { GRADIENT, PANORAMA }
enum Below { GRADIENT, MIRROR }

const SHADER := preload("res://addons/tk_psx/shaders/psx_sky.gdshader")
## Seed of the default cloud texture.
const DEFAULT_SEED := 11

static var _default_clouds: ImageTexture

## GRADIENT draws the colour gradient; PANORAMA draws panorama above the horizon.
@export var mode := Mode.GRADIENT:
	set(value):
		mode = value
		set_shader_parameter(&"sky_mode", value)
@export var zenith_colour := Color("#262b44"):
	set(value):
		zenith_colour = value
		set_shader_parameter(&"zenith_colour", value)
## Used when horizon_follows_fog is off.
@export var horizon_colour := Color("#3a4466"):
	set(value):
		horizon_colour = value
		set_shader_parameter(&"horizon_colour", value)
## Used when ground_follows_fog is off.
@export var ground_colour := Color("#262b44"):
	set(value):
		ground_colour = value
		set_shader_parameter(&"ground_colour", value)
## The horizon colour is psx_fog_colour, so fogged geometry meets the sky with no seam.
@export var horizon_follows_fog := true:
	set(value):
		horizon_follows_fog = value
		set_shader_parameter(&"horizon_follows_fog", value)
## Below the horizon is psx_fog_colour too. Off runs to ground_colour, which shows as a
## seam wherever the ground stops short of full fog.
@export var ground_follows_fog := true:
	set(value):
		ground_follows_fog = value
		set_shader_parameter(&"ground_follows_fog", value)
## Elevation of the horizon line, as the sine of the angle above level.
@export_range(-0.5, 0.5, 0.01) var horizon_height := 0.0:
	set(value):
		horizon_height = value
		set_shader_parameter(&"horizon_height", value)
## 1 is a linear gradient; higher keeps the horizon colour in a thinner band.
@export_range(0.25, 16.0, 0.05) var sharpness := 2.0:
	set(value):
		sharpness = value
		set_shader_parameter(&"sharpness", value)
## Negative scrolls the clouds on the engine clock. 0 or more freezes them at that time.
@export var time_override := -1.0:
	set(value):
		time_override = value
		set_shader_parameter(&"time_override", value)

@export_group("Banding")
## Quantise per channel with an ordered dither, like the tk_look quantise pass.
@export var banding := true:
	set(value):
		banding = value
		set_shader_parameter(&"banding", value)
## Levels per channel. 0 follows look_colour_levels (32, PSX 15-bit colour).
@export_range(0.0, 256.0, 1.0) var band_levels := 0.0:
	set(value):
		band_levels = value
		set_shader_parameter(&"band_levels", value)
## Dither by look_dither_strength with the look_bayer_size matrix. Off gives hard bands.
@export var dither := true:
	set(value):
		dither = value
		set_shader_parameter(&"dither", value)

@export_group("Sun")
@export var sun_enabled := false:
	set(value):
		sun_enabled = value
		set_shader_parameter(&"sun_enabled", value)
## Direction towards the sun.
@export var sun_direction := Vector3(0.0, 0.5, -1.0):
	set(value):
		sun_direction = value
		set_shader_parameter(&"sun_direction", value)
## Put the sun where the first DirectionalLight3D shines from, instead of sun_direction.
@export var sun_follows_light := false:
	set(value):
		sun_follows_light = value
		set_shader_parameter(&"sun_follows_light", value)
## Angular radius in degrees.
@export_range(0.0, 30.0, 0.1) var sun_size := 3.0:
	set(value):
		sun_size = value
		set_shader_parameter(&"sun_size", value)
@export var sun_colour := Color("#feeebc"):
	set(value):
		sun_colour = value
		set_shader_parameter(&"sun_colour", value)
## A ring as wide as the disc around it, this far towards sun_colour.
@export_range(0.0, 1.0, 0.05) var sun_halo := 0.25:
	set(value):
		sun_halo = value
		set_shader_parameter(&"sun_halo", value)

@export_group("Clouds")
@export var clouds_enabled := false:
	set(value):
		clouds_enabled = value
		set_shader_parameter(&"clouds_enabled", value)
## Texels with alpha 0.5 and up are cloud, tinted by cloud_colour; the rest are clear.
## Null uses default_clouds().
@export var cloud_texture: Texture2D:
	set(value):
		cloud_texture = value
		set_shader_parameter(&"cloud_texture", value if value else default_clouds())
@export var cloud_colour := Color.WHITE:
	set(value):
		cloud_colour = value
		set_shader_parameter(&"cloud_colour", value)
## Elevation of the band's bottom row (sine of the angle above level).
@export_range(-0.5, 1.0, 0.01) var cloud_low := 0.06:
	set(value):
		cloud_low = value
		set_shader_parameter(&"cloud_low", value)
## Elevation of the band's top row.
@export_range(-0.5, 1.0, 0.01) var cloud_high := 0.3:
	set(value):
		cloud_high = value
		set_shader_parameter(&"cloud_high", value)
## Times the texture wraps around the horizon.
@export_range(1.0, 16.0, 1.0) var cloud_repeats := 3.0:
	set(value):
		cloud_repeats = value
		set_shader_parameter(&"cloud_repeats", value)
## Texels per second along the horizon. The band moves a whole texel at a time.
@export_range(-32.0, 32.0, 0.5) var cloud_speed := 2.0:
	set(value):
		cloud_speed = value
		set_shader_parameter(&"cloud_speed", value)

@export_group("Panorama")
## Covers the horizon (bottom row) to the zenith (top row) all around. Keep it small:
## PSX skies were a few hundred texels around.
@export var panorama: Texture2D:
	set(value):
		panorama = value
		set_shader_parameter(&"panorama", value)
## Grid the panorama is sampled on, nearest. Zero uses the texture's own size.
@export var panorama_resolution := Vector2i.ZERO:
	set(value):
		panorama_resolution = value
		set_shader_parameter(&"panorama_resolution", value)
## Elevation over which the panorama fades in from the horizon colour. 0 is a hard edge.
@export_range(0.0, 0.5, 0.01) var panorama_fade := 0.08:
	set(value):
		panorama_fade = value
		set_shader_parameter(&"panorama_fade", value)
## GRADIENT fills below the horizon with the ground gradient; MIRROR reflects the panorama.
@export var panorama_below := Below.GRADIENT:
	set(value):
		panorama_below = value
		set_shader_parameter(&"panorama_below", value)


func _init() -> void:
	shader = SHADER
	# Push every field, so the shader's own defaults never disagree with the inspector.
	for prop in ["mode", "zenith_colour", "horizon_colour", "ground_colour", "horizon_follows_fog", "ground_follows_fog", "horizon_height", "sharpness", "time_override", "banding", "band_levels", "dither", "sun_enabled", "sun_direction", "sun_follows_light", "sun_size", "sun_colour", "sun_halo", "clouds_enabled", "cloud_texture", "cloud_colour", "cloud_low", "cloud_high", "cloud_repeats", "cloud_speed", "panorama", "panorama_resolution", "panorama_fade", "panorama_below"]:
		set(prop, get(prop))


## A material in one call, for code that builds scenes.
static func make(p_zenith := Color("#262b44"), p_sharpness := 2.0) -> PsxSkyMaterial:
	var m := PsxSkyMaterial.new()
	m.zenith_colour = p_zenith
	m.sharpness = p_sharpness
	return m


## The horizon colour the shader uses: psx_fog_colour when horizon_follows_fog.
func current_horizon() -> Color:
	return TKLook.get_param("psx_fog_colour") if horizon_follows_fog else horizon_colour


## The ground colour the shader uses: psx_fog_colour when ground_follows_fog.
func current_ground() -> Color:
	return TKLook.get_param("psx_fog_colour") if ground_follows_fog else ground_colour


## The gradient colour at `elevation` (sine of the angle above level) before banding:
## the same maths as psx_sky_gradient. For things that must match the sky, such as
## distant sprites or a loading screen.
func gradient_at(elevation: float) -> Color:
	return gradient(elevation, zenith_colour, current_horizon(), current_ground(), horizon_height, sharpness)


## psx_sky_gradient in GDScript.
static func gradient(elevation: float, zenith: Color, horizon: Color, ground: Color, p_horizon_height: float, p_sharpness: float) -> Color:
	var d := elevation - p_horizon_height
	if d >= 0.0:
		return horizon.lerp(zenith, weight(d, 1.0 - p_horizon_height, p_sharpness))
	return horizon.lerp(ground, weight(-d, 1.0 + p_horizon_height, p_sharpness))


## psx_sky_weight in GDScript: 1 - (1 - d / span) ^ sharpness, with d / span clamped.
static func weight(d: float, span: float, p_sharpness: float) -> float:
	var t := clampf(d / maxf(span, 1e-4), 0.0, 1.0)
	return 1.0 - pow(1.0 - t, maxf(p_sharpness, 1e-3))


## The default cloud band: 64x8, flat-bottomed clouds placed from a seeded PCG32 stream,
## white on top with a grey underside. Wraps at the edges.
static func default_clouds() -> ImageTexture:
	if not _default_clouds:
		_default_clouds = ImageTexture.create_from_image(make_clouds_image(DEFAULT_SEED))
	return _default_clouds


static func make_clouds_image(p_seed: int) -> Image:
	const W := 64
	const H := 8
	var top := Color(1.0, 1.0, 1.0)
	var under := Color(0.78, 0.8, 0.88)
	var img := Image.create_empty(W, H, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	var rng := TKPcg32.new(p_seed, "psx_sky_clouds")
	for i in 7:
		var x := rng.next_range(0, W - 1)
		var base := rng.next_range(4, H - 1)
		var length := rng.next_range(6, 14)
		var height := rng.next_range(2, mini(4, base))
		for row in height:
			# Each row up is shorter at both ends, so clouds are flat below and round above.
			var inset := row * 2 + rng.next_range(0, 1)
			for j in range(inset, length - inset):
				img.set_pixel((x + j) % W, base - row, under if row == 0 else top)
	return img


func _validate_property(property: Dictionary) -> void:
	# The shader is fixed; editing it by hand would be undone on load.
	if property.name == "shader":
		property.usage |= PROPERTY_USAGE_READ_ONLY
