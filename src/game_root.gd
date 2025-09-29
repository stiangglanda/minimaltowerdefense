extends Node2D

var tower_data_to_build: Dictionary
var is_placing = false
var ghost_tower = null

@export var force_mobile_controls_for_testing: bool = false

@onready var tile_map = $"NavigationRegion2D/y-sort/TileMapLayer3"
@onready var towers_node = $"NavigationRegion2D/y-sort/towers"

@export var enemy_scene: PackedScene
@export var MobileControlsScene: PackedScene

@onready var spawn_points: Dictionary = {
	"spawn1": $NavigationRegion2D/spawn1,
	"spawn2": $NavigationRegion2D/spawn2
}
@onready var castle = $NavigationRegion2D/castle
@onready var wave_timer = $WaveTimer
@onready var spawn_in_wave_timer = $SpawnInWaveTimer
@onready var enemy_spawn_node = $"NavigationRegion2D/y-sort/enemys"
@onready var player = $"NavigationRegion2D/y-sort/Player"
@onready var GameOver = $GameOver
@onready var build_menu = $BuildMenu

var wave_number: int = 0
var is_in_wave: bool = false
var current_wave_enemies_to_spawn: Array = []

func _is_mobile() -> bool:
	if OS.has_feature("mobile"):
		return true
	
	if Engine.has_singleton("JavaScriptBridge"):
		var js_bridge = Engine.get_singleton("JavaScriptBridge")
		var result = js_bridge.eval("isMobileDevice()")
		return result == true
	
	return false

func _ready():	
	wave_timer.timeout.connect(_on_wave_timer_timeout)
	spawn_in_wave_timer.timeout.connect(_on_spawn_in_wave_timer_timeout)
	
	player.gold_updated.connect(build_menu.on_player_gold_updated)
	build_menu.build_tower_selected.connect(_on_build_menu_build_tower_selected)
	build_menu.on_player_gold_updated(player.gold)
	
	wave_timer.start(5.0)
	print("Game started. First wave in 5 seconds.")
	
	if _is_mobile() or force_mobile_controls_for_testing:
		var mobile_controls = MobileControlsScene.instantiate()
		add_child(mobile_controls)
		print("Mobile device detected. Adding touch controls.")

func _on_wave_timer_timeout():
	wave_number += 1
	is_in_wave = true
	print("--- Wave %d starting! ---" % wave_number)
	
	# Generate the list of enemies for this new wave
	current_wave_enemies_to_spawn = _generate_wave_plan()
	
	# Set the spawn speed for this wave (gets faster over time)
	var spawn_interval = max(0.2, 1.5 - (wave_number * 0.05))
	spawn_in_wave_timer.wait_time = spawn_interval
	
	# Start the timer that spawns enemies one by one
	spawn_in_wave_timer.start()

func _on_spawn_in_wave_timer_timeout():
	if current_wave_enemies_to_spawn.is_empty():
		# The wave is over!
		spawn_in_wave_timer.stop()
		is_in_wave = false
		print("Wave %d complete. Next wave in 10 seconds." % wave_number)
		wave_timer.start(10.0) 
	else:
		var enemy_data = current_wave_enemies_to_spawn.pop_front()
		_spawn_enemy(enemy_data)


func _generate_wave_plan() -> Array:
	var plan: Array = []
	
	# --- WAVE 1: Simple introduction ---
	if wave_number == 1:
		for i in 5: # Spawn 5 basic enemies
			plan.append({
				"scene": enemy_scene,
				"spawn_point": "spawn1",
				"health_multiplier": 1.0
			})
			
	# --- WAVE 2: A few more enemies ---
	elif wave_number == 2:
		for i in 8:
			plan.append({
				"scene": enemy_scene,
				"spawn_point": "spawn1",
				"health_multiplier": 1.2 # Slightly tougher!
			})
			
	# --- WAVE 3: Introduce the SECOND SPAWN POINT! ---
	elif wave_number == 3:
		for i in 6: # 6 enemies from the first point
			plan.append({"scene": enemy_scene, "spawn_point": "spawn1", "health_multiplier": 1.2})
		for i in 3: # 3 enemies from the second point!
			plan.append({"scene": enemy_scene, "spawn_point": "spawn2", "health_multiplier": 1.0})
			
	# --- After Wave 3, use a formula for endless difficulty ---
	else:
		var enemy_count = 5 + (wave_number * 2) # Number of enemies increases each wave
		var health_mult = 1.0 + (wave_number * 0.15) # Health increases each wave
		
		for i in enemy_count:
			var spawn_location = "spawn1" if i % 2 == 0 else "spawn2"
			plan.append({
				"scene": enemy_scene,
				"spawn_point": spawn_location,
				"health_multiplier": health_mult
			})

	return plan

func _spawn_enemy(enemy_data: Dictionary):
	if not enemy_data.scene or not spawn_points.has(enemy_data.spawn_point):
		print("Error: Invalid enemy data for spawning.")
		return
		
	var new_enemy = enemy_data.scene.instantiate()
	
	if "health" in new_enemy and "max_health" in new_enemy:
		var scaled_max_health = new_enemy.max_health * enemy_data.health_multiplier
		new_enemy.max_health = scaled_max_health
		new_enemy.health = scaled_max_health

	var spawn_node = spawn_points[enemy_data.spawn_point]
	new_enemy.global_position = spawn_node.global_position
	
	enemy_spawn_node.add_child(new_enemy)
	
	new_enemy.set_target_position(castle.global_position)
	new_enemy.died.connect(player.add_gold)
	new_enemy.died.connect(GameOver.IncreseHighscore)

func _on_build_menu_build_tower_selected(tower_data: Dictionary):
	if is_placing:
		cancel_placement()
	
	if player.gold >= tower_data.cost:
		tower_data_to_build = tower_data
		start_placement(tower_data.scene)
	else:
		print("UI let you click, but you can't afford it!")

func _input(event):
	if is_placing and Input.is_action_just_pressed("accept"):
		place_tower(tower_data_to_build.scene)
		get_tree().get_root().set_input_as_handled()

	if is_placing and Input.is_action_just_pressed("cancel"):
		cancel_placement()
		get_tree().get_root().set_input_as_handled()

func _process(delta):
	if is_placing:
		update_ghost_tower()

func start_placement(tower_scene):
	if !tower_scene:
		print("ERROR: Tower scene not set.")
		return
	
	is_placing = true
	ghost_tower = tower_scene.instantiate()
	ghost_tower.set_as_ghost()
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

func place_tower(tower_scene):
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
