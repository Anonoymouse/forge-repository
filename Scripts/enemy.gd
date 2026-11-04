extends StaticBody3D

@export var fire_interval := 2.0
@export var attack_range := 10.0
@export_range(1, 10, 1) var attack_damage: int = 1
@export var health := 3

var bullet_scene: PackedScene = preload("res://Scenes/blasterbolt.tscn")
var player: Node3D
var fire_timer := 1.0

@onready var enemy_muzzle: Marker3D = $EnemyMuzzle


func _ready() -> void:
	player = get_tree().current_scene.find_child(
		"CharacterBody3D", true, false
	) as Node3D


func _physics_process(delta: float) -> void:
	if player == null:
		return

	var distance_to_player := global_position.distance_to(player.global_position)

	if distance_to_player > attack_range:
		fire_timer = fire_interval
		return

	var target_point := player.global_position + Vector3(0, 1, 0)
	var query := PhysicsRayQueryParameters3D.create(
		enemy_muzzle.global_position,
		target_point
	)
	query.exclude = [get_rid()]

	var result := get_world_3d().direct_space_state.intersect_ray(query)

	if not result.is_empty() and result.get("collider") != player:
		fire_timer = fire_interval
		return

	fire_timer -= delta

	if fire_timer <= 0.0:
		shoot()
		fire_timer = fire_interval

func shoot() -> void:
	var bullet = bullet_scene.instantiate()
	bullet.set("damage", attack_damage)
	bullet.set("shooter", self)

	get_tree().current_scene.add_child(bullet)
	bullet.global_position = enemy_muzzle.global_position
	bullet.look_at(player.global_position + Vector3(0, 1, 0), Vector3.UP)


func take_damage(damage_amount: int) -> void:
	health -= damage_amount
	print("Enemy health: ", health)

	if health <= 0:
		queue_free()
