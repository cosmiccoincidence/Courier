extends Node
class_name MultiGridFloor

## Multi-Grid Floor Tile System with Multi-GridMap Support
## This system uses 4 gridmaps all offset by (0.5, 0, 0.5) to create seamless
## floor transitions by analyzing 4 overlapping tiles from the primary gridmap.
## When multiple floor types overlap, they're placed on separate GridMaps.

# References to the gridmaps
var primary_grid: GridMap
var floor_grids: Array = []  # Array of up to 4 GridMaps

# Dictionary to preserve floor types at each position (for FOV/pathfinding)
# Key: Vector3i position, Value: floor type name (e.g. "grass", "stone_road")
var floor_type_map: Dictionary = {}

# Dictionary to store tile IDs for different floor types and shapes
# Structure: { "floor_type": { "whole": id, "half": id, "threequarter": id, "quarter": id } }
var floor_tile_sets: Dictionary = {}

# Map tile IDs from primary grid to floor type names
var tile_id_to_type: Dictionary = {}

# Door tile IDs that act like walls but get cleared after processing
var door_tile_ids: Array = []

# Preserve door positions after clearing (for FOV/door detection)
var door_positions: Dictionary = {}  # Key: Vector3i position, Value: true

# Y level to process in primary grid (usually 0 for floors)
var floor_y_level: int = 0

# Base Y level for floor grids
var floor_grid_base_y: int = 0


func _init(p_primary_grid: GridMap, p_floor_grids: Array):
	primary_grid = p_primary_grid
	floor_grids = p_floor_grids
	
	if floor_grids.size() < 4:
		push_error("[MultiGridFloor] Need at least 4 floor GridMaps, got %d" % floor_grids.size())


## Register a floor type with its mesh tile IDs
func register_floor_type(floor_type: String, tile_ids: Dictionary) -> void:
	floor_tile_sets[floor_type] = tile_ids


## Map a primary grid tile ID to a floor type name
func map_tile_to_type(tile_id: int, type_name: String) -> void:
	tile_id_to_type[tile_id] = type_name


## Register door tile IDs (treated like walls but cleared after processing)
## NOTE: This is for door_floor_tile placeholder, NOT the actual door_tile mesh
func register_door_tiles(tile_ids: Array) -> void:
	door_tile_ids = tile_ids


## Clear all floor grids (for map regeneration)
func clear_all_floors() -> void:	
	for grid in floor_grids:
		if grid:
			grid.clear()
	
	# Clear preserved data
	floor_type_map.clear()
	door_positions.clear()
	


## Main processing function
func process_multi_grid_floors() -> void:	
	# Track which GridMap is used at each multi-grid cell
	# Key: "x,z", Value: grid_layer (0-3)
	var cell_usage: Dictionary = {}
	
	# Get bounds of the primary gridmap
	var used_cells = primary_grid.get_used_cells()
	if used_cells.is_empty():
		print("[MultiGridFloor] No cells found in primary grid")
		return
	
	var min_pos = used_cells[0]
	var max_pos = used_cells[0]
	
	for cell_pos in used_cells:
		if cell_pos.x < min_pos.x: min_pos.x = cell_pos.x
		if cell_pos.z < min_pos.z: min_pos.z = cell_pos.z
		if cell_pos.x > max_pos.x: max_pos.x = cell_pos.x
		if cell_pos.z > max_pos.z: max_pos.z = cell_pos.z
	
	print("[MultiGridFloor] Processing area from (%d, %d, %d) to (%d, %d, %d)" % 
		[min_pos.x, min_pos.y, min_pos.z, max_pos.x, max_pos.y, max_pos.z])
	
	# Track processed cells for clearing
	var cells_to_clear: Array = []
	
	# Process each multi-grid cell
	var processed_count = 0
	for z in range(min_pos.z - 1, max_pos.z + 1):
		for x in range(min_pos.x - 1, max_pos.x + 1):
			if _process_dual_grid_cell(x, z, cell_usage):
				processed_count += 1
	
	print("[MultiGridFloor] Processed %d multi-grid floor cells" % processed_count)
	
	# Clear the floor tiles from primary grid
	_clear_floor_tiles_from_primary()


## Process a single multi-grid cell at position (x, z)
func _process_dual_grid_cell(x: int, z: int, cell_usage: Dictionary) -> bool:
	# Get the 4 overlapping tiles from primary grid
	# For each quadrant, check if it's a wall and look at opposite neighbor if needed
	var tiles = [
		_get_floor_type_for_quadrant(x, floor_y_level, z, 0),      # Quadrant 0
		_get_floor_type_for_quadrant(x+1, floor_y_level, z, 1),    # Quadrant 1
		_get_floor_type_for_quadrant(x, floor_y_level, z+1, 2),    # Quadrant 2
		_get_floor_type_for_quadrant(x+1, floor_y_level, z+1, 3)   # Quadrant 3
	]
	
	# Store floor type for this dual-grid position (use most common type)
	var valid_types = []
	for tile_type in tiles:
		if tile_type != null:
			valid_types.append(tile_type)
	
	if not valid_types.is_empty():
		# Count occurrences
		var type_counts = {}
		for t in valid_types:
			type_counts[t] = type_counts.get(t, 0) + 1
		
		# Find most common
		var most_common = valid_types[0]
		var max_count = type_counts[most_common]
		for type_name in type_counts.keys():
			if type_counts[type_name] > max_count:
				most_common = type_name
				max_count = type_counts[type_name]
		
		# Store in map for FOV/pathfinding
		floor_type_map[Vector3i(x, floor_y_level, z)] = most_common
	
	# Filter out null tiles
	var valid_tiles = []
	var quadrants = []
	for i in range(4):
		if tiles[i] != null:
			valid_tiles.append(tiles[i])
			quadrants.append(i)
	
	if valid_tiles.is_empty():
		return false
	
	# Group by floor type
	var types_dict = {}
	for i in range(valid_tiles.size()):
		var type_name = valid_tiles[i]
		if not types_dict.has(type_name):
			types_dict[type_name] = []
		types_dict[type_name].append(quadrants[i])
	
	# Place each floor type on a separate GridMap layer
	var layer = 0
	for type_name in types_dict.keys():
		var quads = types_dict[type_name]
		var tile_set = floor_tile_sets.get(type_name)
		
		if tile_set == null:
			push_warning("[MultiGridFloor] No tile set registered for type: %s" % type_name)
			continue
		
		# Check if we have 2 non-adjacent quadrants - need to split into separate layers
		if quads.size() == 2 and not _are_quadrants_adjacent(quads[0], quads[1]):
			# Place each quarter on its own layer
			for quad in quads:
				if layer >= floor_grids.size():
					continue
				
				_place_floor_at_layer(x, z, layer, [quad], tile_set)
				layer += 1
		else:
			# Normal placement
			if layer >= floor_grids.size():
				continue
			
			_place_floor_at_layer(x, z, layer, quads, tile_set)
			layer += 1
	
	return true


## Get floor type for a specific quadrant of a primary grid cell
## If the cell contains a wall, look at neighbors to find floor type
func _get_floor_type_for_quadrant(x: int, y: int, z: int, quadrant: int):
	var tile_id = primary_grid.get_cell_item(Vector3i(x, y, z))
	if tile_id == GridMap.INVALID_CELL_ITEM:
		return null
	
	# Check if this is a registered floor tile
	var floor_type = tile_id_to_type.get(tile_id)
	
	if floor_type != null:
		# This is a floor tile, return its type
		return floor_type
	
	# This is a wall or door tile (not a floor)
	# Check neighbors to determine floor type
	
	# For each quadrant, check OPPOSITE directions (into the room)
	# Q0 (top-left): look RIGHT and DOWN (away from top-left edge)
	# Q1 (top-right): look LEFT and DOWN (away from top-right edge)
	# Q2 (bottom-left): look RIGHT and UP (away from bottom-left edge)
	# Q3 (bottom-right): look LEFT and UP (away from bottom-right edge)
	var check_positions = []
	var diagonal_pos: Vector3i
	
	match quadrant:
		0:
			check_positions = [Vector3i(x + 1, y, z), Vector3i(x, y, z + 1)]
			diagonal_pos = Vector3i(x + 1, y, z + 1)
		1:
			check_positions = [Vector3i(x - 1, y, z), Vector3i(x, y, z + 1)]
			diagonal_pos = Vector3i(x - 1, y, z + 1)
		2:
			check_positions = [Vector3i(x + 1, y, z), Vector3i(x, y, z - 1)]
			diagonal_pos = Vector3i(x + 1, y, z - 1)
		3:
			check_positions = [Vector3i(x - 1, y, z), Vector3i(x, y, z - 1)]
			diagonal_pos = Vector3i(x - 1, y, z - 1)
	
	# Check the two cardinal neighbors for this quadrant
	for check_pos in check_positions:
		var neighbor_id = primary_grid.get_cell_item(check_pos)
		if neighbor_id != GridMap.INVALID_CELL_ITEM:
			var neighbor_type = tile_id_to_type.get(neighbor_id)
			if neighbor_type != null:
				return neighbor_type
	
	# If both cardinals are walls, check diagonal
	var diagonal_id = primary_grid.get_cell_item(diagonal_pos)
	if diagonal_id != GridMap.INVALID_CELL_ITEM:
		var diagonal_type = tile_id_to_type.get(diagonal_id)
		if diagonal_type != null:
			return diagonal_type
	
	return null


## Place floor tile(s) at a specific GridMap layer
func _place_floor_at_layer(grid_x: int, grid_z: int, layer: int, quadrants: Array, tile_set: Dictionary) -> void:
	var count = quadrants.size()
	var target_grid = floor_grids[layer]
	
	if count == 4:
		_place_tile(target_grid, grid_x, grid_z, tile_set["whole"], 0)
	elif count == 3:
		_place_threequarter_tile(target_grid, grid_x, grid_z, quadrants, tile_set)
	elif count == 2:
		_place_half_tile(target_grid, grid_x, grid_z, quadrants, tile_set)
	elif count == 1:
		_place_quarter_tile(target_grid, grid_x, grid_z, quadrants[0], tile_set)


func _are_quadrants_adjacent(q1: int, q2: int) -> bool:
	if (q1 == 0 and q2 == 2) or (q1 == 2 and q2 == 0):
		return true
	if (q1 == 1 and q2 == 3) or (q1 == 3 and q2 == 1):
		return true
	if (q1 == 0 and q2 == 1) or (q1 == 1 and q2 == 0):
		return true
	if (q1 == 2 and q2 == 3) or (q1 == 3 and q2 == 2):
		return true
	return false


func _place_tile(grid: GridMap, x: int, z: int, tile_id: int, rotation: int) -> void:
	grid.set_cell_item(Vector3i(x, floor_grid_base_y, z), tile_id, rotation)


func _place_quarter_tile(grid: GridMap, grid_x: int, grid_z: int, quadrant: int, tile_set: Dictionary) -> void:
	var rotation = _get_quarter_tile_rotation(quadrant)
	_place_tile(grid, grid_x, grid_z, tile_set["quarter"], rotation)


func _get_quarter_tile_rotation(quadrant: int) -> int:
	match quadrant:
		0: return 0
		1: return 22
		2: return 16
		3: return 10
	return 0


func _place_half_tile(grid: GridMap, grid_x: int, grid_z: int, quadrants: Array, tile_set: Dictionary) -> void:
	var q1 = quadrants[0]
	var q2 = quadrants[1]
	var rotation = 0
	
	if (q1 == 0 and q2 == 2) or (q1 == 2 and q2 == 0):
		rotation = 16
	elif (q1 == 1 and q2 == 3) or (q1 == 3 and q2 == 1):
		rotation = 22
	elif (q1 == 0 and q2 == 1) or (q1 == 1 and q2 == 0):
		rotation = 0
	elif (q1 == 2 and q2 == 3) or (q1 == 3 and q2 == 2):
		rotation = 10
	
	_place_tile(grid, grid_x, grid_z, tile_set["half"], rotation)


func _place_threequarter_tile(grid: GridMap, grid_x: int, grid_z: int, quadrants: Array, tile_set: Dictionary) -> void:
	var all_quads = [0, 1, 2, 3]
	var missing_quad = -1
	
	for q in all_quads:
		if not quadrants.has(q):
			missing_quad = q
			break
	
	if missing_quad == -1:
		push_warning("[MultiGridFloor] Could not determine missing quadrant")
		return
	
	var rotation = _get_quarter_tile_rotation(missing_quad)
	_place_tile(grid, grid_x, grid_z, tile_set["threequarter"], rotation)


func _clear_floor_tiles_from_primary() -> void:
	print("[MultiGridFloor] Clearing processed floor tiles from primary grid...")
	
	var cleared_count = 0
	var used_cells = primary_grid.get_used_cells()
	
	for cell_pos in used_cells:
		if cell_pos.y != floor_y_level:
			continue
		
		var tile_id = primary_grid.get_cell_item(cell_pos)
		if tile_id == GridMap.INVALID_CELL_ITEM:
			continue
		
		# Check if it's a door tile
		var is_door = door_tile_ids.has(tile_id)
		
		if is_door:
			# Store door position before clearing
			door_positions[cell_pos] = true
			primary_grid.set_cell_item(cell_pos, GridMap.INVALID_CELL_ITEM)
			cleared_count += 1
		else:
			# Clear regular floor tiles
			var type_name = tile_id_to_type.get(tile_id)
			if type_name != null:
				primary_grid.set_cell_item(cell_pos, GridMap.INVALID_CELL_ITEM)
				cleared_count += 1
	
	print("[MultiGridFloor] Cleared %d floor/door tiles from primary grid" % cleared_count)

## Get the floor type at a given position (for FOV/pathfinding systems)
func get_floor_type_at(position: Vector3i) -> String:
	return floor_type_map.get(position, "")


## Check if a position is walkable (has any floor type)
func is_walkable_at(position: Vector3i) -> bool:
	return floor_type_map.has(position)


## Check if a position has a door tile
func has_door_at(position: Vector3i) -> bool:
	return door_positions.has(position)
