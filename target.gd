extends StaticBody3D

var health := 3

func hit() -> void:
	health -= 1
	print("Target hit! Health: ", health)

	if health <= 0:
		queue_free()
