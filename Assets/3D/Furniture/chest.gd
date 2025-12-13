extends StaticBody3D
class_name Chest

@export var loot_table: LootTable
@export var interaction_range := 1.5
@export var open_sound: AudioStream

@onready var audio_player: AudioStreamPlayer3D = $AudioStreamPlayer3D
@onready var mesh_instance: MeshInstance3D = $MeshInstance3D
@onready var collision_shape: CollisionShape3D = $CollisionShape3D

var is_open := false
var player: CharacterBody3D = null
var can_interact := true

func _ready():
	# Create a basic chest mesh if none exists
	if not mesh_instance:
		mesh_instance = MeshInstance3D.new()
		add_child(mesh_instance)
		var box_mesh = BoxMesh.new()
		box_mesh.size = Vector3(1, 0.8, 0.7)
		mesh_instance.mesh = box_mesh
		mesh_instance.position.y = 0.4
	
	if not collision_shape:
		collision_shape = CollisionShape3D.new()
		add_child(collision_shape)
		var box_shape = BoxShape3D.new()
		box_shape.size = Vector3(1, 0.8, 0.7)
		collision_shape.shape = box_shape
		collision_shape.position.y = 0.4
	
	if not audio_player:
		audio_player = AudioStreamPlayer3D.new()
		add_child(audio_player)
	
	player = get_tree().get_first_node_in_group("player")

func _physics_process(_delta):
	if not player or not can_interact:
		return
	
	var distance = global_position.distance_to(player.global_position)
	
	if distance <= interaction_range and not is_open:
		# Check for interaction input (you may need to adjust this based on your input setup)
		if Input.is_action_just_pressed("interact"):  # Make sure you have an "interact" action defined
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
