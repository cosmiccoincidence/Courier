extends Node
class_name DualGridFloor

## Dual Grid Floor Tile System with Multi-Layer Support
## This system uses a second gridmap offset by (0.5, 0, 0.5) to create seamless
## floor transitions by analyzing 4 overlapping tiles from the primary gridmap.
## Supports placing multiple meshes per cell using stacked Y-levels.

# References to the two gridmaps
var primary_grid: GridMap
var floor_grid: GridMap

# Dictionary to store tile IDs for different floor types and shapes
# Structure: { "floor_type": { "whole": id, "half": id, "threequarter": id, "quarter": id } }
var floor_tile_sets: Dictionary = {}

# Map tile IDs from primary grid to floor type names
var tile_id_to_type: Dictionary = {}

# Y level to process in primary grid (usually 0 for floors)
var floor_y_level: int = 0

# Base Y level for floor grid (we'll stack additional meshes at +1, +2, +3)
var floor_grid_base_y: int = 0

# Container for additional mesh instances (layers beyond base Y)
var mesh_container: Node3D

# Debug mode for troubleshooting gaps and rotations
var debug_gaps: bool = false


func _init(p_primary_grid: GridMap, p_floor_grid: GridMap):
	primary_grid = p_primary_grid
	floor_grid = p_floor_grid


## Register a floor type with its mesh tile IDs
## floor_type: string identifier (e.g., "grass", "road", "water", "interior_floor")
## tile_ids: Dictionary with keys: "whole", "half", "threequarter", "quarter"
func register_floor_type(floor_type: String, tile_ids: Dictionary) -> void:
	floor_tile_sets[floor_type] = tile_ids


## Map a primary grid tile ID to a floor type name
func map_tile_to_type(tile_id: int, type_name: String) -> void:
	tile_id_to_type[tile_id] = type_name


## Enable debug output for troubleshooting gaps and rotations
func enable_debug_mode() -> void:
	debug_gaps = true
	print("[DualGridFloor] Debug mode ENABLED")


## Main processing function - call this after primary map generation is complete
func process_dual_grid_floors() -> void:
	print("[DualGridFloor] Starting dual-grid floor processing...")
	
	# Create mesh container NOW (after floor_grid has been positioned)
	if mesh_container == null:
		mesh_container = Node3D.new()
		mesh_container.name = "DualGridFloorMeshes"
		floor_grid.add_child(mesh_container)
		print("[DualGridFloor] Created mesh container as child of floor_grid")
		print("[DualGridFloor] floor_grid position: %s" % floor_grid.position)
		print("[DualGridFloor] mesh_container global position: %s" % mesh_container.global_position)
	
	# Get bounds of the primary gridmap
	var used_cells = primary_grid.get_used_cells()
	if used_cells.is_empty():
		print("[DualGridFloor] No cells found in primary grid")
		return
	
	var min_pos = used_cells[0]
	var max_pos = used_cells[0]
	
	for cell in used_cells:
		if cell.y != floor_y_level:
			continue
			
		min_pos.x = min(min_pos.x, cell.x)
		min_pos.z = min(min_pos.z, cell.z)
		max_pos.x = max(max_pos.x, cell.x)
		max_pos.z = max(max_pos.z, cell.z)
	
	print("[DualGridFloor] Processing area from ", min_pos, " to ", max_pos)
	
	# Process each potential dual-grid position
	var cells_processed = 0
	for x in range(min_pos.x, max_pos.x + 1):
		for z in range(min_pos.z, max_pos.z + 1):
			if _process_dual_grid_cell(x, z):
				cells_processed += 1
	
	print("[DualGridFloor] Processed ", cells_processed, " dual-grid floor cells")


## Process a single dual-grid cell position
## Returns true if any meshes were placed
func _process_dual_grid_cell(x: int, z: int) -> bool:
	# Get the 4 overlapping tiles from primary grid
	# In dual-grid, a cell at (x, z) overlaps primary cells:
	# (x, z), (x+1, z), (x, z+1), (x+1, z+1)
	var tiles = [
		_get_floor_type_at(x, z),       # Top-left (quadrant 0)
		_get_floor_type_at(x + 1, z),   # Top-right (quadrant 1)
		_get_floor_type_at(x, z + 1),   # Bottom-left (quadrant 2)
		_get_floor_type_at(x + 1, z + 1) # Bottom-right (quadrant 3)
	]
	
	# If all tiles are empty, skip this dual-grid cell
	if tiles[0] == "" and tiles[1] == "" and tiles[2] == "" and tiles[3] == "":
		return false
	
	# Group tiles by type and position
	var tile_groups = _analyze_tile_quadrants(tiles)
	
	# Place the appropriate meshes for each tile type found
	# We'll use multiple Y-levels if needed (up to 4 meshes = 4 Y-levels)
	var y_level = floor_grid_base_y
	
	for tile_type in tile_groups.keys():
		var quadrants = tile_groups[tile_type]
		_place_floor_meshes(x, z, y_level, tile_type, quadrants)
		y_level += 1  # Next mesh goes on next Y-level
	
	return true


## Get the floor type at a specific position in the primary grid
func _get_floor_type_at(x: int, z: int) -> String:
	var cell_item = primary_grid.get_cell_item(Vector3i(x, floor_y_level, z))
	
	if cell_item == GridMap.INVALID_CELL_ITEM:
		return ""
	
	# Look up the floor type from our mapping
	if tile_id_to_type.has(cell_item):
		return tile_id_to_type[cell_item]
	
	return ""


## Analyze which quadrants belong to each tile type
## Returns: { "tile_type": [array of quadrant indices 0-3] }
func _analyze_tile_quadrants(tiles: Array) -> Dictionary:
	var groups = {}
	
	for i in range(4):
		var tile_type = tiles[i]
		if tile_type != "":
			if not groups.has(tile_type):
				groups[tile_type] = []
			groups[tile_type].append(i)
	
	return groups


## Place the appropriate floor meshes based on quadrant configuration
## Now includes y_level parameter for multi-layer support
func _place_floor_meshes(grid_x: int, grid_z: int, y_level: int, tile_type: String, quadrants: Array) -> void:
	if not floor_tile_sets.has(tile_type):
		push_warning("[DualGridFloor] Floor type '%s' not registered!" % tile_type)
		return
	
	var tile_set = floor_tile_sets[tile_type]
	var quad_count = quadrants.size()
	
	if debug_gaps:
		print("[DualGridFloor] Placing %s at (%d,%d) Y=%d, quadrants=%s, count=%d" % [tile_type, grid_x, grid_z, y_level, quadrants, quad_count])
	
	match quad_count:
		4:
			# All 4 quadrants - use whole tile
			if debug_gaps:
				print("  → Using WHOLE tile")
			_place_tile(grid_x, grid_z, y_level, tile_set["whole"], 0)
		
		3:
			# 3 quadrants - use threequarter tile
			if debug_gaps:
				print("  → Using THREEQUARTER tile")
			_place_threequarter_tile(grid_x, grid_z, y_level, quadrants, tile_set)
		
		2:
			# 2 quadrants - check if adjacent or diagonal
			if _are_quadrants_adjacent(quadrants):
				if debug_gaps:
					print("  → Using HALF tile (adjacent)")
				_place_half_tile(grid_x, grid_z, y_level, quadrants, tile_set)
			else:
				if debug_gaps:
					print("  → Using 2 QUARTER tiles (diagonal)")
				# Diagonal - use 2 quarter tiles
				# For mesh instances, we need to place them at different positions
				for quad in quadrants:
					_place_quarter_tile_at_quadrant(grid_x, grid_z, y_level, quad, tile_set)
		
		1:
			# Single quadrant - use quarter tile at specific quadrant position
			if debug_gaps:
				print("  → Using QUARTER tile")
			_place_quarter_tile_at_quadrant(grid_x, grid_z, y_level, quadrants[0], tile_set)


## Check if two quadrants are adjacent
func _are_quadrants_adjacent(quadrants: Array) -> bool:
	if quadrants.size() != 2:
		return false
	
	var q1 = quadrants[0]
	var q2 = quadrants[1]
	
	# Quadrant layout:
	# 0 1
	# 2 3
	
	# Horizontal adjacency
	if (q1 == 0 and q2 == 1) or (q1 == 1 and q2 == 0):
		return true
	if (q1 == 2 and q2 == 3) or (q1 == 3 and q2 == 2):
		return true
	
	# Vertical adjacency
	if (q1 == 0 and q2 == 2) or (q1 == 2 and q2 == 0):
		return true
	if (q1 == 1 and q2 == 3) or (q1 == 3 and q2 == 1):
		return true
	
	return false


## Place a whole tile
func _place_tile(grid_x: int, grid_z: int, y_level: int, tile_id: int, rotation: int) -> void:
	if y_level == floor_grid_base_y:
		# First layer - use GridMap directly
		floor_grid.set_cell_item(Vector3i(grid_x, y_level, grid_z), tile_id, rotation)
		if debug_gaps:
			print("[DualGridFloor] GridMap tile at (%d, %d) Y=%d, tile_id=%d, rotation=%d" % [grid_x, grid_z, y_level, tile_id, rotation])
	else:
		# Additional layers - use MeshInstance3D with Y-offset
		_place_mesh_instance(grid_x, grid_z, y_level, tile_id, rotation)


## Place a half tile with appropriate rotation
func _place_half_tile(grid_x: int, grid_z: int, y_level: int, quadrants: Array, tile_set: Dictionary) -> void:
	var rotation = _get_half_tile_rotation(quadrants)
	if debug_gaps:
		print("[DualGridFloor] Half tile at (%d, %d) Y=%d, quadrants=%s, rotation=%d" % [grid_x, grid_z, y_level, quadrants, rotation])
	_place_tile(grid_x, grid_z, y_level, tile_set["half"], rotation)


## Get rotation for half tile based on which quadrants it covers
func _get_half_tile_rotation(quadrants: Array) -> int:
	var q1 = quadrants[0]
	var q2 = quadrants[1]
	
	# Quadrant layout:
	# 0 1
	# 2 3
	
	# Vertical half tiles - swapping left/right
	if (q1 == 0 and q2 == 2) or (q1 == 2 and q2 == 0):
		return 16   # Left vertical - 90°
	elif (q1 == 1 and q2 == 3) or (q1 == 3 and q2 == 1):
		return 22   # Right vertical - 270°
	
	# Horizontal half tiles
	elif (q1 == 0 and q2 == 1) or (q1 == 1 and q2 == 0):
		return 0  # Top horizontal
	elif (q1 == 2 and q2 == 3) or (q1 == 3 and q2 == 2):
		return 10  # Bottom horizontal
	
	return 0


## Place two diagonal quarter tiles
## For mesh instances, these go at their specific quadrant positions
func _place_diagonal_quarters(grid_x: int, grid_z: int, y_level: int, quadrants: Array, tile_set: Dictionary) -> void:
	for quad in quadrants:
		_place_quarter_tile_at_quadrant(grid_x, grid_z, y_level, quad, tile_set)


## Place a quarter tile with appropriate rotation (old method for GridMap)
func _place_quarter_tile(grid_x: int, grid_z: int, y_level: int, quadrant: int, tile_set: Dictionary) -> void:
	var rotation = _get_quarter_tile_rotation(quadrant)
	_place_tile(grid_x, grid_z, y_level, tile_set["quarter"], rotation)


## Place a quarter tile at a specific quadrant position (for mesh instances)
func _place_quarter_tile_at_quadrant(grid_x: int, grid_z: int, y_level: int, quadrant: int, tile_set: Dictionary) -> void:
	var rotation = _get_quarter_tile_rotation(quadrant)
	
	if y_level == floor_grid_base_y:
		# First layer - use GridMap with GridMap orientation values
		_place_tile(grid_x, grid_z, y_level, tile_set["quarter"], rotation)
	else:
		# Additional layers - use MeshInstance3D with direct quadrant-to-degrees conversion
		_place_mesh_instance_for_quadrant(grid_x, grid_z, y_level, tile_set["quarter"], quadrant)


## Get rotation for quarter tile based on which quadrant it covers
func _get_quarter_tile_rotation(quadrant: int) -> int:
	# Testing reverse rotation mapping
	# Godot GridMap orientations might map differently
	match quadrant:
		0: return 0   # Top-left - keep as is
		1: return 22  # Top-right - trying 270° instead of 90°
		2: return 16  # Bottom-left - trying 90° instead of 270°
		3: return 10  # Bottom-right - keep 180°
	return 0


## Place threequarter tile
func _place_threequarter_tile(grid_x: int, grid_z: int, y_level: int, quadrants: Array, tile_set: Dictionary) -> void:
	# Find which quadrant is NOT covered (the missing one)
	var all_quads = [0, 1, 2, 3]
	var missing_quad = -1
	
	for q in all_quads:
		if not quadrants.has(q):
			missing_quad = q
			break
	
	if missing_quad == -1:
		push_error("[DualGridFloor] Error: couldn't find missing quadrant for threequarter tile")
		return
	
	# Place threequarter tile (rotated to leave the missing quadrant empty)
	var rotation = _get_threequarter_tile_rotation(missing_quad)
	_place_tile(grid_x, grid_z, y_level, tile_set["threequarter"], rotation)


## Get rotation for threequarter tile based on which quadrant is MISSING
func _get_threequarter_tile_rotation(missing_quadrant: int) -> int:
	# Assuming threequarter tile is modeled with top-left quadrant missing by default
	match missing_quadrant:
		0: return 0   # Top-left missing
		1: return 22  # Top-right missing (270°)
		2: return 16  # Bottom-left missing (90°)
		3: return 10  # Bottom-right missing (180°)
	return 0


## Optional: Clear processed floor tiles from primary grid
## Call this after process_dual_grid_floors() if you want to remove the simple tiles
func clear_primary_grid_floors() -> void:
	print("[DualGridFloor] Clearing processed floor tiles from primary grid...")
	
	var used_cells = primary_grid.get_used_cells()
	var cleared_count = 0
	
	for cell in used_cells:
		var tile_id = primary_grid.get_cell_item(cell)
		
		# Clear ALL floor tiles including entry/exit zones (0, 1)
		# The dual-grid floor system has already replaced them with proper floor meshes
		if tile_id_to_type.has(tile_id):
			primary_grid.set_cell_item(cell, GridMap.INVALID_CELL_ITEM)
			cleared_count += 1
	
	print("[DualGridFloor] Cleared ", cleared_count, " floor tiles from primary grid")


## Place a MeshInstance for a specific quadrant (Y>0 layers)
func _place_mesh_instance_for_quadrant(grid_x: int, grid_z: int, y_level: int, tile_id: int, quadrant: int) -> void:
	if debug_gaps:
		print("[DualGridFloor] Creating MeshInstance at (%d, %d) Y-level=%d, tile_id=%d, quadrant=%d" % [grid_x, grid_z, y_level, tile_id, quadrant])
	
	# Get the mesh from the MeshLibrary
	var mesh_lib = floor_grid.mesh_library
	if not mesh_lib or tile_id < 0 or tile_id >= mesh_lib.get_item_list().size():
		push_warning("[DualGridFloor] Invalid tile_id %d for mesh instance" % tile_id)
		return
	
	var mesh = mesh_lib.get_item_mesh(tile_id)
	if not mesh:
		push_warning("[DualGridFloor] No mesh found for tile_id %d" % tile_id)
		return
	
	# Create MeshInstance3D
	var mesh_instance = MeshInstance3D.new()
	mesh_instance.mesh = mesh
	
	# Position the mesh
	# mesh_container is a child of floor_grid, so positions are in floor_grid's local space
	# GridMap cells are simply at their grid coordinates in this space
	var local_pos = Vector3(
		grid_x * floor_grid.cell_size.x,
		0.5,
		grid_z * floor_grid.cell_size.z
	)
	mesh_instance.position = local_pos
	
	if debug_gaps:
		print("[DualGridFloor]   MeshInstance local pos: %s (grid cell: %d, %d)" % [local_pos, grid_x, grid_z])
	
	# Apply rotation using GridMap's basis system
	# Instead of converting to degrees, get the actual basis GridMap would use
	# GridMap orientations: 0, 10, 16, 22
	var gridmap_orientation = 0
	match quadrant:
		0: gridmap_orientation = 0
		1: gridmap_orientation = 22
		2: gridmap_orientation = 16
		3: gridmap_orientation = 10
	
	# Get the basis from GridMap's mesh library
	var basis = floor_grid.mesh_library.get_item_mesh_transform(tile_id).basis
	var orientation_basis = Basis()
	
	# Apply GridMap's orientation to the basis
	# GridMap uses orthogonal basis indices
	match gridmap_orientation:
		0:  # No rotation
			orientation_basis = Basis()
		10: # 180° rotation
			orientation_basis = Basis(Vector3.DOWN, Vector3.BACK, Vector3.LEFT)
		16: # 90° rotation (one direction)
			orientation_basis = Basis(Vector3.BACK, Vector3.UP, Vector3.LEFT)
		22: # 270° rotation (other direction)
			orientation_basis = Basis(Vector3.FORWARD, Vector3.UP, Vector3.RIGHT)
	
	mesh_instance.basis = orientation_basis
	
	if debug_gaps:
		print("[DualGridFloor]   MeshInstance using GridMap orientation: %d (quadrant %d)" % [gridmap_orientation, quadrant])
	
	# Add to container
	mesh_container.add_child(mesh_instance)


## Place a mesh instance for additional layers (Y > 0)
## This allows us to offset the mesh down so it renders at the same height as Y=0 tiles
func _place_mesh_instance(grid_x: int, grid_z: int, y_level: int, tile_id: int, rotation: int) -> void:
	if debug_gaps:
		print("[DualGridFloor] Creating MeshInstance at (%d, %d) Y-level=%d, tile_id=%d" % [grid_x, grid_z, y_level, tile_id])
	
	# Get the mesh from the MeshLibrary
	var mesh_lib = floor_grid.mesh_library
	if not mesh_lib or tile_id < 0 or tile_id >= mesh_lib.get_item_list().size():
		push_warning("[DualGridFloor] Invalid tile_id %d for mesh instance" % tile_id)
		return
	
	var mesh = mesh_lib.get_item_mesh(tile_id)
	if not mesh:
		push_warning("[DualGridFloor] No mesh found for tile_id %d" % tile_id)
		return
	
	# Create MeshInstance3D
	var mesh_instance = MeshInstance3D.new()
	mesh_instance.mesh = mesh
	
	# Position the mesh
	# MeshInstances are parented to mesh_container which is a child of floor_grid
	# So positions are relative to floor_grid (which is already offset by 0.5, 0, 0.5)
	# We just need grid coordinates * cell_size
	var local_pos = Vector3(
		grid_x * floor_grid.cell_size.x,
		0.5,  # Match GridMap's internal Y offset
		grid_z * floor_grid.cell_size.z
	)
	mesh_instance.position = local_pos
	
	if debug_gaps:
		var global_pos = mesh_container.global_position + local_pos
		print("[DualGridFloor]   MeshInstance local pos: %s, global pos: %s" % [local_pos, global_pos])
	
	# Apply rotation
	# MeshInstances need different rotation than GridMap orientations
	var rotation_y = _get_meshinstance_rotation_degrees(rotation)
	mesh_instance.rotation_degrees.y = rotation_y
	
	if debug_gaps:
		print("[DualGridFloor]   MeshInstance rotation: %s degrees" % rotation_y)
	
	# Add to container
	mesh_container.add_child(mesh_instance)



## Convert GridMap orientation to rotation degrees for MeshInstances
func _get_meshinstance_rotation_degrees(gridmap_orientation: int) -> float:
	# MeshInstances rotate differently than GridMap
	# Based on testing, these are the correct degree values:
	match gridmap_orientation:
		0: return 0.0    # Quadrant 0
		22: return 270.0 # Quadrant 1 - was 90, needs to be 270
		16: return 90.0  # Quadrant 2 - was 270, needs to be 90
		10: return 180.0 # Quadrant 3
		_: return 0.0


## Convert GridMap orientation to rotation degrees
func _get_rotation_degrees_from_orientation(orientation: int) -> float:
	# GridMap orientations produce these visual rotations:
	# 0 → 0° visual rotation
	# 10 → 180° visual rotation  
	# 16 → 270° visual rotation (or -90°)
	# 22 → 90° visual rotation (or -270°)
	match orientation:
		0: return 0.0
		10: return 180.0
		16: return 270.0  
		22: return 90.0
		_: return 0.0


## Get the offset for a specific quadrant within a cell
## Quadrants: 0=TL, 1=TR, 2=BL, 3=BR
func _get_quadrant_offset(quadrant: int) -> Vector3:
	var half_cell_x = floor_grid.cell_size.x * 0.25
	var half_cell_z = floor_grid.cell_size.z * 0.25
	
	match quadrant:
		0: return Vector3(-half_cell_x, 0, -half_cell_z)  # Top-left
		1: return Vector3(half_cell_x, 0, -half_cell_z)   # Top-right
		2: return Vector3(-half_cell_x, 0, half_cell_z)   # Bottom-left
		3: return Vector3(half_cell_x, 0, half_cell_z)    # Bottom-right
	
	return Vector3.ZERO


## Place a mesh instance with a quadrant offset for quarter tiles
func _place_mesh_instance_with_offset(grid_x: int, grid_z: int, y_level: int, tile_id: int, rotation: int, offset: Vector3) -> void:
	if debug_gaps:
		print("[DualGridFloor] Creating MeshInstance WITH OFFSET at (%d, %d) Y-level=%d, tile_id=%d, offset=%s" % [grid_x, grid_z, y_level, tile_id, offset])
	
	# Get the mesh from the MeshLibrary
	var mesh_lib = floor_grid.mesh_library
	if not mesh_lib or tile_id < 0 or tile_id >= mesh_lib.get_item_list().size():
		push_warning("[DualGridFloor] Invalid tile_id %d for mesh instance" % tile_id)
		return
	
	var mesh = mesh_lib.get_item_mesh(tile_id)
	if not mesh:
		push_warning("[DualGridFloor] No mesh found for tile_id %d" % tile_id)
		return
	
	# Create MeshInstance3D
	var mesh_instance = MeshInstance3D.new()
	mesh_instance.mesh = mesh
	
	# Position with quadrant offset - GridMap internally offsets cells by +0.5 in Y
	mesh_instance.position = Vector3(
		grid_x * floor_grid.cell_size.x + offset.x,
		0.5,  # Match GridMap's internal Y offset
		grid_z * floor_grid.cell_size.z + offset.z
	)
	
	# Apply rotation
	var rotation_y = _get_rotation_degrees_from_orientation(rotation)
	mesh_instance.rotation_degrees.y = rotation_y
	
	# Add to container
	mesh_container.add_child(mesh_instance)
