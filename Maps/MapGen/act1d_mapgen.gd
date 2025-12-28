# act1d_mapgen.gd
# Level 1D configuration - individual level settings
class_name Act1dMapGen
extends Act1MapGen

# ============================================================================
# MAP CONFIGURATION
# ============================================================================

@export var map_number: int = 4  # First map in Act 4
var map_level: int  # Calculated below

func _ready():
	# Calculate map_level before calling super._ready()
	map_level = (act_number + map_number) + (5 * (act_number - 1))
	print("Map Level: ", map_level, " (Act ", act_number, ", Map ", map_number, ")")
	
	# ========================================
	# CORE SETTINGS (from CoreMapGen)
	# ========================================
	
	# Level 1a - square map
	min_chunks_width = 10
	max_chunks_width = 10
	min_chunks_depth = 10
	max_chunks_depth = 10
	
	protrusion_chance = 0.4
	indentation_chance = 0.4
	max_protrusion_depth = 3
	max_indentation_depth = 3
	
	# Organic smoothing settings
	enable_organic_smoothing = true
	smoothing_iterations = 6
	corner_smoothing_chance = 0.8
	edge_variation_amount = 0.05
	
	# ========================================
	# ACT 1 FEATURE SETTINGS (from Act1MapGen)
	# ========================================
	
	# Road settings
	road_width = 2
	road_min_distance_from_exterior = 2
	road_zone_proximity = 30
	
	# Building settings
	min_buildings = 1
	max_buildings = 3
	min_building_width = 9
	max_building_width = 15
	min_building_length = 9
	max_building_length = 15
	
	min_rooms_per_building = 2
	max_rooms_per_building = 3
	extra_room_chance = 0.5
	min_additional_room_width = 5
	max_additional_room_width = 9
	min_additional_room_length = 5
	max_additional_room_length = 9
	
	building_exterior_wall_buffer = 3
	building_road_buffer = 15
	building_to_building_buffer = 20
	building_zone_buffer = 25
	
	# Enemy settings
	enemy_spawn_chance = 0.005
	
	super._ready()
