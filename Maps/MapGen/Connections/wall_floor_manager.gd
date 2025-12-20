extends Node
class_name WallFloorManager

## Manages spawning floor meshes for wall tiles in a GridMap
## Add this as a child of your GridMap or call it after wall placement

var gridmap: GridMap
var wall_tile_configs: Dictionary = {}  # tile_id -> {shape: WallShape, floor_meshes: [names]}
var spawned_floor_meshes: Array = []  # Track for cleanup

# Floor scenes mapped by tile ID - e.g. grass_tile_id -> {mesh_name -> scene}
var floor_scenes_by_tile: Dictionary = {}

enum WallShape {
	O, U, I, L_NONE, L_SINGLE,
	T_NONE, T_SINGLE_LEFT, T_SINGLE_RIGHT, T_DOUBLE,
	X_NONE, X_SINGLE, X_OPPOSITE, X_SIDE, X_TRIPLE, X_QUAD
}

func setup(grid_map: GridMap):
	"""Initialize with the GridMap reference"""
	gridmap = grid_map

func assign_floor_scene_for_tile(tile_id: int, mesh_name: String, scene: PackedScene):
	"""Assign a specific floor scene for a tile type and mesh name
	   Example: assign_floor_scene_for_tile(grass_tile_id, 'WallInteriorFloorNE', grass_corner_scene)"""
	if not floor_scenes_by_tile.has(tile_id):
		floor_scenes_by_tile[tile_id] = {}
	floor_scenes_by_tile[tile_id][mesh_name] = scene

func register_wall_tile(tile_id: int, shape: WallShape, floor_mesh_names: Array):
	"""Register a wall tile type with its shape and required floor meshes"""
	wall_tile_configs[tile_id] = {
		"shape": shape,
		"floor_meshes": floor_mesh_names
	}

func spawn_floor_meshes_for_all_walls():
	"""Scan the GridMap and spawn floor meshes for all wall tiles"""
	if not gridmap:
		return
	
	# Clear existing floor meshes
	cleanup_floor_meshes()
	
	var used_cells = gridmap.get_used_cells()
	
	for cell in used_cells:
		var tile_id = gridmap.get_cell_item(cell)
		if wall_tile_configs.has(tile_id):
			spawn_floor_meshes_at(cell, tile_id)

func spawn_floor_meshes_at(grid_pos: Vector3i, tile_id: int):
	"""Spawn floor meshes for a specific wall tile"""
	var config = wall_tile_configs.get(tile_id)
	if not config:
		return
	
	var shape = config.shape
	var world_pos = gridmap.map_to_local(grid_pos)
	var orientation = gridmap.get_cell_item_orientation(grid_pos)
	var rotation = get_rotation_from_orientation(orientation)
	
	# Create floor meshes based on shape
	for mesh_name in config.floor_meshes:
		var floor_mesh = create_floor_mesh(mesh_name, world_pos, rotation, grid_pos, shape)
		if floor_mesh:
			spawned_floor_meshes.append(floor_mesh)

func create_floor_mesh(mesh_name: String, world_pos: Vector3, rotation: float, grid_pos: Vector3i, shape: WallShape) -> Node3D:
	"""Create a single floor mesh instance"""
	
	# Determine which tile type to match
	var neighbor_positions = get_neighbor_positions_for_mesh(mesh_name, grid_pos, rotation, shape)
	var tile_to_match = get_most_common_tile(neighbor_positions)
	
	# Fallback: if no valid floor tile found, use interior floor (tile 5) as default
	if tile_to_match == -1:
		tile_to_match = 5  # Interior floor tile ID
	
	# Check if we have a scene for this tile type + mesh name
	var scene_to_use: PackedScene = null
	if tile_to_match != -1 and floor_scenes_by_tile.has(tile_to_match):
		if floor_scenes_by_tile[tile_to_match].has(mesh_name):
			scene_to_use = floor_scenes_by_tile[tile_to_match][mesh_name]
	
	if not scene_to_use:
		return null
	
	# Instantiate the scene
	var instance = scene_to_use.instantiate()
	if not instance:
		return null
	
	instance.name = mesh_name + "_" + str(grid_pos)
	
	# Add to GridMap first
	gridmap.add_child(instance)
	
	# Set position to the wall's world position (no offset - scene handles its own positioning)
	instance.global_position = world_pos
	instance.global_position.y = 0.01  # Slightly above floor to prevent z-fighting
	
	# Apply rotation
	instance.rotation.y = rotation
	
	return instance

func get_most_common_tile(positions: Array) -> int:
	"""Get the most common floor tile ID from a list of positions (excludes walls)"""
	var tile_counts = {}
	
	for pos in positions:
		var tile_id = gridmap.get_cell_item(pos)
		
		# Skip empty tiles and wall tiles
		if tile_id == -1:
			continue
		
		# Get wall tile IDs from wall_tile_configs
		var is_wall = false
		for wall_tile_id in wall_tile_configs.keys():
			if tile_id == wall_tile_id:
				is_wall = true
				break
		
		# Only count non-wall tiles
		if not is_wall:
			tile_counts[tile_id] = tile_counts.get(tile_id, 0) + 1
	
	if tile_counts.size() == 0:
		return -1
	
	# Find most common
	var most_common = -1
	var max_count = 0
	for tile_id in tile_counts.keys():
		if tile_counts[tile_id] > max_count:
			max_count = tile_counts[tile_id]
			most_common = tile_id
	
	return most_common

func find_mesh_instance_recursive(node: Node) -> MeshInstance3D:
	"""Recursively find MeshInstance3D in a scene"""
	if node is MeshInstance3D:
		return node
	
	for child in node.get_children():
		var result = find_mesh_instance_recursive(child)
		if result:
			return result
	
	return null

func get_floor_mesh_config(mesh_name: String) -> Dictionary:
	"""Get position offset and size for a floor mesh type"""
	var configs = {
		"WallInteriorFloor": {"offset": Vector3(0, 0, 0), "size": Vector2(1, 1)},
		"WallInteriorFloorE": {"offset": Vector3(0.25, 0, 0), "size": Vector2(0.5, 1)},
		"WallInteriorFloorW": {"offset": Vector3(-0.25, 0, 0), "size": Vector2(0.5, 1)},
		"WallInteriorFloorOneCorner": {"offset": Vector3(0.25, 0, -0.25), "size": Vector2(0.5, 0.5)},
		"WallInteriorFloorThreeCorner": {"offset": Vector3(-0.125, 0, 0.125), "size": Vector2(0.75, 0.75)},
		"WallInteriorFloorS": {"offset": Vector3(0, 0, 0.25), "size": Vector2(1, 0.5)},
		"WallInteriorFloorNE": {"offset": Vector3(0.25, 0, -0.25), "size": Vector2(0.5, 0.5)},
		"WallInteriorFloorNW": {"offset": Vector3(-0.25, 0, -0.25), "size": Vector2(0.5, 0.5)},
		"WallInteriorFloorSE": {"offset": Vector3(0.25, 0, 0.25), "size": Vector2(0.5, 0.5)},
		"WallInteriorFloorSW": {"offset": Vector3(-0.25, 0, 0.25), "size": Vector2(0.5, 0.5)}
	}
	return configs.get(mesh_name, {"offset": Vector3.ZERO, "size": Vector2(1, 1)})

func get_neighbor_positions_for_mesh(mesh_name: String, grid_pos: Vector3i, rotation: float, shape: WallShape) -> Array:
	"""Get neighbor positions to check for a specific floor mesh"""
	var neighbors = []
	
	match shape:
		WallShape.O:
			# Check all 4 cardinals
			neighbors = [
				grid_pos + Vector3i(0, 0, -1),
				grid_pos + Vector3i(0, 0, 1),
				grid_pos + Vector3i(1, 0, 0),
				grid_pos + Vector3i(-1, 0, 0)
			]
		
		WallShape.U:
			# Check 3 non-connected cardinals
			var open_dir = get_rotated_direction(Vector3i(0, 0, -1), rotation)
			var all_dirs = [Vector3i(0, 0, -1), Vector3i(0, 0, 1), Vector3i(1, 0, 0), Vector3i(-1, 0, 0)]
			for dir in all_dirs:
				if dir != -open_dir:
					neighbors.append(grid_pos + dir)
		
		WallShape.I:
			# Check perpendicular sides
			if mesh_name == "WallInteriorFloorE":
				neighbors.append(grid_pos + get_rotated_direction(Vector3i(1, 0, 0), rotation))
			elif mesh_name == "WallInteriorFloorW":
				neighbors.append(grid_pos + get_rotated_direction(Vector3i(-1, 0, 0), rotation))
		
		WallShape.L_NONE, WallShape.L_SINGLE:
			if mesh_name == "WallInteriorFloorOneCorner":
				# Inner corner - check diagonal
				neighbors.append(grid_pos + get_rotated_direction(Vector3i(1, 0, -1), rotation))
			elif mesh_name == "WallInteriorFloorThreeCorner":
				# Covers SW, S, W corners - check multiple neighbors for better matching
				neighbors.append(grid_pos + get_rotated_direction(Vector3i(0, 0, 1), rotation))  # South
				neighbors.append(grid_pos + get_rotated_direction(Vector3i(-1, 0, 0), rotation)) # West
				neighbors.append(grid_pos + get_rotated_direction(Vector3i(-1, 0, 1), rotation)) # SW diagonal
		
		WallShape.T_NONE, WallShape.T_SINGLE_LEFT, WallShape.T_SINGLE_RIGHT, WallShape.T_DOUBLE:
			if mesh_name == "WallInteriorFloorS":
				neighbors.append(grid_pos + get_rotated_direction(Vector3i(0, 0, 1), rotation))
			elif mesh_name == "WallInteriorFloorNE":
				neighbors.append(grid_pos + get_rotated_direction(Vector3i(1, 0, -1), rotation))
			elif mesh_name == "WallInteriorFloorNW":
				neighbors.append(grid_pos + get_rotated_direction(Vector3i(-1, 0, -1), rotation))
		
		WallShape.X_NONE, WallShape.X_SINGLE, WallShape.X_OPPOSITE, WallShape.X_SIDE, WallShape.X_TRIPLE, WallShape.X_QUAD:
			if mesh_name == "WallInteriorFloorNE":
				neighbors.append(grid_pos + get_rotated_direction(Vector3i(1, 0, -1), rotation))
			elif mesh_name == "WallInteriorFloorNW":
				neighbors.append(grid_pos + get_rotated_direction(Vector3i(-1, 0, -1), rotation))
			elif mesh_name == "WallInteriorFloorSE":
				neighbors.append(grid_pos + get_rotated_direction(Vector3i(1, 0, 1), rotation))
			elif mesh_name == "WallInteriorFloorSW":
				neighbors.append(grid_pos + get_rotated_direction(Vector3i(-1, 0, 1), rotation))
	
	return neighbors

func get_rotated_direction(base_direction: Vector3i, rotation_rad: float) -> Vector3i:
	"""Rotate a direction vector by the given rotation"""
	var rotation_deg = rad_to_deg(rotation_rad)
	var normalized = fmod(rotation_deg, 360.0)
	if normalized < 0:
		normalized += 360.0
	
	var steps = int(round(normalized / 90.0)) % 4
	
	var result = base_direction
	for i in range(steps):
		result = Vector3i(-result.z, result.y, result.x)
	
	return result

func get_rotation_from_orientation(orientation: int) -> float:
	"""Convert GridMap orientation to rotation in radians"""
	match orientation:
		0: return 0.0
		16: return PI / 2.0
		10: return PI
		22: return 3.0 * PI / 2.0
	return 0.0

func cleanup_floor_meshes():
	"""Remove all spawned floor meshes"""
	for mesh in spawned_floor_meshes:
		if is_instance_valid(mesh):
			mesh.queue_free()
	spawned_floor_meshes.clear()
