extends Control
## PSX sky lab: the PSX lab's stone floor and a corridor of pillars running into fog under
## a PsxSkyMaterial, at 320x240 through the PSX post chain. The fog and the sky meet at
## the horizon, so the far floor and pillars must fade into the sky with no seam.
##
## Two skies: a gradient with a sun and a scrolling cloud band, and a generated
## low-resolution panorama (twilight with stars and two mountain ridges) mirrored below
## the horizon. M switches between them. The camera pans slowly from side to side.
##
## Time is frozen at a fixed value, so every run draws the same picture; set
## time_override negative (the gallery does) to pan and scroll live.
##
## Command line (after --):
##   --time=<seconds>        frozen time; negative animates
##   --sky=gradient|panorama which sky to start with
##   --look=off              every PSX effect off and the post chain inactive, to compare

const RESOLUTION := Vector2i(320, 240)
const DEFAULT_TIME := 4.0
## The look.json defaults for fog and draw distance: fog is solid well inside the draw
## distance, so nothing pops in against the sky.
const LAB_PARAMS := {
	"psx_fog_start": 6.0,
	"psx_fog_end": 30.0,
	"psx_draw_distance": 40.0,
}
const PSX_LAB := preload("res://addons/tk_psx/lab/psx_lab.gd")
const FLOOR_SIZE := 160.0
const FLOOR_TILES := 40
const PILLAR_SPACING := 5.0
const PILLAR_COUNT := 12
## Pan: degrees either side of straight down the corridor, and radians per second.
const PAN_DEGREES := 35.0
const PAN_SPEED := 0.2
const CAMERA_PITCH := 6.0

## 0 or more freezes the camera pan and the clouds at that time; negative runs live.
var time_override := DEFAULT_TIME:
	set(value):
		time_override = value
		if gradient_sky:
			gradient_sky.time_override = value
			panorama_sky.time_override = value
		if value >= 0.0:
			_time = value

var viewport: SubViewport
var post: LookPost
var camera: Camera3D
var environment: Environment
var gradient_sky: PsxSkyMaterial
var panorama_sky: PsxSkyMaterial
var label: Label

var _time := DEFAULT_TIME


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	_build_view()
	_build_world()
	time_override = float(TKArgs.value("time", str(DEFAULT_TIME)))
	set_panorama(TKArgs.value("sky", "gradient") == "panorama")
	var on := TKArgs.value("look", "on") != "off"
	if on:
		TKPsx.reset()
		TKPsx.set_params(LAB_PARAMS)
	else:
		TKPsx.disable()
	post.active = on
	_update_camera()


func _exit_tree() -> void:
	TKPsx.reset()


func _process(delta: float) -> void:
	if time_override < 0.0:
		_time += delta
	_update_camera()


func _unhandled_input(event: InputEvent) -> void:
	var key := event as InputEventKey
	if key and key.pressed and not key.echo and key.keycode == KEY_M:
		set_panorama(not is_panorama())
		get_viewport().set_input_as_handled()


## Shows the panorama sky (true) or the gradient sky (false).
func set_panorama(on: bool) -> void:
	environment.sky.sky_material = panorama_sky if on else gradient_sky
	label.text = "Panorama sky, mirrored below. M: gradient" if on else "Gradient sky, sun, clouds. M: panorama"


func is_panorama() -> bool:
	return environment.sky.sky_material == panorama_sky


func _update_camera() -> void:
	camera.rotation_degrees = Vector3(CAMERA_PITCH, PAN_DEGREES * sin(_time * PAN_SPEED), 0.0)


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

	label = Label.new()
	label.name = "Caption"
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	label.offset_left = -RESOLUTION.x / 2.0
	label.offset_right = RESOLUTION.x / 2.0
	label.offset_top = -40.0
	label.offset_bottom = -20.0
	label.add_theme_font_size_override("font_size", 8)
	add_child(label)


func _build_world() -> void:
	gradient_sky = PsxSkyMaterial.make(Color("#1b3a6b"), 1.6)
	gradient_sky.sun_enabled = true
	gradient_sky.sun_direction = Vector3(-0.42, 0.42, -0.8)
	gradient_sky.sun_size = 3.0
	gradient_sky.clouds_enabled = true

	panorama_sky = PsxSkyMaterial.new()
	panorama_sky.mode = PsxSkyMaterial.Mode.PANORAMA
	panorama_sky.panorama = panorama_texture()
	panorama_sky.panorama_below = PsxSkyMaterial.Below.MIRROR
	panorama_sky.panorama_fade = 0.06

	environment = TKPsx.make_sky(gradient_sky, Color(0.36, 0.38, 0.46))
	var world_env := WorldEnvironment.new()
	world_env.name = "Environment"
	world_env.environment = environment
	viewport.add_child(world_env)

	camera = Camera3D.new()
	camera.name = "Camera"
	camera.fov = 60.0
	camera.near = 0.1
	camera.far = 300.0
	camera.position = Vector3(0.0, 1.7, 6.0)
	camera.current = true
	viewport.add_child(camera)

	var sun := DirectionalLight3D.new()
	sun.name = "Sun"
	sun.light_color = Color(1.0, 0.95, 0.85)
	sun.light_energy = 0.7
	sun.rotation_degrees = Vector3(-50.0, -30.0, 0.0)
	viewport.add_child(sun)

	var plane := PlaneMesh.new()
	plane.size = Vector2(FLOOR_SIZE, FLOOR_SIZE)
	plane.subdivide_width = FLOOR_TILES - 1
	plane.subdivide_depth = FLOOR_TILES - 1
	var floor_mat := PsxMaterial3D.make(PSX_LAB.floor_texture())
	floor_mat.uv_scale = Vector2(FLOOR_TILES, FLOOR_TILES)
	_add_mesh("Floor", plane, floor_mat, Vector3(0.0, 0.0, 6.0))

	var box := BoxMesh.new()
	box.size = Vector3(0.6, 3.0, 0.6)
	var pillar_mat := PsxMaterial3D.make(PSX_LAB.pillar_texture())
	pillar_mat.uv_scale = Vector2(3.0, 6.0)
	for i in PILLAR_COUNT:
		for side in [-1.0, 1.0]:
			_add_mesh("Pillar%d%s" % [i, "L" if side < 0.0 else "R"], box, pillar_mat, Vector3(2.6 * side, 1.5, -i * PILLAR_SPACING))


func _add_mesh(node_name: String, mesh: Mesh, mat: Material, pos: Vector3) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.name = node_name
	mi.mesh = mesh
	mi.material_override = mat
	mi.position = pos
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	viewport.add_child(mi)
	return mi


## A 256x64 twilight panorama (1.4 degrees a texel), generated so the lab needs no image
## files: a banded sky lightening towards the horizon, stars from a seeded PCG32 stream,
## and a far and a near mountain ridge along the bottom rows. Wraps around the horizon.
static func panorama_texture() -> ImageTexture:
	const W := 256
	const H := 64
	var bands := [Color("#181425"), Color("#1d2240"), Color("#262b44"), Color("#2e3a5e"), Color("#3a4466"), Color("#4b5b85")]
	var star := Color("#c0cbdc")
	var far := Color("#2e3a5e")
	var near := Color("#1d2240")
	var img := Image.create_empty(W, H, false, Image.FORMAT_RGBA8)
	for y in H:
		var band: int = mini(bands.size() - 1, y * bands.size() / H)
		for x in W:
			img.set_pixel(x, y, bands[band])
	var rng := TKPcg32.new(5, "psx_sky_lab")
	for i in 140:
		img.set_pixel(rng.next_range(0, W - 1), rng.next_range(0, 50), star)
	# Ridges: heights in texels above the bottom row, from whole sine periods with seeded
	# phases, so they wrap.
	var phases: Array[float] = []
	for i in 4:
		phases.append(rng.next_float() * TAU)
	for x in W:
		var a := TAU * x / W
		var far_h := roundi(5.0 + 2.0 * sin(a * 3.0 + phases[0]) + 1.2 * sin(a * 11.0 + phases[1]))
		var near_h := roundi(2.5 + 1.2 * sin(a * 5.0 + phases[2]) + 0.8 * sin(a * 17.0 + phases[3]))
		for y in range(H - far_h, H):
			img.set_pixel(x, y, far)
		for y in range(H - near_h, H):
			img.set_pixel(x, y, near)
	return ImageTexture.create_from_image(img)
