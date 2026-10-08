@tool
class_name PsxMaterial3D
extends ShaderMaterial
## A PSX surface material: set the fields and it picks the matching shader in
## shaders/variants/ and forwards the values to its uniforms. Vertex snap, affine
## mapping, fog, draw distance and texture LOD come from the psx_* global parameters
## (TKPsx), so they are not per-material fields.
##
## Pattern after psx_visuals' PsxMaterial3D (Unlicense), with fixed shader files instead
## of shaders generated at runtime.

enum Shading { LIT, UNLIT }
enum Transparency { OPAQUE, SCISSOR, BLEND }

const VARIANT_DIR := "res://addons/tk_psx/shaders/variants/"

static var _shaders: Dictionary[String, Shader] = {}

## LIT is per-vertex Lambert lighting with no specular; UNLIT shows albedo as is.
@export var shading := Shading.LIT:
	set(value):
		shading = value
		_update_shader()
## SCISSOR cuts out texels below alpha_scissor; BLEND alpha blends.
@export var transparency := Transparency.OPAQUE:
	set(value):
		transparency = value
		_update_shader()
## Draws back faces too.
@export var double_sided := false:
	set(value):
		double_sided = value
		_update_shader()
## Sampled nearest, repeating. Multiplied by albedo_colour and the vertex colour.
@export var albedo_texture: Texture2D:
	set(value):
		albedo_texture = value
		set_shader_parameter(&"albedo_texture", value)
@export var albedo_colour := Color.WHITE:
	set(value):
		albedo_colour = value
		set_shader_parameter(&"albedo_colour", value)
@export var uv_scale := Vector2.ONE:
	set(value):
		uv_scale = value
		set_shader_parameter(&"uv_scale", value)
@export var uv_offset := Vector2.ZERO:
	set(value):
		uv_offset = value
		set_shader_parameter(&"uv_offset", value)
## Takes UVs from world position (box projection, one repeat per metre times uv_scale)
## instead of the mesh, for greybox geometry. Like StandardMaterial3D's world triplanar.
@export var world_uv := false:
	set(value):
		world_uv = value
		set_shader_parameter(&"world_uv", value)
## Share of its distance the surface is drawn nearer the camera, along the view ray.
## For decals and posters a few millimetres off a wall, which vertex snap would
## otherwise push behind it in patches. 0.01 is plenty.
@export_range(0.0, 0.1, 0.001) var depth_lift := 0.0:
	set(value):
		depth_lift = value
		set_shader_parameter(&"depth_lift", value)
## Alpha below this is cut out. Used when transparency is SCISSOR.
@export_range(0.0, 1.0, 0.01) var alpha_scissor := 0.5:
	set(value):
		alpha_scissor = value
		set_shader_parameter(&"alpha_scissor", value)
## Dissolve pattern (TKPsx.dissolve): 0 ordered (8x8 Bayer), 1 each texel hashed on its
## own, 2 or more blobs about that many texels across with a rough fringe.
@export_range(0, 16) var dissolve_cell := 4:
	set(value):
		dissolve_cell = value
		set_shader_parameter(&"dissolve_cell", value)
## Texels within this many texels of a dissolved texel draw in dissolve_edge_colour,
## unlit. 0 turns the edge off.
@export_range(0, 3) var dissolve_edge_width := 1:
	set(value):
		dissolve_edge_width = value
		set_shader_parameter(&"dissolve_edge_width", value)
@export var dissolve_edge_colour := Color("feae34"):
	set(value):
		dissolve_edge_colour = value
		set_shader_parameter(&"dissolve_edge_colour", value)
## Texels per UV unit the dissolve works in. Zero uses the albedo texture's size; set it
## for untextured surfaces.
@export var dissolve_texels := Vector2.ZERO:
	set(value):
		dissolve_texels = value
		set_shader_parameter(&"dissolve_texels", value)


func _init() -> void:
	_update_shader()


## res:// path of the shader variant for a combination of fields.
static func variant_path(p_shading: Shading, p_transparency: Transparency, p_double_sided: bool) -> String:
	var shading_name: String = ["lit", "unlit"][p_shading]
	var transparency_name: String = ["opaque", "scissor", "blend"][p_transparency]
	return VARIANT_DIR + "psx_%s_%s%s.gdshader" % [shading_name, transparency_name, "_double" if p_double_sided else ""]


## The shader variant for a combination of fields, loaded once.
static func variant(p_shading: Shading, p_transparency: Transparency, p_double_sided: bool) -> Shader:
	var path := variant_path(p_shading, p_transparency, p_double_sided)
	if not _shaders.has(path):
		_shaders[path] = load(path) as Shader
	return _shaders[path]


## A material in one call, for code that builds scenes.
static func make(texture: Texture2D = null, colour := Color.WHITE, p_shading := Shading.LIT, p_transparency := Transparency.OPAQUE, p_double_sided := false) -> PsxMaterial3D:
	var m := PsxMaterial3D.new()
	m.shading = p_shading
	m.transparency = p_transparency
	m.double_sided = p_double_sided
	m.albedo_texture = texture
	m.albedo_colour = colour
	return m


## A PsxMaterial3D standing in for a StandardMaterial3D: albedo texture and colour,
## UV scale and offset, world triplanar (as world_uv), unshaded, alpha scissor or blend,
## and cull disabled carry over, and a "depth_lift" meta becomes depth_lift. Anything
## else (normal maps, emission, metal) does not.
static func from_standard(m: BaseMaterial3D) -> PsxMaterial3D:
	var p := PsxMaterial3D.new()
	p.shading = Shading.UNLIT if m.shading_mode == BaseMaterial3D.SHADING_MODE_UNSHADED else Shading.LIT
	match m.transparency:
		BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR:
			p.transparency = Transparency.SCISSOR
			p.alpha_scissor = m.alpha_scissor_threshold
		BaseMaterial3D.TRANSPARENCY_DISABLED:
			p.transparency = Transparency.OPAQUE
		_:
			p.transparency = Transparency.BLEND
	p.double_sided = m.cull_mode == BaseMaterial3D.CULL_DISABLED
	p.albedo_texture = m.albedo_texture
	p.albedo_colour = m.albedo_color
	p.world_uv = m.uv1_triplanar and m.uv1_world_triplanar
	p.uv_scale = Vector2(m.uv1_scale.x, m.uv1_scale.y)
	p.uv_offset = Vector2(m.uv1_offset.x, m.uv1_offset.y)
	p.depth_lift = m.get_meta(&"depth_lift", 0.0)
	return p


func _update_shader() -> void:
	var next := variant(shading, transparency, double_sided)
	if shader == next:
		return
	shader = next
	# Set every field again so a new variant's uniforms (alpha_scissor) pick them up.
	set_shader_parameter(&"albedo_texture", albedo_texture)
	set_shader_parameter(&"albedo_colour", albedo_colour)
	set_shader_parameter(&"uv_scale", uv_scale)
	set_shader_parameter(&"uv_offset", uv_offset)
	set_shader_parameter(&"alpha_scissor", alpha_scissor)
	set_shader_parameter(&"world_uv", world_uv)
	set_shader_parameter(&"depth_lift", depth_lift)
	set_shader_parameter(&"dissolve_cell", dissolve_cell)
	set_shader_parameter(&"dissolve_edge_width", dissolve_edge_width)
	set_shader_parameter(&"dissolve_edge_colour", dissolve_edge_colour)
	set_shader_parameter(&"dissolve_texels", dissolve_texels)


func _validate_property(property: Dictionary) -> void:
	# The shader follows the fields; editing it by hand would be undone on the next change.
	if property.name == "shader":
		property.usage |= PROPERTY_USAGE_READ_ONLY
