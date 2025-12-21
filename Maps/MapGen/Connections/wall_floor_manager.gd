extends Node
class_name WallFloorManager

## Manages spawning floor meshes for wall tiles in a GridMap
## Add this as a child of your GridMap or call it after wall placement

var gridmap: GridMap
var wall_tile_configs: Dictionary = {}  # tile_id -> {shape: WallShape, floor_meshes: [names]}
var spawned_floor_meshes: Array = []  # Track for cleanup
var spawned_mesh_tiles: Dictionary = {}  # wall_grid_pos -> {mesh_name -> tile_type}

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
	   Example: assign_floor_scene_for_tile(grass_tile_id, 'FloorNE', grass_corner_scene)"""
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
	var tile_to_match = get_most_common_tile(neighbor_positions, grid_pos)  # Pass grid_pos for directional weighting
	
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
	
	# Track which tile type this mesh is using
	if not spawned_mesh_tiles.has(grid_pos):
		spawned_mesh_tiles[grid_pos] = {}
	spawned_mesh_tiles[grid_pos][mesh_name] = tile_to_match
	
	# Add to GridMap first
	gridmap.add_child(instance)
	
	# Set position to the wall's world position (no offset - scene handles its own positioning)
	instance.global_position = world_pos
	instance.global_position.y = 0.01  # Slightly above floor to prevent z-fighting
	
	# Apply rotation
	instance.rotation.y = rotation
	
	return instance

func get_most_common_tile(positions: Array, mesh_grid_pos: Vector3i = Vector3i.ZERO) -> int:
	"""Get the most common floor tile ID from a list of positions (excludes walls)"""
	var tile_counts = {}
	var wall_positions = []  # Track wall positions for backup search
	
	for pos in positions:
		var tile_id = gridmap.get_cell_item(pos)
		
		# Skip empty tiles
		if tile_id == -1:
			continue
		
		# Check if this is a wall tile
		var is_wall = false
		for wall_tile_id in wall_tile_configs.keys():
			if tile_id == wall_tile_id:
				is_wall = true
				wall_positions.append(pos)  # Save for backup search
				break
		
		# Only count non-wall tiles
		if not is_wall:
			tile_counts[tile_id] = tile_counts.get(tile_id, 0) + 1
	
	# If we found floor tiles, return the most common
	if tile_counts.size() > 0:
		var most_common = -1
		var max_count = 0
		for tile_id in tile_counts.keys():
			var count = tile_counts[tile_id]
			# Prefer this tile if: (1) higher count, or (2) same count but it's grass (tile 6)
			if count > max_count or (count == max_count and tile_id == 6):
				max_count = count
				most_common = tile_id
		return most_common
	
	# BACKUP SEARCH: If only walls found, check adjacent tiles for floor tiles
	if wall_positions.size() > 0 and mesh_grid_pos != Vector3i.ZERO:
		var backup_tile_counts = {}
		
		# For each wall we found, determine what to check
		for wall_pos in wall_positions:
			var check_dir = wall_pos - mesh_grid_pos  # Direction from mesh to wall
			
			# Determine if this is a diagonal or cardinal check
			var is_diagonal = abs(check_dir.x) > 0 and abs(check_dir.z) > 0
			
			if is_diagonal:
				# DIAGONAL CHECK: Look around the wall for floor tiles
				var expected_floor_pos = mesh_grid_pos + (check_dir * 2)
				
				var directions = [
					Vector3i(1, 0, 0), Vector3i(-1, 0, 0),   # East, West
					Vector3i(0, 0, 1), Vector3i(0, 0, -1),   # South, North
					Vector3i(1, 0, 1), Vector3i(-1, 0, 1),   # SE, SW
					Vector3i(1, 0, -1), Vector3i(-1, 0, -1)  # NE, NW
				]
				
				for dir in directions:
					var check_pos = wall_pos + dir
					var check_tile = gridmap.get_cell_item(check_pos)
					
					if check_tile == -1:
						continue
					
					var is_wall_tile = false
					for wall_tile_id in wall_tile_configs.keys():
						if check_tile == wall_tile_id:
							is_wall_tile = true
							break
					
					if not is_wall_tile:
						var weight = 100 if check_pos == expected_floor_pos else 1
						backup_tile_counts[check_tile] = backup_tile_counts.get(check_tile, 0) + weight
			else:
				# CARDINAL CHECK: Look at perpendicular walls and use their floor meshes in the same direction
				var perpendicular_dirs = []
				if check_dir.x == 0:  # Checking north/south, check east/west walls
					perpendicular_dirs = [Vector3i(1, 0, 0), Vector3i(-1, 0, 0)]
				else:  # Checking east/west, check north/south walls
					perpendicular_dirs = [Vector3i(0, 0, 1), Vector3i(0, 0, -1)]
				
				for perp_dir in perpendicular_dirs:
					var neighbor_wall_pos = mesh_grid_pos + perp_dir
					
					# Check if this neighboring position has spawned meshes
					if spawned_mesh_tiles.has(neighbor_wall_pos):
						var neighbor_meshes = spawned_mesh_tiles[neighbor_wall_pos]
						
						# Look for any mesh in that wall that points in the same direction
						# For example, if we're checking FloorS, look for FloorS or FloorThreeCorner or any south-facing mesh
						for neighbor_mesh_name in neighbor_meshes.keys():
							var neighbor_tile = neighbor_meshes[neighbor_mesh_name]
							# Use this tile type with high priority
							backup_tile_counts[neighbor_tile] = backup_tile_counts.get(neighbor_tile, 0) + 100
		
		# Return most common floor tile found around walls
		if backup_tile_counts.size() > 0:
			var most_common = -1
			var max_count = 0
			for tile_id in backup_tile_counts.keys():
				if backup_tile_counts[tile_id] > max_count:
					max_count = backup_tile_counts[tile_id]
					most_common = tile_id
			return most_common
	
	return -1

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
		"FloorWhole": {"offset": Vector3(0, 0, 0), "size": Vector2(1, 1)},
		"FloorE": {"offset": Vector3(0.25, 0, 0), "size": Vector2(0.5, 1)},
		"FloorW": {"offset": Vector3(-0.25, 0, 0), "size": Vector2(0.5, 1)},
		"FloorThreeCorner": {"offset": Vector3(-0.125, 0, 0.125), "size": Vector2(0.75, 0.75)},
		"FloorS": {"offset": Vector3(0, 0, 0.25), "size": Vector2(1, 0.5)},
		"FloorNE": {"offset": Vector3(0.25, 0, -0.25), "size": Vector2(0.5, 0.5)},
		"FloorNW": {"offset": Vector3(-0.25, 0, -0.25), "size": Vector2(0.5, 0.5)},
		"FloorSE": {"offset": Vector3(0.25, 0, 0.25), "size": Vector2(0.5, 0.5)},
		"FloorSW": {"offset": Vector3(-0.25, 0, 0.25), "size": Vector2(0.5, 0.5)}
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
			# I-shape has two floor meshes positioned on opposite sides of the tile
			# Each mesh should check only its own adjacent neighbor
			
			var rotation_deg = rad_to_deg(rotation)
			var normalized = fmod(rotation_deg, 360.0)
			if normalized < 0:
				normalized += 360.0
			
			# Determine if wall runs north-south or east-west
			var is_north_south = (normalized < 45) or (normalized >= 135 and normalized < 225) or (normalized >= 315)
			
			if is_north_south:
				# Wall runs north-south
				if mesh_name == "FloorE":
					neighbors.append(grid_pos + Vector3i(1, 0, 0))   # E checks east ONLY
				elif mesh_name == "FloorW":
					neighbors.append(grid_pos + Vector3i(-1, 0, 0))  # W checks west ONLY
			else:
				# Wall runs east-west
				if mesh_name == "FloorE":
					neighbors.append(grid_pos + Vector3i(0, 0, -1))  # E checks north ONLY
				elif mesh_name == "FloorW":
					neighbors.append(grid_pos + Vector3i(0, 0, 1))   # W checks south ONLY
		
		WallShape.L_NONE, WallShape.L_SINGLE:
			var rotation_deg = rad_to_deg(rotation)
			var normalized = fmod(rotation_deg, 360.0)
			if normalized < 0:
				normalized += 360.0
			
			# At 90° and 270°, the meshes swap physical positions due to rotation
			var needs_swap = (normalized >= 45 and normalized < 135) or (normalized >= 225 and normalized < 315)
			
			if mesh_name == "FloorNE":
				# Inner corner mesh - always checks its diagonal
				if needs_swap:
					var diag = get_rotated_direction(Vector3i(-1, 0, 1), rotation)  # SW at 0°
					neighbors.append(grid_pos + diag)
				else:
					var diag = get_rotated_direction(Vector3i(1, 0, -1), rotation)
					neighbors.append(grid_pos + diag)
					
			elif mesh_name == "FloorThreeCorner":
				# Three corner mesh: Only check the two cardinal neighbors (not the diagonal)
				# The diagonal often goes into walls or off-map, cardinals are more reliable
				if needs_swap:
					# At 90°/270°: Check N and E cardinals only
					neighbors.append(grid_pos + get_rotated_direction(Vector3i(0, 0, -1), rotation))  # Cardinal 1
					neighbors.append(grid_pos + get_rotated_direction(Vector3i(1, 0, 0), rotation))   # Cardinal 2
				else:
					# At 0°/180°: Check S and W cardinals only
					neighbors.append(grid_pos + get_rotated_direction(Vector3i(0, 0, 1), rotation))   # Cardinal 1
					neighbors.append(grid_pos + get_rotated_direction(Vector3i(-1, 0, 0), rotation))  # Cardinal 2
		
		WallShape.T_NONE, WallShape.T_SINGLE_LEFT, WallShape.T_SINGLE_RIGHT, WallShape.T_DOUBLE:
			var rotation_deg = rad_to_deg(rotation)
			var normalized = fmod(rotation_deg, 360.0)
			if normalized < 0:
				normalized += 360.0
			
			# Determine T orientation and assign neighbors directly
			if normalized < 45:  # 0° - T opens north, FloorS on south side
				if mesh_name == "FloorS":
					neighbors.append(grid_pos + Vector3i(0, 0, 1))  # South
				elif mesh_name == "FloorNE":
					neighbors.append(grid_pos + Vector3i(1, 0, -1))  # NE diagonal
				elif mesh_name == "FloorNW":
					neighbors.append(grid_pos + Vector3i(-1, 0, -1))  # NW diagonal
			elif normalized < 135:  # 90° - T opens east, FloorS on west side
				if mesh_name == "FloorS":
					neighbors.append(grid_pos + Vector3i(1, 0, 0))  # East (OPPOSITE - should check where FloorS scene actually is)
				elif mesh_name == "FloorNE":
					neighbors.append(grid_pos + Vector3i(-1, 0, -1))  # NW diagonal
				elif mesh_name == "FloorNW":
					neighbors.append(grid_pos + Vector3i(-1, 0, 1))  # SW diagonal
			elif normalized < 225:  # 180° - T opens south, FloorS on north side
				if mesh_name == "FloorS":
					neighbors.append(grid_pos + Vector3i(0, 0, -1))  # North
				elif mesh_name == "FloorNE":
					neighbors.append(grid_pos + Vector3i(-1, 0, 1))  # SW diagonal
				elif mesh_name == "FloorNW":
					neighbors.append(grid_pos + Vector3i(1, 0, 1))  # SE diagonal
			else:  # 270° - T opens west, FloorS on east side  
				if mesh_name == "FloorS":
					neighbors.append(grid_pos + Vector3i(-1, 0, 0))  # West (OPPOSITE - should check where FloorS scene actually is)
				elif mesh_name == "FloorNE":
					neighbors.append(grid_pos + Vector3i(1, 0, 1))  # SE diagonal
				elif mesh_name == "FloorNW":
					neighbors.append(grid_pos + Vector3i(1, 0, -1))  # NE diagonal
		
		WallShape.X_NONE, WallShape.X_SINGLE, WallShape.X_OPPOSITE, WallShape.X_SIDE, WallShape.X_TRIPLE, WallShape.X_QUAD:
			var rotation_deg = rad_to_deg(rotation)
			var normalized = fmod(rotation_deg, 360.0)
			if normalized < 0:
				normalized += 360.0
			
			# X-shape has 4 corners that rotate with the wall
			if normalized < 45:  # 0°
				if mesh_name == "FloorNE":
					neighbors.append(grid_pos + Vector3i(1, 0, -1))  # NE
				elif mesh_name == "FloorNW":
					neighbors.append(grid_pos + Vector3i(-1, 0, -1))  # NW
				elif mesh_name == "FloorSE":
					neighbors.append(grid_pos + Vector3i(1, 0, 1))  # SE
				elif mesh_name == "FloorSW":
					neighbors.append(grid_pos + Vector3i(-1, 0, 1))  # SW
			elif normalized < 135:  # 90° - all meshes rotate 90° clockwise
				if mesh_name == "FloorNE":
					neighbors.append(grid_pos + Vector3i(-1, 0, -1))  # NW (FloorNE → NW position)
				elif mesh_name == "FloorNW":
					neighbors.append(grid_pos + Vector3i(-1, 0, 1))  # SW (FloorNW → SW position)
				elif mesh_name == "FloorSE":
					neighbors.append(grid_pos + Vector3i(1, 0, -1))  # NE (FloorSE → NE position)
				elif mesh_name == "FloorSW":
					neighbors.append(grid_pos + Vector3i(1, 0, 1))  # SE (FloorSW → SE position)
			elif normalized < 225:  # 180° - all meshes rotate 180°
				if mesh_name == "FloorNE":
					neighbors.append(grid_pos + Vector3i(-1, 0, 1))  # SW (FloorNE → SW position)
				elif mesh_name == "FloorNW":
					neighbors.append(grid_pos + Vector3i(1, 0, 1))  # SE (FloorNW → SE position)
				elif mesh_name == "FloorSE":
					neighbors.append(grid_pos + Vector3i(-1, 0, -1))  # NW (FloorSE → NW position)
				elif mesh_name == "FloorSW":
					neighbors.append(grid_pos + Vector3i(1, 0, -1))  # NE (FloorSW → NE position)
			else:  # 270° - all meshes rotate 270° clockwise
				if mesh_name == "FloorNE":
					neighbors.append(grid_pos + Vector3i(1, 0, 1))  # SE (FloorNE → SE position)
				elif mesh_name == "FloorNW":
					neighbors.append(grid_pos + Vector3i(1, 0, -1))  # NE (FloorNW → NE position)
				elif mesh_name == "FloorSE":
					neighbors.append(grid_pos + Vector3i(-1, 0, 1))  # SW (FloorSE → SW position)
				elif mesh_name == "FloorSW":
					neighbors.append(grid_pos + Vector3i(-1, 0, -1))  # NW (FloorSW → NW position)
	
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
