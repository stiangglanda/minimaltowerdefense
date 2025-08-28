extends Area2D

@export var projectile_scene: PackedScene
@export var fire_rate: float = 1.0
@export var health: int = 200
@export var destruction_effect_scene: PackedScene

var max_health: int
var is_destroyed: bool = false

var target = null
var enemies_in_range: Array = []

@onready var fire_rate_timer: Timer = $FireRate
@onready var muzzle: Marker2D = $Muzzle
@onready var sprite: Sprite2D = $Sprite2D
@onready var bow: Sprite2D = $Bow
@onready var animation_tree = $AnimationTree
@onready var state_machine = animation_tree.get("parameters/playback")
@onready var hitbox: StaticBody2D = $Footprint

var original_sprite_modulate: Color
var original_bow_modulate: Color


func _ready():
	add_to_group("towers")
	
	max_health = health
	original_sprite_modulate = sprite.modulate
	original_bow_modulate = bow.modulate

	fire_rate_timer.wait_time = fire_rate
	fire_rate_timer.start()

func _process(delta: float):
	if is_destroyed:
		return

	if not is_instance_valid(target):
		find_new_target()

func find_new_target():
	enemies_in_range = enemies_in_range.filter(func(enemy): return is_instance_valid(enemy))
	
	if not enemies_in_range.is_empty():
		target = enemies_in_range[0]
		
		var direction_to_target = global_position.direction_to(target.global_position)
		if direction_to_target.x < -0.1:
			$Bow.flip_h = true
		elif direction_to_target.x > 0.1:
			$Bow.flip_h = false
	else:
		target = null

func _on_firerate_timeout():
	if is_instance_valid(target):
		start_attack(target)

func start_attack(p_target):
	target = p_target
	
	state_machine.travel("attack")

func _fire_projectile():
	if not is_instance_valid(target):
		return
		
	if not projectile_scene:
		print("ERROR: Projectile scene not set on tower!")
		return
		
	var projectile = projectile_scene.instantiate()
	get_tree().root.add_child(projectile)
	
	projectile.global_transform = muzzle.global_transform
	projectile.look_at(target.global_position)

func _on_body_entered(body: Node2D):
	if body.is_in_group("enemies"):
		enemies_in_range.append(body)
		if not is_instance_valid(target):
			find_new_target()

func _on_body_exited(body: Node2D):
	if body in enemies_in_range:
		enemies_in_range.erase(body)
		if body == target:
			find_new_target()

func take_damage(amount: int):
	if is_destroyed:
		return

	health -= amount
	
	if health <= 0:
		destroy_tower()
	else:
		show_hit_effect()


func show_hit_effect():
	sprite.modulate = Color.RED
	bow.modulate = Color.RED
	await get_tree().create_timer(0.08).timeout
	
	sprite.modulate = Color.WHITE
	bow.modulate = Color.WHITE
	await get_tree().create_timer(0.08).timeout
	
	sprite.modulate = original_sprite_modulate
	bow.modulate = original_bow_modulate


func destroy_tower():
	is_destroyed = true
	set_process(false)
	fire_rate_timer.stop()
	
	remove_from_group("towers")
	hitbox.get_node("CollisionShape2D").set_deferred("disabled", true)
	get_node("Range").set_deferred("disabled", true)

	if destruction_effect_scene:
		var effect = destruction_effect_scene.instantiate()
		get_parent().add_child(effect)
		effect.global_position = global_position

	var tween = create_tween().set_parallel(true)
	tween.tween_property(self, "modulate:a", 0.0, 0.5)
	tween.tween_property(self, "scale", Vector2.ZERO, 0.5)
	
	await tween.finished
	queue_free()
