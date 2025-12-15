extends GridMap
class_name ManualMap

# Tile IDs from MeshLibrary
@export var entrance_tile_id: int = 0
@export var exit_tile_id: int = 1
@export var grass_tile_id: int = 6
@export var stone_road_tile_id: int = 2
@export var dirt_road_tile_id: int = 3
@export var interior_wall_tile_id: int = 8
@export var exterior_wall_tile_id: int = 9
@export var interior_floor_tile_id: int = 5
@export var door_tile_id: int = 12
@export var door_floor_tile_id: int = 4

@export var is_passive_map: bool = false  # Disable fog/vision for towns

var exit_triggered: bool = false  # Add this at the top with other variables

signal generation_complete
signal player_reached_exit

func _ready():
	# Set up exit detection
	setup_exit_detection()

# This gets called by GameManager
func start_generation():
	# Wait one frame then emit (map is already ready)
	await get_tree().process_frame
	generation_complete.emit()

func setup_exit_detection():
	var used_cells = get_used_cells()
	
	var exit_count = 0
	for cell in used_cells:
		if get_cell_item(cell) == exit_tile_id:
			exit_count += 1
			var exit_area = Area3D.new()
			exit_area.name = "ExitDetector_" + str(cell)
			exit_area.monitoring = true  # Make sure it's enabled
			
			var collision_shape = CollisionShape3D.new()
			var box_shape = BoxShape3D.new()
			box_shape.size = Vector3(1, 2, 1)
			collision_shape.shape = box_shape
			
			exit_area.add_child(collision_shape)
			add_child(exit_area)
			
			var world_pos = map_to_local(cell)
			world_pos.y = 1
			exit_area.global_position = world_pos
			
			exit_area.body_entered.connect(_on_exit_area_entered)

func _on_exit_area_entered(body: Node3D):
	if exit_triggered:
		return  # Already triggered, ignore
		
	if body.is_in_group("player"):
		print("Player reached exit! Emitting signal...")
		exit_triggered = true  # Set flag
		player_reached_exit.emit()

func get_entrance_zone_spawn_position() -> Vector3:
	var used_cells = get_used_cells()
	var entrance_tiles = []
	
	for cell in used_cells:
		var tile_id = get_cell_item(cell)
		if tile_id == entrance_tile_id:
			entrance_tiles.append(cell)
	
	if entrance_tiles.size() == 0:
		return Vector3.ZERO
	
	var spawn_tile = entrance_tiles[randi() % entrance_tiles.size()]
	var world_pos = map_to_local(spawn_tile)
	world_pos.y = 0.1 # player spawn height
	
	print("Spawning at: ", world_pos)
	return world_pos
