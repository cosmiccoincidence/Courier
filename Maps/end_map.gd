# end_map.gd
# Ending map - final area
class_name EndMap
extends ManualMap

# ============================================================================
# MAP CONFIGURATION
# ============================================================================

var map_level: int = 50  # Ending map is level 50
var map_name: String = "The End"

func _ready():
	print("Ending Map - Level: ", map_level, " Name: ", map_name)
	super._ready()
