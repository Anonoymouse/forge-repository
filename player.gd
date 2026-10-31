extends CharacterBody3D

@export var speed := 6.0
@export var crouch_speed := 3.0
@export var crouch_height := 1.2
@export var mouse_sensitivity := 0.002

var bullet_scene: PackedScene = preload("res://blasterbolt.tscn")
var gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity")

var current_weapon := 1
var fire_cooldown := 0.0

@onready var muzzle: Marker3D = find_child("Muzzle", true, false)
@onready var camera: Camera3D = find_child("Camera3D", true, false)
@onready var body_shape: CollisionShape3D = $CollisionShape3D
@onready var head_pivot: Node3D = camera.get_parent() as Node3D
@onready var standard_weapon: MeshInstance3D = camera.get_node("StandardWeapon")
@onready var rapid_weapon: MeshInstance3D = camera.get_node("RapidWeapon")

var standing_capsule_height := 0.0
var standing_collision_y := 0.0
var standing_pivot_y := 0.0
@export var max_health := 5
var health := 0
@onready var health_label: Label = find_child("HealthLabel", true, false)

func _ready() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	camera.current = true
	health = max_health
	update_health_display()
	
	standard_weapon.visible = true
	rapid_weapon.visible = false

	var capsule := body_shape.shape as CapsuleShape3D
	standing_capsule_height = capsule.height
	standing_collision_y = body_shape.position.y
	standing_pivot_y = head_pivot.position.y


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_2:
		if current_weapon == 1:
			current_weapon = 2
			standard_weapon.visible = false
			rapid_weapon.visible = true
			print("Rapid blaster selected")
		else:
			current_weapon = 1
			standard_weapon.visible = true
			rapid_weapon.visible = false
			print("Standard blaster selected")

	if event.is_action_pressed("shoot") and current_weapon == 1:
		shoot()

	if event is InputEventMouseMotion:
		rotate_y(-event.relative.x * mouse_sensitivity)
		camera.rotate_x(-event.relative.y * mouse_sensitivity)
		camera.rotation.x = clamp(
			camera.rotation.x,
			deg_to_rad(-80),
			deg_to_rad(80)
		)

	if event.is_action_pressed("ui_cancel"):
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


func _physics_process(delta: float) -> void:
	if not is_on_floor():
		velocity.y -= gravity * delta

	if Input.is_action_just_pressed("jump") and is_on_floor():
		velocity.y = 5.5

	var is_crouching := Input.is_action_pressed("crouch")
	var capsule := body_shape.shape as CapsuleShape3D

	if is_crouching:
		capsule.height = crouch_height
		body_shape.position.y = standing_collision_y - (standing_capsule_height - crouch_height) / 2.0
		head_pivot.position.y = standing_pivot_y - 0.5
	else:
		capsule.height = standing_capsule_height
		body_shape.position.y = standing_collision_y
		head_pivot.position.y = standing_pivot_y

	var current_speed := speed
	if is_crouching:
		current_speed = crouch_speed

	var input_2d := Input.get_vector(
		"move_left", "move_right", "move_forward", "move_back"
	)
	var direction := transform.basis * Vector3(input_2d.x, 0, input_2d.y)

	velocity.x = direction.x * current_speed
	velocity.z = direction.z * current_speed

	if fire_cooldown > 0.0:
		fire_cooldown -= delta

	if current_weapon == 2 and Input.is_action_pressed("shoot") and fire_cooldown <= 0.0:
		shoot()
		fire_cooldown = 0.12

	move_and_slide()


func shoot() -> void:
	var aim_end := camera.global_position - camera.global_transform.basis.z * 100.0
	var query := PhysicsRayQueryParameters3D.create(camera.global_position, aim_end)
	query.exclude = [get_rid()]

	var result := get_world_3d().direct_space_state.intersect_ray(query)
	if not result.is_empty():
		aim_end = result.position

	var bullet = bullet_scene.instantiate()
	get_tree().current_scene.add_child(bullet)
	bullet.global_position = muzzle.global_position
	bullet.look_at(aim_end, Vector3.UP)
	bullet.set("shooter", self)
	
func hit() -> void:
	health = maxi(health - 1, 0)
	update_health_display()
	print("Player health: ", health)

	if health == 0:
		print("Player defeated")


func update_health_display() -> void:
	if health_label != null:
		health_label.text = "Health: " + str(health)
