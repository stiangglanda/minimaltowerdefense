extends CharacterBody2D

signal gold_updated(new_gold_amount)

@onready var animation_tree = $AnimationTree
@onready var state_machine = animation_tree.get("parameters/playback")
@onready var attack_area = $AttackArea
@onready var attack_collision = $AttackArea/AttackCollisionShape
@onready var health_bar = $CanvasLayer/Control/HealthProgressBar
@onready var end_game_label = $CanvasLayer/Control/EndGame
@onready var sprite = $Sprite2D
@onready var GoldLabel = $CanvasLayer/Control/HBoxContainer/GoldLabel
@onready var regen_delay_timer: Timer = $RegenDelayTimer
@onready var regen_tick_timer: Timer = $RegenTickTimer

@export_group("Regeneration")
@export var regen_delay: float = 5.0
@export var regen_amount: int = 5
@export var regen_tick_rate: float = 1.0

@export var health: int = 300
@export var max_health: int = 300

const SPEED = 300.0
const ACCEL = 5.0
const ATTACK_DAMAGE = 25

var input: Vector2
var attack_combo = 0
var can_attack = true
var enemies_in_range = []
var isDead = false
var original_modulate: Color
var gold = 10

func _ready():
	attack_area.body_entered.connect(_on_enemy_entered_range)
	attack_area.body_exited.connect(_on_enemy_exited_range)
	
	animation_tree.animation_finished.connect(_on_animation_finished)
	original_modulate = sprite.modulate
	gold_updated.emit(gold)
	
	regen_delay_timer.wait_time = regen_delay
	regen_tick_timer.wait_time = regen_tick_rate
	regen_delay_timer.timeout.connect(_on_regen_delay_timer_timeout)
	regen_tick_timer.timeout.connect(_on_regen_tick_timer_timeout)
	
	update_health_bar()

func get_input():
	input.x = Input.get_action_strength("right") - Input.get_action_strength("left")
	input.y = Input.get_action_strength("down") - Input.get_action_strength("up")
	return input.normalized()

func _physics_process(delta):
	var playerInput = get_input()
	
	if(playerInput.x <= -0.5):
		sprite.flip_h = true
	elif(playerInput.x >= 0.5):
		sprite.flip_h = false
	
	if Input.is_action_just_pressed("attack") and can_attack:
		handle_attack()
	else:
		pick_new_state(playerInput)
		velocity = lerp(velocity, playerInput * SPEED, delta * ACCEL)
	
	move_and_slide()

func handle_attack():
	if not can_attack:
		return
		
	velocity = Vector2.ZERO
	can_attack = false
	
	if attack_combo == 0:
		state_machine.travel("attack_1")
		attack_combo = 1
	else:
		state_machine.travel("attack_2")
		attack_combo = 0
		
	get_tree().create_timer(0.3).timeout.connect(deal_damage)

func deal_damage():
	for enemy in enemies_in_range:
		if enemy and is_instance_valid(enemy) and enemy.is_in_group("enemies"):
			if enemy.has_method("take_damage"):
				enemy.take_damage(ATTACK_DAMAGE)
				print("Player dealt ", ATTACK_DAMAGE, " damage to enemy!")

func pick_new_state(playerInput):
	var current_state = state_machine.get_current_node()
	if current_state == "attack_1" or current_state == "attack_2":
		return
	if playerInput != Vector2.ZERO:
		state_machine.travel("walk")
	else:
		state_machine.travel("idle")

func _on_enemy_entered_range(body):
	if body.has_method("take_damage"):
		enemies_in_range.append(body)

func _on_enemy_exited_range(body):
	if body in enemies_in_range:
		enemies_in_range.erase(body)

func _on_animation_finished(anim_name):
	if anim_name == "attack_1" or anim_name == "attack_2":
		can_attack = true

func take_damage(amount: int):
	if isDead:
		return
		
	health -= amount
	
	update_health_bar()
	show_hit_effect()
	
	regen_tick_timer.stop()
	regen_delay_timer.start()
	
	if health <= 0:
		die_from_combat()


func die_from_combat():
	if isDead:
		return
		
	isDead = true
	velocity = Vector2.ZERO
	
	$CollisionShape2D.set_deferred("disabled", true)
	create_death_effects()
	end_game()
	
	await get_tree().create_timer(3).timeout
	queue_free()

func show_hit_effect():
	sprite.modulate = Color.RED
	await get_tree().create_timer(0.08).timeout
	sprite.modulate = Color.WHITE
	await get_tree().create_timer(0.08).timeout
	sprite.modulate = original_modulate

func update_health_bar():
	if health_bar:
		health_bar.value = health
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
	
func _on_regen_delay_timer_timeout():
	print("Player is now out of combat. Starting regeneration.")
	if health < max_health:
		regen_tick_timer.start()

func _on_regen_tick_timer_timeout():
	health += regen_amount
	
	health = min(health, max_health)
	
	print("Player regenerated %d HP. Current health: %d" % [regen_amount, health])
	update_health_bar()
	
	if health >= max_health:
		regen_tick_timer.stop()
		print("Health is full. Stopping regeneration.")

func add_gold(amount: int):
	gold += amount
	GoldLabel.text = str(gold)
	gold_updated.emit(gold)
	print("Player received %d gold! Total gold: %d" % [amount, gold])

func spend_gold(amount: int) -> bool:
	if gold >= amount:
		gold -= amount
		gold_updated.emit(gold)
		print("Player spent %d gold! Total gold: %d" % [amount, gold])
		return true
	else:
		print("Not enough gold!")
		return false

func end_game():
	end_game_label.visible = true
