# act1_mapgen.gd
class_name Act1MapGen
extends CoreMapGen

# ============================================================================
# ACT CONFIGURATION
# ============================================================================

@export var act_number: int = 1  # Act 1

# ============================================================================
# FEATURE GENERATORS
# ============================================================================

var roads_generator: RoadsMapGen
var buildings_generator: BuildingsMapGen

# ============================================================================
# ACT 1 FEATURE SETTINGS
# ============================================================================

@export var is_passive_map: bool = false

# Road settings for Act 1
@export_group("Road Generation")
@export var road_width: int = 2
@export var road_min_distance_from_exterior: int = 2
@export var road_zone_proximity: int = 5

# Building settings for Act 1
@export_group("Building Generation")
@export var min_buildings: int = 1
@export var max_buildings: int = 3
@export var min_building_width: int = 9
@export var max_building_width: int = 15
@export var min_building_length: int = 9
@export var max_building_length: int = 15

@export var min_rooms_per_building: int = 1
@export var max_rooms_per_building: int = 3
@export var extra_room_chance: float = 0.5
@export var min_additional_room_width: int = 5
@export var max_additional_room_width: int = 9
@export var min_additional_room_length: int = 5
@export var max_additional_room_length: int = 9

@export var building_exterior_wall_buffer: int = 3
@export var building_road_buffer: int = 15
@export var building_to_building_buffer: int = 20
@export var building_zone_buffer: int = 25

# Enemy spawn settings for Act 1
@export_group("Enemy Spawning")
@export var enemy_spawn_list: Array[EnemySpawnData] = []
@export var enemy_spawn_chance: float = 0.01

# ============================================================================
# INITIALIZATION
# ============================================================================

func _ready():
	super._ready()
	
	# Initialize feature generators
	initialize_features()

func initialize_features():
	# Create roads generator
	roads_generator = RoadsMapGen.new()
	roads_generator.setup(self)
	roads_generator.road_width = road_width
	roads_generator.road_min_distance_from_exterior = road_min_distance_from_exterior
	roads_generator.road_zone_proximity = road_zone_proximity
	
	# Create buildings generator
	buildings_generator = BuildingsMapGen.new()
	buildings_generator.setup(self)
	buildings_generator.min_buildings = min_buildings
	buildings_generator.max_buildings = max_buildings
	buildings_generator.min_building_width = min_building_width
	buildings_generator.max_building_width = max_building_width
	buildings_generator.min_building_length = min_building_length
	buildings_generator.max_building_length = max_building_length
	buildings_generator.min_rooms_per_building = min_rooms_per_building
	buildings_generator.max_rooms_per_building = max_rooms_per_building
	buildings_generator.extra_room_chance = extra_room_chance
	buildings_generator.min_additional_room_width = min_additional_room_width
	buildings_generator.max_additional_room_width = max_additional_room_width
	buildings_generator.min_additional_room_length = min_additional_room_length
	buildings_generator.max_additional_room_length = max_additional_room_length
	buildings_generator.building_exterior_wall_buffer = building_exterior_wall_buffer
	buildings_generator.building_road_buffer = building_road_buffer
	buildings_generator.building_to_building_buffer = building_to_building_buffer
	buildings_generator.building_zone_buffer = building_zone_buffer

# ============================================================================
# ACT GENERATION (roads, enemies - core act elements)
# ============================================================================

func generate_act():
	"""Generate act-level elements: roads and enemies"""
	# Re-sync any inspector-set values before generating
	# (In case they were set in Act1aMapGen or in the Inspector)
	sync_act_settings()
	
	# Generate roads first (features need to know where roads are)
	print("\n--- PHASE 6: Road Generation ---")
	roads_generator.generate()
	
	# Generate features (buildings, etc.)
	print("\n--- PHASE 7: Feature Generation ---")
	generate_features()
	
	# Spawn enemies AFTER all features are placed
	print("\n--- PHASE 8: Enemy Spawning ---")
	spawn_enemies()

func sync_act_settings():
	"""Re-apply settings to act generators (in case they were changed in Inspector or subclass)"""
	# Roads
	roads_generator.road_width = road_width
	roads_generator.road_min_distance_from_exterior = road_min_distance_from_exterior
	roads_generator.road_zone_proximity = road_zone_proximity

# ============================================================================
# FEATURE GENERATION (buildings and other map features)
# ============================================================================

func generate_features():
	"""Generate map features: buildings, etc."""
	# Sync feature-specific settings
	sync_feature_settings()
	
	# Generate buildings
	buildings_generator.generate()

func sync_feature_settings():
	"""Re-apply settings to feature generators (in case they were changed in Inspector or subclass)"""
	# Buildings
	buildings_generator.min_buildings = min_buildings
	buildings_generator.max_buildings = max_buildings
	buildings_generator.min_building_width = min_building_width
	buildings_generator.max_building_width = max_building_width
	buildings_generator.min_building_length = min_building_length
	buildings_generator.max_building_length = max_building_length
	buildings_generator.min_rooms_per_building = min_rooms_per_building
	buildings_generator.max_rooms_per_building = max_rooms_per_building
	buildings_generator.extra_room_chance = extra_room_chance
	buildings_generator.min_additional_room_width = min_additional_room_width
	buildings_generator.max_additional_room_width = max_additional_room_width
	buildings_generator.min_additional_room_length = min_additional_room_length
	buildings_generator.max_additional_room_length = max_additional_room_length
	buildings_generator.building_exterior_wall_buffer = building_exterior_wall_buffer
	buildings_generator.building_road_buffer = building_road_buffer
	buildings_generator.building_to_building_buffer = building_to_building_buffer
	buildings_generator.building_zone_buffer = building_zone_buffer

# ============================================================================
# ENEMY SPAWNING
# ============================================================================

func spawn_enemies():
	print("Spawning enemies...")
	print("Enemy spawn list size: ", enemy_spawn_list.size())
	
	if enemy_spawn_list.size() == 0:
		print("Warning: No enemy spawn data assigned")
		return
	
	var used_cells = get_used_cells()
	var enemies_spawned = 0
	var enemy_positions = []
	
	for cell in used_cells:
		if get_cell_item(cell) != grass_tile_id:
			continue
		
		if entrance_zone_tiles.has(cell) or exit_zone_tiles.has(cell):
			continue
		
		# Don't spawn on roads
		if roads_generator.road_tiles.has(cell):
			continue
		
		# Don't spawn in buildings
		var in_building = false
		for building in buildings_generator.placed_buildings:
			for room in building.rooms:
				if cell.x >= room.start.x and cell.x < room.start.x + room.width:
					if cell.z >= room.start.z and cell.z < room.start.z + room.length:
						in_building = true
						break
				if in_building:
					break
			if in_building:
				break
		
		if in_building:
			continue
		
		# Check distance from entrance
		var min_entrance_dist = 999999
		for entrance_tile in entrance_zone_tiles:
			var dist = abs(cell.x - entrance_tile.x) + abs(cell.z - entrance_tile.z)
			min_entrance_dist = min(min_entrance_dist, dist)
		
		if min_entrance_dist < 20:
			continue
		
		# Check distance from exit
		var min_exit_dist = 999999
		for exit_tile in exit_zone_tiles:
			var dist = abs(cell.x - exit_tile.x) + abs(cell.z - exit_tile.z)
			min_exit_dist = min(min_exit_dist, dist)
		
		if min_exit_dist < 10:
			continue
		
		# Check distance from other enemies
		var min_enemy_dist = 999999
		for enemy_pos in enemy_positions:
			var dist = abs(cell.x - enemy_pos.x) + abs(cell.z - enemy_pos.z)
			min_enemy_dist = min(min_enemy_dist, dist)
		
		if enemy_positions.size() > 0 and min_enemy_dist < 20:
			continue
		
		if randf() < enemy_spawn_chance:
			var world_pos = map_to_local(cell)
			world_pos.y = 0.5
			
			call_deferred("_spawn_enemy_deferred", world_pos)
			enemy_positions.append(cell)
			enemies_spawned += 1
	
	print("Spawned ", enemies_spawned, " enemies")

func _spawn_enemy_deferred(world_pos: Vector3):
	if enemy_spawn_list.size() == 0:
		return
	
	var total_weight = 0.0
	for enemy_data in enemy_spawn_list:
		if enemy_data and enemy_data.enemy_scene:
			total_weight += enemy_data.spawn_weight
	
	if total_weight <= 0:
		return
	
	var random_value = randf() * total_weight
	var current_weight = 0.0
	
	for enemy_data in enemy_spawn_list:
		if enemy_data and enemy_data.enemy_scene:
			current_weight += enemy_data.spawn_weight
			if random_value <= current_weight:
				var enemy_instance = enemy_data.enemy_scene.instantiate()
				get_parent().add_child(enemy_instance)
				enemy_instance.global_position = world_pos
				return
