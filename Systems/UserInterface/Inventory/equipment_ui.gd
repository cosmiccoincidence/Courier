# equipment_ui.gd
extends Panel

# ===== NODE REFERENCES =====
@onready var equipment_grid: GridContainer = $EquipmentGrid
var slot_tooltip: Control = null  # Will be set by InventoryUI

# ===== CONSTANTS =====
const SLOT_SCENE_PATH = "res://Systems/UserInterface/Inventory/inventory_slot.tscn"

# ===== GRID CONFIGURATION =====
var slot_size: int = 64
var equipment_columns: int = 4
var equipment_rows: int = 4

# Equipment slot names (in order, 16 total slots for 4x4 grid)
var equipment_slot_names: Array = [
	"Helmet",     # Slot 0 (Row 1, Col 1)
	"Bag",        # Slot 1 (Row 1, Col 2)
	"Amulet",     # Slot 2 (Row 1, Col 3)
	"Totem",      # Slot 3 (Row 1, Col 4)
	"Bodyarmor",  # Slot 4 (Row 2, Col 1)
	"Cape",       # Slot 5 (Row 2, Col 2)
	"Ring 1",     # Slot 6 (Row 2, Col 3)
	"Ring 2",     # Slot 7 (Row 2, Col 4)
	"Pants",      # Slot 8 (Row 3, Col 1)
	"Belt",       # Slot 9 (Row 3, Col 2)
	"L Hand 1",   # Slot 10 (Row 3, Col 3)
	"R Hand 1",   # Slot 11 (Row 3, Col 4)
	"Boots",      # Slot 12 (Row 4, Col 1)
	"Gloves",     # Slot 13 (Row 4, Col 2)
	"L Hand 2",   # Slot 14 (Row 4, Col 3)
	"R Hand 2"    # Slot 15 (Row 4, Col 4)
]

# ===== STATE =====
var player_ref: CharacterBody3D = null

# ===== INITIALIZATION =====

func _ready():
	# Make panel transparent
	_setup_transparent_panel()
	
	# Wait for Equipment singleton to be ready
	if not has_node("/root/Equipment"):
		push_warning("Equipment singleton not found - add equipment.gd to AutoLoad as 'Equipment'")
		return
	
	# Load slot scene
	var slot_scene = load(SLOT_SCENE_PATH)
	if not slot_scene:
		push_error("Could not load slot scene from: ", SLOT_SCENE_PATH)
		return
	
	# Setup equipment grid
	_setup_equipment_grid(slot_scene)
	
	# Connect signals
	Equipment.equipment_changed.connect(_update_equipment)
	Equipment.weapon_set_changed.connect(_on_weapon_set_changed)
	
	# Get player reference
	player_ref = get_tree().get_first_node_in_group("player")
	
	# Initial update
	_update_equipment()
	_update_inactive_weapon_slots()

func _input(event):
	"""Handle weapon set swapping with X key"""
	if event.is_action_pressed("swap_weapon_sets"):  # You'll need to add this input action
		Equipment.swap_weapon_sets()

func _on_weapon_set_changed(new_set: int):
	"""Called when weapon set changes"""
	_update_inactive_weapon_slots()
	print("Swapped to weapon set %d" % (new_set + 1))

# ===== SETUP FUNCTIONS =====

func set_tooltip_manager(tooltip: Control):
	"""Called by InventoryUI to pass tooltip reference"""
	slot_tooltip = tooltip
	
	# Update all existing slots
	for child in equipment_grid.get_children():
		if child.has_method("set_tooltip_manager"):
			child.set_tooltip_manager(slot_tooltip)

func _setup_transparent_panel():
	"""Make equipment panel transparent"""
	var transparent_style = StyleBoxFlat.new()
	transparent_style.bg_color = Color(0, 0, 0, 0)
	add_theme_stylebox_override("panel", transparent_style)
	mouse_filter = Control.MOUSE_FILTER_PASS

func _setup_equipment_grid(slot_scene: PackedScene):
	"""Create simple 4x4 equipment grid"""
	if not equipment_grid:
		return
	
	equipment_grid.columns = equipment_columns
	equipment_grid.mouse_filter = Control.MOUSE_FILTER_PASS
	
	# Create all 16 slots (4x4 grid)
	for i in range(equipment_columns * equipment_rows):
		var slot = slot_scene.instantiate()
		if not slot:
			continue
		
		slot.set_mouse_filter(Control.MOUSE_FILTER_STOP)
		slot.mouse_filter = Control.MOUSE_FILTER_STOP
		slot.custom_minimum_size = Vector2(slot_size, slot_size)
		slot.slot_index = i
		slot.set_meta("is_equipment_slot", true)
		slot.add_to_group("equipment_slots")
		equipment_grid.add_child(slot)
		
		# Add slot name label
		if i < equipment_slot_names.size():
			_add_slot_name_label(slot, equipment_slot_names[i])
		
		if slot.has_method("set_tooltip_manager") and slot_tooltip:
			slot.set_tooltip_manager(slot_tooltip)

func _add_slot_name_label(slot: Control, slot_name: String):
	"""Add name label to equipment slot"""
	var slot_name_label = Label.new()
	slot_name_label.name = "SlotNameLabel"
	slot_name_label.text = slot_name
	slot_name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	slot_name_label.vertical_alignment = VERTICAL_ALIGNMENT_TOP
	slot_name_label.add_theme_font_size_override("font_size", 10)
	slot_name_label.add_theme_color_override("font_color", Color(1, 1, 1, 0.5))
	slot_name_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	
	slot_name_label.anchor_left = 0
	slot_name_label.anchor_top = 0
	slot_name_label.anchor_right = 1
	slot_name_label.anchor_bottom = 0
	slot_name_label.offset_left = 2
	slot_name_label.offset_top = 2
	slot_name_label.offset_right = -2
	slot_name_label.offset_bottom = 14
	
	slot.add_child(slot_name_label)

# ===== UPDATE FUNCTIONS =====

func _update_equipment():
	"""Update equipment slots to display equipped items"""
	var equipped_items = Equipment.get_items()
	var equipment_slots = equipment_grid.get_children()
	
	# All children are now equipment slots (no spacers)
	for i in range(min(equipped_items.size(), equipment_slots.size())):
		var slot = equipment_slots[i]
		var item = equipped_items[i]
		
		if item != null:
			# Check if this is a two-handed weapon placeholder
			if typeof(item) == TYPE_DICTIONARY and item.has("_twohand_occupant"):
				slot.show_twohand_placeholder(item.primary_slot)
			else:
				slot.set_item(item)
		else:
			slot.clear_item()

func _update_inactive_weapon_slots():
	"""Dim the inactive weapon set slots"""
	var equipment_slots = equipment_grid.get_children()
	var weapon_slot_indices = [10, 11, 14, 15]  # All weapon slots
	
	for slot_idx in weapon_slot_indices:
		if slot_idx < equipment_slots.size():
			var slot = equipment_slots[slot_idx]
			var is_active = Equipment.is_weapon_slot_active(slot_idx)
			
			# Dim inactive slots
			if is_active:
				slot.modulate = Color(1, 1, 1, 1)  # Full brightness
			else:
				slot.modulate = Color(0.5, 0.5, 0.5, 0.6)  # Dimmed

func highlight_valid_slots(item_data):
	"""Highlight equipment slots that can accept this item"""
	if not item_data:
		return
	
	var equipment_slots = equipment_grid.get_children()
	
	for i in range(equipment_slots.size()):
		var slot = equipment_slots[i]
		if Equipment.can_equip_item_in_slot(item_data, i):
			# This slot can accept the item - highlight it
			if slot.has_method("highlight"):
				slot.highlight(true)
		else:
			# This slot cannot accept the item - dim it
			if slot.has_method("highlight"):
				slot.highlight(false)

func clear_slot_highlights():
	"""Clear all slot highlights"""
	var equipment_slots = equipment_grid.get_children()
	
	for slot in equipment_slots:
		if slot.has_method("clear_highlight"):
			slot.clear_highlight()

# ===== DROP HANDLING =====

func handle_outside_drop(mouse_pos: Vector2, dragged_slot: Control):
	"""Drop item from equipment to world when dropped outside grid"""
	_drop_item_in_world(dragged_slot)

func _drop_item_in_world(dragged_slot: Control):
	"""Drop item from equipment into the game world"""
	var slot_idx = dragged_slot.get("dragged_from_slot_index")
	
	if slot_idx == null:
		return
	
	var item = Equipment.get_item_at_slot(slot_idx)
	if item and player_ref:
		_spawn_item_in_world(item)
	
	Equipment.remove_item_at_slot(slot_idx)

func _spawn_item_in_world(item: Dictionary):
	"""Spawn an item in the world"""
	if not item.has("scene") or not item.scene or not player_ref:
		return
	
	print("[Equipment Drop Debug] Item data keys: ", item.keys())
	if item.has("icon"):
		print("[Equipment Drop Debug] Icon type: ", typeof(item.icon))
		print("[Equipment Drop Debug] Icon value: ", item.icon)
	if item.has("weapon_damage"):
		print("[Equipment Drop Debug] Item weapon_damage in dict: ", item.weapon_damage)
	if item.has("item_quality"):
		print("[Equipment Drop Debug] Item quality in dict: ", item.item_quality)
	
	var forward = -player_ref.global_transform.basis.z
	var drop_position = player_ref.global_position + forward * 1 + Vector3(0, 0.35, 0)
	
	var item_instance = item.scene.instantiate()
	if not item_instance is Node3D:
		return
	
	get_tree().current_scene.add_child(item_instance)
	item_instance.global_position = drop_position
	
	# Restore ALL item properties from equipment data
	if item_instance is BaseItem:
		print("[Equipment Drop Debug] Item instance is BaseItem")
		
		# First update properties (this may set defaults)
		if item_instance.has_method("set_item_properties"):
			print("[Equipment Drop Debug] Calling set_item_properties")
			item_instance.set_item_properties(
				item.get("item_level", 1),
				item.get("item_quality", ItemQuality.Quality.NORMAL),
				item.get("value", 10)
			)
		
		# NOW restore all the specific stats (these will override defaults)
		# Restore basic properties
		if item.has("name"):
			item_instance.item_name = item.name  # Dictionary uses "name", BaseItem uses "item_name"
		if item.has("icon"):
			item_instance.item_icon = item.icon  # Dictionary uses "icon", BaseItem uses "item_icon"
		if item.has("item_level"):
			item_instance.item_level = item.item_level
		if item.has("item_quality"):
			item_instance.item_quality = item.item_quality
		if item.has("value"):
			item_instance.value = item.value
		if item.has("item_subtype"):
			item_instance.item_subtype = item.item_subtype
		if item.has("durability"):
			item_instance.durability = item.durability
		if item.has("mass"):
			item_instance.mass = item.mass
		
		# Restore weapon stats
		if item.has("weapon_damage"):
			item_instance.weapon_damage = item.weapon_damage
			print("[Equipment Drop Debug] Set weapon_damage to: ", item_instance.weapon_damage)
		if item.has("weapon_class"):
			item_instance.weapon_class = item.weapon_class
		if item.has("weapon_hand"):
			item_instance.weapon_hand = item.weapon_hand
		if item.has("weapon_range"):
			item_instance.weapon_range = item.weapon_range
		if item.has("weapon_speed"):
			item_instance.weapon_speed = item.weapon_speed
		if item.has("weapon_block_rating"):
			item_instance.weapon_block_rating = item.weapon_block_rating
		if item.has("weapon_parry_window"):
			item_instance.weapon_parry_window = item.weapon_parry_window
		if item.has("weapon_crit_chance"):
			item_instance.weapon_crit_chance = item.weapon_crit_chance
		if item.has("weapon_crit_multiplier"):
			item_instance.weapon_crit_multiplier = item.weapon_crit_multiplier
		
		# Restore armor stats
		if item.has("base_armor_rating"):
			item_instance.base_armor_rating = item.base_armor_rating
		if item.has("armor_class"):
			item_instance.armor_class = item.armor_class
		
		# Restore stat requirements
		if item.has("required_strength"):
			item_instance.required_strength = item.required_strength
		if item.has("required_dexterity"):
			item_instance.required_dexterity = item.required_dexterity
		
		# Set stack count if item is stackable
		if item.get("stackable", false) and item.get("stack_count", 1) > 1:
			item_instance.stack_count = item.stack_count
		
		# Finally update label text
		if item_instance.has_method("update_label_text"):
			print("[Equipment Drop Debug] Calling update_label_text")
			item_instance.update_label_text()
		
		print("[Equipment Drop Debug] Final weapon_damage: ", item_instance.weapon_damage)
		print("[Equipment Drop Debug] Final item_quality: ", item_instance.item_quality)
	
	# Mark as just spawned so FOV doesn't hide it immediately
	if item_instance.has_method("set"):
		item_instance.set("just_spawned", true)
		item_instance.set("spawn_timer", 0.0)

# ===== UTILITY =====

func get_equipment_rect() -> Rect2:
	"""Get the global rect of the equipment grid"""
	return equipment_grid.get_global_rect()
