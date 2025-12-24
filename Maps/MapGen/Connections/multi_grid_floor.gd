extends Node
class_name MultiGridFloor

## Multi-Grid Floor Tile System with Multi-GridMap Support
## This system uses 4 gridmaps all offset by (0.5, 0, 0.5) to create seamless
## floor transitions by analyzing 4 overlapping tiles from the primary gridmap.
## When multiple floor types overlap, they're placed on separate GridMaps.

# References to the gridmaps
var primary_grid: GridMap
var floor_grids: Array = []  # Array of up to 4 GridMaps

# Dictionary to store tile IDs for different floor types and shapes
# Structure: { "floor_type": { "whole": id, "half": id, "threequarter": id, "quarter": id } }
var floor_tile_sets: Dictionary = {}

# Map tile IDs from primary grid to floor type names
var tile_id_to_type: Dictionary = {}

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


## Main processing function
func process_multi_grid_floors() -> void:
	print("[MultiGridFloor] Starting multi-grid floor processing with %d GridMaps..." % floor_grids.size())
	
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
## If the cell contains a wall, look at the opposite neighbor's corresponding quadrant
func _get_floor_type_for_quadrant(x: int, y: int, z: int, quadrant: int):
	var tile_id = primary_grid.get_cell_item(Vector3i(x, y, z))
	if tile_id == GridMap.INVALID_CELL_ITEM:
		return null
	
	# Check if this is a registered floor tile
	var floor_type = tile_id_to_type.get(tile_id)
	
	if floor_type != null:
		# This is a floor tile, return its type
		return floor_type
	
	# This is a wall - add debug
	print("[Wall] Cell (%d,%d) quadrant %d is a wall (ID %d)" % [x, z, quadrant, tile_id])
	
	# This is NOT a floor tile (wall, door, etc)
	# Check all 4 cardinal neighbors to find floor tiles
	var neighbor_positions = [
		Vector3i(x - 1, y, z),  # Left
		Vector3i(x + 1, y, z),  # Right
		Vector3i(x, y, z - 1),  # Up
		Vector3i(x, y, z + 1)   # Down
	]
	
	var found_types = []
	for check_pos in neighbor_positions:
		var neighbor_id = primary_grid.get_cell_item(check_pos)
		if neighbor_id != GridMap.INVALID_CELL_ITEM:
			var neighbor_type = tile_id_to_type.get(neighbor_id)
			if neighbor_type != null and not found_types.has(neighbor_type):
				found_types.append(neighbor_type)
	
	# If we found floor types, decide which to use based on quadrant
	if found_types.is_empty():
		return null
	
	# For each quadrant, check the OPPOSITE direction (inward to room, not outward)
	# Quadrant 0 (top-left): look RIGHT (+x) and DOWN (+z) instead of left/up
	# Quadrant 1 (top-right): look LEFT (-x) and DOWN (+z) instead of right/up
	# Quadrant 2 (bottom-left): look RIGHT (+x) and UP (-z) instead of left/down
	# Quadrant 3 (bottom-right): look LEFT (-x) and UP (-z) instead of right/down
	
	var preferred_positions = []
	match quadrant:
		0: preferred_positions = [Vector3i(x + 1, y, z), Vector3i(x, y, z + 1)]
		1: preferred_positions = [Vector3i(x - 1, y, z), Vector3i(x, y, z + 1)]
		2: preferred_positions = [Vector3i(x + 1, y, z), Vector3i(x, y, z - 1)]
		3: preferred_positions = [Vector3i(x - 1, y, z), Vector3i(x, y, z - 1)]
	
	# Check preferred neighbors first
	for pref_pos in preferred_positions:
		var neighbor_id = primary_grid.get_cell_item(pref_pos)
		if neighbor_id != GridMap.INVALID_CELL_ITEM:
			var neighbor_type = tile_id_to_type.get(neighbor_id)
			if neighbor_type != null:
				print("  → Using %s from preferred neighbor (%d,%d)" % [neighbor_type, pref_pos.x, pref_pos.z])
				return neighbor_type
	
	# Fallback: return first found type
	if not found_types.is_empty():
		print("  → Fallback to %s" % found_types[0])
		return found_types[0]
	
	return null


## Place floor tile(s) at a specific GridMap layer
func _place_floor_at_layer(grid_x: int, grid_z: int, layer: int, quadrants: Array, tile_set: Dictionary) -> void:
	var count = quadrants.size()
	var target_grid = floor_grids[layer]
	
	if count == 4:
		# Whole tile
		_place_tile(target_grid, grid_x, grid_z, tile_set["whole"], 0)
	elif count == 3:
		# Threequarter tile
		_place_threequarter_tile(target_grid, grid_x, grid_z, quadrants, tile_set)
	elif count == 2:
		# Half tile (caller ensures these are adjacent)
		_place_half_tile(target_grid, grid_x, grid_z, quadrants, tile_set)
	elif count == 1:
		# Quarter tile
		_place_quarter_tile(target_grid, grid_x, grid_z, quadrants[0], tile_set)


## Check if two quadrants are adjacent
func _are_quadrants_adjacent(q1: int, q2: int) -> bool:
	# Vertical adjacency (left or right half)
	if (q1 == 0 and q2 == 2) or (q1 == 2 and q2 == 0):
		return true
	if (q1 == 1 and q2 == 3) or (q1 == 3 and q2 == 1):
		return true
	# Horizontal adjacency (top or bottom half)
	if (q1 == 0 and q2 == 1) or (q1 == 1 and q2 == 0):
		return true
	if (q1 == 2 and q2 == 3) or (q1 == 3 and q2 == 2):
		return true
	return false


## Place a tile on a GridMap
func _place_tile(grid: GridMap, x: int, z: int, tile_id: int, rotation: int) -> void:
	grid.set_cell_item(Vector3i(x, floor_grid_base_y, z), tile_id, rotation)


## Place quarter tile
func _place_quarter_tile(grid: GridMap, grid_x: int, grid_z: int, quadrant: int, tile_set: Dictionary) -> void:
	var rotation = _get_quarter_tile_rotation(quadrant)
	_place_tile(grid, grid_x, grid_z, tile_set["quarter"], rotation)


## Get rotation for quarter tile based on quadrant
func _get_quarter_tile_rotation(quadrant: int) -> int:
	match quadrant:
		0: return 0
		1: return 22
		2: return 16
		3: return 10
	return 0


## Place half tile (only called for adjacent quadrants)
func _place_half_tile(grid: GridMap, grid_x: int, grid_z: int, quadrants: Array, tile_set: Dictionary) -> void:
	var q1 = quadrants[0]
	var q2 = quadrants[1]
	var rotation = 0
	
	# Determine rotation based on which quadrants are filled
	# Vertical adjacency (left or right half)
	if (q1 == 0 and q2 == 2) or (q1 == 2 and q2 == 0):
		rotation = 16  # Left half
	elif (q1 == 1 and q2 == 3) or (q1 == 3 and q2 == 1):
		rotation = 22  # Right half
	# Horizontal adjacency (top or bottom half)
	elif (q1 == 0 and q2 == 1) or (q1 == 1 and q2 == 0):
		rotation = 0   # Top half
	elif (q1 == 2 and q2 == 3) or (q1 == 3 and q2 == 2):
		rotation = 10  # Bottom half
	
	_place_tile(grid, grid_x, grid_z, tile_set["half"], rotation)


## Place threequarter tile
func _place_threequarter_tile(grid: GridMap, grid_x: int, grid_z: int, quadrants: Array, tile_set: Dictionary) -> void:
	# Find the missing quadrant
	var all_quads = [0, 1, 2, 3]
	var missing_quad = -1
	
	for q in all_quads:
		if not quadrants.has(q):
			missing_quad = q
			break
	
	if missing_quad == -1:
		push_warning("[MultiGridFloor] Could not determine missing quadrant for threequarter tile")
		return
	
	# Rotate threequarter mesh based on which quadrant is missing
	var rotation = _get_quarter_tile_rotation(missing_quad)
	_place_tile(grid, grid_x, grid_z, tile_set["threequarter"], rotation)


## Clear floor tiles from primary grid
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
		
		var type_name = tile_id_to_type.get(tile_id)
		if type_name != null:
			primary_grid.set_cell_item(cell_pos, GridMap.INVALID_CELL_ITEM)
			cleared_count += 1
	
	print("[MultiGridFloor] Cleared %d floor tiles from primary grid" % cleared_count)
