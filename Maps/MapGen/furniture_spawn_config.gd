extends Resource
class_name FurnitureSpawnConfig

## Configuration for spawning specific furniture in different contexts

@export var furniture_scene: PackedScene
@export var furniture_type: String = "generic"  ## Type identifier (chest, door, table, etc.)

@export_group("Spawn Rules")
@export var spawn_chance: float = 0.5  ## Probability to spawn (0.0-1.0)
@export var min_per_area: int = 0  ## Minimum spawns per area/room
@export var max_per_area: int = 1  ## Maximum spawns per area/room
@export var min_distance_from_door: int = 2  ## Min tiles from doorways
@export var avoid_walls: bool = true  ## Don't spawn adjacent to walls

@export_group("Placement")
@export var requires_floor: bool = true  ## Must be on walkable floor
@export var requires_interior: bool = false  ## Must be inside buildings
@export var requires_exterior: bool = false  ## Must be outside buildings
@export var fixed_rotation: bool = false  ## Use specific rotation instead of random
@export var rotation_y: float = 0.0  ## Rotation if fixed_rotation is true

## Check if this furniture can spawn in the current context
func can_spawn_in_context(is_interior: bool, is_near_door: bool, dist_from_door: int) -> bool:
	if requires_interior and not is_interior:
		return false
	if requires_exterior and is_interior:
		return false
	if is_near_door and dist_from_door < min_distance_from_door:
		return false
	
	return randf() <= spawn_chance
