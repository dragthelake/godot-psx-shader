extends Control
## PSX water lab: a stone pool of PsxWater3D at 320x240, with banks, pillars and
## stepping stones of PSX blocks around and in it, a tiled floor under the water, and the
## camera looking across. The water is frozen at a fixed time, so every run draws the
## same frames.
##
## Command line (after --):
##   --time=<seconds>  frozen water time; negative animates
##   --look=off        every PSX effect off and the post chain inactive, to compare

const RESOLUTION := Vector2i(320, 240)
const DEFAULT_TIME := 2.0
const LAB_PARAMS := {
	"psx_fog_start": 10.0,
	"psx_fog_end": 46.0,
	"psx_draw_distance": 60.0,
}
const LAB := preload("res://addons/tk_psx/lab/psx_lab.gd")
## Pool interior: x from -POOL.x to POOL.x, z from POOL_NEAR to POOL_FAR.
const POOL_HALF_WIDTH := 8.0
const POOL_NEAR := 2.0
const POOL_FAR := -22.0
const POOL_DEPTH := 1.6
const WATER_LEVEL := -0.3

var viewport: SubViewport
var post: LookPost
var camera: Camera3D
var water: PsxWater3D
var blocks: Array[MeshInstance3D] = []


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	_build_view()
	_build_world()
	var on := TKArgs.value("look", "on") != "off"
	if on:
		TKPsx.reset()
		TKPsx.set_params(LAB_PARAMS)
	else:
		TKPsx.disable()
	post.active = on


func _exit_tree() -> void:
	TKPsx.reset()


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
	env.ambient_light_color = Color(0.36, 0.38, 0.46)
	env.tonemap_mode = Environment.TONE_MAPPER_LINEAR
	var world_env := WorldEnvironment.new()
	world_env.environment = env
	viewport.add_child(world_env)

	camera = Camera3D.new()
	camera.name = "Camera"
	camera.fov = 60.0
	camera.far = 200.0
	camera.position = Vector3(1.5, 2.4, 4.2)
	camera.rotation_degrees = Vector3(-15.0, 6.0, 0.0)
	camera.current = true
	viewport.add_child(camera)

	var sun := DirectionalLight3D.new()
	sun.name = "Sun"
	sun.light_color = Color(1.0, 0.95, 0.85)
	sun.light_energy = 0.8
	sun.rotation_degrees = Vector3(-38.0, 35.0, 0.0)
	viewport.add_child(sun)

	_build_pool()
	_build_blocks()

	water = PsxWater3D.new()
	water.name = "Water"
	water.size = Vector2(POOL_HALF_WIDTH * 2.0, POOL_NEAR - POOL_FAR)
	water.cell_size = 1.0
	water.position = Vector3(0.0, WATER_LEVEL, (POOL_NEAR + POOL_FAR) / 2.0)
	water.water_material.wave_height = 0.2
	water.water_material.time_override = float(TKArgs.value("time", str(DEFAULT_TIME)))
	viewport.add_child(water)


func _build_pool() -> void:
	var stone := LAB.floor_texture()
	var length := POOL_NEAR - POOL_FAR
	var mid_z := (POOL_NEAR + POOL_FAR) / 2.0
	# Pool floor, under the water.
	var floor_mesh := PlaneMesh.new()
	floor_mesh.size = Vector2(POOL_HALF_WIDTH * 2.0, length)
	floor_mesh.subdivide_width = 7
	floor_mesh.subdivide_depth = 11
	var floor_mat := PsxMaterial3D.make(tile_texture())
	floor_mat.uv_scale = Vector2(POOL_HALF_WIDTH, length / 2.0)
	_add_mesh("PoolFloor", floor_mesh, floor_mat, Vector3(0.0, -POOL_DEPTH, mid_z))
	# Banks: four blocks around the pool, their tops at y 0.
	var banks := [
		[Vector3(6.0, POOL_DEPTH, length + 12.0), Vector3(-POOL_HALF_WIDTH - 3.0, -POOL_DEPTH / 2.0, mid_z)],
		[Vector3(6.0, POOL_DEPTH, length + 12.0), Vector3(POOL_HALF_WIDTH + 3.0, -POOL_DEPTH / 2.0, mid_z)],
		[Vector3(POOL_HALF_WIDTH * 2.0, POOL_DEPTH, 6.0), Vector3(0.0, -POOL_DEPTH / 2.0, POOL_NEAR + 3.0)],
		[Vector3(POOL_HALF_WIDTH * 2.0, POOL_DEPTH, 6.0), Vector3(0.0, -POOL_DEPTH / 2.0, POOL_FAR - 3.0)],
	]
	for i in banks.size():
		var box := BoxMesh.new()
		box.size = banks[i][0]
		box.subdivide_width = 4
		box.subdivide_depth = 6
		# BoxMesh gives the top face a third of the texture's width and half its height;
		# scale so one repeat (2 x 2 stones) covers 2 m.
		var mat := PsxMaterial3D.make(stone)
		mat.uv_scale = Vector2(box.size.x * 1.5, box.size.z)
		_add_mesh("Bank%d" % i, box, mat, banks[i][1])


func _build_blocks() -> void:
	var bricks := PsxMaterial3D.make(LAB.pillar_texture())
	bricks.uv_scale = Vector2(3.0, 6.0)
	var crate := PsxMaterial3D.make(crate_texture())
	# Pillars standing in the water.
	for p: Vector3 in [Vector3(-4.0, 0.9, -5.0), Vector3(4.5, 0.9, -11.0), Vector3(-2.5, 0.9, -17.0)]:
		var box := BoxMesh.new()
		box.size = Vector3(0.9, 5.0, 0.9)
		_add_mesh("Pillar", box, bricks, p)
	# Stepping stones, just above the water.
	for p: Vector3 in [Vector3(1.0, -0.6, -2.0), Vector3(2.2, -0.6, -4.2), Vector3(1.4, -0.6, -6.6)]:
		var box := BoxMesh.new()
		box.size = Vector3(1.1, 0.8, 1.1)
		_add_mesh("Stone", box, PsxMaterial3D.make(LAB.floor_texture()), p)
	# Crates on the side banks and the far bank.
	for p: Vector3 in [Vector3(-9.6, 0.5, -3.0), Vector3(-10.8, 0.5, -2.2), Vector3(-10.2, 1.5, -2.6), Vector3(9.8, 0.6, -9.0), Vector3(5.0, 0.6, -24.0), Vector3(3.6, 0.6, -24.5)]:
		var box := BoxMesh.new()
		box.size = Vector3.ONE * (1.0 if p.x < 0.0 else 1.2)
		_add_mesh("Crate", box, crate, p)
	# A ruined wall on the far bank.
	var wall := BoxMesh.new()
	wall.size = Vector3(10.0, 3.0, 0.8)
	var wall_mat := PsxMaterial3D.make(LAB.pillar_texture())
	wall_mat.uv_scale = Vector2(10.0, 4.0)
	_add_mesh("Wall", wall, wall_mat, Vector3(-3.0, 1.5, -26.0))


func _add_mesh(node_name: String, mesh: Mesh, mat: Material, pos: Vector3) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.name = node_name
	mi.mesh = mesh
	mi.material_override = mat
	mi.position = pos
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	viewport.add_child(mi)
	blocks.append(mi)
	return mi


# --- Textures, generated so the lab needs no image files --------------------------------

## 16x16 pool tile: pale squares of 8x8 with grout lines.
static func tile_texture() -> ImageTexture:
	var img := Image.create_empty(16, 16, false, Image.FORMAT_RGBA8)
	for y in 16:
		for x in 16:
			var c := Color(0.82, 0.78, 0.62) if ((x / 8) + (y / 8)) % 2 == 0 else Color(0.74, 0.7, 0.56)
			if x % 8 == 0 or y % 8 == 0:
				c = Color(0.45, 0.42, 0.36)
			img.set_pixel(x, y, c)
	return ImageTexture.create_from_image(img)


## 16x16 crate: planks with a dark frame and a cross brace.
static func crate_texture() -> ImageTexture:
	var img := Image.create_empty(16, 16, false, Image.FORMAT_RGBA8)
	for y in 16:
		for x in 16:
			var c := Color(0.62, 0.44, 0.24) if (y / 4) % 2 == 0 else Color(0.56, 0.39, 0.21)
			if x == 0 or y == 0 or x == 15 or y == 15 or x == y or x == 15 - y:
				c = Color(0.32, 0.22, 0.12)
			img.set_pixel(x, y, c)
	return ImageTexture.create_from_image(img)
