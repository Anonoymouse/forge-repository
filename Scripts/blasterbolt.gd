extends Area3D

@export var speed := 35.0
@export var max_range := 100.0
@export var drop_strength := 5.0

var shooter: Node3D
var damage := 1
var distance_travelled := 0.0
var vertical_speed := 0.0


func _physics_process(delta: float) -> void:
	vertical_speed -= drop_strength * delta

	var forward := -global_transform.basis.z.normalized()
	var movement := (forward * speed + Vector3.UP * vertical_speed) * delta
	var step_distance := movement.length()
	var remaining_distance := max_range - distance_travelled

	if remaining_distance <= 0.0:
		queue_free()
		return

	if step_distance > remaining_distance:
		movement = movement.normalized() * remaining_distance
		step_distance = remaining_distance

	var start_position := global_position
	var end_position := start_position + movement
	var query := PhysicsRayQueryParameters3D.create(start_position, end_position)

	if is_instance_valid(shooter):
		query.exclude = [shooter.get_rid()]

	var result := get_world_3d().direct_space_state.intersect_ray(query)

	if not result.is_empty():
		global_position = result.position
		var hit_object = result.collider

		if hit_object.has_method("take_damage"):
			hit_object.take_damage(damage)
		elif hit_object.has_method("hit"):
			hit_object.hit()

		queue_free()
		return

	global_position = end_position
	distance_travelled += step_distance

	if distance_travelled >= max_range:
		queue_free()
