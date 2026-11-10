extends CharacterBody3D

@export var starting_weapon_slot_1: WeaponData
@export var starting_weapon_slot_2: WeaponData

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
@export var normal_fov := 75.0
@export var sprint_fov := 82.0
@export var fov_smoothness := 8.0

@export var max_health := 5

var health := 0
var player_dead := false
var course_finished := false
var elapsed_time := 0.0

var weapon_slots: Array[WeaponData] = []
var magazine_ammo: Array[int] = [0, 0]
var active_slot := 0
var current_weapon: WeaponData

var is_reloading := false
var reload_timer := 0.0
var fire_cooldown := 0.0

var camera_bob_time := 0.0
var camera_base_y := 0.0

var gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity")

@onready var camera: Camera3D = find_child("Camera3D", true, false)
@onready var default_muzzle: Marker3D = find_child("Muzzle", true, false)
@onready var weapon_holder: Node3D = camera.get_node("WeaponHolder")
@onready var body_shape: CollisionShape3D = $CollisionShape3D
@onready var head_pivot: Node3D = camera.get_parent() as Node3D
@onready var player_animation: AnimationPlayer = find_child("AnimationPlayer", true, false)

@onready var timer_label: Label = find_child("TimerLabel", true, false)
@onready var win_label: Label = find_child("WinLabel", true, false)
@onready var game_over_label: Label = find_child("GameOverLabel", true, false)
@onready var health_label: Label = find_child("HealthLabel", true, false)
@onready var ammo_label: Label = find_child("AmmoLabel", true, false)
@onready var play_again_button: Button = find_child("PlayAgainButton", true, false)

var active_muzzle: Marker3D
var standing_capsule_height := 0.0
var standing_collision_y := 0.0
var standing_pivot_y := 0.0


func _ready() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	camera.current = true
	camera_base_y = camera.position.y
	camera.fov = normal_fov

	weapon_slots.append(starting_weapon_slot_1)
	weapon_slots.append(starting_weapon_slot_2)

	if starting_weapon_slot_1 != null:
		magazine_ammo[0] = starting_weapon_slot_1.magazine_size

	if starting_weapon_slot_2 != null:
		magazine_ammo[1] = starting_weapon_slot_2.magazine_size

	health = max_health
	active_muzzle = default_muzzle

	if game_over_label != null:
		game_over_label.visible = false

	if win_label != null:
		win_label.visible = false

	if play_again_button != null:
		play_again_button.visible = false
		play_again_button.focus_mode = Control.FOCUS_ALL
		play_again_button.pressed.connect(_on_play_again_pressed)

	var capsule := body_shape.shape as CapsuleShape3D
	standing_capsule_height = capsule.height
	standing_collision_y = body_shape.position.y
	standing_pivot_y = head_pivot.position.y

	_select_weapon_slot(0)
	update_health_display()


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

	if event.is_action_pressed("switch_weapon") and not is_reloading:
		_select_weapon_slot(1 - active_slot)

	if event.is_action_pressed("reload") or (
		event is InputEventKey
		and event.pressed
		and not event.echo
		and event.keycode == KEY_R
	):
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

	var target_fov := normal_fov
	if is_sprinting and input_2d.length() > 0.1:
		target_fov = sprint_fov

	camera.fov = lerp(
		camera.fov,
		target_fov,
		delta * fov_smoothness
	)

	if player_animation != null:
		var wanted_animation := "Idle"

		if is_on_floor() and input_2d.length() > 0.1:
			wanted_animation = "Walk"
			if is_sprinting:
				wanted_animation = "Run"

		if player_animation.has_animation(wanted_animation):
			if player_animation.current_animation != wanted_animation:
				player_animation.play(wanted_animation)

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

	if current_weapon != null and Input.is_action_pressed("shoot") and fire_cooldown <= 0.0:
		shoot()
		fire_cooldown = current_weapon.fire_interval

	move_and_slide()

	for i in get_slide_collision_count():
		var collision := get_slide_collision(i)
		var body := collision.get_collider()

		if body is RigidBody3D:
			var push_direction := -collision.get_normal()
			push_direction.y = 0.0

			if push_direction.length_squared() > 0.001:
				body.apply_central_impulse(
					push_direction.normalized() * 1.5
				)


func _select_weapon_slot(slot_index: int) -> void:
	if slot_index < 0 or slot_index >= weapon_slots.size():
		return

	active_slot = slot_index
	current_weapon = weapon_slots[active_slot]
	_update_held_model()
	update_ammo_label()


func _update_held_model() -> void:
	for child in weapon_holder.get_children():
		child.queue_free()

	active_muzzle = default_muzzle

	if current_weapon == null or current_weapon.held_model == null:
		return

	var model := current_weapon.held_model.instantiate()
	weapon_holder.add_child(model)

	var model_muzzle := model.find_child("Muzzle", true, false) as Marker3D
	if model_muzzle != null:
		active_muzzle = model_muzzle


func collect_weapon_pickup(pickup: Node) -> void:
	if player_dead or course_finished or is_reloading:
		return

	var new_weapon := pickup.get("weapon_data") as WeaponData
	if new_weapon == null:
		return

	var pickup_ammo := int(pickup.get("ammo_in_magazine"))
	if pickup_ammo < 0:
		pickup_ammo = new_weapon.magazine_size

	var empty_slot := -1
	for i in range(weapon_slots.size()):
		if weapon_slots[i] == null:
			empty_slot = i
			break

	if empty_slot >= 0:
		weapon_slots[empty_slot] = new_weapon
		magazine_ammo[empty_slot] = pickup_ammo
		pickup.queue_free()

		if current_weapon == null:
			_select_weapon_slot(empty_slot)
		return

	var old_weapon := weapon_slots[active_slot]
	var old_ammo := magazine_ammo[active_slot]

	weapon_slots[active_slot] = new_weapon
	magazine_ammo[active_slot] = pickup_ammo

	pickup.set("weapon_data", old_weapon)
	pickup.set("ammo_in_magazine", old_ammo)
	pickup.call("update_visual")

	_select_weapon_slot(active_slot)


func shoot() -> void:
	if current_weapon == null or is_reloading:
		return

	if magazine_ammo[active_slot] <= 0:
		start_reload()
		return

	if current_weapon.projectile_scene == null:
		push_warning("This weapon has no projectile scene assigned.")
		return

	var aim_end := camera.global_position - camera.global_transform.basis.z * current_weapon.weapon_range
	var query := PhysicsRayQueryParameters3D.create(camera.global_position, aim_end)
	query.exclude = [get_rid()]

	var result := get_world_3d().direct_space_state.intersect_ray(query)
	if not result.is_empty():
		aim_end = result.position

	var bullet = current_weapon.projectile_scene.instantiate()
	bullet.set("max_range", current_weapon.weapon_range)
	bullet.set("damage", current_weapon.damage)
	bullet.set("shooter", self)

	get_tree().current_scene.add_child(bullet)

	if is_instance_valid(active_muzzle):
		bullet.global_position = active_muzzle.global_position
	else:
		bullet.global_position = camera.global_position

	bullet.look_at(aim_end, Vector3.UP)

	magazine_ammo[active_slot] -= 1
	update_ammo_label()


func start_reload() -> void:
	if current_weapon == null or is_reloading:
		return

	if magazine_ammo[active_slot] >= current_weapon.magazine_size:
		return

	is_reloading = true
	reload_timer = current_weapon.reload_duration

	if ammo_label != null:
		ammo_label.text = "Reloading..."


func finish_reload() -> void:
	if current_weapon == null:
		is_reloading = false
		return

	magazine_ammo[active_slot] = current_weapon.magazine_size
	is_reloading = false
	update_ammo_label()


func update_ammo_label() -> void:
	if ammo_label == null:
		return

	if current_weapon == null:
		ammo_label.text = "No weapon"
	else:
		ammo_label.text = current_weapon.weapon_name + ": " + str(magazine_ammo[active_slot]) + " / Unlimited"


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
		play_again_button.grab_focus()

	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


func _on_play_again_pressed() -> void:
	get_tree().reload_current_scene()
