extends CharacterBody3D

@export var speed := 6.0
@export var mouse_sensitivity := 0.002
var bullet_scene: PackedScene = preload("res://blasterbolt.tscn")
@onready var muzzle: Marker3D = find_child("Muzzle", true, false)
@onready var camera: Camera3D = find_child("Camera3D", true, false)
@onready var crosshair: Label = find_child("Crosshair", true, false)

var gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity")


func _ready() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	camera.current = true


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("shoot"):
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

	var input_2d := Input.get_vector(
		"move_left", "move_right", "move_forward", "move_back"
	)
	var direction := transform.basis * Vector3(input_2d.x, 0, input_2d.y)

	velocity.x = direction.x * speed
	velocity.z = direction.z * speed

	move_and_slide()


func shoot() -> void:
	var bullet = bullet_scene.instantiate()
	get_tree().current_scene.add_child(bullet)
	bullet.global_transform = muzzle.global_transform
	bullet.set("shooter", self)
