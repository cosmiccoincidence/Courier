extends Node3D
class_name VisionCone

## Vision cone that ACTUALLY stops at walls
## Generates triangle fan geometry that raycasts to walls

@export var player: CharacterBody3D
@export var map_container: Node3D
@export var vision_radius: float = 35.0
@export var vision_angle: float = 130.0
@export var near_vision_radius: float = 3.0  # Small circle around player
@export var feather_distance: float = 1.5  # How far to feather the fog edges
@export var fog_color: Color = Color(0, 0, 0, 0.5)
@export var ray_count: int = 60  # More rays = smoother

var cone_mesh: MeshInstance3D
var map_generator: GridMap
var is_passive_mode: bool = false  # Set when on passive maps
var debug_disabled: bool = false  # Debug: disable system
var debug_slash_pressed: bool = false  # Debounce slash key

func _ready():
	if not player or not map_container:
		push_error("VisionCone: Missing player or map_container!")
		return
	
	find_map()
	create_cone_mesh()
	
	# Listen for new maps being added
	if map_container:
		map_container.child_entered_tree.connect(_on_child_added)

func _on_child_added(node: Node):
	if not map_generator:
		find_map()

func find_map():
	map_generator = find_gridmap_recursive(map_container)
	if map_generator:
		# Check if this is a passive map
		is_passive_mode = map_generator.get("is_passive_map")
		if is_passive_mode == null:
			is_passive_mode = false
			
		# Listen for generation complete if it has that signal
		if map_generator.has_signal("generation_complete"):
			if not map_generator.generation_complete.is_connected(_on_map_generated):
				map_generator.generation_complete.connect(_on_map_generated)

func _on_map_generated():
	pass  # Map generation complete - no action needed

func find_gridmap_recursive(node: Node) -> GridMap:
	if node is GridMap:
		return node
	for child in node.get_children():
		var result = find_gridmap_recursive(child)
		if result:
			return result
	return null

func create_cone_mesh():
	cone_mesh = MeshInstance3D.new()
	
	# Simple material - no shader complications
	var material = StandardMaterial3D.new()
	material.albedo_color = fog_color
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	material.disable_receive_shadows = true
	
	cone_mesh.material_override = material
	cone_mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	
	add_child(cone_mesh)

func _process(_delta):
	if not player or not cone_mesh:
		return
	
	# Debug input handling with debounce
	if Input.is_physical_key_pressed(KEY_SLASH):
		if not debug_slash_pressed:
			debug_slash_pressed = true
			debug_toggle_system()
	else:
		debug_slash_pressed = false
	
	# Check if map was freed (level transition)
	if map_generator and not is_instance_valid(map_generator):
		map_generator = null
		is_passive_mode = false  # Reset passive mode on map change
	
	# If no map, keep trying to find it
	if not map_generator:
		find_map()
		if not map_generator:
			# No map yet, skip this frame
			return
	
	# If system disabled OR passive map, hide cone and skip updates
	if debug_disabled or is_passive_mode:
		cone_mesh.visible = false
		return
	else:
		cone_mesh.visible = true
	
	# Update cone geometry every frame
	update_cone_geometry()

func update_cone_geometry():
	var player_forward = -player.global_transform.basis.z
	var forward_xz = Vector2(player_forward.x, player_forward.z).normalized()
	
	var forward_angle = atan2(forward_xz.y, forward_xz.x)
	var half_cone = deg_to_rad(vision_angle / 2.0)
	
	var surface_tool = SurfaceTool.new()
	surface_tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	
	var center = Vector3(player.global_position.x, 0.65, player.global_position.z)
	
	# Create fog that covers ONLY the blocked areas
	# Strategy: For each direction, check if it's in near circle, vision cone, or fog area
	var total_rays = 120
	
	for i in range(total_rays):
		var t = float(i) / float(total_rays)
		var angle = t * TAU
		var dir = Vector2(cos(angle), sin(angle))
		
		# Check if in vision cone
		var angle_diff = abs(fmod(angle - forward_angle + PI, TAU) - PI)
		var in_vision_cone = angle_diff <= half_cone
		
		# Near circle: within near_vision_radius from player
		# Vision cone: within cone angle
		# If EITHER is true, we can potentially see (unless wall blocks)
		
		if in_vision_cone:
			# Raycast to find wall in cone direction
			var hit_pos = raycast_to_wall(player.global_position, dir, vision_radius)
			var hit_dist = (hit_pos - Vector2(center.x, center.z)).length()
			
			# If we hit a wall before max distance, create fog BEYOND it
			if hit_dist < vision_radius - 0.5:
				var push_distance = 0.85
				var wall_point_pushed = hit_pos + dir * push_distance
				
				var wall_point = Vector3(wall_point_pushed.x, 0.65, wall_point_pushed.y)
				var max_point = Vector3(center.x, 0.65, center.z) + Vector3(dir.x, 0, dir.y) * vision_radius
				
				var next_angle = ((float(i + 1) / float(total_rays)) * TAU)
				var next_dir = Vector2(cos(next_angle), sin(next_angle))
				var next_hit = raycast_to_wall(player.global_position, next_dir, vision_radius)
				var next_wall_pushed = next_hit + next_dir * push_distance
				
				var next_wall_point = Vector3(next_wall_pushed.x, 0.65, next_wall_pushed.y)
				var next_max_point = Vector3(center.x, 0.65, center.z) + Vector3(next_dir.x, 0, next_dir.y) * vision_radius
				
				# Create quad from wall to max distance
				surface_tool.add_vertex(wall_point)
				surface_tool.add_vertex(next_wall_point)
				surface_tool.add_vertex(next_max_point)
				
				surface_tool.add_vertex(wall_point)
				surface_tool.add_vertex(next_max_point)
				surface_tool.add_vertex(max_point)
		else:
			# Outside vision cone - check if in near circle
			var test_point = Vector2(center.x, center.z) + dir * near_vision_radius
			var dist_to_test = (test_point - Vector2(center.x, center.z)).length()
			
			if dist_to_test <= near_vision_radius + 0.1:
				# In near circle range - raycast to see if wall blocks
				var hit_pos = raycast_to_wall(player.global_position, dir, near_vision_radius)
				var hit_dist = (hit_pos - Vector2(center.x, center.z)).length()
				
				# If wall blocks before near_vision_radius, create fog beyond wall
				if hit_dist < near_vision_radius - 0.5:
					var push_distance = 0.5
					var wall_point_pushed = hit_pos + dir * push_distance
					
					var wall_point = Vector3(wall_point_pushed.x, 0.65, wall_point_pushed.y)
					var max_point = Vector3(center.x, 0.65, center.z) + Vector3(dir.x, 0, dir.y) * vision_radius
					
					var next_angle = ((float(i + 1) / float(total_rays)) * TAU)
					var next_dir = Vector2(cos(next_angle), sin(next_angle))
					var next_hit = raycast_to_wall(player.global_position, next_dir, near_vision_radius)
					var next_wall_pushed = next_hit + next_dir * push_distance
					
					var next_wall_point = Vector3(next_wall_pushed.x, 0.65, next_wall_pushed.y)
					var next_max_point = Vector3(center.x, 0.65, center.z) + Vector3(next_dir.x, 0, next_dir.y) * vision_radius
					
					surface_tool.add_vertex(wall_point)
					surface_tool.add_vertex(next_wall_point)
					surface_tool.add_vertex(next_max_point)
					
					surface_tool.add_vertex(wall_point)
					surface_tool.add_vertex(next_max_point)
					surface_tool.add_vertex(max_point)
				else:
					# No wall in near circle, but past near_vision_radius = fog
					var near_end = Vector3(center.x, 0.65, center.z) + Vector3(dir.x, 0, dir.y) * near_vision_radius
					var far_end = Vector3(center.x, 0.65, center.z) + Vector3(dir.x, 0, dir.y) * vision_radius
					
					var next_angle = ((float(i + 1) / float(total_rays)) * TAU)
					var next_dir = Vector2(cos(next_angle), sin(next_angle))
					var next_near = Vector3(center.x, 0.65, center.z) + Vector3(next_dir.x, 0, next_dir.y) * near_vision_radius
					var next_far = Vector3(center.x, 0.65, center.z) + Vector3(next_dir.x, 0, next_dir.y) * vision_radius
					
					surface_tool.add_vertex(near_end)
					surface_tool.add_vertex(next_near)
					surface_tool.add_vertex(next_far)
					
					surface_tool.add_vertex(near_end)
					surface_tool.add_vertex(next_far)
					surface_tool.add_vertex(far_end)
			else:
				# Not in cone or near circle - always fog from center to max
				var end_pos = Vector3(center.x, 0.65, center.z) + Vector3(dir.x, 0, dir.y) * vision_radius
				var next_angle = ((float(i + 1) / float(total_rays)) * TAU)
				var next_dir = Vector2(cos(next_angle), sin(next_angle))
				var next_end = Vector3(center.x, 0.65, center.z) + Vector3(next_dir.x, 0, next_dir.y) * vision_radius
				
				surface_tool.add_vertex(center)
				surface_tool.add_vertex(end_pos)
				surface_tool.add_vertex(next_end)
	
	var mesh = surface_tool.commit()
	cone_mesh.mesh = mesh

func raycast_to_wall(from: Vector3, direction: Vector2, max_dist: float) -> Vector2:
	if not map_generator:
		return Vector2(from.x, from.z) + direction * max_dist
	
	var from_2d = Vector2(from.x, from.z)
	var step_size = 0.4  # Smaller steps for better accuracy
	
	# Step along ray
	var dist = step_size
	while dist <= max_dist:
		var check_pos_2d = from_2d + direction * dist
		var check_pos_3d = Vector3(check_pos_2d.x, from.y, check_pos_2d.y)
		var tile_pos = map_generator.local_to_map(check_pos_3d)
		var tile_id = map_generator.get_cell_item(tile_pos)
		
		# Check current tile
		if is_wall_tile(tile_id):
			# Check if this is a door tile and if there's an open door here
			var door_floor_id = map_generator.get("door_floor_tile_id")
			if door_floor_id != null and tile_id == door_floor_id:
				# This is a door tile - check if there's an open door at this position
				if is_door_open_at_position(check_pos_3d):
					# Door is open - treat as walkable, don't block vision
					dist += step_size
					continue
			
			var return_dist = max(0.1, dist - step_size)
			return from_2d + direction * return_dist
		
		# NEW IMPROVED: Check for diagonal wall corner gaps
		# Only check if moving diagonally AND we're in an empty/walkable tile
		if abs(direction.x) > 0.1 and abs(direction.y) > 0.1 and tile_id == -1:
			# Get world position of current check point
			var world_pos = map_generator.map_to_local(tile_pos)
			
			# Check how close we are to the tile center (the corner intersection)
			var offset_x = abs(check_pos_2d.x - world_pos.x)
			var offset_z = abs(check_pos_2d.y - world_pos.z)
			
			# Only block if we're near the corner intersection point
			if offset_x < 0.3 and offset_z < 0.3:
				# Check the two orthogonal neighbors
				var dir_x = int(sign(direction.x))
				var dir_z = int(sign(direction.y))
				
				var check_x = Vector3i(tile_pos.x + dir_x, tile_pos.y, tile_pos.z)
				var check_z = Vector3i(tile_pos.x, tile_pos.y, tile_pos.z + dir_z)
				
				var tile_x = map_generator.get_cell_item(check_x)
				var tile_z = map_generator.get_cell_item(check_z)
				
				# If BOTH adjacent tiles are walls, block the diagonal gap
				if is_wall_tile(tile_x) and is_wall_tile(tile_z):
					var return_dist = max(0.1, dist - step_size)
					return from_2d + direction * return_dist
		
		dist += step_size
	
	# No wall hit - return max distance
	return from_2d + direction * max_dist

func is_door_open_at_position(world_pos: Vector3) -> bool:
	"""Check if there's an open door at the given world position"""
	# Get all doors in the scene
	var doors = get_tree().get_nodes_in_group("door")
	
	# Check if any door is close to this position and is open
	for door in doors:
		if door is Door:  # Make sure it's actually a Door
			var door_pos = door.global_position
			var distance = Vector2(world_pos.x - door_pos.x, world_pos.z - door_pos.z).length()
			
			# If door is within 1 unit and is open (collision disabled)
			if distance < 1.0 and door.is_open:
				return true
	
	return false

func is_wall_tile(tile_id: int) -> bool:
	if tile_id == -1:
		return true  # Empty/outside map = wall
	
	if not map_generator:
		return false
	
	# Try to get specific wall IDs
	var exterior_wall_id = map_generator.get("exterior_wall_tile_id")
	var interior_wall_id = map_generator.get("interior_wall_tile_id") 
	var interior_floor_id = map_generator.get("interior_floor_tile_id")
	var door_floor_id = map_generator.get("door_floor_tile_id")
	var grass_id = map_generator.get("grass_tile_id")
	var dirt_road_id = map_generator.get("dirt_road_tile_id")
	var stone_road_id = map_generator.get("stone_road_tile_id")
	var entrance_id = map_generator.get("entrance_tile_id")
	var exit_id = map_generator.get("exit_tile_id")
	
	# NEW: Get wall connector to check for all wall variations
	var wall_connector = map_generator.get("interior_wall_connector")
	
	# Explicit wall check
	if exterior_wall_id != null and tile_id == exterior_wall_id:
		return true
	if interior_wall_id != null and tile_id == interior_wall_id:
		return true
	
	# NEW: Check if it's any of the wall variations
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
	
	# Door tiles are walls (they block vision unless the door is open)
	# The raycast function checks door state separately
	if door_floor_id != null and tile_id == door_floor_id:
		return true
	
	# Assume anything that's NOT floor/grass/road/path/entrance/exit is a wall
	var is_walkable = false
	if interior_floor_id != null and tile_id == interior_floor_id:
		is_walkable = true
	# Removed door_floor_id from walkable - doors are walls unless open
	if grass_id != null and tile_id == grass_id:
		is_walkable = true
	if dirt_road_id != null and tile_id == dirt_road_id:
		is_walkable = true
	if stone_road_id != null and tile_id == stone_road_id:
		is_walkable = true
	if entrance_id != null and tile_id == entrance_id:
		is_walkable = true
	if exit_id != null and tile_id == exit_id:
		is_walkable = true
	
	return not is_walkable

## Check if a world position is visible (for entity culling)
func is_position_visible(world_pos: Vector3) -> bool:
	if not player:
		return false
	
	var to_pos = world_pos - player.global_position
	var dist_xz = Vector2(to_pos.x, to_pos.z).length()
	
	# Very close = always visible
	if dist_xz < 0.5:
		return true
	
	# Check if in near vision circle (with wall blocking)
	if dist_xz <= near_vision_radius:
		var direction = Vector2(to_pos.x, to_pos.z).normalized()
		var hit_pos = raycast_to_wall(player.global_position, direction, dist_xz + 1.0)
		var hit_dist = (hit_pos - Vector2(player.global_position.x, player.global_position.z)).length()
		# If no wall blocks it, it's visible in near circle
		if hit_dist >= dist_xz - 0.5:
			return true
	
	# Outside vision radius = not visible
	if dist_xz > vision_radius:
		return false
	
	# Check if in cone angle
	var player_forward = -player.global_transform.basis.z
	var forward_xz = Vector2(player_forward.x, player_forward.z).normalized()
	var to_pos_xz = Vector2(to_pos.x, to_pos.z).normalized()
	
	var angle = acos(clamp(forward_xz.dot(to_pos_xz), -1.0, 1.0))
	var half_cone = deg_to_rad(vision_angle / 2.0)
	
	if angle > half_cone:
		return false  # Outside cone
	
	# Check wall blocking in cone
	var direction = Vector2(to_pos.x, to_pos.z).normalized()
	var hit_pos = raycast_to_wall(player.global_position, direction, dist_xz + 1.0)
	var hit_dist = (hit_pos - Vector2(player.global_position.x, player.global_position.z)).length()
	
	# If wall is closer than entity, entity is blocked
	return hit_dist >= dist_xz - 0.5

## DEBUG FUNCTIONS

func debug_toggle_system():
	"""Debug: Toggle system on/off (slash key)"""
	debug_disabled = not debug_disabled
