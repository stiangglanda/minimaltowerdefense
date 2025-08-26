extends CharacterBody2D

@export var movement_speed: float = 100.0
@export var health: int = 50
@export var max_health: int = 50

@onready var navigation_agent: NavigationAgent2D = $NavigationAgent2D
@onready var animation_tree: AnimationTree = $AnimationTree
@onready var state_machine = animation_tree.get("parameters/playback")
@onready var sprite: Sprite2D = $Sprite2D
@onready var health_bar: ProgressBar = $HealthBar

var is_taking_damage = false
var is_dying = false
var original_modulate: Color
var damage_numbers_scene = preload("res://scenes/DamageNumber.tscn")

func _ready():
	max_health = health
	original_modulate = sprite.modulate
	
	if health_bar:
		health_bar.max_value = max_health
		health_bar.value = health
		health_bar.visible = false

func set_target_position(target_pos: Vector2):
	navigation_agent.target_position = target_pos

func _physics_process(delta: float):
	if is_dying:
		velocity = Vector2.ZERO
		return
		
	if navigation_agent.is_navigation_finished():
		velocity = Vector2.ZERO
		pick_new_state()
		die_peacefully()
		return
	
	var next_path_position: Vector2 = navigation_agent.get_next_path_position()
	var direction: Vector2 = global_position.direction_to(next_path_position)
	
	velocity = direction * movement_speed
	
	if velocity.x < -1.0:
		sprite.flip_h = true
	elif velocity.x > 1.0:
		sprite.flip_h = false
		
	pick_new_state()
	move_and_slide()

func pick_new_state():
	if is_taking_damage or is_dying:
		return
		
	var current_state = state_machine.get_current_node()
	if current_state == "attack_1" or current_state == "attack_2":
		return
	
	if velocity.length() > 1.0:
		state_machine.travel("walk")
	else:
		state_machine.travel("idle")

func take_damage(amount: int):
	if is_dying:
		return
		
	health -= amount
	
	show_damage_number(amount)
	
	update_health_bar()
	
	show_hit_effect()
	
	if health <= 0:
		die_from_combat()
	else:
		hit_reaction()

func show_hit_effect():
	"""Flash the enemy red, then white, then back to normal"""
	is_taking_damage = true
	
	sprite.modulate = Color.RED
	await get_tree().create_timer(0.08).timeout
	
	sprite.modulate = Color.WHITE
	await get_tree().create_timer(0.08).timeout
	
	sprite.modulate = original_modulate
	is_taking_damage = false

func hit_reaction():
	"""Brief knockback and pause when hit"""
	var knockback_force = Vector2.RIGHT * 50 if sprite.flip_h else Vector2.LEFT * 50
	velocity = knockback_force
	
	await get_tree().create_timer(0.2).timeout

func show_damage_number(damage_amount: int):
	"""Show floating damage number (optional - requires DamageNumber scene)"""
	if damage_numbers_scene:
		var damage_instance = damage_numbers_scene.instantiate()
		get_parent().add_child(damage_instance)
		damage_instance.global_position = global_position + Vector2(0, -20)
		damage_instance.setup(damage_amount)

func update_health_bar():
	"""Update and show health bar"""
	if health_bar:
		health_bar.value = health
		health_bar.visible = true
		
		var health_percent = float(health) / float(max_health)
		if health_percent > 0.6:
			health_bar.modulate = Color.GREEN
		elif health_percent > 0.3:
			health_bar.modulate = Color.YELLOW
		else:
			health_bar.modulate = Color.RED

func die_from_combat():
	"""Death from taking damage"""
	if is_dying:
		return
		
	is_dying = true
	velocity = Vector2.ZERO
	
	create_death_effects()
	
	await get_tree().create_timer(0.8).timeout
	queue_free()

func die_peacefully():
	"""Death from reaching destination (no dramatic effects)"""
	queue_free()

func create_death_effects():
	"""Create death effects without animations"""
	var tween = create_tween()
	tween.parallel().tween_property(sprite, "modulate:a", 0.0, 0.5)
	tween.parallel().tween_property(sprite, "scale", Vector2(1.2, 1.2), 0.3)
	tween.parallel().tween_property(sprite, "scale", Vector2(0.8, 0.8), 0.5).set_delay(0.3)
	
	tween.parallel().tween_property(sprite, "rotation", randf_range(-PI/4, PI/4), 0.4)
	
	create_screen_shake()

func create_screen_shake():
	"""Simple screen shake effect"""
	if get_viewport().get_camera_2d():
		var camera = get_viewport().get_camera_2d()
		var original_pos = camera.global_position
		
		for i in range(10):
			var shake_offset = Vector2(randf_range(-5, 5), randf_range(-5, 5))
			camera.global_position = original_pos + shake_offset
			await get_tree().create_timer(0.05).timeout
		
		camera.global_position = original_pos
