extends GridMap
class_name ManualMap

# Tile IDs from MeshLibrary (Primary Grid)
@export var entrance_tile_id: int = 0
@export var exit_tile_id: int = 1
@export var grass_tile_id: int = 6
@export var water_tile_id: int = 7
@export var stone_road_tile_id: int = 2
@export var dirt_road_tile_id: int = 3
@export var interior_wall_tile_id: int = 8
@export var exterior_wall_tile_id: int = 9
@export var interior_floor_tile_id: int = 5
@export var door_tile_id: int = 27
@export var door_floor_tile_id: int = 4
@export var is_passive_map: bool = false  # Disable fog/vision for towns

# Advanced wall connections
@export var interior_wall_connector: AdvancedWallConnector

# Floor Grid Tile IDs - add these for your dual-grid floor meshes
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
@export var clear_simple_floors_after_processing: bool = true
@export var floor_mesh_library: MeshLibrary  # Separate MeshLibrary for floor tiles
@export var debug_multi_grid_floors: bool = false  # Enable debug output for troubleshooting

# Floor grids for dual-grid system (need 4 for multi-layer support)
@onready var floor_grid_1: GridMap = get_node("../FloorGridMap1")
@onready var floor_grid_2: GridMap = get_node("../FloorGridMap2")
@onready var floor_grid_3: GridMap = get_node("../FloorGridMap3")
@onready var floor_grid_4: GridMap = get_node("../FloorGridMap4")

var multi_grid_processor: MultiGridFloor
var exit_triggered: bool = false

# Cached entry/exit positions (stored before clearing tiles)
var cached_entrance_pos: Vector3 = Vector3.ZERO
var cached_exit_pos: Vector3 = Vector3.ZERO
var has_cached_positions: bool = false

signal generation_complete
signal player_reached_exit


func _ready():
	# Offset all floor grids for dual-grid system
	var floor_grids = [floor_grid_1, floor_grid_2, floor_grid_3, floor_grid_4]
	
	for i in range(floor_grids.size()):
		var grid = floor_grids[i]
		if grid:
			grid.position = Vector3(0.5, 0, 0.5)
			
			# Assign the separate floor MeshLibrary if provided
			if floor_mesh_library:
				grid.mesh_library = floor_mesh_library
			
			# Only enable collision on the first grid to avoid overlapping collisions
			if i > 0:
				grid.collision_layer = 0
				grid.collision_mask = 0
		else:
			push_warning("[ManualMap] Floor grid %d not found!" % (i + 1))
	
	# Apply advanced wall connections if available
	if interior_wall_connector:
		apply_wall_connections()
	
	# Apply multi-grid floor system if enabled
	if enable_multi_grid_floors and floor_grid_1:
		setup_and_process_multi_grid_floors()
	
	# Set up exit detection
	setup_exit_detection()


# This gets called by GameManager
func start_generation():
	# Wait one frame then emit (map is already ready)
	await get_tree().process_frame
	generation_complete.emit()


func _cache_entry_exit_positions():
	"""Cache entry and exit positions before tiles are cleared"""
	var used_cells = get_used_cells()
	
	for cell_pos in used_cells:
		var tile_id = get_cell_item(cell_pos)
		
		if tile_id == entrance_tile_id:
			cached_entrance_pos = map_to_local(cell_pos)
			print("[ManualMap] Cached entrance position: ", cached_entrance_pos)
		elif tile_id == exit_tile_id:
			cached_exit_pos = map_to_local(cell_pos)
			print("[ManualMap] Cached exit position: ", cached_exit_pos)
	
	has_cached_positions = true


func setup_and_process_multi_grid_floors():
	"""Set up and process the dual-grid floor system"""
	
	# IMPORTANT: Store entry/exit positions BEFORE clearing tiles
	_cache_entry_exit_positions()
	
	# Create the processor
	# Create dual grid processor with all 4 floor grids
	var floor_grids = [floor_grid_1, floor_grid_2, floor_grid_3, floor_grid_4]
	multi_grid_processor = MultiGridFloor.new(self, floor_grids)
	
	# Map primary grid tile IDs to floor type names
	# Entry/exit zones should use stone road floor tiles
	multi_grid_processor.map_tile_to_type(entrance_tile_id, "stone_road")  # 0 -> stone_road
	multi_grid_processor.map_tile_to_type(exit_tile_id, "stone_road")      # 1 -> stone_road
	multi_grid_processor.map_tile_to_type(stone_road_tile_id, "stone_road") # 2 -> stone_road
	multi_grid_processor.map_tile_to_type(dirt_road_tile_id, "dirt_road")   # 3 -> dirt_road
	multi_grid_processor.map_tile_to_type(interior_floor_tile_id, "interior_floor") # 5 -> interior_floor
	multi_grid_processor.map_tile_to_type(grass_tile_id, "grass")           # 6 -> grass
	multi_grid_processor.map_tile_to_type(water_tile_id, "water")           # 7 -> water
	
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


func apply_wall_connections():
	"""Apply advanced wall mesh connections to all interior walls"""
	print("[ManualMap] Applying advanced wall connections...")
	
	var used_cells = get_used_cells()
	var wall_positions = []
	
	# Find all interior wall positions
	for cell in used_cells:
		if get_cell_item(cell) == interior_wall_tile_id:
			wall_positions.append(cell)
	
	print("[ManualMap] Found ", wall_positions.size(), " interior wall tiles")
	
	if wall_positions.size() == 0:
		print("[ManualMap] No interior walls found")
		return
	
	# Phase 1: Gather adjacency data for all walls
	var wall_data = []
	
	for wall_pos in wall_positions:
		var adjacency_map = get_adjacency_map(wall_pos)
		var tile_data = interior_wall_connector.get_tile_and_rotation(adjacency_map)
		
		wall_data.append({
			"pos": wall_pos,
			"tile_id": tile_data.tile_id,
			"rotation": tile_data.rotation,
			"shape": tile_data.shape
		})
	
	# Phase 2: Apply all tile changes
	var walls_updated = 0
	
	for data in wall_data:
		if data.tile_id != -1:
			var orientation = get_orientation_from_rotation(data.rotation)
			set_cell_item(data.pos, data.tile_id, orientation)
			walls_updated += 1
	
	print("[ManualMap] Updated ", walls_updated, " wall tiles with advanced connections")


func get_adjacency_map(pos: Vector3i) -> Dictionary:
	"""Get adjacency map for a wall position"""
	var adjacency = {}
	
	# Cardinal directions
	adjacency[AdjacencyShapeResolver.Direction.NORTH] = is_wall_or_door(pos + Vector3i(0, 0, -1))
	adjacency[AdjacencyShapeResolver.Direction.SOUTH] = is_wall_or_door(pos + Vector3i(0, 0, 1))
	adjacency[AdjacencyShapeResolver.Direction.EAST] = is_wall_or_door(pos + Vector3i(1, 0, 0))
	adjacency[AdjacencyShapeResolver.Direction.WEST] = is_wall_or_door(pos + Vector3i(-1, 0, 0))
	
	# Diagonal directions (for corners)
	adjacency[AdjacencyShapeResolver.Direction.NORTH_EAST] = is_wall_or_door(pos + Vector3i(1, 0, -1))
	adjacency[AdjacencyShapeResolver.Direction.SOUTH_EAST] = is_wall_or_door(pos + Vector3i(1, 0, 1))
	adjacency[AdjacencyShapeResolver.Direction.SOUTH_WEST] = is_wall_or_door(pos + Vector3i(-1, 0, 1))
	adjacency[AdjacencyShapeResolver.Direction.NORTH_WEST] = is_wall_or_door(pos + Vector3i(-1, 0, -1))
	
	return adjacency


func is_wall_or_door(pos: Vector3i) -> bool:
	"""Check if a tile is a wall OR a door (for seamless connections)"""
	var tile_id = get_cell_item(pos)
	
	# Check if it's a wall
	if tile_id == interior_wall_tile_id:
		return true
	
	# Check if it's a door
	if tile_id == door_floor_tile_id:
		return true
	
	return false


func get_orientation_from_rotation(rotation_degrees: float) -> int:
	"""Convert rotation (degrees) to GridMap orientation"""
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


func setup_exit_detection():
	# Use cached exit position if available (after dual-grid processing clears tiles)
	if has_cached_positions and cached_exit_pos != Vector3.ZERO:
		_create_exit_detector_at_position(cached_exit_pos)
		print("[ManualMap] Created exit detector at cached position: ", cached_exit_pos)
		return
	
	# Fallback: search for exit tiles (for maps without dual-grid)
	var used_cells = get_used_cells()
	var exit_count = 0
	
	for cell in used_cells:
		if get_cell_item(cell) == exit_tile_id:
			exit_count += 1
			var world_pos = map_to_local(cell)
			_create_exit_detector_at_position(world_pos)
	
	if exit_count == 0:
		push_warning("[ManualMap] No exit zone found!")


func _create_exit_detector_at_position(world_pos: Vector3):
	"""Create an exit detector Area3D at the specified world position"""
	var exit_area = Area3D.new()
	exit_area.name = "ExitDetector_" + str(world_pos)
	exit_area.monitoring = true
	
	var collision_shape = CollisionShape3D.new()
	var box_shape = BoxShape3D.new()
	box_shape.size = Vector3(1, 2, 1)
	collision_shape.shape = box_shape
	
	exit_area.add_child(collision_shape)
	add_child(exit_area)
	
	world_pos.y = 1
	exit_area.global_position = world_pos
	
	exit_area.body_entered.connect(_on_exit_area_entered)


func _on_exit_area_entered(body: Node3D):
	if exit_triggered:
		return  # Already triggered, ignore
		
	if body.is_in_group("player"):
		print("Player reached exit! Emitting signal...")
		exit_triggered = true  # Set flag
		player_reached_exit.emit()


func get_entrance_zone_spawn_position() -> Vector3:
	# Use cached position if available (after dual-grid processing clears tiles)
	if has_cached_positions and cached_entrance_pos != Vector3.ZERO:
		var spawn_pos = cached_entrance_pos
		spawn_pos.y = 0.1  # player spawn height
		print("Spawning at cached entrance: ", spawn_pos)
		return spawn_pos
	
	# Fallback: search for entrance tiles (for maps without dual-grid)
	var used_cells = get_used_cells()
	var entrance_tiles = []
	
	for cell in used_cells:
		var tile_id = get_cell_item(cell)
		if tile_id == entrance_tile_id:
			entrance_tiles.append(cell)
	
	if entrance_tiles.size() == 0:
		push_warning("[ManualMap] No entrance zone found!")
		return Vector3.ZERO
	
	var spawn_tile = entrance_tiles[randi() % entrance_tiles.size()]
	var world_pos = map_to_local(spawn_tile)
	world_pos.y = 0.1  # player spawn height
	
	print("Spawning at: ", world_pos)
	return world_pos
