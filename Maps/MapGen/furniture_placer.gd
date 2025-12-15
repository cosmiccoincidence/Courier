# furniture_placer.gd
# Helper class for placing furniture in buildings without replacing floor tiles
class_name FurniturePlacer
extends RefCounted

# References
var map_generator: GridMap
var world_node: Node  # Parent node to add furniture to

# Furniture scenes
var furniture_scenes: Dictionary = {
	"chair": null,  # Set these in setup
	"table": null,
	"bed": null,
	"chest": null,
}

# Settings
var min_furniture_per_room: int = 0  # Changed: Can have 0 furniture
var max_furniture_per_room: int = 1  # Changed: Max 1 per room
var furniture_spawn_chance: float = 0.5  # 50% chance to spawn furniture in room
var min_distance_from_door: int = 2  # Minimum tiles away from doorway

func setup(generator: GridMap, world: Node):
	map_generator = generator
	world_node = world
	print("[FurniturePlacer] Setup complete. World node: ", world_node.name if world_node else "NULL")

func set_furniture_scene(furniture_type: String, scene: PackedScene):
	"""Register a furniture scene type"""
	furniture_scenes[furniture_type] = scene
	print("[FurniturePlacer] Registered furniture scene: ", furniture_type, " -> ", scene)

func place_furniture_in_room(room_start: Vector3i, room_width: int, room_length: int, door_pos: Vector3i = Vector3i(-999, 0, -999)):
	"""Place random furniture in a room's interior, avoiding door area"""
	
	print("  [Furniture] Attempting to place furniture in room at ", room_start, " (", room_width, "x", room_length, ")")
	print("  [Furniture] Door position: ", door_pos)
	
	# Get interior positions (not walls)
	var interior_positions = []
	for x in range(1, room_width - 1):
		for z in range(1, room_length - 1):
			var pos = Vector3i(room_start.x + x, 0, room_start.z + z)
			
			# Check distance from door if door position is provided
			if door_pos != Vector3i(-999, 0, -999):
				var distance_to_door = abs(pos.x - door_pos.x) + abs(pos.z - door_pos.z)
				if distance_to_door < min_distance_from_door:
					continue  # Too close to door, skip this position
			
			interior_positions.append(pos)
	
	print("  [Furniture] Found ", interior_positions.size(), " valid interior positions")
	
	if interior_positions.size() == 0:
		print("  [Furniture] No valid positions - room too small or all positions too close to door")
		return  # Room too small or all positions too close to door
	
	# Random chance to not spawn furniture at all
	var spawn_roll = randf()
	print("  [Furniture] Spawn chance roll: ", spawn_roll, " vs ", furniture_spawn_chance)
	if spawn_roll > furniture_spawn_chance:
		print("  [Furniture] Failed spawn chance - no furniture placed")
		return
	
	# Shuffle positions for random placement
	interior_positions.shuffle()
	
	# Place exactly 1 furniture piece (since we passed the spawn chance)
	var furniture_count = 1  # Changed: Always place 1 if we passed the spawn chance
	
	print("  [Furniture] Placing ", furniture_count, " furniture pieces")
	
	for i in range(furniture_count):
		var grid_pos = interior_positions[i]
		
		# Only spawn non-door furniture (chests, tables, etc)
		var furniture_type = get_random_non_door_furniture_type()
		
		print("  [Furniture] Selected type: ", furniture_type)
		
		if furniture_type and furniture_scenes[furniture_type]:
			spawn_furniture(grid_pos, furniture_type)
		else:
			print("  [Furniture] ERROR: No scene for furniture type: ", furniture_type)

func place_door_at_position(door_pos: Vector3i, wall_side: int):
	"""Place a door furniture at the specified position with correct rotation"""
	if not furniture_scenes.has("door") or not furniture_scenes["door"]:
		print("  [Furniture] No door scene registered - skipping door placement")
		return
	
	# Calculate rotation based on wall side (cardinal directions only)
	var rotation_y = 0.0
	match wall_side:
		0:  # Top wall (facing down/south)
			rotation_y = 0.0
		1:  # Bottom wall (facing up/north)
			rotation_y = PI  # 180 degrees
		2:  # Left wall (facing right/east)
			rotation_y = PI / 2  # 90 degrees
		3:  # Right wall (facing left/west)
			rotation_y = -PI / 2  # 270 degrees (or -90)
	
	spawn_furniture_with_rotation(door_pos, "door", rotation_y)
	print("  [Furniture] Placed door at ", door_pos, " (wall side: ", wall_side, ", rotation: ", rad_to_deg(rotation_y), "°)")

func spawn_furniture(grid_pos: Vector3i, furniture_type: String):
	"""Spawn a furniture instance at the given grid position with random rotation"""
	spawn_furniture_with_rotation(grid_pos, furniture_type, randf() * TAU)

func spawn_furniture_with_rotation(grid_pos: Vector3i, furniture_type: String, rotation_y: float):
	"""Spawn a furniture instance at the given grid position with specific rotation"""
	var scene = furniture_scenes[furniture_type]
	if not scene:
		print("  [Furniture] ERROR: No scene found for type: ", furniture_type)
		return
	
	# Convert grid position to world position
	var world_pos = map_generator.map_to_local(grid_pos)
	world_pos.y = 0.5  # Slightly above floor to prevent z-fighting
	
	print("  [Furniture] Grid pos: ", grid_pos, " -> World pos: ", world_pos)
	
	# Instantiate furniture
	var furniture_instance = scene.instantiate()
	
	if not furniture_instance:
		print("  [Furniture] ERROR: Failed to instantiate scene!")
		return
	
	print("  [Furniture] Instantiated: ", furniture_instance.name, " (Type: ", furniture_instance.get_class(), ")")
	
	# Debug: Print all children
	print("  [Furniture] Children of ", furniture_instance.name, ":")
	for child in furniture_instance.get_children():
		print("    - ", child.name, " (", child.get_class(), ")")
	
	if furniture_instance is Node3D:
		print("  [Furniture] Instantiated Node3D: ", furniture_instance.name)
		
		# Set position BEFORE adding to tree (this works fine)
		furniture_instance.position = world_pos
		furniture_instance.rotation.y = rotation_y
		
		# Add to world
		world_node.add_child(furniture_instance)
		
		print("  [Furniture] Successfully placed ", furniture_type, " in scene tree")
		print("  [Furniture] Final position: ", furniture_instance.global_position)
	else:
		print("  [Furniture] ERROR: Instantiated scene is not a Node3D! Type: ", furniture_instance.get_class())

func get_random_non_door_furniture_type() -> String:
	"""Get a random furniture type from available scenes, excluding doors"""
	var available = []
	for type in furniture_scenes.keys():
		if furniture_scenes[type] and type != "door":  # Exclude doors
			available.append(type)
	
	print("  [Furniture] Available non-door furniture types: ", available)
	
	if available.size() == 0:
		print("  [Furniture] ERROR: No non-door furniture scenes registered!")
		return ""
	
	return available[randi() % available.size()]

func get_random_furniture_type() -> String:
	"""Get a random furniture type from available scenes"""
	var available = []
	for type in furniture_scenes.keys():
		if furniture_scenes[type]:
			available.append(type)
	
	print("  [Furniture] Available furniture types: ", available)
	
	if available.size() == 0:
		print("  [Furniture] ERROR: No furniture scenes registered!")
		return ""
	
	return available[randi() % available.size()]
