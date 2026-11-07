extends CharacterBody3D

@export var speed := 6.0
@export var sprint_speed := 9.0
@export var crouch_speed := 3.0

@export var ground_acceleration := 40.0
@export var ground_deceleration := 45.0
@export var air_acceleration := 8.0

@export var crouch_height := 1.2
@export var mouse_sensitivity := 0.002
@export var controller_sensitivity := 2.0
@export_range(1.0, 12.0, 0.5) var jump_velocity := 5.5

@export var camera_bob_amount := 0.025
@export var sprint_bob_amount := 0.045
@export var camera_bob_frequency := 10.0

@export_range(1, 10, 1) var standard_weapon_damage: int = 2
@export_range(1, 10, 1) var rapid_weapon_damage: int = 1
@export_range(5.0, 200.0, 5.0) var standard_weapon_range := 60.0
@export_range(5.0, 200.0, 5.0) var rapid_weapon_range := 25.0

@export_range(1, 60, 1) var standard_magazine_size: int = 12
@export_range(1, 100, 1) var rapid_magazine_size: int = 30
@export_range(0.1, 5.0, 0.1) var reload_duration := 1.5

@export var max_health := 5

var health := 0
var player_dead := false
var course_finished := false
var elapsed_time := 0.0

var current_weapon := 1
var fire_cooldown := 0.0

var standard_ammo := 0
var rapid_ammo := 0
var is_reloading := false
var reload_timer := 0.0

var camera_bob_time := 0.0
var camera_base_y := 0.0

var bullet_scene: PackedScene = preload("res://Scenes/blasterbolt.tscn")
var gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity")

@onready var camera: Camera3D = find_child("Camera3D", true, false)
@onready var muzzle: Marker3D = find_child("Muzzle", true, false)
@onready var body_shape: CollisionShape3D = $CollisionShape3D
@onready var head_pivot: Node3D = camera.get_parent() as Node3D

@onready var standard_weapon: MeshInstance3D = camera.get_node("StandardWeapon")
@onready var rapid_weapon: MeshInstance3D = camera.get_node("RapidWeapon")

@onready var timer_label: Label = find_child("TimerLabel", true, false)
@onready var win_label: Label = find_child("WinLabel", true, false)
@onready var game_over_label: Label = find_child("GameOverLabel", true, false)
@onready var health_label: Label = find_child("HealthLabel", true, false)
@onready var ammo_label: Label = find_child("AmmoLabel", true, false)
@onready var play_again_button: Button = find_child("PlayAgainButton", true, false)

var standing_capsule_height := 0.0
var standing_collision_y := 0.0
var standing_pivot_y := 0.0


func _ready() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	camera.current = true
	camera_base_y = camera.position.y

	standard_ammo = standard_magazine_size
	rapid_ammo = rapid_magazine_size
	health = max_health

	standard_weapon.visible = true
	rapid_weapon.visible = false

	if game_over_label != null:
		game_over_label.visible = false

	if play_again_button != null:
		play_again_button.visible = false
		play_again_button.pressed.connect(_on_play_again_pressed)

	update_ammo_label()
	update_health_display()

	var capsule := body_shape.shape as CapsuleShape3D
	standing_capsule_height = capsule.height
	standing_collision_y = body_shape.position.y
	standing_pivot_y = head_pivot.position.y


func _unhandled_input(event: InputEvent) -> void:
	if player_dead or course_finished:
		if event.is_action_pressed("restart") or (
			event is InputEventKey
			and event.pressed
			and not event.echo
			and event.keycode == KEY_R
		):
			get_tree().reload_current_scene()
		return

	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_2 and not is_reloading:
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

		update_ammo_label()

	if event.is_action_pressed("shoot") and current_weapon == 1:
		shoot()

	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_R:
		start_reload()

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
	if course_finished or player_dead:
		return

	if is_reloading:
		reload_timer -= delta
		if reload_timer <= 0.0:
			finish_reload()

	elapsed_time += delta

	if timer_label != null:
		timer_label.text = "Time: " + format_time(int(elapsed_time))

	if not is_on_floor():
		velocity.y -= gravity * delta

	if Input.is_action_just_pressed("jump") and is_on_floor():
		velocity.y = jump_velocity

	var is_crouching := Input.is_action_pressed("crouch")
	var is_sprinting := Input.is_action_pressed("sprint") and not is_crouching
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
	elif is_sprinting:
		current_speed = sprint_speed

	var look_input := Input.get_vector(
		"look_left", "look_right", "look_up", "look_down"
	)

	rotate_y(-look_input.x * controller_sensitivity * delta)
	camera.rotate_x(-look_input.y * controller_sensitivity * delta)
	camera.rotation.x = clamp(
		camera.rotation.x,
		deg_to_rad(-80),
		deg_to_rad(80)
	)

	var input_2d := Input.get_vector(
		"move_left", "move_right", "move_forward", "move_back"
	)
	var direction := transform.basis * Vector3(input_2d.x, 0, input_2d.y)

	var target_velocity := direction * current_speed
	var horizontal_velocity := Vector3(velocity.x, 0.0, velocity.z)

	if is_on_floor():
		var rate := ground_acceleration
		if input_2d == Vector2.ZERO:
			rate = ground_deceleration

		horizontal_velocity = horizontal_velocity.move_toward(
			target_velocity,
			rate * delta
		)
	else:
		horizontal_velocity = horizontal_velocity.move_toward(
			target_velocity,
			air_acceleration * delta
		)

	velocity.x = horizontal_velocity.x
	velocity.z = horizontal_velocity.z

	var is_moving_on_ground := input_2d.length() > 0.1 and is_on_floor()

	if is_moving_on_ground:
		var bob_frequency := camera_bob_frequency
		var bob_amount := camera_bob_amount

		if is_sprinting:
			bob_frequency *= 1.35
			bob_amount = sprint_bob_amount

		camera_bob_time += delta * bob_frequency
		camera.position.y = camera_base_y + sin(camera_bob_time) * bob_amount
	else:
		camera.position.y = lerp(
			camera.position.y,
			camera_base_y,
			delta * 8.0
		)

	if fire_cooldown > 0.0:
		fire_cooldown -= delta

	if current_weapon == 2 and Input.is_action_pressed("shoot") and fire_cooldown <= 0.0:
		shoot()
		fire_cooldown = 0.12

	move_and_slide()


func shoot() -> void:
	if is_reloading:
		return

	if current_weapon == 1 and standard_ammo <= 0:
		start_reload()
		return

	if current_weapon == 2 and rapid_ammo <= 0:
		start_reload()
		return

	var weapon_range := standard_weapon_range
	if current_weapon == 2:
		weapon_range = rapid_weapon_range

	var aim_end := camera.global_position - camera.global_transform.basis.z * weapon_range
	var query := PhysicsRayQueryParameters3D.create(camera.global_position, aim_end)
	query.exclude = [get_rid()]

	var result := get_world_3d().direct_space_state.intersect_ray(query)
	if not result.is_empty():
		aim_end = result.position

	var bullet = bullet_scene.instantiate()
	bullet.set("max_range", weapon_range)

	if current_weapon == 1:
		bullet.set("damage", standard_weapon_damage)
		standard_ammo -= 1
	else:
		bullet.set("damage", rapid_weapon_damage)
		rapid_ammo -= 1

	bullet.set("shooter", self)
	get_tree().current_scene.add_child(bullet)
	bullet.global_position = muzzle.global_position
	bullet.look_at(aim_end, Vector3.UP)

	update_ammo_label()


func start_reload() -> void:
	if is_reloading:
		return

	if current_weapon == 1 and standard_ammo >= standard_magazine_size:
		return

	if current_weapon == 2 and rapid_ammo >= rapid_magazine_size:
		return

	is_reloading = true
	reload_timer = reload_duration

	if ammo_label != null:
		ammo_label.text = "Reloading..."


func finish_reload() -> void:
	if current_weapon == 1:
		standard_ammo = standard_magazine_size
	else:
		rapid_ammo = rapid_magazine_size

	is_reloading = false
	update_ammo_label()


func update_ammo_label() -> void:
	if ammo_label == null:
		return

	if current_weapon == 1:
		ammo_label.text = "Ammo: " + str(standard_ammo) + " / Unlimited"
	else:
		ammo_label.text = "Ammo: " + str(rapid_ammo) + " / Unlimited"


func take_damage(damage_amount: int) -> void:
	if player_dead or course_finished:
		return

	health = maxi(health - damage_amount, 0)
	update_health_display()
	print("Player health: ", health)

	if health == 0:
		player_dead = true

		if game_over_label != null:
			game_over_label.text = "DEFEATED!\nPress R or Start to restart"
			game_over_label.visible = true

		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


func hit() -> void:
	take_damage(1)


func update_health_display() -> void:
	if health_label != null:
		health_label.text = "Health: " + str(health)


func format_time(total_seconds: int) -> String:
	var minutes := int(total_seconds / 60)
	var seconds := total_seconds % 60
	return "%02d:%02d" % [minutes, seconds]


func finish_course() -> void:
	if course_finished:
		return

	course_finished = true
	var final_time := format_time(int(elapsed_time))

	if timer_label != null:
		timer_label.text = "Time: " + final_time

	if win_label != null:
		win_label.text = "COURSE COMPLETE!\nFinal time: " + final_time
		win_label.visible = true

	if play_again_button != null:
		play_again_button.visible = true

	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


func _on_play_again_pressed() -> void:
	get_tree().reload_current_scene()
