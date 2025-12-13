extends Node3D
class_name EntityCullingSystem

## Handles hiding/showing entities based on vision cone
## Separate from fog systems for clarity

@export var player: Node3D
@export var vision_cone: Node3D  # Can be VisionConeSystem or WorkingVisionCone
@export var map_container: Node3D
@export var update_interval: float = 0.1

var map_generator: GridMap
var update_timer: float = 0.0
var is_initialized: bool = false

func _ready():
	if not player or not vision_cone or not map_container:
		push_error("EntityCulling: Missing references!")
		return
	
	find_map()

func find_map():
	for child in map_container.get_children():
		if child is GridMap:
			map_generator = child
			is_initialized = true
			return
		# Search recursively
		var gridmap = find_gridmap_recursive(child)
		if gridmap:
			map_generator = gridmap
			is_initialized = true
			return

func find_gridmap_recursive(node: Node) -> GridMap:
	if node is GridMap:
		return node
	for child in node.get_children():
		if child is GridMap:
			return child
		var result = find_gridmap_recursive(child)
		if result:
			return result
	return null

func _process(delta):
	if not is_initialized:
		find_map()
		return
	
	# Check if map was freed (level change)
	if not is_instance_valid(map_generator):
		is_initialized = false
		map_generator = null
		return
	
	update_timer += delta
	if update_timer >= update_interval:
		update_timer = 0.0
		update_entity_visibility()

func update_entity_visibility():
	var world = get_tree().get_first_node_in_group("world")
	if not world:
		return
	
	var entities = []
	find_entities(world, entities)
	
	if entities.size() == 0:
		return
	
	# Check if vision cone system is debug disabled
	var vision_disabled = false
	if vision_cone.has_method("get") and vision_cone.get("debug_disabled") != null:
		vision_disabled = vision_cone.get("debug_disabled")
	
	for entity in entities:
		if not is_instance_valid(entity):
			continue
		
		# Skip entities without global_position (like HoverTooltipManager which is a Node, not Node3D)
		if not entity is Node3D:
			continue
		
		# If vision system is disabled, show all entities
		if vision_disabled:
			entity.visible = true
			continue
		
		# Check if entity is visible using vision cone
		var is_visible = false
		if vision_cone.has_method("is_position_visible"):
			is_visible = vision_cone.is_position_visible(entity.global_position)
		elif vision_cone.has_method("is_tile_visible"):
			# Old system compatibility
			var entity_grid = map_generator.local_to_map(entity.global_position)
			var entity_world = map_generator.map_to_local(entity_grid)
			is_visible = vision_cone.is_tile_visible(entity_world)
		
		entity.visible = is_visible

func find_entities(node: Node, entities: Array):
	if node.is_in_group("enemy") or node.is_in_group("npc") or node.is_in_group("item"):
		entities.append(node)
	
	for child in node.get_children():
		find_entities(child, entities)
