extends CharacterBody2D

signal died(gold_value)

@export var gold_value: int = 1
@export var movement_speed: float = 100.0
@export var health: int = 50
@export var max_health: int = 50
@export var attack_damage: int = 10
@export var attack_range: float = 70.0
@export var tower_attack_range: float = 100.0
@export var castle_attack_range: float = 50.0

enum State { MOVE, ATTACK, DIE }
var current_state: State = State.MOVE

var current_target = null

@onready var navigation_agent: NavigationAgent2D = $NavigationAgent2D
@onready var animation_tree: AnimationTree = $AnimationTree
@onready var state_machine = animation_tree.get("parameters/playback")
@onready var sprite: Sprite2D = $Sprite2D
@onready var health_bar: ProgressBar = $HealthBar
@onready var player_detection_area: Area2D = $PlayerDetectionArea
@onready var attack_area: Area2D = $AttackArea
@onready var attack_cooldown: Timer = $AttackCooldown

var is_taking_damage = false
var original_modulate: Color
var damage_numbers_scene = preload("res://scenes/DamageNumber.tscn")
var health_bar_stylebox_is_unique = false

func _ready():
	add_to_group("enemies")
	
	max_health = health
	original_modulate = sprite.modulate
	
	if health_bar:
		health_bar.max_value = max_health
		health_bar.value = health
		health_bar.visible = false

func set_target_position(target_pos: Vector2):
	navigation_agent.target_position = target_pos

func _physics_process(delta: float):
	match current_state:
		State.MOVE:
			state_move(delta)
		State.ATTACK:
			state_attack(delta)
		State.DIE:
			pass
			
	move_and_slide()

func state_move(delta: float):
	if navigation_agent.is_navigation_finished():
		velocity = Vector2.ZERO
		var castle = get_tree().get_first_node_in_group("castle")
		if castle:
			current_target = castle
			change_state(State.ATTACK)
		else:
			die_peacefully()
		return
	
	var next_path_position: Vector2 = navigation_agent.get_next_path_position()
	var direction: Vector2 = global_position.direction_to(next_path_position)
	
	velocity = direction * movement_speed
	
	if velocity.x < -1.0:
		sprite.flip_h = true
	elif velocity.x > 1.0:
		sprite.flip_h = false
	
	state_machine.travel("walk")

func state_attack(delta: float):
	if not is_instance_valid(current_target):
		current_target = null
		change_state(State.MOVE)
		var castle = get_tree().get_first_node_in_group("castle")
		if castle:
			set_target_position(castle.global_position)
		return

	var direction_to_target = global_position.direction_to(current_target.global_position)
	if direction_to_target.x < -0.1:
		sprite.flip_h = true
	elif direction_to_target.x > 0.1:
		sprite.flip_h = false
	
	var distance_to_target = global_position.distance_to(current_target.global_position)
	
	
	var effective_range: float
	if current_target.is_in_group("towers"):
		effective_range = tower_attack_range
	elif current_target.is_in_group("castle"):
		effective_range = castle_attack_range
	else:
		effective_range = attack_range
		
	if distance_to_target > effective_range:
		# BEHAVIOR: PURSUE
		velocity = direction_to_target * movement_speed
		state_machine.travel("walk")
	else:
		velocity = Vector2.ZERO
		
		if attack_cooldown.is_stopped():
			perform_attack()
		else:
			state_machine.travel("idle")


func change_state(new_state: State):
	current_state = new_state

func _on_player_detection_area_body_entered(body):
	if body.is_in_group("player"):
		current_target = body
		change_state(State.ATTACK)

func _on_player_detection_area_body_exited(body):
	if body == current_target:
		current_target = null
		change_state(State.MOVE)
		var castle = get_tree().get_first_node_in_group("castle")
		if castle:
			set_target_position(castle.global_position)

func _on_attack_area_body_entered(body):
	var target = body.owner
	
	if current_state == State.MOVE:
		if target.is_in_group("towers") or target.is_in_group("castle"):
			current_target = target
			change_state(State.ATTACK)

func _on_attack_area_body_exited(body):
	if body == current_target:
		current_target = null
		change_state(State.MOVE)

func perform_attack():
	state_machine.travel("attack_1")
	
	if is_instance_valid(current_target) and current_target.has_method("take_damage"):
		current_target.take_damage(attack_damage)
	
	attack_cooldown.start()


func take_damage(amount: int):
	if current_state == State.DIE:
		return
		
	health -= amount
	
	show_damage_number(amount)
	update_health_bar()
	show_hit_effect()
	
	if health <= 0:
		die_from_combat()


func die_from_combat():
	if current_state == State.DIE:
		return
		
	change_state(State.DIE)
	velocity = Vector2.ZERO
	
	$CollisionShape2D.set_deferred("disabled", true)
	
	died.emit(gold_value)
	
	create_death_effects()
	
	await get_tree().create_timer(0.8).timeout
	queue_free()

func die_peacefully():
	queue_free()

func show_hit_effect():
	is_taking_damage = true
	sprite.modulate = Color.RED
	await get_tree().create_timer(0.08).timeout
	sprite.modulate = Color.WHITE
	await get_tree().create_timer(0.08).timeout
	sprite.modulate = original_modulate
	is_taking_damage = false

func show_damage_number(damage_amount: int):
	if damage_numbers_scene:
		var damage_instance = damage_numbers_scene.instantiate()
		get_parent().add_child(damage_instance)
		damage_instance.global_position = global_position + Vector2(0, -20)
		damage_instance.setup(damage_amount)

func update_health_bar():
	if health_bar:
		if not health_bar_stylebox_is_unique:
			var fill_stylebox = health_bar.get_theme_stylebox("fill")
			var unique_fill_stylebox = fill_stylebox.duplicate()
			health_bar.add_theme_stylebox_override("fill", unique_fill_stylebox)
			health_bar_stylebox_is_unique = true
		
		health_bar.value = health
		health_bar.visible = true
		var health_percent = float(health) / float(max_health)
		if health_percent > 0.6:
			health_bar.modulate = Color.GREEN
		elif health_percent > 0.3:
			health_bar.modulate = Color.YELLOW
		else:
			health_bar.modulate = Color.RED

func create_death_effects():
	var tween = create_tween()
	tween.parallel().tween_property(sprite, "modulate:a", 0.0, 0.5)
	tween.parallel().tween_property(sprite, "scale", Vector2(1.2, 1.2), 0.3)
	tween.parallel().tween_property(sprite, "scale", Vector2(0.8, 0.8), 0.5).set_delay(0.3)
	tween.parallel().tween_property(sprite, "rotation", randf_range(-PI/4, PI/4), 0.4)
