extends Control
## PSX particles lab: every PsxParticles3D preset in a 320x240 PSX view, frozen at fixed
## times so every run draws the same picture.
##
## Front row: each preset early in its life, 5.5 m from the camera. Back row: the same
## presets later in their lives and 12 m further away, in the fog, where the dither fade
## and the one-pixel minimum size show. Floor, fog, snap and post chain as in the PSX lab.
##
## Command line (after --): --look=off turns the PSX surface effects and post chain off.
## --palette=<name> constrains particles to a palette instead of quantising them.
## --fade=cut|steps|dither picks the fade.

const RESOLUTION := Vector2i(320, 240)
const PSX_LAB := preload("res://addons/tk_psx/lab/psx_lab.gd")
const LAB_PARAMS := {
	"psx_fog_start": 4.0,
	"psx_fog_end": 30.0,
	"psx_draw_distance": 40.0,
}
const SPACING := 1.2
const CAMERA_Z := 5.5
const BACK_ROW_Z := -12.0
## Preset, height of the emitter above the floor, and the two times it is frozen at.
const CELLS := [
	[PsxParticles3D.Preset.DUST, 0.0, [0.12, 0.4]],
	[PsxParticles3D.Preset.SPARKS, 0.1, [0.1, 0.3]],
	[PsxParticles3D.Preset.SMOKE, 0.0, [1.0, 3.0]],
	[PsxParticles3D.Preset.HIT, 0.9, [0.04, 0.14]],
	[PsxParticles3D.Preset.SPARKLE, 0.6, [0.2, 0.5]],
]
const FADES := { "cut": PsxParticlesMaterial3D.Fade.CUT, "steps": PsxParticlesMaterial3D.Fade.STEPS, "dither": PsxParticlesMaterial3D.Fade.DITHER }

var viewport: SubViewport
var post: LookPost
var camera: Camera3D
var emitters: Array[PsxParticles3D] = []


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
	_build_emitters()


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
	env.ambient_light_color = Color(0.32, 0.34, 0.42)
	env.tonemap_mode = Environment.TONE_MAPPER_LINEAR
	var world_env := WorldEnvironment.new()
	world_env.environment = env
	viewport.add_child(world_env)

	camera = Camera3D.new()
	camera.name = "Camera"
	camera.fov = 50.0
	camera.far = 100.0
	camera.position = Vector3(0.0, 2.2, CAMERA_Z)
	camera.rotation_degrees = Vector3(-14.0, 0.0, 0.0)
	camera.current = true
	viewport.add_child(camera)

	var sun := DirectionalLight3D.new()
	sun.light_energy = 0.7
	sun.rotation_degrees = Vector3(-50.0, -30.0, 0.0)
	viewport.add_child(sun)

	var plane := PlaneMesh.new()
	plane.size = Vector2(60.0, 60.0)
	plane.subdivide_width = 29
	plane.subdivide_depth = 29
	var mat := PsxMaterial3D.make(PSX_LAB.floor_texture())
	mat.uv_scale = Vector2(30.0, 30.0)
	var floor_mesh := MeshInstance3D.new()
	floor_mesh.name = "Floor"
	floor_mesh.mesh = plane
	floor_mesh.material_override = mat
	floor_mesh.position = Vector3(0.0, 0.0, -20.0)
	floor_mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	viewport.add_child(floor_mesh)

	# One label over each column, centred on where the front row lands on screen.
	for i in CELLS.size():
		var l := Label.new()
		l.text = PsxParticles3D.PRESET_NAMES.find_key(CELLS[i][0])
		l.add_theme_font_size_override("font_size", 8)
		l.add_theme_color_override("font_color", Color("c0cbdc"))
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		l.size = Vector2(56, 12)
		var x := camera.unproject_position(Vector3(_column_x(i), 0.5, 0.0)).x
		l.position = Vector2(roundf(x) - 28.0, 4.0)
		viewport.add_child(l)


func _build_emitters() -> void:
	var palette := TKArgs.value("palette", "none")
	var fade: PsxParticlesMaterial3D.Fade = FADES.get(TKArgs.value("fade", "dither"), PsxParticlesMaterial3D.Fade.DITHER)
	for i in CELLS.size():
		var cell: Array = CELLS[i]
		for row in 2:
			var p := PsxParticles3D.make(cell[0])
			p.palette_name = palette
			p.fade = fade
			# The back row is spread so each column stays under its label.
			var x := _column_x(i) * (1.0 if row == 0 else (CAMERA_Z - BACK_ROW_Z) / CAMERA_Z)
			p.position = Vector3(x, cell[1], 0.0 if row == 0 else BACK_ROW_Z)
			viewport.add_child(p)
			p.freeze_at(cell[2][row])
			emitters.append(p)


func _column_x(i: int) -> float:
	return (i - (CELLS.size() - 1) / 2.0) * SPACING
