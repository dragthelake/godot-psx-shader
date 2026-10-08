extends Node3D
## An ordinary scene built with StandardMaterial3D, standing in for your own: 512 px
## textures (made here from a fixed seed, so no image files are needed), a turning
## crate, a bobbing ball and a camera that drifts, so the vertex snap and affine warp
## show while it moves. PsxScreen converts it.

const TEXTURE_SIZE := 512

var _time := 0.0
@onready var _box: MeshInstance3D = $Box
@onready var _ball: MeshInstance3D = $Ball
@onready var _camera: Camera3D = $Camera
@onready var _camera_start := _camera.position


func _ready() -> void:
	_texture($Ground, bricks(TEXTURE_SIZE, Color("6b5d4a"), Color("3a3128"), 8, 8, 1))
	_texture($Box, bricks(TEXTURE_SIZE, Color("a8442c"), Color("e8d8b0"), 4, 4, 2))
	_texture($Ball, bricks(TEXTURE_SIZE, Color("2f9e8f"), Color("e0f0e8"), 16, 8, 3))
	var stone := bricks(TEXTURE_SIZE, Color("8a8a96"), Color("45454f"), 4, 12, 4)
	for pillar in ["Pillar1", "Pillar2", "Pillar3", "Pillar4"]:
		_texture(get_node(pillar), stone)


func _process(delta: float) -> void:
	_time += delta
	_box.rotation.y = _time * 0.5
	_ball.position.y = 0.6 + 0.3 * sin(_time * 1.7)
	_camera.position = _camera_start + Vector3(sin(_time * 0.3) * 1.5, 0.0, 0.0)


func _texture(mesh: MeshInstance3D, texture: Texture2D) -> void:
	var m: StandardMaterial3D = mesh.get_surface_override_material(0)
	m.albedo_texture = texture
	m.albedo_color = Color.WHITE


## A brick wall texture: `columns` by `rows` bricks of `brick` with `mortar` between, every
## other row offset by half a brick, each brick shaded a little and speckled by noise.
static func bricks(size: int, brick: Color, mortar: Color, columns: int, rows: int, seed: int) -> ImageTexture:
	var noise := FastNoiseLite.new()
	noise.seed = seed
	noise.frequency = 0.05
	var rng := RandomNumberGenerator.new()
	rng.seed = seed
	var shades := []
	for i in columns * rows:
		shades.append(rng.randf_range(-0.12, 0.12))
	var img := Image.create(size, size, false, Image.FORMAT_RGBA8)
	var bw := size / float(columns)
	var bh := size / float(rows)
	var gap := maxf(2.0, size / 128.0)
	for y in size:
		var row := int(y / bh)
		var shift := bw / 2.0 if row % 2 == 1 else 0.0
		for x in size:
			var fx := fposmod(x + shift, size)
			var col := int(fx / bw)
			var in_mortar := fposmod(fx, bw) < gap or fposmod(y, bh) < gap
			var c := mortar if in_mortar else brick.lightened(shades[row * columns + col])
			var n := noise.get_noise_2d(x, y) * 0.15
			img.set_pixel(x, y, Color(c.r + n, c.g + n, c.b + n))
	img.generate_mipmaps()
	return ImageTexture.create_from_image(img)
