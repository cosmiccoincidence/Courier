extends GridMap
class_name ManualMap

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
@export var is_passive_map: bool = false  # Disable fog/vision for towns

# Advanced wall connections
@export var interior_wall_connector: AdvancedWallConnector

# Floor mesh spawning
var wall_floor_manager: WallFloorManager = null

var exit_triggered: bool = false

signal generation_complete
signal player_reached_exit

func _ready():
	# Setup wall floor manager if wall connector is available
	if interior_wall_connector:
		setup_wall_floor_manager()
	
	# Apply advanced wall connections if available
	if interior_wall_connector:
		apply_wall_connections()
		
		# Spawn floor meshes after walls are connected
		if wall_floor_manager:
			wall_floor_manager.spawn_floor_meshes_for_all_walls()
	
	# Set up exit detection
	setup_exit_detection()

func setup_wall_floor_manager():
	"""Setup the wall floor manager with scene assignments"""
	wall_floor_manager = WallFloorManager.new()
	wall_floor_manager.setup(self)
	
	wall_floor_manager.assign_floor_scene_for_tile(interior_floor_tile_id, "WallInteriorFloorWhole", preload("res://Assets/3D/Tiles/WallInteriorFloorWhole.tscn"))
	wall_floor_manager.assign_floor_scene_for_tile(interior_floor_tile_id, "WallInteriorFloorE", preload("res://Assets/3D/Tiles/WallInteriorFloorE.tscn"))
	wall_floor_manager.assign_floor_scene_for_tile(interior_floor_tile_id, "WallInteriorFloorW", preload("res://Assets/3D/Tiles/WallInteriorFloorW.tscn"))
	wall_floor_manager.assign_floor_scene_for_tile(interior_floor_tile_id, "WallInteriorFloorS", preload("res://Assets/3D/Tiles/WallInteriorFloorS.tscn"))
	wall_floor_manager.assign_floor_scene_for_tile(interior_floor_tile_id, "WallInteriorFloorNE", preload("res://Assets/3D/Tiles/WallInteriorFloorNE.tscn"))
	wall_floor_manager.assign_floor_scene_for_tile(interior_floor_tile_id, "WallInteriorFloorNW", preload("res://Assets/3D/Tiles/WallInteriorFloorNW.tscn"))
	wall_floor_manager.assign_floor_scene_for_tile(interior_floor_tile_id, "WallInteriorFloorSW", preload("res://Assets/3D/Tiles/WallInteriorFloorSW.tscn"))
	wall_floor_manager.assign_floor_scene_for_tile(interior_floor_tile_id, "WallInteriorFloorSE", preload("res://Assets/3D/Tiles/WallInteriorFloorSE.tscn"))
	wall_floor_manager.assign_floor_scene_for_tile(interior_floor_tile_id, "WallInteriorFloorThreeCorner", preload("res://Assets/3D/Tiles/WallInteriorFloorThreeCorner.tscn"))
	
	wall_floor_manager.assign_floor_scene_for_tile(grass_tile_id, "WallInteriorFloorWhole", preload("res://Assets/3D/Tiles/WallInteriorFloorWhole.tscn"))
	wall_floor_manager.assign_floor_scene_for_tile(grass_tile_id, "WallInteriorFloorE", preload("res://Assets/3D/Tiles/WallInteriorFloorE.tscn"))
	wall_floor_manager.assign_floor_scene_for_tile(grass_tile_id, "WallInteriorFloorW", preload("res://Assets/3D/Tiles/WallInteriorFloorW.tscn"))
	wall_floor_manager.assign_floor_scene_for_tile(grass_tile_id, "WallInteriorFloorS", preload("res://Assets/3D/Tiles/WallInteriorFloorS.tscn"))
	wall_floor_manager.assign_floor_scene_for_tile(grass_tile_id, "WallInteriorFloorNE", preload("res://Assets/3D/Tiles/WallInteriorFloorNE.tscn"))
	wall_floor_manager.assign_floor_scene_for_tile(grass_tile_id, "WallInteriorFloorNW", preload("res://Assets/3D/Tiles/WallInteriorFloorNW.tscn"))
	wall_floor_manager.assign_floor_scene_for_tile(grass_tile_id, "WallInteriorFloorSW", preload("res://Assets/3D/Tiles/WallInteriorFloorSW.tscn"))
	wall_floor_manager.assign_floor_scene_for_tile(grass_tile_id, "WallInteriorFloorSE", preload("res://Assets/3D/Tiles/WallInteriorFloorSE.tscn"))
	wall_floor_manager.assign_floor_scene_for_tile(grass_tile_id, "WallInteriorFloorThreeCorner", preload("res://Assets/3D/Tiles/WallInteriorFloorThreeCorner.tscn"))
	
	# Register all wall tile types
	register_wall_tiles()

func register_wall_tiles():
	"""Register all wall tile IDs with the floor manager"""
	if not wall_floor_manager or not interior_wall_connector:
		return
	
	# O shape - isolated
	wall_floor_manager.register_wall_tile(
		interior_wall_connector.o_tile_id,
		WallFloorManager.WallShape.O,
		["WallInteriorFloorWhole"]
	)
	
	# U shape - one connection
	wall_floor_manager.register_wall_tile(
		interior_wall_connector.u_tile_id,
		WallFloorManager.WallShape.U,
		["WallInteriorFloorWhole"]
	)
	
	# I shape - straight
	wall_floor_manager.register_wall_tile(
		interior_wall_connector.i_tile_id,
		WallFloorManager.WallShape.I,
		["WallInteriorFloorE", "WallInteriorFloorW"]
	)
	
	# L shapes
	wall_floor_manager.register_wall_tile(
		interior_wall_connector.l_none_tile_id,
		WallFloorManager.WallShape.L_NONE,
		["WallInteriorFloorNE", "WallInteriorFloorThreeCorner"]
	)
	
	wall_floor_manager.register_wall_tile(
		interior_wall_connector.l_single_tile_id,
		WallFloorManager.WallShape.L_SINGLE,
		["WallInteriorFloorThreeCorner"]
	)
	
	# T shapes
	wall_floor_manager.register_wall_tile(
		interior_wall_connector.t_none_tile_id,
		WallFloorManager.WallShape.T_NONE,
		["WallInteriorFloorS", "WallInteriorFloorNE", "WallInteriorFloorNW"]
	)
	
	wall_floor_manager.register_wall_tile(
		interior_wall_connector.t_single_left_tile_id,
		WallFloorManager.WallShape.T_SINGLE_LEFT,
		["WallInteriorFloorS", "WallInteriorFloorNE", "WallInteriorFloorNW"]
	)
	
	wall_floor_manager.register_wall_tile(
		interior_wall_connector.t_single_right_tile_id,
		WallFloorManager.WallShape.T_SINGLE_RIGHT,
		["WallInteriorFloorS", "WallInteriorFloorNE", "WallInteriorFloorNW"]
	)
	
	wall_floor_manager.register_wall_tile(
		interior_wall_connector.t_double_tile_id,
		WallFloorManager.WallShape.T_DOUBLE,
		["WallInteriorFloorS", "WallInteriorFloorNE", "WallInteriorFloorNW"]
	)
	
	# X shapes
	wall_floor_manager.register_wall_tile(
		interior_wall_connector.x_none_tile_id,
		WallFloorManager.WallShape.X_NONE,
		["WallInteriorFloorNE", "WallInteriorFloorNW", "WallInteriorFloorSE", "WallInteriorFloorSW"]
	)
	
	wall_floor_manager.register_wall_tile(
		interior_wall_connector.x_single_tile_id,
		WallFloorManager.WallShape.X_SINGLE,
		["WallInteriorFloorNE", "WallInteriorFloorNW", "WallInteriorFloorSE", "WallInteriorFloorSW"]
	)
	
	wall_floor_manager.register_wall_tile(
		interior_wall_connector.x_opposite_tile_id,
		WallFloorManager.WallShape.X_OPPOSITE,
		["WallInteriorFloorNE", "WallInteriorFloorNW", "WallInteriorFloorSE", "WallInteriorFloorSW"]
	)
	
	wall_floor_manager.register_wall_tile(
		interior_wall_connector.x_side_tile_id,
		WallFloorManager.WallShape.X_SIDE,
		["WallInteriorFloorNE", "WallInteriorFloorNW", "WallInteriorFloorSE", "WallInteriorFloorSW"]
	)
	
	wall_floor_manager.register_wall_tile(
		interior_wall_connector.x_triple_tile_id,
		WallFloorManager.WallShape.X_TRIPLE,
		["WallInteriorFloorNE", "WallInteriorFloorNW", "WallInteriorFloorSE", "WallInteriorFloorSW"]
	)
	
	wall_floor_manager.register_wall_tile(
		interior_wall_connector.x_quad_tile_id,
		WallFloorManager.WallShape.X_QUAD,
		["WallInteriorFloorNE", "WallInteriorFloorNW", "WallInteriorFloorSE", "WallInteriorFloorSW"]
	)

# This gets called by GameManager
func start_generation():
	# Wait one frame then emit (map is already ready)
	await get_tree().process_frame
	generation_complete.emit()

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
	var used_cells = get_used_cells()
	
	var exit_count = 0
	for cell in used_cells:
		if get_cell_item(cell) == exit_tile_id:
			exit_count += 1
			var exit_area = Area3D.new()
			exit_area.name = "ExitDetector_" + str(cell)
			exit_area.monitoring = true  # Make sure it's enabled
			
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

func _on_exit_area_entered(body: Node3D):
	if exit_triggered:
		return  # Already triggered, ignore
		
	if body.is_in_group("player"):
		print("Player reached exit! Emitting signal...")
		exit_triggered = true  # Set flag
		player_reached_exit.emit()

func get_entrance_zone_spawn_position() -> Vector3:
	var used_cells = get_used_cells()
	var entrance_tiles = []
	
	for cell in used_cells:
		var tile_id = get_cell_item(cell)
		if tile_id == entrance_tile_id:
			entrance_tiles.append(cell)
	
	if entrance_tiles.size() == 0:
		return Vector3.ZERO
	
	var spawn_tile = entrance_tiles[randi() % entrance_tiles.size()]
	var world_pos = map_to_local(spawn_tile)
	world_pos.y = 0.1 # player spawn height
	
	print("Spawning at: ", world_pos)
	return world_pos
