extends Node3D

@onready var player_spawn: Node3D = $PlayerSpawn
@onready var player: CharacterBody3D = $Player
@onready var sun_moon_origin = $SunMoonOrigin

func _ready():
	# Register the sun/moon pivot with TimeManager
	TimeManager.set_sun_moon_origin(sun_moon_origin)
	
	if player_spawn and player:
		player.global_transform.origin = player_spawn.global_transform.origin

func on_exit_trigger_entered(next_scene_path: String) -> void:
	if next_scene_path != "":
		call_deferred("_deferred_change_scene", next_scene_path)

func _deferred_change_scene(next_scene_path: String) -> void:
	get_tree().change_scene_to_file(next_scene_path)
