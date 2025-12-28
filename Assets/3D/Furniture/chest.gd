extends BaseFurniture
class_name Chest

# LEVEL-BASED LOOT SYSTEM
@export var base_chest_level: int = 0  # Base level offset (0 = normal, +1 = better loot, etc.)
@export var chest_level: int = 5  # Final calculated level (map_level + base_chest_level)
@export var loot_profile: LootProfile  # Profile for this chest type

@export var open_sound: AudioStream

# Don't use @onready since children might not exist
var audio_player: AudioStreamPlayer3D = null
var mesh_instance: MeshInstance3D = null
var collision_shape: CollisionShape3D = null
var is_open := false

func _ready():
	# Call parent _ready first
	super._ready()
	
	# Chest-specific settings (override defaults)
	is_visual_obstruction = true  # Chests block vision
	obstruction_radius = 0.5
	interaction_range = 1.5
	
	# Try to get existing nodes first
	mesh_instance = get_node_or_null("MeshInstance3D")
	collision_shape = get_node_or_null("CollisionShape3D")
	audio_player = get_node_or_null("AudioStreamPlayer3D")
	
	# Create a basic chest mesh if none exists
	if not mesh_instance:
		mesh_instance = MeshInstance3D.new()
		mesh_instance.name = "MeshInstance3D"
		add_child(mesh_instance)
		var box_mesh = BoxMesh.new()
		box_mesh.size = Vector3(1, 0.8, 0.7)
		mesh_instance.mesh = box_mesh
		mesh_instance.position.y = 0.4
	
	if not collision_shape:
		collision_shape = CollisionShape3D.new()
		collision_shape.name = "CollisionShape3D"
		add_child(collision_shape)
		var box_shape = BoxShape3D.new()
		box_shape.size = Vector3(1, 0.8, 0.7)
		collision_shape.shape = box_shape
		collision_shape.position.y = 0.4
	
	if not audio_player:
		audio_player = AudioStreamPlayer3D.new()
		audio_player.name = "AudioStreamPlayer3D"
		add_child(audio_player)

# Called by map generator to set chest level based on map level
func set_level_from_map(map_level: int):
	chest_level = map_level + base_chest_level
	print("Chest set to level ", chest_level, " (map: ", map_level, " + base: ", base_chest_level, ")")

func _physics_process(_delta):
	if not is_open and check_interaction():
		open_chest()

func open_chest():
	if is_open:
		return
	
	if not can_interact:
		return
	
	is_open = true
	can_interact = false
	
	# Play sound
	if open_sound and audio_player:
		audio_player.stream = open_sound
		audio_player.play()
	
	# Spawn loot using new system
	spawn_loot()
	
	print("Chest opened! (Level ", chest_level, ")")

func spawn_loot():
	if not loot_profile:
		push_warning("No loot profile set for chest")
		return
	
	var loot_manager = get_node_or_null("/root/LootManager")
	if not loot_manager:
		push_error("LootManager not found! Add it as an autoload singleton.")
		return
	
	# Get player luck stat
	var player_luck = 0.0
	var player = get_tree().get_first_node_in_group("player")
	if player and player.has_method("get_total_luck"):
		player_luck = player.get_total_luck()
	elif player and "luck" in player:
		player_luck = player.luck
	
	# Generate loot based on chest_level and player_luck
	var loot_data = loot_manager.generate_loot(chest_level, loot_profile, player_luck)
	
	for item_data in loot_data:
		_spawn_loot_item(item_data)

func _spawn_loot_item(item_data: Dictionary):
	var item: LootItem = item_data["item"]
	var item_level: int = item_data["item_level"]
	var item_quality: int = item_data["item_quality"]
	var item_value: int = item_data["item_value"]
	var stack_size: int = item_data.get("stack_size", 1)
	
	if not item.item_scene:
		push_warning("No scene set for item: %s" % item.item_name)
		return
	
	var loot_instance = item.item_scene.instantiate()
	
	# Set up the item before adding to scene
	if loot_instance is BaseItem:
		# Copy base properties from LootItem resource
		loot_instance.item_name = item.item_name
		loot_instance.item_icon = item.icon
		loot_instance.item_type = item.item_type
		loot_instance.mass = item.mass
		loot_instance.stackable = item.stackable
		loot_instance.max_stack_size = item.max_stack_size
		
		# Set rolled properties (level, quality, value)
		loot_instance.item_level = item_level
		loot_instance.item_quality = item_quality
		loot_instance.value = item_value
		
		# Set stack size if stackable
		if item.stackable:
			loot_instance.stack_count = stack_size
	
	# Add to scene and position (spawn items around the chest)
	get_tree().current_scene.add_child(loot_instance)
	
	# Spawn items in a circle around the chest
	var angle = randf() * TAU  # Random angle
	var radius = randf_range(0.5, 1.0)  # Random distance from chest
	var offset = Vector3(cos(angle) * radius, 0.5, sin(angle) * radius)
	loot_instance.global_position = global_position + offset
	
	# Call set_item_properties after it's in the tree (so label exists)
	if loot_instance.has_method("set_item_properties"):
		loot_instance.set_item_properties(item_level, item_quality, item_value)

# Alternative method: Interact via Area3D detection
func _on_area_entered(area: Area3D):
	# If you add an Area3D as child and connect its body_entered signal
	if area.is_in_group("player"):
		open_chest()
