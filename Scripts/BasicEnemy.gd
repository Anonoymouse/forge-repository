extends StaticBody3D

@export_range(1, 100, 1) var max_health: int = 3
@export var attack_range := 10.0
@export var fire_interval := 2.0
@export_range(1, 10, 1) var attack_damage: int = 1

var health: int
var player: Node3D
var player_collision: CollisionShape3D
var fire_timer := 0.0

var bullet_scene: PackedScene = preload("res://Scenes/EnemyBolt.tscn")

@onready var enemy_muzzle: Marker3D = $EnemyMuzzle


func _ready() -> void:
	add_to_group("enemies")
	health = max_health

	player = get_tree().current_scene.find_child(
		"CharacterBody3D", true, false
	) as Node3D

	if player != null:
		player_collision = player.get_node_or_null(
			"CollisionShape3D"
		) as CollisionShape3D


func _physics_process(delta: float) -> void:
	if player == null:
		return

	var target_point := player.global_position + Vector3.UP

	if player_collision != null:
		target_point = player_collision.global_position

	if global_position.distance_to(target_point) > attack_range:
		return

	fire_timer -= delta

	if fire_timer <= 0.0:
		shoot_at_player(target_point)
		fire_timer = fire_interval


func shoot_at_player(target_point: Vector3) -> void:
	var query := PhysicsRayQueryParameters3D.create(
		enemy_muzzle.global_position,
		target_point
	)

	var excluded_bodies: Array[RID] = []

	for enemy in get_tree().get_nodes_in_group("enemies"):
		if enemy is CollisionObject3D:
			excluded_bodies.append(enemy.get_rid())

	query.exclude = excluded_bodies

	var result := get_world_3d().direct_space_state.intersect_ray(query)

	if not result.is_empty() and result["collider"] != player:
		return

	var bullet = bullet_scene.instantiate()
	bullet.set("damage", attack_damage)
	bullet.set("shooter", self)

	get_tree().current_scene.add_child(bullet)
	bullet.global_position = enemy_muzzle.global_position
	bullet.look_at(target_point, Vector3.UP)


func hit() -> void:
	take_damage(1)


func take_damage(damage_amount: int) -> void:
	health = maxi(health - damage_amount, 0)
	print("BasicEnemy health: ", health)

	if health == 0:
		queue_free()
