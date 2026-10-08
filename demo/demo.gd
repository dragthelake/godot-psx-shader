extends Control
## Flips between the tk_psx labs and runs them live. 1 to 6 picks a lab; L steps up the
## look ladder and Shift+L back down, from Modern to Full PSX.
##
## The ladder has four axes:
## - res: the lab's 3D view rendered at the window's own resolution (filling it), at
##   640x480 or at 320x240 (both 4:3, pillarboxed). Vertex snap stays on its 320x240
##   grid at every resolution, so the hi-res steps still wobble.
## - tex: textures as they are, or shrunk to 256 px on their longest side.
## - surfaces: the PSX surface effects (vertex snap, affine textures, fog, draw distance,
##   texture LOD). A scene that keeps its original materials (PsxScreen) goes back to
##   them when this is off.
## - post: the 15-bit colour and dither pass.

const LABS := [
	["PSX look", "res://addons/tk_psx/lab/psx_lab.tscn"],
	["Water", "res://addons/tk_psx/lab/water_lab.tscn"],
	["Particles", "res://addons/tk_psx/lab/particles_lab.tscn"],
	["Sky (M: panorama)", "res://addons/tk_psx/lab/sky_lab.tscn"],
	["Dissolve and x-ray", "res://addons/tk_psx/lab/sprite_fx_lab.tscn"],
	["Your own scene, through PsxScreen", "res://demo/quickstart.tscn"],
]
const LADDER: Array[Dictionary] = [
	{"name": "Modern", "height": 0, "tex": 0, "surfaces": false, "post": false},
	{"name": "Hi-res PSX", "height": 0, "tex": 0, "surfaces": true, "post": true},
	{"name": "Hi-res PSX, crunchy textures", "height": 0, "tex": 256, "surfaces": true, "post": true},
	{"name": "Mid PSX (640x480)", "height": 480, "tex": 256, "surfaces": true, "post": true},
	{"name": "Full PSX (320x240)", "height": 240, "tex": 256, "surfaces": true, "post": true},
]
## The ladder's starting step: Full PSX.
const LADDER_DEFAULT := 4
## Seconds between replays of one-shot particle effects.
const REPLAY_SECONDS := 1.5

var lab: Node
var lab_index := 0
var step := LADDER_DEFAULT
var caption: Label
## Draws the lab's 3D view in place of the lab's own display.
var view: TextureRect
var viewport: SubViewport
var post: LookPost
## The lab's own psx_* values, put back when the surface effects come on again.
var _psx_params := {}
## Texture -> its copy shrunk for the tex axis.
var _shrunk := {}
var _replay := 0.0


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	view = TextureRect.new()
	view.set_anchors_preset(Control.PRESET_FULL_RECT)
	view.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	view.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(view)
	caption = Label.new()
	caption.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT, Control.PRESET_MODE_MINSIZE, 8)
	caption.grow_vertical = Control.GROW_DIRECTION_BEGIN
	caption.add_theme_constant_override("outline_size", 4)
	caption.add_theme_color_override("font_outline_color", Color.BLACK)
	add_child(caption)
	resized.connect(_apply_res)
	open(0)


func open(index: int) -> void:
	if lab:
		lab.queue_free()
		await lab.tree_exited
	lab_index = index
	lab = load(LABS[index][1]).instantiate()
	add_child(lab)
	move_child(lab, 0)
	_take_view()
	_psx_params = {}
	for name: String in TKLookDefaults.GLOBALS:
		if name.begins_with("psx_"):
			_psx_params[name] = TKPsx.get_param(name)
	_run_live()
	apply_step()


## Shows the current look ladder step.
func apply_step() -> void:
	var look := LADDER[step]
	_apply_res()
	if lab.has_method("set_standard_materials"):
		lab.set_standard_materials(not look.surfaces)
	_apply_textures(look.tex)
	if look.surfaces:
		TKPsx.set_params(_psx_params)
	else:
		TKPsx.disable()
	if post:
		post.active = look.post
	caption.text = "%d  %s\nL / Shift+L  %s  (%d/%d)\n1-6 labs" % [lab_index + 1, LABS[lab_index][0],
			look.name, step + 1, LADDER.size()]


func _process(delta: float) -> void:
	_replay += delta
	if _replay < REPLAY_SECONDS:
		return
	_replay = 0.0
	for p in _descendants(lab):
		if p is CPUParticles3D and p.one_shot and not p.emitting:
			p.restart()


func _unhandled_input(event: InputEvent) -> void:
	var key := event as InputEventKey
	if not key or not key.pressed or key.echo:
		return
	if key.keycode >= KEY_1 and key.keycode < KEY_1 + LABS.size():
		open(key.keycode - KEY_1)
	elif key.keycode == KEY_L:
		step = posmod(step + (-1 if key.shift_pressed else 1), LADDER.size())
		apply_step()


## Hides the lab's own display of its SubViewport and draws that viewport here instead,
## so the ladder can resize it.
func _take_view() -> void:
	viewport = null
	post = null
	for node in _descendants(lab):
		if node is SubViewport and viewport == null:
			viewport = node
		elif node is LookPost and post == null:
			post = node
	if viewport == null:
		return
	var base := viewport.size
	for node in _descendants(lab):
		if node is SubViewportContainer:
			node.stretch = false
			node.visible = false
		elif node is TextureRect and node.texture is ViewportTexture:
			node.visible = false
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	# 2D in the viewport (labels over the scene) keeps the lab's own coordinates.
	viewport.size_2d_override = base
	viewport.size_2d_override_stretch = true
	view.texture = viewport.get_texture()


func _apply_res() -> void:
	if viewport == null:
		return
	var height: int = LADDER[step].height
	if height > 0:
		viewport.size = Vector2i(roundi(height * 4.0 / 3.0), height)
		view.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		view.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	else:
		# The window's own pixels, so the render fills it one to one.
		var scale := get_viewport().get_final_transform().get_scale()
		viewport.size = Vector2i((view.size * scale).round()).max(Vector2i.ONE)
		view.stretch_mode = TextureRect.STRETCH_SCALE
		view.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR


## Every albedo texture in the lab at `size` px on its longest side, or as made (0).
func _apply_textures(size: int) -> void:
	for node in _descendants(lab):
		if node is GeometryInstance3D:
			var materials: Array[Material] = [node.material_override]
			if node is MeshInstance3D:
				for i in node.get_surface_override_material_count():
					materials.append(node.get_surface_override_material(i))
			for m in materials:
				if m and "albedo_texture" in m:
					_resize_texture(m, size)


func _resize_texture(m: Material, size: int) -> void:
	var t: Texture2D = m.albedo_texture
	if t == null:
		return
	var source: Texture2D = t.get_meta(&"source", t)
	if size == 0 or maxi(source.get_width(), source.get_height()) <= size:
		m.albedo_texture = source
		return
	if not _shrunk.has(source):
		var img := source.get_image()
		if img.is_compressed():
			img.decompress()
		var k := float(size) / maxi(img.get_width(), img.get_height())
		img.resize(maxi(1, roundi(img.get_width() * k)), maxi(1, roundi(img.get_height() * k)), Image.INTERPOLATE_BILINEAR)
		img.generate_mipmaps()
		var small := ImageTexture.create_from_image(img)
		small.set_meta(&"source", source)
		_shrunk[source] = small
	m.albedo_texture = _shrunk[source]


## Labs freeze water, sky, effects and particles at a fixed time so captures repeat;
## here they run.
func _run_live() -> void:
	for node in [lab] + _descendants(lab):
		if "time_override" in node:
			node.time_override = -1.0
		elif "water_material" in node and node.water_material and "time_override" in node.water_material:
			node.water_material.time_override = -1.0
		if node is CPUParticles3D:
			if node.has_method("resume"):
				node.resume()
			node.restart()


func _descendants(node: Node) -> Array[Node]:
	return node.find_children("*", "", true, false)
