class_name PsxScreen
extends Control
## Drop-in PSX screen: renders `scene` at `resolution` in a SubViewport with the PSX post
## chain, converts its StandardMaterial3D materials and sprites to PSX ones, and draws
## the result to fill this control with nearest filtering and the aspect kept.

@export var scene: PackedScene
@export var resolution := Vector2i(320, 240)

var viewport: SubViewport
var post: LookPost
var world: Node
## Each original StandardMaterial3D -> the PsxMaterial3D that replaced it.
var materials := {}


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	viewport = SubViewport.new()
	viewport.size = resolution
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(viewport)
	var view := TextureRect.new()
	view.set_anchors_preset(Control.PRESET_FULL_RECT)
	view.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	view.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	view.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	view.texture = viewport.get_texture()
	add_child(view)
	post = LookPost.new()
	TKPsx.apply_post(post)
	viewport.add_child(post)
	set_psx(true)
	if scene:
		world = scene.instantiate()
		viewport.add_child(world)
		TKPsx.convert_materials(world, 2.0, materials)


func _exit_tree() -> void:
	TKPsx.reset()


## Turns the PSX effects and post chain on or off.
func set_psx(on: bool) -> void:
	if on:
		TKPsx.reset()
		TKPsx.set_params({ "psx_snap_resolution": Vector2(resolution) })
	else:
		TKPsx.disable()
	post.active = on


## Puts the scene's original materials back (true), or the PSX ones (false). Sprites keep
## the PSX sprite shader.
func set_standard_materials(on: bool) -> void:
	var swap := {}
	for standard in materials:
		if on:
			swap[materials[standard]] = standard
		else:
			swap[standard] = materials[standard]
	for mi: MeshInstance3D in world.find_children("*", "MeshInstance3D", true, false):
		if swap.has(mi.material_override):
			mi.material_override = swap[mi.material_override]
		for i in mi.get_surface_override_material_count():
			var m := mi.get_surface_override_material(i)
			if swap.has(m):
				mi.set_surface_override_material(i, swap[m])
