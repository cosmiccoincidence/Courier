# town_core_map.gd
# Base class for all town maps (safe zones between acts)
class_name TownCoreMap
extends ManualMap

# ============================================================================
# TOWN CONFIGURATION
# ============================================================================

# These will be set by child classes (Town1Map, Town2Map, etc.)
var act_number: int = 0  # Which act this town belongs to
var map_number: int = 0  # Town number within the game
var map_level: int = 0   # Calculated based on act and map number
var map_name: String = "Town"

func _ready():
	# Calculate map_level (same formula as generated maps)
	# This will be called by child classes after they set act_number and map_number
	if act_number > 0 and map_number > 0:
		map_level = (act_number + map_number) + (5 * (act_number - 1))
	
	print("Town Map - Level: ", map_level, " Name: ", map_name, " (Act ", act_number, ", Map ", map_number, ")")
	super._ready()
