extends Node3D

@export var float_distance := 4.0       # vertical rise in meters
@export var float_forward := 2.0        # movement toward camera (negative Z)
@export var duration := 1.0             # total time in seconds
@export var crit_color: Color = Color(1, 0.8, 0)
@export var normal_color: Color = Color(1, 0, 0)
@export var crit_scale: Vector3 = Vector3.ONE * 4
@export var normal_scale: Vector3 = Vector3.ONE * 3.5

var start_position := Vector3.ZERO
var elapsed := 0.0
var amount: int = 0
var is_crit: bool = false
var label_node: Label3D

func _ready():
	label_node = $Label
	label_node.billboard = 1 # Y-axis only, faces camera vertically

func setup(damage_amount: int, crit: bool):
	amount = damage_amount
	is_crit = crit
	
	# Set text
	label_node.text = str(amount)
	
	# Set color and scale
	if is_crit:
		label_node.modulate = crit_color
		label_node.scale = crit_scale
	else:
		label_node.modulate = normal_color
		label_node.scale = normal_scale
	
	# Capture starting position (relative to enemy)
	start_position = global_position

func _process(delta):
	elapsed += delta
	var t = elapsed / duration
	
	# Move up + slightly toward camera (for top-down)
	global_position = start_position + Vector3(0, float_distance * t, -float_forward * t)
	
	# Fade out
	label_node.modulate.a = 1.0 - t
	
	if elapsed >= duration:
		queue_free()
