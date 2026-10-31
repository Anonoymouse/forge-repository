extends StaticBody3D

@export var fire_interval := 2.0
@export var health := 3

var bullet_scene: PackedScene = preload("res://blasterbolt.tscn")
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

	fire_timer -= delta

	if fire_timer <= 0.0:
		shoot()
		fire_timer = fire_interval


func shoot() -> void:
	var bullet = bullet_scene.instantiate()
	get_tree().current_scene.add_child(bullet)

	bullet.global_position = enemy_muzzle.global_position
	bullet.look_at(player.global_position + Vector3(0, 1, 0), Vector3.UP)
	bullet.set("shooter", self)


func hit() -> void:
	health -= 1
	print("Enemy hit! Health: ", health)

	if health <= 0:
		queue_free()
