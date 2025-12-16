extends BaseFurniture
class_name Door

var collision_shape: CollisionShape3D = null
var is_open := false

func _ready():
	# Call parent _ready first
	super._ready()
	
	# Add to "door" group so vision cone and fog can find us
	add_to_group("door")
	
	# Door-specific settings (override defaults)
	is_visual_obstruction = false  # Doors don't block vision when open
	obstruction_radius = 0.5
	interaction_range = 2.0
	
	# Try to get existing collision shape
	collision_shape = get_node_or_null("CollisionShape3D")
	
	# Create a basic collision shape if none exists
	if not collision_shape:
		collision_shape = CollisionShape3D.new()
		collision_shape.name = "CollisionShape3D"
		add_child(collision_shape)
		var box_shape = BoxShape3D.new()
		box_shape.size = Vector3(1, 2, 0.1)  # Door-sized collision
		collision_shape.shape = box_shape

func _physics_process(_delta):
	if check_interaction():
		toggle_door()

func toggle_door():
	if not can_interact:
		return
	
	is_open = !is_open
	
	# Toggle collision
	if collision_shape:
		collision_shape.disabled = is_open
	
	if is_open:
		print("Door opened (collision disabled)")
	else:
		print("Door closed (collision enabled)")
