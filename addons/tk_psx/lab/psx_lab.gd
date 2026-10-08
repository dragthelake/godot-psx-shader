extends Control
## PSX look lab. Renders a fixed 3D scene at 320x240 through PsxMaterial3D and the PSX
## post chain, so each effect has something that shows it:
##
## - floor of large stone tiles running into the distance: affine warp, fog, texture LOD
## - rotating checker cube: vertex snap
## - corridor of pillars: draw distance pop-in
## - gradient sign over the corridor: quantise and dither
## - low-poly sphere under red, green and blue point lights: vertex lighting
##
## Everything is built in code from fixed values, so every run draws the same frames.
##
## Command line (after --):
##   --look=off       every PSX effect off and the post chain inactive, to compare
##   --snap=WxH       vertex snap grid, e.g. --snap=160x120 to exaggerate the jitter

const RESOLUTION := Vector2i(320, 240)
## Lab values for the psx_* globals. Fog ends past the draw distance so the pillars and
## floor visibly pop in and out instead of vanishing inside solid fog.
const LAB_PARAMS := {
	"psx_fog_start": 6.0,
	"psx_fog_end": 48.0,
	"psx_draw_distance": 34.0,
}
const FLOOR_SIZE := 160.0
const FLOOR_TILES := 40
const PILLAR_SPACING := 5.0
const PILLAR_COUNT := 21
const CUBE_SPEED := 0.6

var stack_on := true
var viewport: SubViewport
var post: LookPost
var camera: Camera3D
var cube: MeshInstance3D
var sphere: MeshInstance3D
var pillars: Array[MeshInstance3D] = []
var floor_mesh: MeshInstance3D
var gradient_wall: MeshInstance3D

var _time := 0.0


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	_build_view()
	_build_world()
	set_stack(TKArgs.value("look", "on") != "off")


func _exit_tree() -> void:
	TKPsx.reset()


func _process(delta: float) -> void:
	_time += delta
	cube.rotation = Vector3(_time * CUBE_SPEED * 0.45, _time * CUBE_SPEED, 0.0)


## Turns the whole PSX stack on (lab values) or off.
func set_stack(on: bool) -> void:
	stack_on = on
	if on:
		TKPsx.reset()
		TKPsx.set_params(LAB_PARAMS)
		var snap := TKArgs.value("snap")
		if snap.contains("x"):
			var parts := snap.split("x")
			TKPsx.set_params({ "psx_snap_resolution": Vector2(float(parts[0]), float(parts[1])) })
	else:
		TKPsx.disable()
	post.active = on


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
	var fog: Color = TKLookDefaults.GLOBALS.psx_fog_colour.value
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = fog
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.32, 0.34, 0.42)
	env.ambient_light_energy = 1.0
	env.tonemap_mode = Environment.TONE_MAPPER_LINEAR
	var world_env := WorldEnvironment.new()
	world_env.environment = env
	viewport.add_child(world_env)

	camera = Camera3D.new()
	camera.name = "Camera"
	camera.fov = 60.0
	camera.near = 0.1
	camera.far = 300.0
	camera.position = Vector3(0.0, 1.7, 6.0)
	camera.rotation_degrees = Vector3(-8.0, 0.0, 0.0)
	camera.current = true
	viewport.add_child(camera)

	var sun := DirectionalLight3D.new()
	sun.name = "Sun"
	sun.light_color = Color(1.0, 0.95, 0.85)
	sun.light_energy = 0.7
	sun.rotation_degrees = Vector3(-50.0, -30.0, 0.0)
	viewport.add_child(sun)

	_build_floor()
	_build_pillars()
	_build_cube()
	_build_sphere()
	_build_gradient_wall()


func _build_floor() -> void:
	var plane := PlaneMesh.new()
	plane.size = Vector2(FLOOR_SIZE, FLOOR_SIZE)
	plane.subdivide_width = FLOOR_TILES - 1
	plane.subdivide_depth = FLOOR_TILES - 1
	var mat := PsxMaterial3D.make(floor_texture())
	mat.uv_scale = Vector2(FLOOR_TILES, FLOOR_TILES)
	floor_mesh = _add_mesh("Floor", plane, mat, Vector3(0.0, 0.0, 6.0 - FLOOR_SIZE / 2.0 + 14.0))


func _build_pillars() -> void:
	var box := BoxMesh.new()
	box.size = Vector3(0.6, 3.0, 0.6)
	var mat := PsxMaterial3D.make(pillar_texture())
	# BoxMesh maps each face to a third by a half of the texture; repeat the bricks.
	mat.uv_scale = Vector2(3.0, 6.0)
	for i in PILLAR_COUNT:
		for side in [-1.0, 1.0]:
			var p := _add_mesh("Pillar%d%s" % [i, "L" if side < 0.0 else "R"], box, mat, Vector3(2.6 * side, 1.5, -i * PILLAR_SPACING))
			pillars.append(p)


func _build_cube() -> void:
	var box := BoxMesh.new()
	box.size = Vector3.ONE * 1.1
	cube = _add_mesh("Cube", box, PsxMaterial3D.make(checker_texture()), Vector3(-1.35, 1.0, 2.2))


func _build_sphere() -> void:
	var mesh := SphereMesh.new()
	mesh.radius = 0.75
	mesh.height = 1.5
	mesh.radial_segments = 10
	mesh.rings = 5
	sphere = _add_mesh("Sphere", mesh, PsxMaterial3D.make(null, Color(0.6, 0.6, 0.6)), Vector3(1.35, 0.95, 2.2))
	var lights := [
		[Color(1.0, 0.1, 0.05), Vector3(-1.0, 0.5, 0.9)],
		[Color(0.1, 1.0, 0.15), Vector3(1.0, 0.5, 0.9)],
		[Color(0.15, 0.3, 1.0), Vector3(0.0, -0.6, 1.1)],
	]
	for i in lights.size():
		var light := OmniLight3D.new()
		light.name = "Light%d" % i
		light.light_color = lights[i][0]
		light.light_energy = 3.5
		light.omni_range = 2.4
		light.position = sphere.position + lights[i][1]
		viewport.add_child(light)


func _build_gradient_wall() -> void:
	# Two vertex colours across a quad: a smooth ramp for the quantise pass to band and
	# dither.
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var w := 3.2
	var h := 0.55
	var left := Color(0.08, 0.1, 0.25)
	var right := Color(0.95, 0.55, 0.25)
	# Clockwise seen from the camera: Godot's front face.
	var corners := [
		[Vector3(-w, -h, 0.0), left], [Vector3(w, h, 0.0), right], [Vector3(w, -h, 0.0), right],
		[Vector3(-w, -h, 0.0), left], [Vector3(-w, h, 0.0), left], [Vector3(w, h, 0.0), right],
	]
	for c in corners:
		st.set_color(c[1])
		st.set_normal(Vector3.BACK)
		st.set_uv(Vector2.ZERO)
		st.add_vertex(c[0])
	var mat := PsxMaterial3D.make(null, Color.WHITE, PsxMaterial3D.Shading.UNLIT)
	gradient_wall = _add_mesh("GradientWall", st.commit(), mat, Vector3(0.0, 4.0, -2.0))


func _add_mesh(node_name: String, mesh: Mesh, mat: Material, pos: Vector3) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.name = node_name
	mi.mesh = mesh
	mi.material_override = mat
	mi.position = pos
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	viewport.add_child(mi)
	return mi


# --- Textures, generated so the lab needs no image files --------------------------------

## 32x32: four stones of 16x16 with dark mortar lines and fixed shading per stone.
static func floor_texture() -> ImageTexture:
	var img := Image.create_empty(32, 32, false, Image.FORMAT_RGBA8)
	var shades := [Color(0.55, 0.5, 0.42), Color(0.47, 0.43, 0.37), Color(0.5, 0.47, 0.4), Color(0.6, 0.55, 0.45)]
	var mortar := Color(0.2, 0.18, 0.16)
	for y in 32:
		for x in 32:
			var stone: int = (x / 16) + 2 * (y / 16)
			var c: Color = shades[stone]
			if x % 16 == 0 or y % 16 == 0:
				c = mortar
			elif (x * 7 + y * 13) % 11 == 0:
				c = c.darkened(0.12)
			img.set_pixel(x, y, c)
	return ImageTexture.create_from_image(img)


## 16x16 checker of 4x4 squares.
static func checker_texture() -> ImageTexture:
	var img := Image.create_empty(16, 16, false, Image.FORMAT_RGBA8)
	for y in 16:
		for x in 16:
			var odd := ((x / 4) + (y / 4)) % 2 == 1
			img.set_pixel(x, y, Color(0.85, 0.2, 0.2) if odd else Color(0.95, 0.9, 0.75))
	return ImageTexture.create_from_image(img)


## 16x32 bricks in courses of 8 pixels, offset every other course.
static func pillar_texture() -> ImageTexture:
	var img := Image.create_empty(16, 32, false, Image.FORMAT_RGBA8)
	for y in 32:
		var course := y / 8
		for x in 16:
			var bx := (x + (4 if course % 2 == 1 else 0)) % 8
			var c := Color(0.62, 0.36, 0.28) if (course + (x + (4 if course % 2 == 1 else 0)) / 8) % 2 == 0 else Color(0.56, 0.32, 0.26)
			if y % 8 == 0 or bx == 0:
				c = Color(0.3, 0.26, 0.24)
			img.set_pixel(x, y, c)
	return ImageTexture.create_from_image(img)
