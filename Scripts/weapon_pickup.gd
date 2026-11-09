extends Area3D

@export var weapon_data: WeaponData
@export var ammo_in_magazine := -1

@onready var model_anchor: Node3D = $ModelAnchor

var player: Node3D


func _ready() -> void:
 body_entered.connect(_on_body_entered)
 body_exited.connect(_on_body_exited)

 if weapon_data != null and ammo_in_magazine < 0:
  ammo_in_magazine = weapon_data.magazine_size

 update_visual()


func _process(_delta: float) -> void:
 if is_instance_valid(player) and Input.is_action_just_pressed("interact"):
  player.call("collect_weapon_pickup", self)


func update_visual() -> void:
 for child in model_anchor.get_children():
  child.queue_free()

 if weapon_data == null or weapon_data.pickup_model == null:
  return

 var model := weapon_data.pickup_model.instantiate()
 model_anchor.add_child(model)


func _on_body_entered(body: Node3D) -> void:
 if body.has_method("collect_weapon_pickup"):
  player = body


func _on_body_exited(body: Node3D) -> void:
 if body == player:
  player = null
