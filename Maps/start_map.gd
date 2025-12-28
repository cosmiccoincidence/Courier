# start_map.gd
# Starting map - tutorial/intro area
class_name StartMap
extends ManualMap

# ============================================================================
# MAP CONFIGURATION
# ============================================================================

var map_level: int = 1  # Starting map is level 1
var map_name: String = "Starting Area"

func _ready():
	print("Starting Map - Level: ", map_level, " Name: ", map_name)
	super._ready()
