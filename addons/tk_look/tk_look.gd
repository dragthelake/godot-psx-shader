extends Node
## Look autoload: global shader parameters for the look stacks, hit flash, and screen
## transitions. Autoloaded as TKLook.
##
## Global parameters (look_*, look_crt_*, psx_*, pixel_*) are declared in each project's
## [shader_globals] by scripts/export look. Any that a project lacks are registered here
## at startup with the defaults from look.json, so shaders always find them.
##
## Transitions draw over everything, on a CanvasLayer at layer 128 of the root viewport.
## With the project setting toolkit/look/internal_resolution set, their edges snap to
## that pixel grid.

const PALETTE_DIR := "res://addons/tk_look/generated/palettes/"
const FLASH_CANVAS := preload("res://addons/tk_look/shaders/flash_canvas.gdshader")
const FLASH_3D := preload("res://addons/tk_look/shaders/flash_3d.gdshader")
const TRANSITION := preload("res://addons/tk_look/shaders/transition.gdshader")
const CRT := preload("res://addons/tk_look/shaders/crt.gdshader")

## Transition kinds. Each sets the transition shader's uniforms; "range" is the progress
## value that fully uncovers the screen and "grows" marks kinds whose covered area grows
## with progress.
const TRANSITIONS := {
	"fade": {},
	"box": { "transition_type": 0, "position": Vector2(0.5, 0.5), "range": 1.0 },
	"blinds": { "transition_type": 0, "position": Vector2(0.5, 0.5), "grid_size": Vector2(1.0, 9.0), "range": 1.0 },
	"diamond": { "transition_type": 2, "position": Vector2(0.5, 0.5), "edges": 4, "rotation_angle": 45.0, "shape_feather": 0.0, "range": "diamond" },
	"circle": { "transition_type": 2, "position": Vector2(0.5, 0.5), "edges": 64, "shape_feather": 0.0, "range": "circle" },
	"clock": { "transition_type": 3, "position": Vector2(0.5, 0.5), "sectors": 1, "clock_feather": 0.001, "rotation_angle": -90.0, "range": 1.0, "grows": true },
	"dissolve": { "transition_type": 4, "range": 1.0 },
	"wipe": { "transition_type": 5, "position": Vector2(0.5, 0.5), "range": 1.0 },
}

static var _values := {}

var transition_kind := ""
var transition_amount := 0.0

var _layer: CanvasLayer
var _rect: ColorRect
var _material: ShaderMaterial
var _tween: Tween
var _flash_canvas: ShaderMaterial
var _flash_3d: ShaderMaterial


func _init() -> void:
	ensure_globals()


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_layer = CanvasLayer.new()
	_layer.layer = 128
	_layer.name = "Transition"
	add_child(_layer)
	_rect = ColorRect.new()
	_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_rect.color = Color.BLACK
	_rect.visible = false
	_layer.add_child(_rect)
	_material = ShaderMaterial.new()
	_material.shader = TRANSITION
	var grid: Variant = ProjectSettings.get_setting("toolkit/look/internal_resolution", Vector2i.ZERO)
	_material.set_shader_parameter("pixel_grid", Vector2(grid))


# --- Global parameters -----------------------------------------------------------------

## Registers every look parameter the project does not declare, with its default.
## RenderingServer cannot list or read global parameters outside the editor, so the
## current values are tracked here.
static func ensure_globals() -> void:
	for name: String in TKLookDefaults.GLOBALS:
		if _values.has(name):
			continue
		var entry: Dictionary = TKLookDefaults.GLOBALS[name]
		var key := "shader_globals/" + name
		if ProjectSettings.has_setting(key):
			_values[name] = ProjectSettings.get_setting(key).value
		else:
			RenderingServer.global_shader_parameter_add(name, _global_type(entry.type), entry.value)
			_values[name] = entry.value


## Sets a look parameter for every material that reads it.
static func set_param(name: String, value: Variant) -> void:
	if not TKLookDefaults.GLOBALS.has(name):
		push_error("TKLook: unknown look parameter %s" % name)
		return
	ensure_globals()
	_values[name] = value
	RenderingServer.global_shader_parameter_set(name, value)


## The current value of a look parameter.
static func get_param(name: String) -> Variant:
	ensure_globals()
	return _values.get(name)


## Restores defaults for every parameter whose name starts with `prefix` ("" for all).
static func reset_params(prefix := "") -> void:
	for name: String in TKLookDefaults.GLOBALS:
		if name.begins_with(prefix):
			set_param(name, TKLookDefaults.GLOBALS[name].value)


## Puts the CRT display pass on `display`, the node that draws the internal-resolution
## image to the screen (a SubViewportContainer, or a TextureRect showing the world
## viewport), or takes it off. Parameters are the look_crt_* globals.
static func set_crt(display: CanvasItem, on: bool) -> void:
	if on == has_crt(display):
		return
	if on:
		var m := ShaderMaterial.new()
		m.shader = CRT
		display.material = m
	else:
		display.material = null


## True when `display` has the CRT display pass.
static func has_crt(display: CanvasItem) -> bool:
	var m := display.material as ShaderMaterial
	return m != null and m.shader == CRT


## The generated palette strip for a palette in assets/source/look/palettes.
static func palette(palette_name: String) -> Texture2D:
	return load(PALETTE_DIR + palette_name + ".png") as Texture2D


static func _global_type(type: String) -> RenderingServer.GlobalShaderParameterType:
	match type:
		"float": return RenderingServer.GLOBAL_VAR_TYPE_FLOAT
		"int": return RenderingServer.GLOBAL_VAR_TYPE_INT
		"bool": return RenderingServer.GLOBAL_VAR_TYPE_BOOL
		"vec2": return RenderingServer.GLOBAL_VAR_TYPE_VEC2
		"color": return RenderingServer.GLOBAL_VAR_TYPE_COLOR
	push_error("TKLook: unknown parameter type %s" % type)
	return RenderingServer.GLOBAL_VAR_TYPE_FLOAT


# --- Hit flash -------------------------------------------------------------------------

## Flashes a CanvasItem or GeometryInstance3D to `colour` and fades back over `duration`
## seconds. A CanvasItem with no material gets the shared flash material; one with its
## own material needs the tk_flash instance uniforms (PixelMaterial2D has them). A mesh
## gets the shared flash overlay when its material_overlay is empty.
func flash(node: Node, duration := 0.15, colour := Color.WHITE) -> void:
	if node is CanvasItem:
		var item := node as CanvasItem
		if not item.material:
			if not _flash_canvas:
				_flash_canvas = ShaderMaterial.new()
				_flash_canvas.shader = FLASH_CANVAS
			item.material = _flash_canvas
	elif node is GeometryInstance3D:
		var geo := node as GeometryInstance3D
		if not geo.material_overlay:
			if not _flash_3d:
				_flash_3d = ShaderMaterial.new()
				_flash_3d.shader = FLASH_3D
			geo.material_overlay = _flash_3d
	else:
		return
	node.set_instance_shader_parameter("tk_flash_colour", colour)
	node.set_instance_shader_parameter("tk_flash", 1.0)
	var tween := node.create_tween()
	tween.tween_method(func(v: float) -> void: node.set_instance_shader_parameter("tk_flash", v), 1.0, 0.0, duration)


# --- Transitions -----------------------------------------------------------------------

## Shows a transition at a fixed amount: 0 is clear, 1 is fully covered. For tests and
## captures; transition_out and transition_in animate it.
func set_transition(kind: String, amount: float, colour := Color.BLACK) -> void:
	if not TRANSITIONS.has(kind):
		push_error("TKLook: unknown transition %s, kinds: %s" % [kind, ", ".join(TRANSITIONS.keys())])
		return
	if kind != transition_kind:
		_apply_kind(kind)
	transition_kind = kind
	transition_amount = clampf(amount, 0.0, 1.0)
	_rect.color = colour
	var preset: Dictionary = TRANSITIONS[kind]
	if kind == "fade":
		_rect.material = null
		_rect.color.a = transition_amount
	else:
		var p := 1.0 - transition_amount
		if preset.get("grows", false):
			p = transition_amount
		_material.set_shader_parameter("progress", p * _range(preset))
	_rect.visible = transition_amount > 0.0


## Covers the screen. Await it.
func transition_out(kind := "diamond", duration := 0.4, colour := Color.BLACK) -> void:
	await _animate(kind, transition_amount if kind == transition_kind else 0.0, 1.0, duration, colour)


## Uncovers the screen. Await it.
func transition_in(kind := "diamond", duration := 0.4, colour := Color.BLACK) -> void:
	await _animate(kind, 1.0, 0.0, duration, colour)


## Covers the screen, changes scene, uncovers it.
func change_scene(path: String, kind := "diamond", duration := 0.4) -> void:
	await transition_out(kind, duration)
	get_tree().change_scene_to_file(path)
	await get_tree().process_frame
	await transition_in(kind, duration)


func _animate(kind: String, from: float, to: float, duration: float, colour: Color) -> void:
	if _tween:
		_tween.kill()
	set_transition(kind, from, colour)
	_tween = create_tween()
	_tween.tween_method(func(v: float) -> void: set_transition(kind, v, colour), from, to, duration)
	await _tween.finished


func _apply_kind(kind: String) -> void:
	if kind == "fade":
		return
	var fresh := ShaderMaterial.new()
	fresh.shader = TRANSITION
	fresh.set_shader_parameter("pixel_grid", _material.get_shader_parameter("pixel_grid"))
	_material = fresh
	var preset: Dictionary = TRANSITIONS[kind]
	for key: String in preset:
		if key in ["range", "grows"]:
			continue
		_material.set_shader_parameter(key, preset[key])
	var size := _rect.get_viewport_rect().size if _rect.is_inside_tree() else Vector2(16, 9)
	_material.set_shader_parameter("aspect", size.x / maxf(size.y, 1.0))
	_rect.material = _material


func _range(preset: Dictionary) -> float:
	var aspect: float = _material.get_shader_parameter("aspect")
	match preset.range:
		"circle": return sqrt(aspect * aspect + 1.0) + 0.02
		"diamond": return aspect + 1.0 + 0.02
	return float(preset.range) + 0.001
