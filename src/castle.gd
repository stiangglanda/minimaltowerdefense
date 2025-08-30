extends Area2D

signal game_over()

@export var health: int = 1000

var max_health: int
var is_destroyed: bool = false

@onready var sprite: Sprite2D = $Sprite2D
@onready var health_bar: ProgressBar = $ProgressBar
@onready var static_body: StaticBody2D = $StaticBody2D

var original_modulate: Color
var health_bar_stylebox_is_unique = false


func _ready():
	add_to_group("castle")
	
	max_health = health
	health_bar.max_value = max_health
	health_bar.value = health
	
	original_modulate = sprite.modulate


func take_damage(amount: int):
	if is_destroyed:
		return

	health -= amount
	update_health_bar()
	
	print("Castle took %d damage, %d health remaining." % [amount, health])
	
	if health <= 0:
		destroy_castle()
	else:
		show_hit_effect()


func update_health_bar():
	var tween = create_tween()
	tween.tween_property(health_bar, "value", health, 0.2).set_trans(Tween.TRANS_SINE)
	
	if not health_bar_stylebox_is_unique:
		var fill_stylebox = health_bar.get_theme_stylebox("fill")
		var unique_fill_stylebox = fill_stylebox.duplicate()
		health_bar.add_theme_stylebox_override("fill", unique_fill_stylebox)
		health_bar_stylebox_is_unique = true
	
	var health_percent = float(health) / float(max_health)
	if health_percent > 0.6:
		health_bar.visible = true
		health_bar.get_theme_stylebox("fill").bg_color = Color.GREEN
	elif health_percent > 0.3:
		health_bar.get_theme_stylebox("fill").bg_color = Color.YELLOW
	else:
		health_bar.get_theme_stylebox("fill").bg_color = Color.RED


func show_hit_effect():
	create_screen_shake(8, 0.2)

	var tween = create_tween()
	tween.tween_property(sprite, "modulate", Color.RED, 0).set_delay(0.01)
	tween.tween_property(sprite, "modulate", original_modulate, 0.3).set_delay(0.1)

func destroy_castle():
	is_destroyed = true
	
	remove_from_group("castle")
	static_body.get_node("CollisionPolygon2D").set_deferred("disabled", true)
	
	var tween = create_tween()
	
	tween.tween_callback(func(): create_screen_shake(25, 0.5))
	tween.tween_property(sprite, "modulate", Color("#5d1a1a"), 0.5)
	tween.tween_property(self, "rotation_degrees", 5, 0.2).set_trans(Tween.TRANS_SINE)
	tween.tween_property(self, "rotation_degrees", -5, 0.2).set_trans(Tween.TRANS_SINE).set_delay(0.2)
	tween.tween_property(self, "rotation_degrees", 0, 0.1).set_delay(0.4)
	
	tween.chain().set_parallel(true)
	tween.tween_property(self, "scale", Vector2(1.1, 0.7), 1.0).set_trans(Tween.TRANS_ELASTIC)
	tween.tween_property(self, "modulate:a", 0.0, 1.5).set_delay(0.5)
	
	await tween.finished
	
	game_over.emit()
	print("GAME OVER")


func create_screen_shake(intensity: int, duration: float):
	var camera = get_viewport().get_camera_2d()
	if not camera:
		return
		
	var original_pos = camera.global_position
	var tween = create_tween().set_trans(Tween.TRANS_SINE)
	
	tween.tween_method(
		func(shake_amount):
			var offset = Vector2(randf_range(-1, 1), randf_range(-1, 1)).normalized() * shake_amount
			camera.global_position = original_pos + offset,
		intensity,
		0,
		duration
	)
	
	tween.tween_callback(func(): camera.global_position = original_pos)
