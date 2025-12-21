class_name WallConnectorHelper
extends RefCounted

## Helper for applying advanced wall connections to GridMap tiles

## Apply advanced wall connections to interior walls in buildings
static func apply_interior_wall_connections(map_generator: GridMap, wall_connector: AdvancedWallConnector, interior_wall_tile_id: int, placed_buildings: Array):
	if not wall_connector:
		print("[WallConnector] No wall connector provided, skipping")
		return
	
	# Get all interior wall positions from placed buildings
	var wall_positions = []
	for building in placed_buildings:
		for room in building.rooms:
			# Get perimeter tiles (walls)
			for x in range(room.width):
				for z in range(room.length):
					var pos = Vector3i(room.start.x + x, 0, room.start.z + z)
					
					# Check if this is a perimeter tile (wall)
					if x == 0 or x == room.width - 1 or z == 0 or z == room.length - 1:
						var tile_id = map_generator.get_cell_item(pos)
						if tile_id == interior_wall_tile_id:
							wall_positions.append(pos)
	
	# IMPORTANT: Gather ALL adjacency data BEFORE replacing tiles
	# Otherwise tiles we replace will break adjacency checks for later tiles
	var wall_data = []
	
	for i in range(wall_positions.size()):
		var wall_pos = wall_positions[i]
		var adjacency_map = get_adjacency_map(map_generator, wall_pos, interior_wall_tile_id)
		var tile_data = wall_connector.get_tile_and_rotation(adjacency_map)
		
		wall_data.append({
			"pos": wall_pos,
			"tile_id": tile_data.tile_id,
			"rotation": tile_data.rotation,
			"shape": tile_data.shape,
			"adjacency": adjacency_map
		})
	
	# Now apply all the changes
	var walls_updated = 0
	
	for i in range(wall_data.size()):
		var data = wall_data[i]
		
		if data.tile_id != -1:
			# Get orientation from rotation
			var orientation = get_orientation_from_rotation(data.rotation)
			
			# Replace the tile with the appropriate variation
			map_generator.set_cell_item(data.pos, data.tile_id, orientation)
			walls_updated += 1
	
	print("[WallConnector] Updated ", walls_updated, " interior wall tiles")

## Get adjacency map for a tile position
static func get_adjacency_map(map_generator: GridMap, pos: Vector3i, target_tile_id: int) -> Dictionary:
	var adjacency = {}
	
	# Get door tile ID to treat doors as walls
	var door_floor_id = map_generator.get("door_floor_tile_id")
	
	# Cardinal directions - check for walls OR doors
	adjacency[AdjacencyShapeResolver.Direction.NORTH] = is_wall_or_door(map_generator, pos + Vector3i(0, 0, -1), target_tile_id, door_floor_id)
	adjacency[AdjacencyShapeResolver.Direction.SOUTH] = is_wall_or_door(map_generator, pos + Vector3i(0, 0, 1), target_tile_id, door_floor_id)
	adjacency[AdjacencyShapeResolver.Direction.EAST] = is_wall_or_door(map_generator, pos + Vector3i(1, 0, 0), target_tile_id, door_floor_id)
	adjacency[AdjacencyShapeResolver.Direction.WEST] = is_wall_or_door(map_generator, pos + Vector3i(-1, 0, 0), target_tile_id, door_floor_id)
	
	# Diagonal directions (for corners) - also check for doors
	adjacency[AdjacencyShapeResolver.Direction.NORTH_EAST] = is_wall_or_door(map_generator, pos + Vector3i(1, 0, -1), target_tile_id, door_floor_id)
	adjacency[AdjacencyShapeResolver.Direction.SOUTH_EAST] = is_wall_or_door(map_generator, pos + Vector3i(1, 0, 1), target_tile_id, door_floor_id)
	adjacency[AdjacencyShapeResolver.Direction.SOUTH_WEST] = is_wall_or_door(map_generator, pos + Vector3i(-1, 0, 1), target_tile_id, door_floor_id)
	adjacency[AdjacencyShapeResolver.Direction.NORTH_WEST] = is_wall_or_door(map_generator, pos + Vector3i(-1, 0, -1), target_tile_id, door_floor_id)
	
	return adjacency

## Check if a tile is a wall OR a door (for seamless connections)
static func is_wall_or_door(map_generator: GridMap, pos: Vector3i, target_tile_id: int, door_floor_id) -> bool:
	var tile_id = map_generator.get_cell_item(pos)
	
	# Check if it's a wall
	if tile_id == target_tile_id:
		return true
	
	# Check if it's a door
	if door_floor_id != null and tile_id == door_floor_id:
		return true
	
	return false

## Check if a tile at position matches the target tile ID OR any wall variation
static func is_same_tile(map_generator: GridMap, pos: Vector3i, target_tile_id: int) -> bool:
	var tile_id = map_generator.get_cell_item(pos)
	return tile_id == target_tile_id

## Check if a tile is any kind of wall (including variations)
static func is_wall_tile_any(map_generator: GridMap, pos: Vector3i, original_wall_id: int, wall_connector: AdvancedWallConnector) -> bool:
	var tile_id = map_generator.get_cell_item(pos)
	
	# Check if it's the original wall
	if tile_id == original_wall_id:
		return true
	
	# Check if it's any of the wall variations
	if wall_connector:
		if tile_id == wall_connector.o_tile_id: return true
		if tile_id == wall_connector.u_tile_id: return true
		if tile_id == wall_connector.i_tile_id: return true
		if tile_id == wall_connector.l_none_tile_id: return true
		if tile_id == wall_connector.l_single_tile_id: return true
		if tile_id == wall_connector.t_none_tile_id: return true
		if tile_id == wall_connector.t_single_right_tile_id: return true
		if tile_id == wall_connector.t_single_left_tile_id: return true
		if tile_id == wall_connector.t_double_tile_id: return true
		if tile_id == wall_connector.x_none_tile_id: return true
		if tile_id == wall_connector.x_single_tile_id: return true
		if tile_id == wall_connector.x_side_tile_id: return true
		if tile_id == wall_connector.x_opposite_tile_id: return true
		if tile_id == wall_connector.x_triple_tile_id: return true
		if tile_id == wall_connector.x_quad_tile_id: return true
	
	return false

## Convert rotation (degrees) to GridMap orientation
static func get_orientation_from_rotation(rotation_degrees: float) -> int:
	# Normalize rotation to 0-360
	var normalized = fmod(rotation_degrees, 360.0)
	if normalized < 0:
		normalized += 360.0
	
	# GridMap uses basis orientations (0-23)
	# For Y-axis rotation around vertical:
	# 0 = 0° rotation
	# 16 = 90° clockwise (when viewed from above)
	# 10 = 180° rotation
	# 22 = 270° clockwise
	
	if normalized < 45 or normalized >= 315:
		return 0  # 0°
	elif normalized >= 45 and normalized < 135:
		return 16  # 90°
	elif normalized >= 135 and normalized < 225:
		return 10  # 180°
	else:
		return 22  # 270°
