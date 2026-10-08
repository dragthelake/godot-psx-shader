extends Control
## Flips between the tk_psx labs. 1 to 6 picks a lab, Space toggles the PSX look on the
## PSX look lab and the PsxScreen one (the other labs take --look=off on the command line).

const LABS := [
	["PSX look", "res://addons/tk_psx/lab/psx_lab.tscn"],
	["Water", "res://addons/tk_psx/lab/water_lab.tscn"],
	["Particles", "res://addons/tk_psx/lab/particles_lab.tscn"],
	["Sky (M: panorama)", "res://addons/tk_psx/lab/sky_lab.tscn"],
	["Dissolve and x-ray", "res://addons/tk_psx/lab/sprite_fx_lab.tscn"],
	["Plain scene through PsxScreen", "res://demo/quickstart.tscn"],
]

var lab: Node
var caption: Label


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	caption = Label.new()
	caption.position = Vector2(8, 4)
	caption.z_index = 10
	open(0)


func open(index: int) -> void:
	if lab:
		lab.queue_free()
		await lab.tree_exited
	lab = load(LABS[index][1]).instantiate()
	add_child(lab)
	if caption.get_parent():
		remove_child(caption)
	add_child(caption)
	var hint := "1-6 labs, Space look on/off" if lab.has_method("set_stack") or lab.has_method("set_psx") else "1-6 labs"
	caption.text = "%d  %s    %s" % [index + 1, LABS[index][0], hint]


func _unhandled_input(event: InputEvent) -> void:
	var key := event as InputEventKey
	if not key or not key.pressed or key.echo:
		return
	if key.keycode >= KEY_1 and key.keycode < KEY_1 + LABS.size():
		open(key.keycode - KEY_1)
	elif key.keycode == KEY_SPACE and lab.has_method("set_stack"):
		lab.set_stack(not lab.stack_on)
	elif key.keycode == KEY_SPACE and lab.has_method("set_psx"):
		lab.set_psx(not lab.post.active)
