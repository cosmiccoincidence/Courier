extends StaticBody3D
class_name BaseFurniture

## Base class for all furniture pieces
## Handles common properties like spawn chance and visual obstruction

@export_group("Spawn Settings")
@export var spawn_chance: float = 1.0  ## Probability this furniture spawns (0.0 to 1.0)
@export var min_per_room: int = 0  ## Minimum spawns per room/area
@export var max_per_room: int = 1  ## Maximum spawns per room/area

@export_group("Visual Settings")
@export var is_visual_obstruction: bool = false  ## Does this block fog of war / vision cone?
@export var obstruction_radius: float = 1.0  ## How large is the obstruction area

@export_group("Interaction")
@export var interaction_range: float = 2.0  ## How close player needs to be to interact
@export var can_interact: bool = true  ## Can the player interact with this?

var player: CharacterBody3D = null

func _ready():
	# Find player reference
	player = get_tree().get_first_node_in_group("player")
	
	# Child classes should call super._ready() then add their own setup

func _physics_process(_delta):
	# Child classes override this for interaction checks
	pass

## Override this in child classes for interaction behavior
func interact():
	pass

## Check if player is in range and pressed interact key
func check_interaction() -> bool:
	if not player or not can_interact:
		return false
	
	var distance = global_position.distance_to(player.global_position)
	
	if distance <= interaction_range:
		if Input.is_action_just_pressed("interact"):
			return true
	
	return false
