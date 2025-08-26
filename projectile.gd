extends Area2D

var speed = 800

func _physics_process(delta):
	position += transform.x * speed * delta

func _on_body_entered(body):
	if body.is_in_group("enemies"):
		if body.has_method("take_damage"):
			body.take_damage(10)
		queue_free()

func _on_visible_on_screen_notifier_2d_screen_exited():
	queue_free()
