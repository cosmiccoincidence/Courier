# furniture_placer.gd
# Helper class for placing furniture in buildings without replacing floor tiles
class_name FurniturePlacer
extends RefCounted

# References
var map_generator: GridMap
var world_node: Node  # Parent node to add furniture to

# Furniture configs (type -> FurnitureSpawnConfig)
var furniture_configs: Dictionary = {}

# Track spawned furniture for cleanup
var spawned_furniture: Array = []

# Settings (can be overridden per placement call)
var default_spawn_chance: float = 0.5
var default_min_distance_from_door: int = 2

func setup(generator: GridMap, world: Node):
	map_generator = generator
	world_node = world
	spawned_furniture.clear()

func cleanup():
	"""Remove all spawned furniture from the scene"""
	for furniture in spawned_furniture:
		if is_instance_valid(furniture) and furniture.get_parent():
			furniture.queue_free()
	spawned_furniture.clear()

func register_furniture_config(config: FurnitureSpawnConfig):
	"""Register a furniture spawn configuration"""
	if config and config.furniture_scene:
		furniture_configs[config.furniture_type] = config

func place_furniture_in_room(room_start: Vector3i, room_width: int, room_length: int, door_pos: Vector3i = Vector3i(-999, 0, -999), furniture_types: Array = []):
	"""Place random furniture in a room's interior, avoiding door area
	   furniture_types: Array of furniture type strings to choose from (empty = all non-door types)"""
	
	# Get valid furniture types for this context
	var available_configs = get_available_furniture_configs(furniture_types, true)  # true = is_interior
	
	if available_configs.size() == 0:
		return
	
	# Get interior positions (not walls)
	var interior_positions = []
	for x in range(1, room_width - 1):
		for z in range(1, room_length - 1):
			var pos = Vector3i(room_start.x + x, 0, room_start.z + z)
			
			# Check distance from door if door position is provided
			var dist_from_door = 9999
			if door_pos != Vector3i(-999, 0, -999):
				dist_from_door = abs(pos.x - door_pos.x) + abs(pos.z - door_pos.z)
			
			interior_positions.append({"pos": pos, "dist_from_door": dist_from_door})
	
	if interior_positions.size() == 0:
		return
	
	# Shuffle positions for random placement
	interior_positions.shuffle()
	
	# Try to place furniture from each available config
	for config in available_configs:
		if randf() > config.spawn_chance:
			continue
		
		# Find valid position for this furniture
		for pos_data in interior_positions:
			var grid_pos = pos_data.pos
			var dist_from_door = pos_data.dist_from_door
			
			# Check if furniture can spawn here
			if dist_from_door < config.min_distance_from_door:
				continue
			
			# Check if position already used
			var position_used = false
			# TODO: Track used positions if multiple furniture per room
			
			if not position_used:
				spawn_furniture_from_config(grid_pos, config)
				break  # Only place one per config per room

func get_available_furniture_configs(filter_types: Array, is_interior: bool) -> Array:
	"""Get configs that match the filter and context"""
	var available = []
	
	for type in furniture_configs.keys():
		# Skip doors - they're placed separately
		if type == "door":
			continue
		
		# If filter specified, only include matching types
		if filter_types.size() > 0 and not filter_types.has(type):
			continue
		
		var config = furniture_configs[type]
		
		# Check if can spawn in this context
		if config.requires_interior and not is_interior:
			continue
		if config.requires_exterior and is_interior:
			continue
		
		available.append(config)
	
	return available

func spawn_furniture_from_config(grid_pos: Vector3i, config: FurnitureSpawnConfig):
	"""Spawn furniture using a config"""
	if not config.furniture_scene:
		return
	
	var rotation_y = randf() * TAU if not config.fixed_rotation else config.rotation_y
	spawn_furniture_with_rotation(grid_pos, config.furniture_scene, rotation_y, config.furniture_type)

func place_door_at_position(door_pos: Vector3i, wall_side: int):
	"""Place a door furniture at the specified position with correct rotation"""
	if not furniture_configs.has("door"):
		return
	
	var config = furniture_configs["door"]
	
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
	
	spawn_furniture_with_rotation(door_pos, config.furniture_scene, rotation_y, "door")

func spawn_furniture(grid_pos: Vector3i, scene: PackedScene, type_name: String = "furniture"):
	"""Spawn a furniture instance at the given grid position with random rotation"""
	spawn_furniture_with_rotation(grid_pos, scene, randf() * TAU, type_name)

func spawn_furniture_with_rotation(grid_pos: Vector3i, scene: PackedScene, rotation_y: float, type_name: String = "furniture"):
	"""Spawn a furniture instance at the given grid position with specific rotation"""
	if not scene:
		return
	
	# Convert grid position to world position
	var world_pos = map_generator.map_to_local(grid_pos)
	world_pos.y = 0.5  # Slightly above floor to prevent z-fighting
	
	# Instantiate furniture
	var furniture_instance = scene.instantiate()
	
	if not furniture_instance:
		return
	
	if furniture_instance is Node3D:
		# Set position BEFORE adding to tree
		furniture_instance.position = world_pos
		furniture_instance.rotation.y = rotation_y
		
		# Add to world
		world_node.add_child(furniture_instance)
		
		# Track for cleanup
		spawned_furniture.append(furniture_instance)
