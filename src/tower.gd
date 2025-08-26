extends Area2D

@export var projectile_scene: PackedScene

@export var fire_rate: float = 1.0

var target: Node2D = null
var enemies_in_range: Array = []

@onready var fire_rate_timer: Timer = $FireRate
@onready var muzzle: Marker2D = $Muzzle
@onready var sprite: Sprite2D = $Sprite2D
@onready var bow: Sprite2D = $Bow

func _ready():
	fire_rate_timer.wait_time = fire_rate
	fire_rate_timer.start()

func _process(delta: float):
	if is_instance_valid(target):
		bow.look_at(target.global_position)
	else:
		find_new_target()

func find_new_target():
	enemies_in_range = enemies_in_range.filter(func(enemy): return is_instance_valid(enemy))
	
	if not enemies_in_range.is_empty():
		target = enemies_in_range[0]
	else:
		target = null

func _on_firerate_timeout():
	if is_instance_valid(target):
		shoot()

func shoot():
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
