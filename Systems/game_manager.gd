# game_manager.gd
extends Node

@export var starting_map: PackedScene
@export var level_1a: PackedScene
@export var level_1b: PackedScene
@export var level_1c: PackedScene
@export var level_1d: PackedScene
@export var level_1e: PackedScene
@export var town_1: PackedScene
@export var ending_map: PackedScene

@onready var map_container: Node3D = get_node("../MapContainer")
@onready var player: CharacterBody3D = get_node("../Player")
@onready var player_spawn: Marker3D = get_node("../PlayerSpawn")
@onready var fade_rect = $"/root/World/BlackScreen/FadeRect"

var current_map: Node3D = null
var current_level_index: int = 0
var level_sequence: Array[PackedScene] = []

func _ready():
	# Set up level sequence
	level_sequence = [starting_map, level_1a, level_1b, level_1c, level_1d, level_1e, town_1, ending_map]
	
	if starting_map:
		load_map(starting_map)

func load_map(map_scene: PackedScene) -> void:
	# Fade to black first
	await fade_rect.fade_out_wait()
	
	var is_ending = (map_scene == ending_map)
	
	# Advance time (skip first map)
	if current_map != null:
		TimeManager.advance_time()
	
	# Clear old map
	if current_map:
		current_map.queue_free()
	
	# Clear all enemies and items
	clear_level_entities()
	
	# Load new map
	current_map = map_scene.instantiate()
	map_container.add_child(current_map)
	
	await get_tree().process_frame
	
	# Find the map generator - could be named differently depending on map type
	var map_gen = find_map_generator(current_map)
	
	if map_gen and map_gen.has_method("start_generation"):
		map_gen.player_reached_exit.connect(_on_player_reached_exit)
		
		map_gen.start_generation()
		await map_gen.generation_complete
		
		# IMPORTANT: Move player IMMEDIATELY after generation completes
		# This must happen BEFORE FOV initializes
		if map_gen.has_method("get_entrance_zone_spawn_position"):
			var spawn_pos = map_gen.get_entrance_zone_spawn_position()
			print("GameManager: Spawning player at: ", spawn_pos)
			
			if player:
				player.global_position = spawn_pos
				print("GameManager: Player position set to: ", player.global_position)
			if player_spawn:
				player_spawn.global_position = spawn_pos
		
		# Wait a frame to ensure position is fully updated
		await get_tree().process_frame
		
		# Update HUD with map info
		update_map_label(map_gen)
	
	if is_ending and player and player.hud:
		player.hud.show_ending_message()
	
	# Finally fade back in
	await fade_rect.fade_in_wait()

func update_map_label(map_gen: Node):
	"""Update the HUD map label with current map info"""
	if not player or not player.hud:
		print("GameManager: No player or HUD found")
		return
	
	var act_num = 1  # Default
	var map_num = 1  # Default
	var map_name = ""  # Optional map name
	
	# Get act_number if it exists
	if map_gen.get("act_number") != null:
		act_num = map_gen.get("act_number")
	
	# Get map_number if it exists
	if map_gen.get("map_number") != null:
		map_num = map_gen.get("map_number")
	
	# Get map_name if it exists (for manual maps like towns, start, end)
	if map_gen.get("map_name") != null:
		map_name = map_gen.get("map_name")
	
	print("GameManager: Updating HUD to Map ", act_num, ":", map_num, " - ", map_name)
	
	# Update the HUD
	if player.hud.has_method("_on_map_loaded"):
		player.hud._on_map_loaded(act_num, map_num, map_name)

func find_map_generator(map_root: Node) -> Node:
	"""
	Find the map generator node in the loaded map scene.
	Searches for nodes with generation capability in this priority:
	1. Direct child named "GridMap" (for generated maps)
	2. Direct child that is a ManualMap
	3. Direct child named "PrimaryGridMap" (for dual-grid manual maps)
	4. Any GridMap child
	"""
	
	# Try common names first
	if map_root.has_node("GridMap"):
		return map_root.get_node("GridMap")
	
	if map_root.has_node("PrimaryGridMap"):
		return map_root.get_node("PrimaryGridMap")
	
	# Search for ManualMap or any GridMap
	for child in map_root.get_children():
		# Check if it's a ManualMap
		if child is ManualMap:
			print("GameManager: Found ManualMap: ", child.name)
			return child
		
		# Check if it's a GridMap with generation capabilities
		if child is GridMap and child.has_method("start_generation"):
			print("GameManager: Found GridMap with generation: ", child.name)
			return child
	
	# Fallback: just find any GridMap
	for child in map_root.get_children():
		if child is GridMap:
			print("GameManager: Found GridMap (fallback): ", child.name)
			return child
	
	push_warning("GameManager: No map generator found in ", map_root.name)
	return null

func _on_player_reached_exit():
	current_level_index += 1
	
	if current_level_index < level_sequence.size():
		load_map(level_sequence[current_level_index])

func clear_level_entities():
	var world = get_parent()
	
	for child in world.get_children():
		if child.is_in_group("enemy"):
			child.queue_free()
	
	for child in world.get_children():
		if child.is_in_group("item"):
			child.queue_free()
