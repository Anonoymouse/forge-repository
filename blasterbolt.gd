extends Area3D

@export var speed := 35.0
@export var lifetime := 3.0

var shooter: Node3D
var time_left := 0.0


func _ready() -> void:
	time_left = lifetime
	body_entered.connect(_on_body_entered)


func _physics_process(delta: float) -> void:
	global_position += -global_transform.basis.z * speed * delta

	time_left -= delta
	if time_left <= 0.0:
		queue_free()


func _on_body_entered(body: Node3D) -> void:
	if body == shooter:
		return

	if body.has_method("hit"):
		body.hit()

	queue_free()
