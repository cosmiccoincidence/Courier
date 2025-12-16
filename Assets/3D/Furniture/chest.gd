extends BaseFurniture
class_name Chest

@export var loot_table: LootTable
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
	
	# Spawn loot
	if loot_table:
		LootSpawner.spawn_loot_from_table(loot_table, global_position, get_tree().current_scene)
	
	print("Chest opened!")

# Alternative method: Interact via Area3D detection
func _on_area_entered(area: Area3D):
	# If you add an Area3D as child and connect its body_entered signal
	if area.is_in_group("player"):
		open_chest()
