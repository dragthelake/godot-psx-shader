@tool
class_name LookPost
extends CanvasLayer
## The post chain. Put it inside the SubViewport that renders the game at internal
## resolution (PixelView/World in the 2D base), so every pass works on game pixels and
## UI outside the SubViewport stays sharp. Each enabled pass is a full-screen ColorRect
## after a BackBufferCopy, so a pass reads the output of the one before it.
##
## Passes run in order. Stack-wide values come from global shader parameters (TKLook);
## per-pass values are the pass material's own uniforms.

## Passes in order. Edit the array (or a pass) and the chain rebuilds.
@export var passes: Array[LookPass] = []:
	set(value):
		for p in passes:
			if p and p.changed.is_connected(_queue_rebuild):
				p.changed.disconnect(_queue_rebuild)
		passes = value
		for p in passes:
			if p and not p.changed.is_connected(_queue_rebuild):
				p.changed.connect(_queue_rebuild)
		_queue_rebuild()
## Turns the whole chain off without touching the passes.
@export var active := true:
	set(value):
		active = value
		_queue_rebuild()

var _rebuild_queued := false


func _init() -> void:
	layer = 100


func _ready() -> void:
	_rebuild()


## The first pass whose shader path ends with `shader_file`, or null.
func find_pass(shader_file: String) -> LookPass:
	for p in passes:
		if p and p.material and p.material.shader and p.material.shader.resource_path.ends_with(shader_file):
			return p
	return null


## Enables or disables the first pass whose shader path ends with `shader_file`.
func set_pass_enabled(shader_file: String, on: bool) -> void:
	var p := find_pass(shader_file)
	if p:
		p.enabled = on


## Names of the passes in order, with their state, for the console and tests.
func describe() -> PackedStringArray:
	var out := PackedStringArray()
	for p in passes:
		if p and p.material and p.material.shader:
			out.append("%s %s" % [p.material.shader.resource_path.get_file().get_basename(), "on" if p.enabled else "off"])
	return out


func _queue_rebuild() -> void:
	if _rebuild_queued or not is_inside_tree():
		return
	_rebuild_queued = true
	_rebuild.call_deferred()


func _rebuild() -> void:
	_rebuild_queued = false
	for child in get_children():
		if child.has_meta("look_post_pass"):
			remove_child(child)
			child.queue_free()
	if not active:
		return
	var i := 0
	for p in passes:
		if not p or not p.enabled or not p.material:
			continue
		var copy := BackBufferCopy.new()
		copy.copy_mode = BackBufferCopy.COPY_MODE_VIEWPORT
		copy.set_meta("look_post_pass", true)
		copy.name = "Copy%d" % i
		add_child(copy)
		var rect := ColorRect.new()
		rect.set_anchors_preset(Control.PRESET_FULL_RECT)
		rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
		rect.material = p.material
		rect.set_meta("look_post_pass", true)
		rect.name = "Pass%d" % i
		add_child(rect)
		i += 1
