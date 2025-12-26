extends Node3D
class_name BaseItem

@export var item_name: String = "Item"
@export var item_icon: Texture2D
@export var item_type: String = ""  # Type: helmet, weapon, armor, ring, etc.
@export var weight: float = 1.0
@export var value: int = 10
@export var stackable: bool = false
@export var max_stack_size: int = 99

# NEW: Level-based system
var item_level: int = 1  # Set by loot system when spawned
var rolled_stats: Dictionary = {}  # Future: store randomized stats based on item_level

var is_hovered: bool = false
var label_3d: Label3D
var collision_body: CollisionObject3D
var just_spawned: bool = true
var spawn_timer: float = 0.0
var being_picked_up: bool = false
var _ready_called: bool = false
var stack_count: int = 1  # How many items in this stack

func _ready():
	# Prevent duplicate _ready calls
	if _ready_called:
		return
	
	_ready_called = true
	
	# Add to item group for FOV system (but mark as just spawned)
	add_to_group("item")
	
	# Create background sprite
	var background = Sprite3D.new()
	background.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	background.texture = create_rounded_rect_texture()
	background.modulate = Color(0, 0, 0, 0.75)
	background.pixel_size = 0.012
	background.position = Vector3(0, 1.5, -0.5)
	background.hide()
	add_child(background)
	
	# Create 3D label for hover
	label_3d = Label3D.new()
	update_label_text()  # Set initial text with stack count
	label_3d.font_size = 110
	label_3d.modulate = Color(1, 1, 1)
	label_3d.outline_size = 0
	label_3d.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label_3d.position = Vector3(0, 1.6, -0.5)
	label_3d.hide()
	add_child(label_3d)
	
	# Store background reference
	set_meta("background", background)
	
	# Find collision body
	collision_body = find_collision_body(self)
	if collision_body:
		# Configure collision layers - items don't collide with player/enemies
		collision_body.collision_layer = 0
		collision_body.collision_mask = 0
		collision_body.set_collision_layer_value(4, true)  # Item layer
		collision_body.set_collision_mask_value(1, true)   # Only collide with world
	else:
		push_warning("BaseItem: No collision body found for ", item_name)

func _process(delta):
	# Give items 0.5 seconds before FOV can hide them
	if just_spawned:
		spawn_timer += delta
		if spawn_timer >= 0.5:
			just_spawned = false
		# Keep visible during spawn grace period
		visible = true
		return
	
	# Manual hover detection via raycast - REQUIRES ALT KEY
	if not visible:
		# Item hidden by FOV, hide label
		if is_hovered:
			is_hovered = false
			label_3d.hide()
			get_meta("background").hide()
		return
	
	# Check if ALT key is pressed
	var alt_pressed = Input.is_physical_key_pressed(KEY_ALT)
	
	# If ALT not pressed, hide tooltip and skip raycast
	if not alt_pressed:
		if is_hovered:
			is_hovered = false
			label_3d.hide()
			get_meta("background").hide()
		return
	
	# ALT is pressed - do raycast to check hover
	var camera = get_viewport().get_camera_3d()
	if not camera:
		return
	
	# Cast ray from mouse position
	var mouse_pos = get_viewport().get_mouse_position()
	var from = camera.project_ray_origin(mouse_pos)
	var to = from + camera.project_ray_normal(mouse_pos) * 1000
	
	var space = get_world_3d().direct_space_state
	var query = PhysicsRayQueryParameters3D.create(from, to)
	var result = space.intersect_ray(query)
	
	# Check if we hit this item
	var hovering_now = false
	if result and result.collider:
		# Check if hit collider belongs to this item
		var hit_node = result.collider
		if hit_node == collision_body or hit_node.get_parent() == self or hit_node.owner == self:
			hovering_now = true
	
	# Update hover state
	if hovering_now and not is_hovered:
		# Started hovering
		is_hovered = true
		label_3d.show()
		get_meta("background").show()
	elif not hovering_now and is_hovered:
		# Stopped hovering
		is_hovered = false
		label_3d.hide()
		get_meta("background").hide()

func find_mesh_instance(node: Node) -> MeshInstance3D:
	if node is MeshInstance3D:
		return node
	for child in node.get_children():
		var result = find_mesh_instance(child)
		if result:
			return result
	return null

func find_collision_body(node):
	if node is CollisionObject3D:
		return node
	for child in node.get_children():
		var result = find_collision_body(child)
		if result:
			return result
	return null

func create_rounded_rect_texture() -> ImageTexture:
	var img = Image.create(256, 64, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	
	# Draw rounded rectangle
	for y in range(64):
		for x in range(256):
			var corner_radius = 16
			var in_corner = false
			
			# Top-left corner
			if x < corner_radius and y < corner_radius:
				var dx = corner_radius - x
				var dy = corner_radius - y
				if dx * dx + dy * dy > corner_radius * corner_radius:
					in_corner = true
			
			# Top-right corner
			if x > 256 - corner_radius and y < corner_radius:
				var dx = x - (256 - corner_radius)
				var dy = corner_radius - y
				if dx * dx + dy * dy > corner_radius * corner_radius:
					in_corner = true
			
			# Bottom-left corner
			if x < corner_radius and y > 64 - corner_radius:
				var dx = corner_radius - x
				var dy = y - (64 - corner_radius)
				if dx * dx + dy * dy > corner_radius * corner_radius:
					in_corner = true
			
			# Bottom-right corner
			if x > 256 - corner_radius and y > 64 - corner_radius:
				var dx = x - (256 - corner_radius)
				var dy = y - (64 - corner_radius)
				if dx * dx + dy * dy > corner_radius * corner_radius:
					in_corner = true
			
			if not in_corner:
				img.set_pixel(x, y, Color(1, 1, 1, 1))
	
	return ImageTexture.create_from_image(img)

func update_label_text():
	if label_3d:
		var display_text = item_name
		
		# Show stack count if stackable
		if stackable and stack_count > 1:
			display_text = "%s (x%d)" % [item_name, stack_count]
		
		label_3d.text = display_text

# NEW: Method called by loot system to set the item level
func set_item_level(level: int):
	item_level = level
	update_label_text()  # Update label to show level
	
	# FUTURE: Roll stats based on item_level
	# roll_item_stats()

# FUTURE: Roll randomized stats based on item_level
func roll_item_stats():
	# Example: Higher item_level = better stats
	# rolled_stats["damage"] = base_damage + (item_level * damage_per_level) + randi_range(-variance, variance)
	# rolled_stats["armor"] = base_armor + (item_level * armor_per_level)
	# etc.
	pass

func pickup():
	# Prevent duplicate pickups
	if being_picked_up:
		return
	
	if not is_inside_tree():
		return
	
	being_picked_up = true  # Immediately mark as being picked up
	
	# Pass the scene reference AND weight/value/stackable/item_type so the item can be dropped later
	var item_scene = load(scene_file_path) if scene_file_path else null
	
	if Inventory.add_item(item_name, item_icon, item_scene, weight, value, stackable, max_stack_size, stack_count, item_type):
		queue_free()
	else:
		being_picked_up = false  # Re-enable if inventory was full
