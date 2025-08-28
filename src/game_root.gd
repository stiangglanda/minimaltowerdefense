extends Node2D

@export var tower_scene: PackedScene

var tower_data_to_build: Dictionary
var is_placing = false
var ghost_tower = null

@onready var tile_map = $"NavigationRegion2D/y-sort/TileMapLayer3"
@onready var towers_node = $"NavigationRegion2D/y-sort/towers"

@export var enemy_scene: PackedScene

@onready var spawn_point = $NavigationRegion2D/spawn
@onready var castle = $NavigationRegion2D/castle
@onready var spawn_timer = $NavigationRegion2D/Timer
@onready var enemy_spawn_node = $"NavigationRegion2D/y-sort/enemys"
@onready var player = $"NavigationRegion2D/y-sort/Player"
@onready var build_menu = $BuildMenu

func _ready():
	spawn_timer.timeout.connect(_on_spawn_timer_timeout)
	spawn_timer.start()

func _on_spawn_timer_timeout():
	if not enemy_scene:
		return
		
	var new_enemy = enemy_scene.instantiate()
	enemy_spawn_node.add_child(new_enemy)
	new_enemy.global_position = spawn_point.global_position
	new_enemy.set_target_position(castle.global_position)
	
	new_enemy.died.connect(player.add_gold)
	
	player.gold_updated.connect(build_menu.on_player_gold_updated)
	build_menu.build_tower_selected.connect(_on_build_menu_build_tower_selected)
	build_menu.on_player_gold_updated(player.gold)

func _on_build_menu_build_tower_selected(tower_data: Dictionary):
	if is_placing:
		cancel_placement()
	
	if player.gold >= tower_data.cost:
		tower_data_to_build = tower_data
		start_placement()
	else:
		print("UI let you click, but you can't afford it!")

func _input(event):
	if is_placing and Input.is_action_just_pressed("accept"):
		place_tower()
		get_tree().get_root().set_input_as_handled()

	if is_placing and Input.is_action_just_pressed("cancel"):
		cancel_placement()
		get_tree().get_root().set_input_as_handled()

func _process(delta):
	if is_placing:
		update_ghost_tower()

func start_placement():
	if !tower_scene:
		print("ERROR: Tower scene not set.")
		return
	
	is_placing = true
	ghost_tower = tower_scene.instantiate()
	ghost_tower.modulate.a = 0.5 
	add_child(ghost_tower)

func cancel_placement():
	if is_placing:
		is_placing = false
		ghost_tower.queue_free()
		ghost_tower = null

func update_ghost_tower():
	var mouse_pos = get_global_mouse_position()
	var map_coords = tile_map.local_to_map(mouse_pos)
	var snapped_pos = tile_map.map_to_local(map_coords)
	ghost_tower.global_position = snapped_pos
	
	ghost_tower.monitoring = false
	ghost_tower.monitorable = false

	var footprint = ghost_tower.get_node("Footprint")
	var space_state = get_world_2d().direct_space_state
	var shape = footprint.get_node("CollisionShape2D").shape
	
	var query = PhysicsShapeQueryParameters2D.new()
	query.transform = footprint.global_transform
	query.shape = shape
	
	query.collision_mask = footprint.collision_mask 
	query.exclude = [footprint.get_rid()]
	var intersecting_bodies = space_state.intersect_shape(query)
	
	if intersecting_bodies.is_empty():
		ghost_tower.modulate = Color(0.5, 1, 0.5, 0.5)
	else:
		ghost_tower.modulate = Color(1, 0.5, 0.5, 0.5)

func place_tower():
	var footprint = ghost_tower.get_node("Footprint")
	var space_state = get_world_2d().direct_space_state
	var query = PhysicsShapeQueryParameters2D.new()
	query.transform = footprint.global_transform
	query.shape = footprint.get_node("CollisionShape2D").shape
	query.collision_mask = footprint.collision_mask
	query.exclude = [footprint.get_rid()]
	var intersecting_bodies = space_state.intersect_shape(query)

	if intersecting_bodies.is_empty() and player.spend_gold(tower_data_to_build.cost):
		var new_tower = tower_scene.instantiate()
		new_tower.global_position = ghost_tower.global_position
		towers_node.add_child(new_tower)
		
		cancel_placement()
