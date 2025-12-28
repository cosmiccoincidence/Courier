# buildings_mapgen.gd
# Building generation feature - handles multi-room building placement
class_name BuildingsMapGen
extends RefCounted

# ============================================================================
# REFERENCES
# ============================================================================

var map_generator: GridMap
var parent_map_gen: CoreMapGen  # Reference to parent map generator for map_level
var entrance_zone_tiles: Array
var exit_zone_tiles: Array
var road_tiles: Array
var grass_tile_id: int
var interior_wall_tile_id: int
var exterior_wall_tile_id: int
var interior_floor_tile_id: int
var door_floor_tile_id: int

# ============================================================================
# SETTINGS
# ============================================================================

var min_buildings: int = 1
var max_buildings: int = 3
var min_building_width: int = 9
var max_building_width: int = 15
var min_building_length: int = 9
var max_building_length: int = 15

var min_rooms_per_building: int = 1
var max_rooms_per_building: int = 3
var extra_room_chance: float = 0.5
var min_additional_room_width: int = 5
var max_additional_room_width: int = 9
var min_additional_room_length: int = 5
var max_additional_room_length: int = 9

var building_exterior_wall_buffer: int = 3
var building_road_buffer: int = 15
var building_to_building_buffer: int = 20
var building_zone_buffer: int = 25

# ============================================================================
# DATA
# ============================================================================

var placed_buildings: Array = []
var furniture_placer: FurniturePlacer = null 
var wall_connector: AdvancedWallConnector = null  # Advanced wall mesh system 

# ============================================================================
# SETUP
# ============================================================================

func setup(generator: CoreMapGen):
	map_generator = generator
	parent_map_gen = generator  # Store reference to parent for map_level access
	entrance_zone_tiles = generator.entrance_zone_tiles
	exit_zone_tiles = generator.exit_zone_tiles
	grass_tile_id = generator.grass_tile_id
	interior_wall_tile_id = generator.interior_wall_tile_id
	exterior_wall_tile_id = generator.exterior_wall_tile_id
	interior_floor_tile_id = generator.interior_floor_tile_id
	door_floor_tile_id = generator.door_floor_tile_id
	
	# Get road tiles from roads generator
	if generator is Act1MapGen:
		road_tiles = generator.roads_generator.road_tiles
	
	# Setup furniture placer
	furniture_placer = FurniturePlacer.new()
	furniture_placer.setup(map_generator, map_generator.get_parent())
	
	# Pass map_level reference to furniture placer so it can set chest levels
	if "parent_map_gen" in furniture_placer:
		furniture_placer.parent_map_gen = parent_map_gen
	
	# Create and register furniture configs
	var door_config = FurnitureSpawnConfig.new()
	door_config.furniture_scene = preload("res://Assets/3D/Furniture/door.tscn")
	door_config.furniture_type = "door"
	door_config.spawn_chance = 1.0  # Always spawn doors
	door_config.fixed_rotation = true  # Doors use wall-based rotation
	door_config.requires_interior = true
	furniture_placer.register_furniture_config(door_config)
	
	var chest_config = FurnitureSpawnConfig.new()
	chest_config.furniture_scene = preload("res://Assets/3D/Furniture/chest.tscn")
	chest_config.furniture_type = "chest"
	chest_config.spawn_chance = 0.5  # 50% chance per room
	chest_config.min_per_area = 0
	chest_config.max_per_area = 1
	chest_config.min_distance_from_door = 2
	chest_config.requires_interior = true
	furniture_placer.register_furniture_config(chest_config)
	
	# Setup wall connector (if provided by generator)
	wall_connector = generator.get("interior_wall_connector")

# ============================================================================
# GENERATION
# ============================================================================

func generate():
	var num_buildings = randi_range(min_buildings, max_buildings)
	print("Generating ", num_buildings, " buildings...")
	
	# Clear any existing furniture from previous generation
	if furniture_placer:
		furniture_placer.cleanup()
	
	placed_buildings.clear()
	var buildings_created = 0
	var max_attempts = 50
	
	for i in range(num_buildings):
		var attempt = 0
		var building_placed = false
		
		while attempt < max_attempts and not building_placed:
			attempt += 1
			
			var width = randi_range(min_building_width, max_building_width)
			var length = randi_range(min_building_length, max_building_length)
			
			var start_pos = find_valid_building_position(width, length)
			
			if start_pos != Vector3i(-999, 0, -999):
				place_building(start_pos, width, length)
				buildings_created += 1
				building_placed = true
		
		if not building_placed:
			print("  Could not place building ", i + 1, " after ", max_attempts, " attempts")
	
	print("Successfully placed ", buildings_created, " buildings")
	
	# Apply advanced wall connections if wall connector is available
	if wall_connector:
		WallConnectorHelper.apply_interior_wall_connections(
			map_generator,
			wall_connector,
			interior_wall_tile_id,
			placed_buildings
		)

func find_valid_building_position(width: int, length: int) -> Vector3i:
	var used_cells = map_generator.get_used_cells()
	var grass_tiles_list = []
	
	for cell in used_cells:
		if map_generator.get_cell_item(cell) == grass_tile_id:
			grass_tiles_list.append(cell)
	
	for attempt in range(20):
		if grass_tiles_list.size() == 0:
			break
		
		var test_pos = grass_tiles_list[randi() % grass_tiles_list.size()]
		
		if is_valid_building_area(test_pos, width, length):
			return test_pos
	
	return Vector3i(-999, 0, -999)

func is_valid_building_area(start: Vector3i, width: int, length: int) -> bool:
	# Check distance to entry/exit zones
	for x in range(width):
		for z in range(length):
			var test_pos = Vector3i(start.x + x, 0, start.z + z)
			
			for entrance_tile in entrance_zone_tiles:
				var dist = abs(test_pos.x - entrance_tile.x) + abs(test_pos.z - entrance_tile.z)
				if dist < building_zone_buffer:
					return false
			
			for exit_tile in exit_zone_tiles:
				var dist = abs(test_pos.x - exit_tile.x) + abs(test_pos.z - exit_tile.z)
				if dist < building_zone_buffer:
					return false
	
	# Check distance to other buildings
	for building in placed_buildings:
		for room in building.rooms:
			var min_dist = 999999
			for x in range(width):
				for z in range(length):
					var test_pos = Vector3i(start.x + x, 0, start.z + z)
					
					for bx in range(room.width):
						for bz in range(room.length):
							var building_pos = Vector3i(room.start.x + bx, 0, room.start.z + bz)
							var dist = abs(test_pos.x - building_pos.x) + abs(test_pos.z - building_pos.z)
							min_dist = min(min_dist, dist)
							
							if min_dist < building_to_building_buffer:
								return false
	
	# Check buffers
	for x in range(-building_exterior_wall_buffer, width + building_exterior_wall_buffer):
		for z in range(-building_exterior_wall_buffer, length + building_exterior_wall_buffer):
			var check_pos = Vector3i(start.x + x, 0, start.z + z)
			var tile = map_generator.get_cell_item(check_pos)
			
			if x >= 0 and x < width and z >= 0 and z < length:
				if tile != grass_tile_id:
					return false
			
			if tile == exterior_wall_tile_id:
				return false
			
			if road_tiles.has(check_pos):
				var dist = min(abs(x), abs(z), abs(x - width + 1), abs(z - length + 1))
				if dist < building_road_buffer:
					return false
	
	return true

# ============================================================================
# BUILDING PLACEMENT
# ============================================================================

func place_building(start: Vector3i, width: int, length: int):
	print("  Placing ", width, "x", length, " building at ", start)
	
	var building_data = {
		"rooms": [{
			"start": start,
			"width": width,
			"length": length,
			"used_walls": [],
			"door_pos": Vector3i(-999, 0, -999)
		}]
	}
	
	place_room_walls_and_floor(start, width, length)
	
	# Add additional rooms
	var rooms_added = 1
	while rooms_added < max_rooms_per_building:
		if randf() > extra_room_chance:
			break
		
		if try_place_additional_room(building_data):
			rooms_added += 1
			print("    Added additional room ", rooms_added, "/", max_rooms_per_building)
		else:
			print("    Failed to place additional room")
			break
	
	place_exterior_door(building_data)
	
	# Place furniture in all rooms (only chests, doors are placed separately)
	if furniture_placer:
		for room in building_data.rooms:
			furniture_placer.place_furniture_in_room(room.start, room.width, room.length, room.door_pos, ["chest"])
	
	placed_buildings.append(building_data)

func place_room_walls_and_floor(start: Vector3i, width: int, length: int):
	"""Place walls on perimeter and floor tiles in interior"""
	for x in range(width):
		for z in range(length):
			var pos = Vector3i(start.x + x, 0, start.z + z)
			
			# Check if this is a perimeter tile (wall)
			if x == 0 or x == width - 1 or z == 0 or z == length - 1:
				var existing_tile = map_generator.get_cell_item(pos)
				
				# Only place wall if it's grass or empty (don't overwrite other rooms' walls)
				if existing_tile == grass_tile_id or existing_tile == -1:
					map_generator.set_cell_item(pos, interior_wall_tile_id)
			else:
				# Interior - place floor tile
				var existing_tile = map_generator.get_cell_item(pos)
				
				# Only place floor if it's grass or empty (allow floor to overwrite floor)
				if existing_tile == grass_tile_id or existing_tile == -1 or existing_tile == interior_floor_tile_id:
					map_generator.set_cell_item(pos, interior_floor_tile_id)

func try_place_additional_room(building_data: Dictionary) -> bool:
	for room in building_data.rooms:
		var walls = [0, 1, 2, 3]
		walls.shuffle()
		
		for wall_side in walls:
			if room.used_walls.has(wall_side):
				continue
			
			var new_room = calculate_new_room_position(room.start, room.width, room.length, wall_side)
			
			if is_valid_additional_room(new_room.start, new_room.width, new_room.length, building_data):
				place_room_walls_and_floor(new_room.start, new_room.width, new_room.length)
				
				var opposite_wall = get_opposite_wall(wall_side)
				var door_position = add_room_door(new_room.start, new_room.width, new_room.length, opposite_wall)
				
				# Calculate where this door is on the ORIGINAL room's wall
				var original_door_pos = calculate_door_on_wall(room.start, room.width, room.length, wall_side)
				
				# Mark wall as used and store door position for original room
				room.used_walls.append(wall_side)
				# Store the interior door position if this room doesn't have one yet
				if room.door_pos == Vector3i(-999, 0, -999):
					room.door_pos = original_door_pos
				
				building_data.rooms.append({
					"start": new_room.start,
					"width": new_room.width,
					"length": new_room.length,
					"used_walls": [opposite_wall],
					"door_pos": door_position
				})
				
				return true
	
	return false

func calculate_new_room_position(existing_start: Vector3i, existing_width: int, existing_length: int, wall_side: int) -> Dictionary:
	var new_width = randi_range(min_additional_room_width, max_additional_room_width)
	var new_length = randi_range(min_additional_room_length, max_additional_room_length)
	var new_start = Vector3i.ZERO
	
	match wall_side:
		0: new_start = Vector3i(existing_start.x + (existing_width - new_width) / 2, 0, existing_start.z - new_length + 1)
		1: new_start = Vector3i(existing_start.x + (existing_width - new_width) / 2, 0, existing_start.z + existing_length - 1)
		2: new_start = Vector3i(existing_start.x - new_width + 1, 0, existing_start.z + (existing_length - new_length) / 2)
		3: new_start = Vector3i(existing_start.x + existing_width - 1, 0, existing_start.z + (existing_length - new_length) / 2)
	
	return {"start": new_start, "width": new_width, "length": new_length}

func is_valid_additional_room(start: Vector3i, width: int, length: int, building_data: Dictionary) -> bool:
	# Check zones
	for x in range(width):
		for z in range(length):
			var test_pos = Vector3i(start.x + x, 0, start.z + z)
			
			for entrance_tile in entrance_zone_tiles:
				var dist = abs(test_pos.x - entrance_tile.x) + abs(test_pos.z - entrance_tile.z)
				if dist < building_zone_buffer:
					return false
			
			for exit_tile in exit_zone_tiles:
				var dist = abs(test_pos.x - exit_tile.x) + abs(test_pos.z - exit_tile.z)
				if dist < building_zone_buffer:
					return false
	
	# Check other buildings
	for other_building in placed_buildings:
		for other_room in other_building.rooms:
			var min_dist = 999999
			for x in range(width):
				for z in range(length):
					var test_pos = Vector3i(start.x + x, 0, start.z + z)
					
					for ox in range(other_room.width):
						for oz in range(other_room.length):
							var other_pos = Vector3i(other_room.start.x + ox, 0, other_room.start.z + oz)
							var dist = abs(test_pos.x - other_pos.x) + abs(test_pos.z - other_pos.z)
							min_dist = min(min_dist, dist)
							
							if min_dist < building_to_building_buffer:
								return false
	
	# Check buffers (allow overlap with own building)
	for x in range(-building_exterior_wall_buffer, width + building_exterior_wall_buffer):
		for z in range(-building_exterior_wall_buffer, length + building_exterior_wall_buffer):
			var check_pos = Vector3i(start.x + x, 0, start.z + z)
			var tile = map_generator.get_cell_item(check_pos)
			
			if x >= 0 and x < width and z >= 0 and z < length:
				# Allow grass, interior walls, and interior floors (for multi-room buildings)
				if tile != grass_tile_id and tile != interior_wall_tile_id and tile != interior_floor_tile_id:
					return false
			else:
				if tile == exterior_wall_tile_id:
					return false
				
				if road_tiles.has(check_pos):
					var dist = min(abs(x), abs(z), abs(x - width + 1), abs(z - length + 1))
					if dist < building_road_buffer:
						return false
	
	return true

func place_exterior_door(building_data: Dictionary):
	var available_walls = []
	
	for room in building_data.rooms:
		for wall_side in range(4):
			if not room.used_walls.has(wall_side):
				available_walls.append({"room": room, "wall_side": wall_side})
	
	if available_walls.size() == 0:
		print("    Warning: No available walls for exterior door!")
		return
	
	var chosen = available_walls[randi() % available_walls.size()]
	var door_position = add_room_door(chosen.room.start, chosen.room.width, chosen.room.length, chosen.wall_side)
	
	# Store door position in the room data
	chosen.room.door_pos = door_position
	
	print("    Placed exterior door on wall ", chosen.wall_side, " at ", door_position)

func add_room_door(start: Vector3i, width: int, length: int, wall_side: int) -> Vector3i:
	var door_pos = Vector3i.ZERO
	
	match wall_side:
		0: door_pos = Vector3i(start.x + width / 2, 0, start.z)
		1: door_pos = Vector3i(start.x + width / 2, 0, start.z + length - 1)
		2: door_pos = Vector3i(start.x, 0, start.z + length / 2)
		3: door_pos = Vector3i(start.x + width - 1, 0, start.z + length / 2)
	
	# Place door floor tile for doorway (so you can walk through)
	map_generator.set_cell_item(door_pos, door_floor_tile_id)
	
	# Place door furniture at this position with correct rotation
	if furniture_placer:
		furniture_placer.place_door_at_position(door_pos, wall_side)
	
	return door_pos

func calculate_door_on_wall(start: Vector3i, width: int, length: int, wall_side: int) -> Vector3i:
	"""Calculate where a door would be on a specific wall (same logic as add_room_door)"""
	var door_pos = Vector3i.ZERO
	
	match wall_side:
		0: door_pos = Vector3i(start.x + width / 2, 0, start.z)
		1: door_pos = Vector3i(start.x + width / 2, 0, start.z + length - 1)
		2: door_pos = Vector3i(start.x, 0, start.z + length / 2)
		3: door_pos = Vector3i(start.x + width - 1, 0, start.z + length / 2)
	
	return door_pos

func get_opposite_wall(wall_side: int) -> int:
	match wall_side:
		0: return 1
		1: return 0
		2: return 3
		3: return 2
	return 0
