@tool
class_name PsxWater3D
extends MeshInstance3D
## A PSX water surface: a flat grid of `size` metres with a vertex about every
## `cell_size` metres, drawn with a PsxWaterMaterial3D. The node's origin is the centre
## of the still surface. Keep it unrotated so height_at is exact.

## Width (x) and depth (z) in metres.
@export var size := Vector2(16.0, 16.0):
	set(value):
		size = value
		_rebuild_mesh()
## Spacing of the grid's vertices in metres. Waves bend the surface only at vertices,
## so keep it under a third of the wave length.
@export var cell_size := 1.0:
	set(value):
		cell_size = maxf(value, 0.05)
		_rebuild_mesh()
## The water's material. Set as material_override.
@export var water_material: PsxWaterMaterial3D:
	set(value):
		water_material = value
		material_override = value


func _init() -> void:
	cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	water_material = PsxWaterMaterial3D.new()
	_rebuild_mesh()


## Vertices along x and z, including both edges.
func vertex_counts() -> Vector2i:
	return Vector2i(ceili(size.x / cell_size) + 1, ceili(size.y / cell_size) + 1)


## World height of the surface at a world position's x and z, at the material's
## current time.
func height_at(world_position: Vector3) -> float:
	return global_position.y + water_material.height(Vector2(world_position.x, world_position.z), water_material.current_time())


func _rebuild_mesh() -> void:
	var plane := PlaneMesh.new()
	plane.size = size
	var counts := vertex_counts()
	plane.subdivide_width = counts.x - 2
	plane.subdivide_depth = counts.y - 2
	mesh = plane
