extends Control
## PSX sprite effects lab: dissolve and x-ray silhouettes in a 320x240 PSX view.
##
## Left: crates (PsxMaterial3D) in front and billboard figures (PSX sprites) behind,
## dissolved by 0, 25, 50 and 75 percent, one column per amount. Right: a brick wall with
## a figure built of boxes half behind it, a sprite figure wholly behind it (dithered
## silhouette) and a box figure in front of it, all with TKPsx.set_xray on.
##
## Frozen at a fixed time, so every run draws the same picture. The Clock child's
## time_override of 0 or more holds the time; negative animates: the amounts sweep and
## the figures walk along the wall. Command line (after --): --time=<seconds>,
## --look=off turns the PSX surface effects and post chain off.

const RESOLUTION := Vector2i(320, 240)
const PSX_LAB := preload("res://addons/tk_psx/lab/psx_lab.gd")
const LAB_PARAMS := {
	"psx_fog_start": 8.0,
	"psx_fog_end": 30.0,
	"psx_draw_distance": 40.0,
}
const AMOUNTS := [0.0, 0.25, 0.5, 0.75]
const COLUMN_X := [-2.3, -1.5, -0.7, 0.1]
const CRATE_Z := 1.8
const SPRITE_Z := -0.6
const WALL := Vector3(1.6, 1.1, -0.4)
const WALL_SIZE := Vector3(1.8, 2.2, 0.3)
## Where the three x-ray figures stand at time 0: half behind, wholly behind, in front.
const XRAY_FIGURES := [Vector3(0.8, 0.0, -1.4), Vector3(1.8, 0.0, -1.8), Vector3(2.0, 0.0, 0.9)]
const XRAY_COLOURS := [Color("8b9bb4"), Color("2ce8f5"), Color("8b9bb4")]
## Seconds per sweep of the dissolve amounts when animating.
const SWEEP := 4.0


## Holds the lab's time. The gallery sets time_override to -1 to let it run.
class Clock extends Node:
	var time_override := 0.0
	var elapsed := 0.0

	func now() -> float:
		return time_override if time_override >= 0.0 else elapsed

	func _process(delta: float) -> void:
		elapsed += delta


var viewport: SubViewport
var post: LookPost
var camera: Camera3D
var clock: Clock
var wall: MeshInstance3D
## Dissolving crates and sprites, each in AMOUNTS order.
var dissolving: Array[Node3D] = []
var figures: Array[Node3D] = []


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	clock = Clock.new()
	clock.name = "Clock"
	clock.time_override = float(TKArgs.value("time", "0"))
	add_child(clock)
	_build_view()
	_build_world()
	var on := TKArgs.value("look", "on") != "off"
	if on:
		TKPsx.reset()
		TKPsx.set_params(LAB_PARAMS)
	else:
		TKPsx.disable()
	post.active = on
	_build_dissolve()
	_build_xray()
	apply_time(clock.now())


func _exit_tree() -> void:
	TKPsx.reset()


func _process(_delta: float) -> void:
	if clock.time_override < 0.0:
		apply_time(clock.now())


## Puts every effect at time `t`: at 0 the dissolves sit at AMOUNTS and the figures at
## XRAY_FIGURES.
func apply_time(t: float) -> void:
	for i in dissolving.size():
		var x: float = AMOUNTS[i % AMOUNTS.size()] + t / SWEEP
		# A triangle wave through 0..1 that passes the column's amount at t = 0.
		TKPsx.set_dissolve(dissolving[i], 1.0 - absf(1.0 - fposmod(x, 2.0)))
	for i in figures.size():
		var offset := sin(t * 0.9 + i) * 0.6 - sin(float(i)) * 0.6
		figures[i].position = XRAY_FIGURES[i] + Vector3(offset, 0.0, 0.0)


func _build_view() -> void:
	var container := SubViewportContainer.new()
	container.name = "View"
	container.stretch = true
	container.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	container.set_anchors_preset(Control.PRESET_CENTER)
	container.offset_left = -RESOLUTION.x / 2.0
	container.offset_right = RESOLUTION.x / 2.0
	container.offset_top = -RESOLUTION.y / 2.0
	container.offset_bottom = RESOLUTION.y / 2.0
	add_child(container)

	viewport = SubViewport.new()
	viewport.name = "World"
	viewport.size = RESOLUTION
	viewport.own_world_3d = true
	viewport.msaa_3d = Viewport.MSAA_DISABLED
	viewport.screen_space_aa = Viewport.SCREEN_SPACE_AA_DISABLED
	viewport.canvas_item_default_texture_filter = Viewport.DEFAULT_CANVAS_ITEM_TEXTURE_FILTER_NEAREST
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	container.add_child(viewport)

	post = LookPost.new()
	post.name = "LookPost"
	TKPsx.apply_post(post)
	viewport.add_child(post)


func _build_world() -> void:
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = TKLookDefaults.GLOBALS.psx_fog_colour.value
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.32, 0.34, 0.42)
	env.tonemap_mode = Environment.TONE_MAPPER_LINEAR
	var world_env := WorldEnvironment.new()
	world_env.environment = env
	viewport.add_child(world_env)

	camera = Camera3D.new()
	camera.name = "Camera"
	camera.fov = 50.0
	camera.far = 100.0
	camera.position = Vector3(0.0, 2.4, 6.2)
	camera.rotation_degrees = Vector3(-16.0, 0.0, 0.0)
	camera.current = true
	viewport.add_child(camera)

	var sun := DirectionalLight3D.new()
	sun.light_energy = 0.8
	sun.rotation_degrees = Vector3(-50.0, -30.0, 0.0)
	viewport.add_child(sun)

	var plane := PlaneMesh.new()
	plane.size = Vector2(60.0, 60.0)
	plane.subdivide_width = 29
	plane.subdivide_depth = 29
	var mat := PsxMaterial3D.make(PSX_LAB.floor_texture())
	mat.uv_scale = Vector2(30.0, 30.0)
	_add_mesh("Floor", plane, mat, Vector3(0.0, 0.0, -20.0))

	for i in AMOUNTS.size():
		var l := Label.new()
		l.text = "%d%%" % roundi(AMOUNTS[i] * 100.0)
		l.add_theme_font_size_override("font_size", 8)
		l.add_theme_color_override("font_color", Color("c0cbdc"))
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		l.size = Vector2(40, 12)
		var x := camera.unproject_position(Vector3(COLUMN_X[i], 0.0, CRATE_Z)).x
		l.position = Vector2(roundf(x) - 20.0, 4.0)
		viewport.add_child(l)
	var xl := Label.new()
	xl.text = "x-ray"
	xl.add_theme_font_size_override("font_size", 8)
	xl.add_theme_color_override("font_color", Color("c0cbdc"))
	xl.position = Vector2(roundf(camera.unproject_position(WALL).x) - 12.0, 4.0)
	viewport.add_child(xl)


func _build_dissolve() -> void:
	var box := BoxMesh.new()
	box.size = Vector3(0.6, 0.6, 0.6)
	var crate := PsxMaterial3D.make(crate_texture())
	# BoxMesh lays its six faces out in thirds and halves of the UV square; this gives
	# each face the whole texture.
	crate.uv_scale = Vector2(3.0, 2.0)
	var figure := figure_texture()
	for i in AMOUNTS.size():
		var c := _add_mesh("Crate%d" % i, box, crate, Vector3(COLUMN_X[i], 0.3, CRATE_Z))
		c.rotation_degrees.y = 20.0
		dissolving.append(c)
	for i in AMOUNTS.size():
		var s := _add_sprite("Figure%d" % i, figure, Vector3(COLUMN_X[i], 0.0, SPRITE_Z))
		dissolving.append(s)


func _build_xray() -> void:
	var box := BoxMesh.new()
	box.size = WALL_SIZE
	var mat := PsxMaterial3D.make(PSX_LAB.pillar_texture())
	mat.uv_scale = Vector2(2.0, 1.0)
	wall = _add_mesh("Wall", box, mat, WALL)
	TKPsx.tessellate(box)
	figures = [_box_figure("XrayFigure0"), _add_sprite("XrayFigure1", figure_texture(), Vector3.ZERO), _box_figure("XrayFigure2")]
	for i in figures.size():
		figures[i].position = XRAY_FIGURES[i]
		TKPsx.set_xray(figures[i], true, XRAY_COLOURS[i], 0.5 if i == 1 else 0.0)


## A figure of boxes: legs, body and head, 1.4 m tall, under one Node3D.
func _box_figure(node_name: String) -> Node3D:
	var root := Node3D.new()
	root.name = node_name
	viewport.add_child(root)
	var cloth := PsxMaterial3D.make(null, Color("124e89"))
	var skin := PsxMaterial3D.make(null, Color("e8b796"))
	var parts := [
		[Vector3(0.16, 0.6, 0.2), Vector3(-0.1, 0.3, 0.0), cloth],
		[Vector3(0.16, 0.6, 0.2), Vector3(0.1, 0.3, 0.0), cloth],
		[Vector3(0.5, 0.5, 0.26), Vector3(0.0, 0.85, 0.0), cloth],
		[Vector3(0.28, 0.28, 0.28), Vector3(0.0, 1.26, 0.0), skin],
	]
	for p: Array in parts:
		var m := BoxMesh.new()
		m.size = p[0]
		var mi := MeshInstance3D.new()
		mi.mesh = m
		mi.material_override = p[2]
		mi.position = p[1]
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		root.add_child(mi)
	return root


func _add_mesh(node_name: String, mesh: Mesh, mat: Material, pos: Vector3) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.name = node_name
	mi.mesh = mesh
	mi.material_override = mat
	mi.position = pos
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	viewport.add_child(mi)
	return mi


## A PSX sprite standing on the floor at `pos`, turning about y to face the camera.
func _add_sprite(node_name: String, texture: Texture2D, pos: Vector3) -> Sprite3D:
	var s := Sprite3D.new()
	s.name = node_name
	s.texture = texture
	s.pixel_size = 0.05
	s.offset = Vector2(0.0, texture.get_height() / 2.0)
	s.billboard = BaseMaterial3D.BILLBOARD_FIXED_Y
	s.position = pos
	viewport.add_child(s)
	TKPsx.apply_to_sprite(s)
	return s


## 16x16 crate: dark frame, planks and a diagonal brace.
static func crate_texture() -> ImageTexture:
	var img := Image.create_empty(16, 16, false, Image.FORMAT_RGBA8)
	var frame := Color(0.36, 0.22, 0.14)
	var plank := Color(0.66, 0.45, 0.28)
	var light := Color(0.82, 0.62, 0.4)
	img.fill(frame)
	img.fill_rect(Rect2i(2, 2, 12, 12), plank)
	for y in [5, 9]:
		img.fill_rect(Rect2i(2, y, 12, 1), frame)
	for i in 12:
		img.set_pixel(2 + i, 2 + i, light)
	img.fill_rect(Rect2i(0, 0, 16, 1), light)
	return ImageTexture.create_from_image(img)


## 16x28 standing figure with a transparent background, for the sprite rows.
static func figure_texture() -> ImageTexture:
	const ROWS := [
		"................",
		"......kkkk......",
		".....kkkkkk.....",
		".....kkkkkk.....",
		".....kkkkkk.....",
		"......kkkk......",
		"...mmmmmmmmmm...",
		"..mmmmmmmmmmmm..",
		"..mmmmmmmmmmmm..",
		"..mm.mmmmmm.mm..",
		"..mm.mmmmmm.mm..",
		"..kk.mmmmmm.kk..",
		"..kk.mmmmmm.kk..",
		".....mmmmmm.....",
		".....ssssss.....",
		".....ss..ss.....",
		".....ss..ss.....",
		".....ss..ss.....",
		".....ss..ss.....",
		".....ss..ss.....",
		".....ss..ss.....",
		".....ss..ss.....",
		".....ss..ss.....",
		".....ss..ss.....",
		"....ddd..ddd....",
		"....ddd..ddd....",
		"................",
		"................",
	]
	var colours := { "k": Color("e8b796"), "m": Color("b55088"), "s": Color("3a4466"), "d": Color("262b44") }
	var img := Image.create_empty(16, ROWS.size(), false, Image.FORMAT_RGBA8)
	for y in ROWS.size():
		var row: String = ROWS[y]
		for x in row.length():
			if colours.has(row[x]):
				img.set_pixel(x, y, colours[row[x]])
	return ImageTexture.create_from_image(img)
