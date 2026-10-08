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
		TKPsx.convert_materials(world)


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
