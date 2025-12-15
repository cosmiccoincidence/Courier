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
@export var door_tile_id: int = 12
@export var door_floor_tile_id: int = 4

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

signal generation_started
signal generation_complete
signal player_reached_exit

# ============================================================================
# MAIN GENERATION FLOW
# ============================================================================

func _ready():
	pass

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
			clear()
	
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
	
	# PHASE 5: SPECIAL ZONES
	print("\n--- PHASE 5: Special Zones ---")
	place_entrance_zone()
	place_exit_zone()
	
	# PHASE 6+: FEATURES (handled by subclasses)
	generate_features()
	
	print("\n=== Map Generation Complete ===")

# Override this in subclasses to add features (roads, buildings, etc.)
func generate_features():
	pass

func validate_map() -> bool:
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
# EXIT DETECTION
# ============================================================================

func setup_exit_detection():
	var used_cells = get_used_cells()
	
	for cell in used_cells:
		if get_cell_item(cell) == exit_tile_id:
			var exit_area = Area3D.new()
			exit_area.name = "ExitDetector_" + str(cell)
			
			var collision_shape = CollisionShape3D.new()
			var box_shape = BoxShape3D.new()
			box_shape.size = Vector3(1, 2, 1)
			collision_shape.shape = box_shape
			
			exit_area.add_child(collision_shape)
			add_child(exit_area)
			
			var world_pos = map_to_local(cell)
			world_pos.y = 1
			exit_area.global_position = world_pos
			
			exit_area.body_entered.connect(_on_exit_area_entered)
	
	print("Exit detection set up")

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
