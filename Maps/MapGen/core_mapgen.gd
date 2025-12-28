# Base map generator - handles core map generation: chunks, tiles, smoothing, walls, zones
class_name CoreMapGen
extends GridMap

# ============================================================================
# CORE SETTINGS
# ============================================================================

# Chunk settings
@export var chunk_size: int = 10
@export var min_chunks_width: int = 8
@export var max_chunks_width: int = 12
@export var min_chunks_depth: int = 16
@export var max_chunks_depth: int = 20

# Calculated map size (in tiles)
var map_width: int = 0
var map_depth: int = 0
var chunks_wide: int = 0
var chunks_long: int = 0

# Chunk data
var active_chunks: Dictionary = {}

# Tile IDs from MeshLibrary
@export var entrance_tile_id: int = 0
@export var exit_tile_id: int = 1
@export var grass_tile_id: int = 6
@export var stone_road_tile_id: int = 2
@export var dirt_road_tile_id: int = 3
@export var interior_wall_tile_id: int = 8
@export var exterior_wall_tile_id: int = 9
@export var interior_floor_tile_id: int = 5
@export var door_tile_id: int = 27
@export var door_floor_tile_id: int = 4
@export var water_tile_id: int = 7

# Floor Grid Tile IDs - for dual-grid floor meshes
@export_group("Dual-Grid Floor Tiles")
@export_subgroup("Floor Types")

@export var grass_quarter: int = 0
@export var grass_half: int = 1
@export var grass_threequarter: int = 2
@export var grass_whole: int = 3

@export var interior_floor_quarter: int = 4
@export var interior_floor_half: int = 5
@export var interior_floor_threequarter: int = 6
@export var interior_floor_whole: int = 7

@export var water_quarter: int = 8
@export var water_half: int = 9
@export var water_threequarter: int = 10
@export var water_whole: int = 11

@export var stone_road_quarter: int = 12
@export var stone_road_half: int = 13
@export var stone_road_threequarter: int = 14
@export var stone_road_whole: int = 15

@export var dirt_road_quarter: int = 16
@export var dirt_road_half: int = 17
@export var dirt_road_threequarter: int = 18
@export var dirt_road_whole: int = 19

# Dual-Grid system
@export_subgroup("Dual-Grid Settings")
@export var enable_multi_grid_floors: bool = true
@export var floor_mesh_library: MeshLibrary  # Separate MeshLibrary for floor tiles

# Floor grids for dual-grid system (need 4 for multi-layer support)
@onready var floor_grid_1: GridMap = $"../FloorGridMap1"
@onready var floor_grid_2: GridMap = $"../FloorGridMap2"
@onready var floor_grid_3: GridMap = $"../FloorGridMap3"
@onready var floor_grid_4: GridMap = $"../FloorGridMap4"

var multi_grid_processor: MultiGridFloor

# Generation settings
@export var use_seed: bool = false
@export var map_seed: int = 0

# Organic edge settings
@export var protrusion_chance: float = 0.3
@export var indentation_chance: float = 0.3
@export var min_protrusion_depth: int = 1
@export var max_protrusion_depth: int = 3
@export var min_indentation_depth: int = 1
@export var max_indentation_depth: int = 3

# Organic smoothing settings
@export_group("Organic Wall Smoothing")
@export var enable_organic_smoothing: bool = true
@export var smoothing_iterations: int = 3
@export var corner_smoothing_chance: float = 0.9
@export var edge_variation_amount: float = 0.15

# Special zone settings
@export var zone_size: int = 2
@export var player_spawn_marker: NodePath = NodePath("../PlayerSpawn")

var exit_triggered: bool = false
var is_generating: bool = false

# Store positions for features
var entrance_zone_tiles: Array = []
var exit_zone_tiles: Array = []

# Cached entry/exit positions (stored before clearing tiles)
var cached_entrance_pos: Vector3 = Vector3.ZERO
var cached_exit_pos: Vector3 = Vector3.ZERO
var has_cached_positions: bool = false

signal generation_started
signal generation_complete
signal player_reached_exit

# Tile connections
@export var interior_wall_connector: AdvancedWallConnector

# ============================================================================
# MAIN GENERATION FLOW
# ============================================================================

func _ready():
	# Setup floor grids
	setup_floor_grids()

func setup_floor_grids():
	"""Initialize floor grids with proper offset and collision settings"""
	var floor_grids = [floor_grid_1, floor_grid_2, floor_grid_3, floor_grid_4]
	
	for i in range(floor_grids.size()):
		var grid = floor_grids[i]
		if grid:
			# Offset for dual-grid system
			grid.position = Vector3(0.5, 0, 0.5)
			
			# Assign floor MeshLibrary if provided
			if floor_mesh_library:
				grid.mesh_library = floor_mesh_library
			
			# Only enable collision on first grid
			if i > 0:
				grid.collision_layer = 0
				grid.collision_mask = 0
		else:
			push_warning("[CoreMapGen] Floor grid %d not found!" % (i + 1))

## Clear the map and floor grids
func clear_map():
	# Clear the primary grid
	clear()
	
	# Clear the floor grids if multi-grid is enabled
	if enable_multi_grid_floors and multi_grid_processor:
		multi_grid_processor.clear_all_floors()

func start_generation():
	generate_map()

func generate_map():
	is_generating = true
	generation_started.emit()
	
	var max_attempts = 10
	var attempt = 0
	var map_valid = false
	
	while not map_valid and attempt < max_attempts:
		attempt += 1
		if attempt > 1:
			print("Map generation attempt ", attempt, "...")
		
		_generate_map_internal()
		map_valid = validate_map()
		
		if not map_valid:
			print("Map validation failed - regenerating...")
			clear_map()
	
	if not map_valid:
		print("ERROR: Failed to generate valid map after ", max_attempts, " attempts!")
	else:
		print("Map generation complete!")
	
	is_generating = false
	
	await get_tree().process_frame
	generation_complete.emit()

func is_generation_in_progress() -> bool:
	return is_generating

func _generate_map_internal():
	print("=== Starting Map Generation ===")
	
	# Clear previous data
	entrance_zone_tiles.clear()
	exit_zone_tiles.clear()
	
	# Initialize random seed
	if use_seed:
		seed(map_seed)
	else:
		seed(Time.get_ticks_usec())
	
	# Randomize chunk dimensions
	chunks_wide = randi_range(min_chunks_width, max_chunks_width)
	chunks_long = randi_range(min_chunks_depth, max_chunks_depth)
	
	var buffer = max_protrusion_depth
	map_width = (chunks_wide + buffer * 2) * chunk_size
	map_depth = (chunks_long + buffer * 2) * chunk_size
	
	print("Base map size: ", chunks_wide, "x", chunks_long, " chunks")
	
	clear()
	active_chunks.clear()
	
	# PHASE 1: CHUNK-LEVEL GENERATION
	print("\n--- PHASE 1: Chunk Generation ---")
	generate_chunk_layout()
	
	# PHASE 2: TILE GENERATION
	print("\n--- PHASE 2: Tile Generation ---")
	generate_tiles_from_chunks()
	
	# PHASE 3: ORGANIC SMOOTHING
	if enable_organic_smoothing:
		print("\n--- PHASE 3: Organic Smoothing ---")
		apply_organic_smoothing()
	
	# PHASE 4: WALL PLACEMENT
	print("\n--- PHASE 4: Wall Placement ---")
	rebuild_perimeter_walls()
	fix_diagonal_wall_gaps()
	
	# PHASE 5: SPECIAL ZONES
	print("\n--- PHASE 5: Special Zones ---")
	place_entrance_zone()
	place_exit_zone()
	
	# PHASE 6-8: ACT GENERATION (handled by subclasses - roads, features, enemies)
	generate_act()
	
	# PHASE 9: MULTI-GRID FLOOR PROCESSING
	if enable_multi_grid_floors:
		print("\n--- PHASE 9: Multi-Grid Floor Processing ---")
		process_multi_grid_floors()
	
	print("\n=== Map Generation Complete ===")

# Override this in act subclasses to add act-specific elements (roads, features, enemies)
func generate_act():
	pass

func validate_map() -> bool:
	# After multi-grid processing, tiles are cleared, so check cached positions
	if has_cached_positions:
		var has_entrance = cached_entrance_pos != Vector3.ZERO
		var has_exit = cached_exit_pos != Vector3.ZERO
		
		if not has_entrance:
			print("Validation failed: No entrance zone found (cached)")
		if not has_exit:
			print("Validation failed: No exit zone found (cached)")
		
		return has_entrance and has_exit
	
	# Before multi-grid processing, check tiles directly
	var has_entrance = false
	var has_exit = false
	var used_cells = get_used_cells()
	
	for cell in used_cells:
		var tile_id = get_cell_item(cell)
		if tile_id == entrance_tile_id:
			has_entrance = true
		if tile_id == exit_tile_id:
			has_exit = true
		if has_entrance and has_exit:
			break
	
	if not has_entrance:
		print("Validation failed: No entrance zone found")
	if not has_exit:
		print("Validation failed: No exit zone found")
	
	return has_entrance and has_exit

# ============================================================================
# PHASE 1: CHUNK-LEVEL GENERATION
# ============================================================================

func generate_chunk_layout():
	for cx in range(chunks_wide):
		for cz in range(chunks_long):
			active_chunks[Vector2i(cx, cz)] = true
	
	add_protrusions()
	add_indentations()
	fix_diagonal_connections()
	connect_isolated_chunks()

func add_protrusions():
	print("Adding protrusions...")
	var protrusions_added = 0
	
	for cx in range(chunks_wide):
		for cz in range(chunks_long):
			if cx == 0 or cx == chunks_wide - 1 or cz == 0 or cz == chunks_long - 1:
				if randf() < protrusion_chance:
					var depth = randi_range(min_protrusion_depth, max_protrusion_depth)
					create_protrusion(cx, cz, depth)
					protrusions_added += 1
	
	print("Added ", protrusions_added, " protrusions")

func create_protrusion(start_cx: int, start_cz: int, depth: int):
	var direction = Vector2i.ZERO
	
	if start_cx == 0:
		direction = Vector2i(-1, 0)
	elif start_cx == chunks_wide - 1:
		direction = Vector2i(1, 0)
	elif start_cz == 0:
		direction = Vector2i(0, -1)
	elif start_cz == chunks_long - 1:
		direction = Vector2i(0, 1)
	
	var current = Vector2i(start_cx, start_cz)
	var perpendicular = Vector2i(-direction.y, direction.x)
	
	for i in range(depth):
		var move_forward = randf() < 0.7
		
		if move_forward:
			current += direction
		else:
			current += perpendicular * (1 if randf() < 0.5 else -1)
			direction = perpendicular if randf() < 0.5 else -perpendicular
			perpendicular = Vector2i(-direction.y, direction.x)
		
		active_chunks[current] = true

func add_indentations():
	print("Adding indentations...")
	var indentations_added = 0
	
	for cx in range(1, chunks_wide - 1):
		for cz in range(1, chunks_long - 1):
			var dist_to_edge = min(cx, chunks_wide - 1 - cx, cz, chunks_long - 1 - cz)
			if dist_to_edge <= 2:
				if randf() < indentation_chance:
					var depth = randi_range(min_indentation_depth, max_indentation_depth)
					create_indentation(cx, cz, depth)
					indentations_added += 1
	
	print("Added ", indentations_added, " indentations")

func create_indentation(start_cx: int, start_cz: int, depth: int):
	active_chunks.erase(Vector2i(start_cx, start_cz))
	
	var to_left = start_cx
	var to_right = chunks_wide - 1 - start_cx
	var to_top = start_cz
	var to_bottom = chunks_long - 1 - start_cz
	
	var min_dist = min(to_left, to_right, to_top, to_bottom)
	var direction = Vector2i.ZERO
	
	if min_dist == to_left:
		direction = Vector2i(-1, 0)
	elif min_dist == to_right:
		direction = Vector2i(1, 0)
	elif min_dist == to_top:
		direction = Vector2i(0, -1)
	else:
		direction = Vector2i(0, 1)
	
	var current = Vector2i(start_cx, start_cz)
	var perpendicular = Vector2i(-direction.y, direction.x)
	
	for i in range(depth):
		var move_forward = randf() < 0.7
		
		if move_forward:
			current += direction
		else:
			current += perpendicular * (1 if randf() < 0.5 else -1)
			direction = perpendicular if randf() < 0.5 else -perpendicular
			perpendicular = Vector2i(-direction.y, direction.x)
		
		active_chunks.erase(current)

func fix_diagonal_connections():
	print("Fixing diagonal connections...")
	var chunks_fixed = 0
	var chunks_to_check = active_chunks.keys().duplicate()
	
	for chunk_pos in chunks_to_check:
		var cx = chunk_pos.x
		var cy = chunk_pos.y
		
		var diagonals = [
			{"diag": Vector2i(cx + 1, cy + 1), "bridge1": Vector2i(cx + 1, cy), "bridge2": Vector2i(cx, cy + 1)},
			{"diag": Vector2i(cx - 1, cy + 1), "bridge1": Vector2i(cx - 1, cy), "bridge2": Vector2i(cx, cy + 1)},
			{"diag": Vector2i(cx + 1, cy - 1), "bridge1": Vector2i(cx + 1, cy), "bridge2": Vector2i(cx, cy - 1)},
			{"diag": Vector2i(cx - 1, cy - 1), "bridge1": Vector2i(cx - 1, cy), "bridge2": Vector2i(cx, cy - 1)}
		]
		
		for diag in diagonals:
			if active_chunks.has(diag.diag):
				if not active_chunks.has(diag.bridge1) and not active_chunks.has(diag.bridge2):
					var bridge_to_add = diag.bridge1 if randf() < 0.5 else diag.bridge2
					active_chunks[bridge_to_add] = true
					chunks_fixed += 1
	
	print("Fixed ", chunks_fixed, " diagonal connections")

func connect_isolated_chunks():
	print("Connecting isolated islands...")
	
	var visited = {}
	var regions = []
	
	for chunk_pos in active_chunks.keys():
		if not visited.has(chunk_pos):
			var region = flood_fill_region(chunk_pos, visited)
			regions.append(region)
	
	print("Found ", regions.size(), " separate regions")
	
	if regions.size() <= 1:
		return
	
	var main_region = regions[0]
	for region in regions:
		if region.size() > main_region.size():
			main_region = region
	
	print("Main region has ", main_region.size(), " chunks")
	
	var bridges_added = 0
	for region in regions:
		if region == main_region:
			continue
		
		var min_distance = 999999
		var best_from = Vector2i.ZERO
		var best_to = Vector2i.ZERO
		
		for island_chunk in region:
			for main_chunk in main_region:
				var dist = abs(island_chunk.x - main_chunk.x) + abs(island_chunk.y - main_chunk.y)
				if dist < min_distance:
					min_distance = dist
					best_from = island_chunk
					best_to = main_chunk
		
		bridge_chunks(best_from, best_to)
		bridges_added += 1
	
	print("Added ", bridges_added, " bridges")

func flood_fill_region(start_pos: Vector2i, visited: Dictionary) -> Array:
	var region = []
	var to_visit = [start_pos]
	
	while to_visit.size() > 0:
		var current = to_visit.pop_back()
		
		if visited.has(current) or not active_chunks.has(current):
			continue
		
		visited[current] = true
		region.append(current)
		
		var neighbors = [
			Vector2i(current.x + 1, current.y),
			Vector2i(current.x - 1, current.y),
			Vector2i(current.x, current.y + 1),
			Vector2i(current.x, current.y - 1)
		]
		
		for neighbor in neighbors:
			if not visited.has(neighbor) and active_chunks.has(neighbor):
				to_visit.append(neighbor)
	
	return region

func bridge_chunks(from_pos: Vector2i, to_pos: Vector2i):
	var current = from_pos
	
	while current != to_pos:
		if current.x != to_pos.x:
			current.x += 1 if current.x < to_pos.x else -1
		elif current.y != to_pos.y:
			current.y += 1 if current.y < to_pos.y else -1
		
		active_chunks[current] = true

# ============================================================================
# PHASE 2: TILE GENERATION
# ============================================================================

func generate_tiles_from_chunks():
	print("Generating tiles from chunks...")
	
	for chunk_pos in active_chunks.keys():
		generate_chunk_tiles(chunk_pos.x, chunk_pos.y)

func generate_chunk_tiles(chunk_x: int, chunk_y: int):
	var start_x = chunk_x * chunk_size
	var start_z = chunk_y * chunk_size
	
	for x in range(chunk_size):
		for z in range(chunk_size):
			var tile_x = start_x + x
			var tile_z = -(start_z + z)
			set_cell_item(Vector3i(tile_x, 0, tile_z), grass_tile_id)

# ============================================================================
# PHASE 3: ORGANIC SMOOTHING
# ============================================================================

func apply_organic_smoothing():
	print("Applying organic smoothing (", smoothing_iterations, " iterations)...")
	
	for iteration in range(smoothing_iterations):
		print("  Smoothing pass ", iteration + 1, "/", smoothing_iterations)
		smooth_floor_edges()
	
	print("Organic smoothing complete")

func smooth_floor_edges():
	var used_cells = get_used_cells()
	var floor_tiles = []
	
	for cell in used_cells:
		if get_cell_item(cell) == grass_tile_id:
			floor_tiles.append(cell)
	
	var tiles_to_add = []
	
	for tile_pos in floor_tiles:
		var x = tile_pos.x
		var z = tile_pos.z
		
		var corners = [
			{"diag": Vector3i(x + 1, 0, z + 1), "adj1": Vector3i(x + 1, 0, z), "adj2": Vector3i(x, 0, z + 1)},
			{"diag": Vector3i(x - 1, 0, z + 1), "adj1": Vector3i(x - 1, 0, z), "adj2": Vector3i(x, 0, z + 1)},
			{"diag": Vector3i(x + 1, 0, z - 1), "adj1": Vector3i(x + 1, 0, z), "adj2": Vector3i(x, 0, z - 1)},
			{"diag": Vector3i(x - 1, 0, z - 1), "adj1": Vector3i(x - 1, 0, z), "adj2": Vector3i(x, 0, z - 1)}
		]
		
		for corner in corners:
			var diag_tile = get_cell_item(corner.diag)
			var adj1_tile = get_cell_item(corner.adj1)
			var adj2_tile = get_cell_item(corner.adj2)
			
			if adj1_tile == grass_tile_id and adj2_tile == grass_tile_id:
				if diag_tile != grass_tile_id:
					if randf() < corner_smoothing_chance:
						if not tiles_to_add.has(corner.diag):
							tiles_to_add.append(corner.diag)
	
	for tile_pos in tiles_to_add:
		set_cell_item(tile_pos, grass_tile_id)
	
	print("    Added ", tiles_to_add.size(), " tiles")

# ============================================================================
# PHASE 4: WALL PLACEMENT
# ============================================================================

func rebuild_perimeter_walls():
	print("Building perimeter walls...")
	
	var used_cells = get_used_cells()
	var floor_set = {}
	
	for cell in used_cells:
		if get_cell_item(cell) == grass_tile_id:
			floor_set[cell] = true
	
	var walls_added = 0
	for floor_pos in floor_set.keys():
		var x = floor_pos.x
		var z = floor_pos.z
		
		var neighbors = [
			Vector3i(x + 1, 0, z),
			Vector3i(x - 1, 0, z),
			Vector3i(x, 0, z + 1),
			Vector3i(x, 0, z - 1)
		]
		
		for neighbor in neighbors:
			var neighbor_tile = get_cell_item(neighbor)
			if neighbor_tile == -1 and not floor_set.has(neighbor):
				set_cell_item(neighbor, exterior_wall_tile_id)
				walls_added += 1
	
	print("Added ", walls_added, " wall tiles")

func fix_diagonal_wall_gaps():
	"""Fix walls that only touch diagonally by adding a connecting wall"""
	print("Fixing diagonal wall gaps...")
	
	var used_cells = get_used_cells()
	var wall_positions = []
	
	# Find all exterior wall positions
	for cell in used_cells:
		if get_cell_item(cell) == exterior_wall_tile_id:
			wall_positions.append(cell)
	
	var walls_added = 0
	var checked_pairs = {}  # Track pairs we've already processed
	
	# Check each wall for diagonal-only connections
	for wall_pos in wall_positions:
		var x = wall_pos.x
		var z = wall_pos.z
		
		# Check all 4 diagonal neighbors for walls
		var diagonals = [
			{"diag": Vector3i(x + 1, 0, z + 1), "bridge1": Vector3i(x + 1, 0, z), "bridge2": Vector3i(x, 0, z + 1)},
			{"diag": Vector3i(x - 1, 0, z + 1), "bridge1": Vector3i(x - 1, 0, z), "bridge2": Vector3i(x, 0, z + 1)},
			{"diag": Vector3i(x + 1, 0, z - 1), "bridge1": Vector3i(x + 1, 0, z), "bridge2": Vector3i(x, 0, z - 1)},
			{"diag": Vector3i(x - 1, 0, z - 1), "bridge1": Vector3i(x - 1, 0, z), "bridge2": Vector3i(x, 0, z - 1)}
		]
		
		for diag in diagonals:
			# If diagonal position has a wall
			if get_cell_item(diag.diag) == exterior_wall_tile_id:
				# Create unique key for this pair (sort to avoid duplicates)
				var pair_key = str(wall_pos) + "-" + str(diag.diag)
				var reverse_key = str(diag.diag) + "-" + str(wall_pos)
				
				# Skip if we've already processed this pair
				if checked_pairs.has(pair_key) or checked_pairs.has(reverse_key):
					continue
				
				checked_pairs[pair_key] = true
				
				# Check both cardinal bridge positions
				var bridge1_tile = get_cell_item(diag.bridge1)
				var bridge2_tile = get_cell_item(diag.bridge2)
				
				# If BOTH cardinal bridges are NOT walls, they're only touching diagonally
				if bridge1_tile != exterior_wall_tile_id and bridge2_tile != exterior_wall_tile_id:
					# Randomly choose which bridge position to fill
					var bridge_to_fill = diag.bridge1 if randf() < 0.5 else diag.bridge2
					
					# Fill it with a wall
					set_cell_item(bridge_to_fill, exterior_wall_tile_id)
					walls_added += 1
	
	print("Added ", walls_added, " bridge walls to fix diagonal gaps")

# ============================================================================
# PHASE 5: SPECIAL ZONES
# ============================================================================

func place_entrance_zone():
	print("Placing entrance zone...")
	
	var min_z = 999999
	var max_z = -999999
	var used_cells = get_used_cells()
	
	for cell in used_cells:
		if get_cell_item(cell) == grass_tile_id:
			min_z = min(min_z, cell.z)
			max_z = max(max_z, cell.z)
	
	var z_range = max_z - min_z
	var south_threshold = max_z - int(z_range * 0.1)
	
	var candidate_floors = []
	
	for cell in used_cells:
		if get_cell_item(cell) == grass_tile_id and cell.z >= south_threshold:
			var south_pos = Vector3i(cell.x, 0, cell.z + 1)
			if get_cell_item(south_pos) == exterior_wall_tile_id:
				candidate_floors.append(cell)
	
	if candidate_floors.size() == 0:
		print("Warning: No suitable entrance location found")
		return
	
	var entrance_floor = candidate_floors[randi() % candidate_floors.size()]
	
	var placed = 0
	for x in range(zone_size):
		for z in range(zone_size):
			var tile_pos = Vector3i(entrance_floor.x + x - zone_size / 2, 0, entrance_floor.z - z)
			if get_cell_item(tile_pos) == grass_tile_id:
				set_cell_item(tile_pos, entrance_tile_id)
				entrance_zone_tiles.append(tile_pos)
				placed += 1
	
	print("Entrance zone placed - ", placed, " tiles")

func place_exit_zone():
	print("Placing exit zone...")
	
	var all_chunk_positions = active_chunks.keys()
	var min_y = 999999
	var max_y = -999999
	
	for chunk_pos in all_chunk_positions:
		min_y = min(min_y, chunk_pos.y)
		max_y = max(max_y, chunk_pos.y)
	
	var map_height = max_y - min_y
	var north_threshold = max_y - int(map_height * 0.1)
	
	var valid_chunks = []
	for chunk_pos in all_chunk_positions:
		if chunk_pos.y >= north_threshold:
			var north_neighbor = Vector2i(chunk_pos.x, chunk_pos.y + 1)
			if not active_chunks.has(north_neighbor):
				valid_chunks.append(chunk_pos)
	
	if valid_chunks.size() == 0:
		print("Warning: No valid chunks found for exit")
		return
	
	var exit_chunk = valid_chunks[randi() % valid_chunks.size()]
	
	var chunk_x = exit_chunk.x * chunk_size
	var chunk_y = exit_chunk.y * chunk_size
	
	var northernmost_floors = []
	
	for x in range(chunk_size):
		for z_offset in range(chunk_size):
			var tile_z = -(chunk_y + z_offset)
			var pos = Vector3i(chunk_x + x, 0, tile_z)
			
			if get_cell_item(pos) == grass_tile_id:
				var north_pos = Vector3i(pos.x, 0, pos.z - 1)
				if get_cell_item(north_pos) == exterior_wall_tile_id:
					northernmost_floors.append(pos)
	
	if northernmost_floors.size() == 0:
		print("Warning: No floor tiles found at north edge")
		return
	
	var center_floor = northernmost_floors[northernmost_floors.size() / 2]
	
	var placed = 0
	for x in range(zone_size):
		for z in range(zone_size):
			var tile_pos = Vector3i(center_floor.x + x - zone_size / 2, 0, center_floor.z + z)
			if get_cell_item(tile_pos) == grass_tile_id:
				set_cell_item(tile_pos, exit_tile_id)
				exit_zone_tiles.append(tile_pos)
				placed += 1
	
	print("Exit zone placed at ", center_floor, " - ", placed, " tiles")

# ============================================================================
# PHASE 7: MULTI-GRID FLOOR PROCESSING
# ============================================================================

func _cache_entry_exit_positions():
	"""Store entry/exit positions before they get cleared by multi-grid processing"""
	var used_cells = get_used_cells()
	
	for cell in used_cells:
		var tile_id = get_cell_item(cell)
		if tile_id == entrance_tile_id:
			cached_entrance_pos = map_to_local(cell)
			cached_entrance_pos.y = 0.5
		elif tile_id == exit_tile_id:
			cached_exit_pos = map_to_local(cell)
			cached_exit_pos.y = 0.5
	
	has_cached_positions = true
	print("[CoreMapGen] Cached entrance position: ", cached_entrance_pos)
	print("[CoreMapGen] Cached exit position: ", cached_exit_pos)

func process_multi_grid_floors():
	"""Set up and process the multi-grid floor system"""
	
	# IMPORTANT: Cache entry/exit positions BEFORE clearing tiles
	_cache_entry_exit_positions()
	
	# Create the processor with all 4 floor grids
	var floor_grids = [floor_grid_1, floor_grid_2, floor_grid_3, floor_grid_4]
	multi_grid_processor = MultiGridFloor.new(self, floor_grids)
	
	# Map primary grid tile IDs to floor type names
	multi_grid_processor.map_tile_to_type(entrance_tile_id, "stone_road")
	multi_grid_processor.map_tile_to_type(exit_tile_id, "stone_road")
	multi_grid_processor.map_tile_to_type(stone_road_tile_id, "stone_road")
	multi_grid_processor.map_tile_to_type(dirt_road_tile_id, "dirt_road")
	multi_grid_processor.map_tile_to_type(interior_floor_tile_id, "interior_floor")
	multi_grid_processor.map_tile_to_type(grass_tile_id, "grass")
	multi_grid_processor.map_tile_to_type(water_tile_id, "water")
	
	# Register floor types with their tile IDs from the floor grid MeshLibrary
	multi_grid_processor.register_floor_type("interior_floor", {
		"whole": interior_floor_whole,
		"half": interior_floor_half,
		"threequarter": interior_floor_threequarter,
		"quarter": interior_floor_quarter
	})
	
	multi_grid_processor.register_floor_type("grass", {
		"whole": grass_whole,
		"half": grass_half,
		"threequarter": grass_threequarter,
		"quarter": grass_quarter
	})
	
	multi_grid_processor.register_floor_type("stone_road", {
		"whole": stone_road_whole,
		"half": stone_road_half,
		"threequarter": stone_road_threequarter,
		"quarter": stone_road_quarter
	})
	
	multi_grid_processor.register_floor_type("dirt_road", {
		"whole": dirt_road_whole,
		"half": dirt_road_half,
		"threequarter": dirt_road_threequarter,
		"quarter": dirt_road_quarter
	})
	
	multi_grid_processor.register_floor_type("water", {
		"whole": water_whole,
		"half": water_half,
		"threequarter": water_threequarter,
		"quarter": water_quarter
	})
	
	# Register door tiles (treated like walls but cleared after processing)
	multi_grid_processor.register_door_tiles([door_floor_tile_id])
	
	# Process the multi-grid floors (this also clears primary grid automatically)
	multi_grid_processor.process_multi_grid_floors()

# ============================================================================
# EXIT DETECTION
# ============================================================================

func setup_exit_detection():
	"""Set up exit detection area - uses cached position after multi-grid processing"""
	if not has_cached_positions:
		push_warning("[CoreMapGen] Cannot setup exit detection - positions not cached")
		return
	
	var exit_area = Area3D.new()
	exit_area.name = "ExitDetector"
	
	var collision_shape = CollisionShape3D.new()
	var box_shape = BoxShape3D.new()
	box_shape.size = Vector3(2, 2, 2)  # Larger area to cover the zone
	collision_shape.shape = box_shape
	
	exit_area.add_child(collision_shape)
	add_child(exit_area)
	
	exit_area.global_position = cached_exit_pos
	exit_area.body_entered.connect(_on_exit_area_entered)
	
	print("[CoreMapGen] Created exit detector at cached position: ", cached_exit_pos)

func _on_exit_area_entered(body: Node3D):
	if exit_triggered:
		return
	
	if body.is_in_group("player"):
		print("Player reached exit!")
		exit_triggered = true
		player_reached_exit.emit()

# ============================================================================
# UTILITY FUNCTIONS
# ============================================================================

func get_entrance_zone_spawn_position() -> Vector3:
	"""Get spawn position at entrance - uses cached position after multi-grid processing"""
	if has_cached_positions:
		return cached_entrance_pos
	
	# Fallback: try to find entrance tiles (before multi-grid processing)
	if entrance_zone_tiles.size() == 0:
		return Vector3.ZERO
	
	var spawn_tile = entrance_zone_tiles[randi() % entrance_zone_tiles.size()]
	var world_pos = map_to_local(spawn_tile)
	world_pos.y = 0.1
	
	return world_pos

func regenerate():
	generate_map()

func get_random_floor_position() -> Vector3:
	var max_attempts = 100
	for i in range(max_attempts):
		var x = randi_range(1, map_width - 2)
		var z = randi_range(1, map_depth - 2)
		if is_walkable(x, z):
			return map_to_local(Vector3i(x, 0, z))
	
	return map_to_local(Vector3i(int(map_width / 2.0), 0, int(map_depth / 2.0)))

func is_walkable(x: int, z: int) -> bool:
	var tile = get_cell_item(Vector3i(x, 0, z))
	return tile == grass_tile_id or tile == stone_road_tile_id

func get_tile_at_position(x: int, z: int) -> int:
	return get_cell_item(Vector3i(x, 0, z))


## Get floor type at position (after multi-grid processing)
func get_floor_type_at_position(x: int, z: int) -> String:
	if multi_grid_processor:
		return multi_grid_processor.get_floor_type_at(Vector3i(x, 0, z))
	return ""


## Check if position is walkable (after multi-grid processing)
func is_position_walkable(x: int, z: int) -> bool:
	if multi_grid_processor:
		return multi_grid_processor.is_walkable_at(Vector3i(x, 0, z))
	
	# Fallback: check primary grid
	return is_walkable(x, z)


## Check if position has a door (after multi-grid processing)
func has_door_at_position(x: int, z: int) -> bool:
	if multi_grid_processor:
		return multi_grid_processor.has_door_at(Vector3i(x, 0, z))
	return false
