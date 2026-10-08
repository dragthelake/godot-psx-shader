extends Node
## Transition lab: a busy test card with a TKLook transition held at a fixed amount.
##
## Command line (after --): --transition=<kind>[@<amount>]. Kinds are the keys of
## TKLook.TRANSITIONS (default diamond); amount is 0 (clear) to 1 (covered), default 0.5.
## One argument without a colon, so scripts/capture -GameArgs can pass it.

const SIZE := Vector2i(320, 180)


func _ready() -> void:
	var view := SubViewportContainer.new()
	view.stretch = true
	view.stretch_shrink = 2
	view.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	view.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(view)
	var world := SubViewport.new()
	world.size = SIZE
	world.disable_3d = true
	view.add_child(world)
	var card := TextureRect.new()
	card.texture = ImageTexture.create_from_image(test_card())
	world.add_child(card)
	var parts := TKArgs.value("transition", "diamond").split("@")
	var kind := parts[0]
	var amount := float(parts[1]) if parts.size() > 1 else 0.5
	TKLook.set_transition.call_deferred(kind, amount)


func _exit_tree() -> void:
	TKLook.set_transition("fade", 0.0)


## 16 px checks in endesga-32 colours, so transition edges show against every colour.
static func test_card() -> Image:
	var strip := TKLook.palette("endesga-32").get_image()
	var img := Image.create_empty(SIZE.x, SIZE.y, false, Image.FORMAT_RGBA8)
	for y in SIZE.y:
		for x in SIZE.x:
			var i := (x / 16 + (y / 16) * 7) % strip.get_width()
			img.set_pixel(x, y, strip.get_pixel(i, 0))
	return img
