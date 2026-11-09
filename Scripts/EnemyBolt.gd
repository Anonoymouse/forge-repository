extends Node3D

@export var speed := 18.0
@export var max_range := 30.0

var shooter: Node3D
var damage := 1
var distance_travelled := 0.0


func _physics_process(delta: float) -> void:
	var movement := -global_transform.basis.z.normalized() * speed * delta
	var query := PhysicsRayQueryParameters3D.create(
		global_position,
		global_position + movement
	)

	var excluded_bodies: Array[RID] = []

	if is_instance_valid(shooter) and shooter is CollisionObject3D:
		excluded_bodies.append(shooter.get_rid())

	for enemy in get_tree().get_nodes_in_group("enemies"):
		if enemy is CollisionObject3D:
			excluded_bodies.append(enemy.get_rid())

	query.exclude = excluded_bodies

	var result := get_world_3d().direct_space_state.intersect_ray(query)

	if not result.is_empty():
		var body = result["collider"]

		if body.has_method("take_damage"):
			body.take_damage(damage)
		elif body.has_method("hit"):
			body.hit()

		queue_free()
		return

	global_position += movement
	distance_travelled += movement.length()

	if distance_travelled >= max_range:
		queue_free()
