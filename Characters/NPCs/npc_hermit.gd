extends CharacterBody3D

@onready var audio_vocal: AudioStreamPlayer3D = $AudioVocal

@export var display_name: String = "NPC"
@export var rotation_speed := 30.0
@export var rotation_change_interval := 2.0

var vocal_sounds = {
}

var gravity = ProjectSettings.get_setting("physics/3d/default_gravity")

var target_yaw := 0.0
var time_since_last_change := 0.0

func _ready():
	randomize()
	target_yaw = randf_range(0, 360)

func _physics_process(delta):
	
	# Apply gravity
	if not is_on_floor():
		velocity.y -= gravity * delta

	move_and_slide()

func idle_behavior(delta: float, distance: float):
	# Random rotation
	time_since_last_change += delta
	if time_since_last_change >= rotation_change_interval:
		time_since_last_change = 0
		target_yaw = fposmod(rotation_degrees.y + randf_range(-90, 90), 360.0)
	
	smooth_rotate_to_yaw(delta)
	
func smooth_rotate_to_yaw(delta: float):
	var current_yaw = rotation_degrees.y
	var difference = fposmod((target_yaw - current_yaw + 180.0), 360.0) - 180.0
	var step = rotation_speed * delta
	
	if abs(difference) < step:
		rotation_degrees.y = target_yaw
	else:
		rotation_degrees.y += step * sign(difference)

func play_vocal(name: String):
	if vocal_sounds.has(name):
		audio_vocal.stream = vocal_sounds[name]
		audio_vocal.play()
