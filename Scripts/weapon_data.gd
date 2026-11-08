extends Resource
class_name WeaponData

@export var weapon_name: String = "Blaster"
@export var held_model: PackedScene
@export var pickup_model: PackedScene
@export var projectile_scene: PackedScene

@export_range(1, 100, 1) var damage: int = 1
@export_range(5.0, 200.0, 1.0) var weapon_range := 50.0
@export_range(0.05, 2.0, 0.01) var fire_interval := 0.2
@export_range(1, 100, 1) var magazine_size: int = 12
@export_range(0.1, 5.0, 0.1) var reload_duration := 1.5
