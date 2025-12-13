extends Resource
class_name TileLibrary

@export var glb_path: String = "res://Assets/Tiles/Tiles.glb"

# prototypes will store node prototypes (not in the scene tree)
var tiles: Dictionary = {}

func load_tiles() -> void:
	# Load and instantiate the GLB scene temporarily
	var packed = load(glb_path)
	if not packed:
		push_error("TileLibrary: failed to load: %s" % glb_path)
		return

	var tmp_scene = packed.instantiate()
	# Make sure tmp_scene is not added to the active scene tree.
	# Extract children by name and store duplicated prototypes
	var names = ["RedTile","GreenTile","BlueTile","Wall","Fence","Post"]
	for name in names:
		var n = tmp_scene.get_node_or_null(name)
		if n:
			# store a prototype (a deep duplicate so it's independent)
			tiles[name.to_lower()] = n.duplicate(true)
		else:
			push_warning("TileLibrary: node '%s' not found in %s" % [name, glb_path])

	# Free the temporary instance to avoid keeping it in memory tree references
	tmp_scene.free()
