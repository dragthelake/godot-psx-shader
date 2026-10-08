class_name PsxBlobShadow3D
extends Node3D
## The PSX and N64 blob shadow: a dark disc on the ground under its parent. Put it under
## a body (CharacterBody3D, RigidBody3D) or anything under one. Each physics frame it
## casts a ray straight down through the parent's origin, ignoring the nearest
## CollisionObject3D at or above it, and lays a flat quad on what the ray hits, a few
## centimetres above the surface and turned to its normal. The disc shrinks and thins
## with height and is hidden when nothing is within max_distance.
##
## The disc is drawn with shaders/psx_blob_shadow.gdshader: one dark colour, opacity and
## soft edge as an ordered dither on internal-resolution pixels (the pixel stack's blob
## maths), with vertex snap, fog and draw distance from the psx_* globals.

const SHADER := preload("res://addons/tk_psx/shaders/psx_blob_shadow.gdshader")

## Disc diameter on the ground, in metres.
@export var size := 0.9:
	set(value):
		size = value
		_update_now()
## Height of the parent's origin above the ground when it stands on it, in metres: 0
## for bodies whose origin is at their feet, half the height for a centred capsule.
@export var foot_offset := 0.0
## Longest ray, in metres below the parent's origin. Beyond it the shadow hides.
@export var max_distance := 12.0
## The ray starts this far above the parent's origin, so a body whose origin is at its
## feet still finds the ground it stands on.
@export var ray_start := 0.25
## Height above the ground (past foot_offset) where the disc reaches height_scale and
## height_opacity.
@export var height_range := 4.0
## Disc size at height_range and above, as a share of `size`.
@export_range(0.0, 1.0, 0.01) var height_scale := 0.4
## Opacity at height_range and above, as a share of `opacity`.
@export_range(0.0, 1.0, 0.01) var height_opacity := 0.35
## Share of disc pixels drawn on the ground, by ordered dither.
@export_range(0.0, 1.0, 0.01) var opacity := 1.0:
	set(value):
		opacity = value
		_update_now()
## Share of the radius that fades out by dither. 0 is a hard rim.
@export_range(0.0, 1.0, 0.01) var edge := 0.35:
	set(value):
		edge = value
		_material.set_shader_parameter(&"edge", value)
## sRGB shadow colour. It mixes into the PSX fog with distance.
@export var colour := Color(0.094, 0.078, 0.145):
	set(value):
		colour = value
		_material.set_shader_parameter(&"colour", value)
## How far the quad sits above the hit surface, in metres.
@export var lift := 0.03
## Physics layers the ray hits.
@export_flags_3d_physics var collision_mask := 1

## The quad. top_level, so it ignores the parent's rotation and scale.
var quad: MeshInstance3D
## Height of the parent above the ground at the last update (past foot_offset), or -1
## when the ray hit nothing.
var height := -1.0
## Where the ray hit at the last update, and the surface normal there.
var hit_position := Vector3.ZERO
var hit_normal := Vector3.UP

var _material := ShaderMaterial.new()


func _init() -> void:
	_material.shader = SHADER
	for key in [&"edge", &"colour"]:
		set(key, get(key))
	var mesh := PlaneMesh.new()
	mesh.size = Vector2.ONE
	quad = MeshInstance3D.new()
	quad.name = "Quad"
	quad.mesh = mesh
	quad.material_override = _material
	quad.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	quad.top_level = true
	quad.visible = false
	add_child(quad, false, Node.INTERNAL_MODE_FRONT)


func _ready() -> void:
	update_shadow()


func _physics_process(_delta: float) -> void:
	update_shadow()


## The body the ray ignores: the nearest CollisionObject3D at or above this node's
## parent. Null when there is none.
func body() -> CollisionObject3D:
	var n := get_parent()
	while n:
		if n is CollisionObject3D:
			return n
		n = n.get_parent()
	return null


## Disc diameter and opacity at `h` metres above the ground.
func factors_at(h: float) -> Vector2:
	var t := clampf(h / height_range, 0.0, 1.0) if height_range > 0.0 else 0.0
	return Vector2(size * lerpf(1.0, height_scale, t), opacity * lerpf(1.0, height_opacity, t))


## Casts the ray and places the quad. Runs every physics frame; call it after moving the
## parent outside physics, so the shadow follows at once.
func update_shadow() -> void:
	if not is_inside_tree():
		return
	var parent := get_parent() as Node3D
	var world := get_world_3d()
	if parent == null or world == null:
		_hide()
		return
	var from := parent.global_position
	var query := PhysicsRayQueryParameters3D.create(from + Vector3.UP * ray_start, from + Vector3.DOWN * max_distance, collision_mask)
	var ignore := body()
	if ignore:
		query.exclude = [ignore.get_rid()]
	var hit := world.direct_space_state.intersect_ray(query)
	if hit.is_empty():
		_hide()
		return
	hit_position = hit.position
	hit_normal = (hit.normal as Vector3).normalized()
	height = maxf(from.y - hit_position.y - foot_offset, 0.0)
	_place()


func _place() -> void:
	var f := factors_at(height)
	var n := hit_normal
	var x := Vector3.RIGHT - n * n.dot(Vector3.RIGHT)
	if x.length_squared() < 1e-6:
		x = Vector3.FORWARD - n * n.dot(Vector3.FORWARD)
	x = x.normalized()
	var z := x.cross(n)
	quad.global_transform = Transform3D(Basis(x * f.x, n, z * f.x), hit_position + n * lift)
	_material.set_shader_parameter(&"opacity", f.y)
	quad.visible = f.x > 0.0 and f.y > 0.0


func _hide() -> void:
	height = -1.0
	quad.visible = false


func _update_now() -> void:
	if height >= 0.0 and quad:
		_place()
