class_name TKPsx
extends RefCounted
## PSX stack helpers. Static, no autoload: the stack-wide values are the psx_* global
## shader parameters (TKLook registers them), and the post preset is the tk_look quantise
## pass, whose look_colour_levels default of 32 is PSX 15-bit colour.

const QUANTISE := preload("res://addons/tk_look/shaders/post_quantise.gdshader")
## The quantise pass as a resource, for a LookPost set up in the inspector.
const POST_PRESET := "res://addons/tk_psx/post/psx_post_quantise.tres"
const SPRITE_LIT := preload("res://addons/tk_psx/shaders/psx_sprite_lit.gdshader")
const SPRITE_UNLIT := preload("res://addons/tk_psx/shaders/psx_sprite_unlit.gdshader")
const XRAY_MARK := preload("res://addons/tk_psx/shaders/xray/psx_xray_mark.gdshader")
const XRAY := preload("res://addons/tk_psx/shaders/xray/psx_xray.gdshader")
const XRAY_MARK_SPRITE := preload("res://addons/tk_psx/shaders/xray/psx_xray_mark_sprite.gdshader")
const XRAY_SPRITE := preload("res://addons/tk_psx/shaders/xray/psx_xray_sprite.gdshader")
## Default x-ray silhouette colour.
const XRAY_COLOUR := Color("8b9bb4")
## Render priorities of the x-ray passes: after every other transparent surface, and
## every mark before any silhouette, so one actor's visible parts hide its own hidden
## parts' silhouettes.
const XRAY_MARK_PRIORITY := 120
const XRAY_PRIORITY := 121

static var _xray_overlay: ShaderMaterial

## Values that turn every surface effect off, for comparing captures with the stack on
## and off.
const OFF := {
	"psx_snap_resolution": Vector2.ZERO,
	"psx_affine": false,
	"psx_fog_start": 0.0,
	"psx_fog_end": 0.0,
	"psx_draw_distance": 0.0,
	"psx_texture_lod_distance": 0.0,
}


## Restores every psx_* parameter to its look.json default.
static func reset() -> void:
	for name: String in TKLookDefaults.GLOBALS:
		if name.begins_with("psx_"):
			_store(name, TKLookDefaults.GLOBALS[name].value)


## Turns the surface effects off: snap, affine, fog, draw distance and texture LOD.
## reset() turns them back on.
static func disable() -> void:
	set_params(OFF)


## Sets psx_* parameters from a name -> value dictionary.
static func set_params(params: Dictionary) -> void:
	for name: String in params:
		if not name.begins_with("psx_") or not TKLookDefaults.GLOBALS.has(name):
			push_error("TKPsx: unknown PSX parameter %s" % name)
			continue
		_store(name, params[name])


## The current value of a psx_* parameter.
static func get_param(name: String) -> Variant:
	return TKLook.get_param(name)


## True when no surface effect is on: every parameter in OFF has its off value.
static func is_disabled() -> bool:
	for name: String in OFF:
		if get_param(name) != OFF[name]:
			return false
	return true


static func _store(name: String, value: Variant) -> void:
	TKLook.set_param(name, value)


## A fresh quantise pass for a LookPost chain. Colour depth and dither come from the
## look_* globals.
static func quantise_pass() -> LookPass:
	return LookPass.from_shader(QUANTISE)


## The PSX post chain: the quantise pass.
static func post_passes() -> Array[LookPass]:
	var passes: Array[LookPass] = [quantise_pass()]
	return passes


## Gives `post` the PSX post chain.
static func apply_post(post: LookPost) -> void:
	post.passes = post_passes()


## An Environment that draws `material` (a new PsxSkyMaterial when null) as its sky, lit
## by a flat ambient colour like a PSX scene: the sky gives no ambient or reflected
## light, so it is never rendered into a radiance map. Linear tonemap, so colours reach
## the screen as set.
static func make_sky(material: PsxSkyMaterial = null, ambient := Color(0.36, 0.38, 0.46)) -> Environment:
	var env := Environment.new()
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = ambient
	env.reflected_light_source = Environment.REFLECTION_SOURCE_DISABLED
	env.tonemap_mode = Environment.TONE_MAPPER_LINEAR
	set_sky(env, material)
	return env


## Puts `material` (a new PsxSkyMaterial when null) on `world_env`'s environment as its
## background, creating the environment if it has none. Ambient light, reflections and
## tonemap stay as they are. Returns the material.
static func apply_sky(world_env: WorldEnvironment, material: PsxSkyMaterial = null) -> PsxSkyMaterial:
	if world_env.environment == null:
		world_env.environment = make_sky(material)
		return world_env.environment.sky.sky_material
	return set_sky(world_env.environment, material)


## Makes `env`'s background a Sky drawing `material` (a new PsxSkyMaterial when null).
## Returns the material.
static func set_sky(env: Environment, material: PsxSkyMaterial = null) -> PsxSkyMaterial:
	if material == null:
		material = PsxSkyMaterial.new()
	var sky := Sky.new()
	sky.sky_material = material
	sky.radiance_size = Sky.RADIANCE_SIZE_32
	env.sky = sky
	env.background_mode = Environment.BG_SKY
	return material


## Swaps every StandardMaterial3D used as a material_override or surface override under
## `root` for an equivalent PsxMaterial3D (PsxMaterial3D.from_standard), so existing
## geometry such as the greybox takes the PSX surface effects. Shared materials stay
## shared. Sprites under `root` get apply_to_sprite. Primitive meshes on converted
## nodes are also tessellated to `max_edge` metres (0 leaves them alone): fog, texture
## LOD and draw distance work per vertex, so a face many metres across fogs or culls as
## a whole. `made` collects source material
## -> PsxMaterial3D, for callers that look materials up later. Returns how many meshes
## and sprites changed.
static func convert_materials(root: Node, max_edge := 2.0, made: Dictionary = {}) -> int:
	var count := 0
	var stack: Array[Node] = [root]
	while not stack.is_empty():
		var node: Node = stack.pop_back()
		stack.append_array(node.get_children())
		if node is SpriteBase3D:
			if not is_psx_sprite(node):
				apply_to_sprite(node)
				count += 1
			continue
		var mesh := node as MeshInstance3D
		if not mesh:
			continue
		var changed := false
		if mesh.material_override is BaseMaterial3D:
			mesh.material_override = _converted(mesh.material_override, made)
			changed = true
		for i in mesh.get_surface_override_material_count():
			if mesh.get_surface_override_material(i) is BaseMaterial3D:
				mesh.set_surface_override_material(i, _converted(mesh.get_surface_override_material(i), made))
				changed = true
		if changed:
			count += 1
			if max_edge > 0.0:
				tessellate(mesh.mesh, max_edge)
	return count


## Gives a Sprite3D, AnimatedSprite3D or TKSprite3D the PSX sprite shader as its
## material_override: vertex snap, affine mapping, fog, draw distance and texture LOD,
## alpha cut, with the sprite's billboard mode, shading (lit or unlit) and modulate.
## The shader is told the current texture or frame whenever it changes. Sprite
## settings changed afterwards (billboard, shaded) need another call. Label3D is not
## supported: its glyphs draw from per-surface font textures an override cannot see.
static func apply_to_sprite(sprite: SpriteBase3D) -> ShaderMaterial:
	var m := sprite.material_override as ShaderMaterial
	if not is_psx_sprite(sprite):
		m = ShaderMaterial.new()
		var sync := _sync_sprite_texture.bind(sprite)
		if sprite is AnimatedSprite3D:
			sprite.frame_changed.connect(sync)
			sprite.animation_changed.connect(sync)
			sprite.sprite_frames_changed.connect(sync)
		elif sprite is Sprite3D:
			sprite.texture_changed.connect(sync)
	m.shader = SPRITE_LIT if sprite.shaded else SPRITE_UNLIT
	m.set_shader_parameter(&"billboard_mode", sprite.billboard)
	m.set_shader_parameter(&"alpha_scissor", 0.5)
	if m.next_pass:
		_set_sprite_xray_params(m)
	sprite.material_override = m
	_sync_sprite_texture(sprite)
	return m


## True when `sprite` has the PSX sprite shader from apply_to_sprite.
static func is_psx_sprite(sprite: SpriteBase3D) -> bool:
	var m := sprite.material_override as ShaderMaterial
	return m != null and (m.shader == SPRITE_LIT or m.shader == SPRITE_UNLIT)


## The texture a sprite is drawing now: its texture, or its current animation frame.
static func sprite_texture(sprite: SpriteBase3D) -> Texture2D:
	if sprite is AnimatedSprite3D:
		var frames: SpriteFrames = sprite.sprite_frames
		if frames and frames.has_animation(sprite.animation) and sprite.frame < frames.get_frame_count(sprite.animation):
			return frames.get_frame_texture(sprite.animation, sprite.frame)
		return null
	if sprite is Sprite3D:
		return sprite.texture
	return null


static func _sync_sprite_texture(sprite: SpriteBase3D) -> void:
	if not is_psx_sprite(sprite):
		return
	var tex := sprite_texture(sprite)
	# The sprite's mesh UVs address an AtlasTexture's whole atlas, so pass the atlas.
	while tex is AtlasTexture:
		tex = (tex as AtlasTexture).atlas
	var m: Material = sprite.material_override
	while m:
		m.set_shader_parameter(&"albedo_texture", tex)
		m = m.next_pass


## Subdivides a BoxMesh, PrismMesh or PlaneMesh so no edge is longer than `max_edge`
## metres. Other meshes are left alone. Returns true if the mesh is a supported primitive.
static func tessellate(mesh: Mesh, max_edge := 2.0) -> bool:
	var cuts := func(length: float) -> int: return maxi(0, ceili(length / max_edge) - 1)
	if mesh is BoxMesh or mesh is PrismMesh:
		mesh.subdivide_width = cuts.call(mesh.size.x)
		mesh.subdivide_height = cuts.call(mesh.size.y)
		mesh.subdivide_depth = cuts.call(mesh.size.z)
		return true
	if mesh is PlaneMesh:
		mesh.subdivide_width = cuts.call(mesh.size.x)
		mesh.subdivide_depth = cuts.call(mesh.size.y)
		return true
	return false


static func _converted(m: BaseMaterial3D, made: Dictionary) -> PsxMaterial3D:
	if not made.has(m):
		made[m] = PsxMaterial3D.from_standard(m)
	return made[m]


## Plays a particle preset once at `position` (in `parent`'s space) and frees the
## emitter when it finishes. A non-zero `seed` replaces the preset's seed, so repeated
## bursts can differ while each stays deterministic.
static func burst(parent: Node, preset: PsxParticles3D.Preset, position: Vector3, seed := 0) -> PsxParticles3D:
	var p := PsxParticles3D.make(preset)
	p.one_shot = true
	p.free_on_finish = true
	if seed != 0:
		p.seed = seed
	p.position = position
	parent.add_child(p)
	p.restart(true)
	return p


## Gives `parent` (a body, or a node under one) a PsxBlobShadow3D with a disc `size`
## metres across, for a parent whose origin is `foot_offset` metres above its feet, and
## returns it.
static func add_blob_shadow(parent: Node3D, size := 0.9, foot_offset := 0.0) -> PsxBlobShadow3D:
	var shadow := PsxBlobShadow3D.new()
	shadow.name = "BlobShadow"
	shadow.size = size
	shadow.foot_offset = foot_offset
	parent.add_child(shadow)
	return shadow


# --- Dissolve and x-ray ----------------------------------------------------------------

## Holds the dissolve of every PSX surface and sprite at or under `node` at `amount`:
## 0 shows it all, 1 none. Whole texels of each albedo texture go in the material's
## pattern (PsxMaterial3D.dissolve_cell), so the dissolve sticks to the surface.
static func set_dissolve(node: Node, amount: float) -> void:
	for g in _geometry(node):
		g.set_instance_shader_parameter(&"tk_dissolve", clampf(amount, 0.0, 1.0))


## Dissolves `node` away over `duration` seconds, or back in with `out` false. Returns
## the tween, so callers can await its finished signal.
static func dissolve(node: Node, duration := 0.6, out := true) -> Tween:
	var from := 0.0 if out else 1.0
	set_dissolve(node, from)
	var tween := node.create_tween()
	tween.tween_method(func(v: float) -> void: set_dissolve(node, v), from, 1.0 - from, duration)
	return tween


## Turns the x-ray silhouette of every mesh and sprite at or under `node` on or off. A
## hidden part draws as a flat `colour`, with `dither` (0 to 1) of its pixels left out by
## an ordered pattern, wherever something opaque is in front of it.
##
## Meshes take the x-ray passes as material_overlay, which also carries TKLook.flash.
## PSX sprites (apply_to_sprite) take them as the next pass of their own material.
## Uses the stencil buffer and an inverted depth test, so it works on every renderer
## including Compatibility.
static func set_xray(node: Node, on: bool, colour := XRAY_COLOUR, dither := 0.0) -> void:
	for g in _geometry(node):
		if not (g is MeshInstance3D or g is SpriteBase3D):
			continue
		if g is SpriteBase3D:
			if not is_psx_sprite(g):
				continue
			var m := g.material_override as ShaderMaterial
			m.next_pass = _sprite_xray_passes() if on else null
			if on:
				_set_sprite_xray_params(m)
				_sync_sprite_texture(g)
		elif on:
			g.material_overlay = xray_overlay()
		elif g.material_overlay == _xray_overlay:
			g.material_overlay = null
		if on:
			g.set_instance_shader_parameter(&"tk_xray_colour", colour)
			g.set_instance_shader_parameter(&"tk_xray_dither", clampf(dither, 0.0, 1.0))


## True when `node` (a mesh or PSX sprite) has the x-ray passes.
static func has_xray(node: GeometryInstance3D) -> bool:
	if node is SpriteBase3D:
		var m := node.material_override as ShaderMaterial
		return m != null and m.next_pass is ShaderMaterial and (m.next_pass as ShaderMaterial).shader == XRAY_MARK_SPRITE
	return _xray_overlay != null and node.material_overlay == _xray_overlay


## The shared x-ray overlay for meshes: the mark pass with the silhouette as its next pass.
static func xray_overlay() -> ShaderMaterial:
	if not _xray_overlay:
		_xray_overlay = _xray_pair(XRAY_MARK, XRAY)
	return _xray_overlay


static func _xray_pair(mark_shader: Shader, silhouette_shader: Shader) -> ShaderMaterial:
	var mark := ShaderMaterial.new()
	mark.shader = mark_shader
	mark.render_priority = XRAY_MARK_PRIORITY
	var silhouette := ShaderMaterial.new()
	silhouette.shader = silhouette_shader
	silhouette.render_priority = XRAY_PRIORITY
	mark.next_pass = silhouette
	return mark


static func _sprite_xray_passes() -> ShaderMaterial:
	return _xray_pair(XRAY_MARK_SPRITE, XRAY_SPRITE)


## Copies the sprite material's billboard and cut-out values to its x-ray passes.
static func _set_sprite_xray_params(m: ShaderMaterial) -> void:
	var p := m.next_pass as ShaderMaterial
	while p:
		for name: StringName in [&"billboard_mode", &"alpha_scissor", &"albedo_colour"]:
			var value: Variant = m.get_shader_parameter(name)
			if value != null:
				p.set_shader_parameter(name, value)
		p = p.next_pass as ShaderMaterial


## `node` and every GeometryInstance3D under it.
static func _geometry(node: Node) -> Array[GeometryInstance3D]:
	var out: Array[GeometryInstance3D] = []
	var stack: Array[Node] = [node]
	while not stack.is_empty():
		var n: Node = stack.pop_back()
		stack.append_array(n.get_children())
		if n is GeometryInstance3D:
			out.append(n)
	return out
