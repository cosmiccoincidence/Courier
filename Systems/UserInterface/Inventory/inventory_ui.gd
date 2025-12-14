extends Control

@onready var grid_container: GridContainer = $InventoryPanel/InventoryGrid
@onready var equipment_grid: GridContainer = $EquipmentPanel/EquipmentGrid
@onready var weight_label: Label = $InventoryPanel/WeightLabel
@onready var gold_label: Label = $InventoryPanel/GoldLabel
@onready var slot_tooltip: Control = $SlotTooltip  # Tooltip manager
@onready var stats_panel: Panel = $EquipmentPanel/StatsPanel

# Hardcoded path since export wasn't working
const SLOT_SCENE_PATH = "res://Systems/UserInterface/Inventory/inventory_slot.tscn"

var slot_size: int = 64  # Size of each slot in pixels
var columns: int = 0  # Will be calculated from Inventory.max_slots
var rows: int = 5  # Fixed number of rows

# Player reference for stats
var player_ref: CharacterBody3D = null

# Equipment grid configuration (4 columns x 5 rows with gaps)
var equipment_columns: int = 4
var equipment_rows: int = 5
# Define which slots to skip (create gaps) - grid positions in 4-column layout:
# Row 1: [0] [1] [2] [3]
# Row 2: [4] [5] [6] [7]  
# Row 3: [8] [9] [10] [11]
# Row 4: [12] [13] [14] [15]
# Row 5: [16] [17] [18] [19]
# Skip: entire column 2 (indices 1, 5, 9, 13, 17) + row 3 slots 2-4 (indices 10, 11)
var equipment_skip_slots: Array = [
	1, 5, 9, 13, 17,  # Entire 2nd column
	10, 11            # Row 3 positions 3 and 4 (slot 2 at index 9 already skipped)
]

# Equipment slot names (in order of actual slots, not grid positions)
var equipment_slot_names: Array = [
	"Helmet",    # Slot 0
	"Amulet",    # Slot 1
	"Bag",       # Slot 2
	"Armor",     # Slot 3
	"Ring 1",    # Slot 4
	"Ring 2",    # Slot 5
	"Belt",      # Slot 6
	"Gloves",    # Slot 7
	"L Hand 1",  # Slot 8
	"R Hand 1",  # Slot 9
	"Boots",     # Slot 10
	"L Hand 2",  # Slot 11
	"R Hand 2"   # Slot 12
]

func _input(event):
	"""Handle inventory toggle and drops outside the inventory grid"""
	# Toggle inventory visibility
	if event.is_action_pressed("toggle_inventory"):
		visible = !visible
		
		# Optional: Control mouse mode
		if visible:
			Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		# Uncomment below if you want captured mouse during gameplay
		# else:
		# 	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	
	# Handle drops outside the inventory grid
	if event is InputEventMouseButton and not event.pressed:
		if event.button_index == MOUSE_BUTTON_LEFT:
			# Check if we're dragging an item by getting a reference from any slot
			var any_slot = null
			for child in grid_container.get_children():
				if child.has_method("set_item"):
					any_slot = child
					break
			
			if any_slot:
				# Access static variables through an instance
				var dragged_data = any_slot.get("dragged_item_data")
				var dragged_slot = any_slot.get("dragged_from_slot")
				
				if dragged_data != null and dragged_slot:
					# Mouse released - check if it's outside both grids
					var mouse_pos = get_global_mouse_position()
					var inventory_rect = grid_container.get_global_rect()
					var equipment_rect = equipment_grid.get_global_rect()
					
					# Check if mouse is outside BOTH grids
					var outside_inventory = not inventory_rect.has_point(mouse_pos)
					var outside_equipment = not equipment_rect.has_point(mouse_pos)
					
					if outside_inventory and outside_equipment:
						# Dropped outside both grids - drop in world
						var slot_idx = dragged_slot.get("dragged_from_slot_index")
						var is_equipment = dragged_slot.get_meta("is_equipment_slot", false)
						
						if is_equipment:
							# Drop from equipment - get item first, then spawn in world
							var item = Equipment.get_item_at_slot(slot_idx)
							if item:
								# Spawn in world using Inventory's drop logic
								# Get player position and spawn slightly above ground
								if Inventory.player_ref:
									var forward = -Inventory.player_ref.global_transform.basis.z
									var drop_position = Inventory.player_ref.global_position + forward * 1 + Vector3(0, 0.3, 0)
									
									# Actually spawn the item in the world if we have a scene reference
									if item.has("scene") and item.scene:
										var item_instance = item.scene.instantiate()
										
										if item_instance is Node3D:
											get_tree().current_scene.add_child(item_instance)
											item_instance.global_position = drop_position
											
											# Set stack count if item is stackable
											if item.get("stackable", false) and item.get("stack_count", 1) > 1:
												if item_instance.has_method("set"):
													item_instance.set("stack_count", item.stack_count)
												if item_instance.has_method("update_label_text"):
													item_instance.update_label_text()
											
											# Mark as just spawned
											if item_instance.has_method("set"):
												item_instance.set("just_spawned", true)
												item_instance.set("spawn_timer", 0.0)
							
							# Remove from equipment
							Equipment.remove_item_at_slot(slot_idx)
						else:
							# Drop from inventory
							Inventory.drop_item_at_slot(slot_idx)
						
						# Clean up drag state
						dragged_slot.modulate = Color(1, 1, 1, 1)
						any_slot.call("_end_drag")

func _get_slot_by_index(index: int) -> Panel:
	"""Get a slot by its index"""
	var slots = grid_container.get_children()
	if index >= 0 and index < slots.size():
		return slots[index]
	return null

func _ready():
	# Calculate columns based on Inventory.max_slots
	columns = Inventory.max_slots / rows
	
	# Create tooltip manager if it doesn't exist
	if not slot_tooltip:
		slot_tooltip = Control.new()
		slot_tooltip.name = "SlotTooltip"
		add_child(slot_tooltip)
		
		# Attach tooltip script
		var tooltip_script = load("res://Systems/UserInterface/Inventory/inventory_slot_tooltip.gd")
		if tooltip_script:
			slot_tooltip.set_script(tooltip_script)
		else:
			push_warning("Could not load inventory_slot_tooltip.gd - tooltips will not work")
	
	# Make the main InventoryPanel transparent (so only slots are visible)
	var panel = $InventoryPanel
	if panel:
		var transparent_style = StyleBoxFlat.new()
		transparent_style.bg_color = Color(0, 0, 0, 0)  # Fully transparent
		panel.add_theme_stylebox_override("panel", transparent_style)
		# Panel should pass mouse events to children
		panel.mouse_filter = Control.MOUSE_FILTER_PASS
	
	# Make the EquipmentPanel transparent too
	var equipment_panel = $EquipmentPanel
	if equipment_panel:
		var equip_transparent_style = StyleBoxFlat.new()
		equip_transparent_style.bg_color = Color(0, 0, 0, 0)  # Fully transparent
		equipment_panel.add_theme_stylebox_override("panel", equip_transparent_style)
		# Panel should pass mouse events to children
		equipment_panel.mouse_filter = Control.MOUSE_FILTER_PASS
	
	# Load slot scene directly
	var slot_scene = load(SLOT_SCENE_PATH)
	
	if not slot_scene:
		push_error("Could not load slot scene from: ", SLOT_SCENE_PATH)
		return
	
	# IMPORTANT: Allow slots to receive mouse events
	# Don't set mouse_filter to IGNORE on the main control!
	# mouse_filter = Control.MOUSE_FILTER_IGNORE  # REMOVED - this blocks all mouse events
	
	# Set up the grid
	grid_container.columns = columns
	# CRITICAL: GridContainer must pass mouse events to children
	grid_container.mouse_filter = Control.MOUSE_FILTER_PASS
	
	# Create all the slots based on calculated grid size
	for i in range(columns * rows):
		var slot = slot_scene.instantiate()
		if not slot:
			continue
		
		# Force it to STOP
		slot.set_mouse_filter(Control.MOUSE_FILTER_STOP)
		slot.mouse_filter = Control.MOUSE_FILTER_STOP
		
		slot.custom_minimum_size = Vector2(slot_size, slot_size)
		slot.slot_index = i
		slot.add_to_group("inventory_slots")
		grid_container.add_child(slot)
		
		# Set tooltip manager reference
		if slot.has_method("set_tooltip_manager") and slot_tooltip:
			slot.set_tooltip_manager(slot_tooltip)
	
	# Connect to inventory changes
	Inventory.inventory_changed.connect(_update_inventory)
	Inventory.weight_changed.connect(_update_weight_display)
	Inventory.gold_changed.connect(_update_gold_display)
	_update_inventory()
	_update_weight_display(Inventory.get_total_weight(), Inventory.soft_max_weight)
	_update_gold_display(Inventory.get_gold())
	
	# Set up equipment grid
	_setup_equipment_grid()
	
	# Connect to equipment changes (if Equipment singleton exists)
	if has_node("/root/Equipment"):
		Equipment.equipment_changed.connect(_update_equipment)
		_update_equipment()
	else:
		push_warning("Equipment singleton not found - add equipment.gd to AutoLoad as 'Equipment'")
	
	# Start hidden
	hide()
	
	# Get player reference for stats
	_setup_player_reference()

func _setup_player_reference():
	"""Get reference to player and setup stats display"""
	# Try to find player in the scene
	player_ref = get_tree().get_first_node_in_group("player")
	if not player_ref:
		push_warning("Player not found - stats panel will not update")
		return
	
	# Setup stats panel if it exists
	if stats_panel:
		_setup_stats_panel()
		_update_stats_display()

func _setup_stats_panel():
	"""Create labels in the stats panel"""
	if not stats_panel:
		return
	
	# Clear any existing children
	for child in stats_panel.get_children():
		child.queue_free()
	
	# Create VBoxContainer to stack labels vertically
	var vbox = VBoxContainer.new()
	vbox.name = "StatsVBox"
	stats_panel.add_child(vbox)
	
	# Create title label
	var title = Label.new()
	title.text = "Player Stats"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 16)
	title.add_theme_color_override("font_color", Color.GOLD)
	vbox.add_child(title)
	
	# Create max health label
	var health_label = Label.new()
	health_label.name = "MaxHealthLabel"
	health_label.text = "Max Health: 0"
	health_label.add_theme_font_size_override("font_size", 14)
	vbox.add_child(health_label)
	
	# Create max stamina label
	var stamina_label = Label.new()
	stamina_label.name = "MaxStaminaLabel"
	stamina_label.text = "Max Stamina: 0"
	stamina_label.add_theme_font_size_override("font_size", 14)
	vbox.add_child(stamina_label)

func _update_stats_display():
	"""Update the stats panel with current player stats"""
	if not stats_panel or not player_ref:
		return
	
	var vbox = stats_panel.get_node_or_null("StatsVBox")
	if not vbox:
		return
	
	# Update max health
	var health_label = vbox.get_node_or_null("MaxHealthLabel")
	if health_label:
		health_label.text = "Max Health: %d" % player_ref.max_health
	
	# Update max stamina (no decimal)
	var stamina_label = vbox.get_node_or_null("MaxStaminaLabel")
	if stamina_label:
		stamina_label.text = "Max Stamina: %d" % int(player_ref.max_stamina)

func _setup_equipment_grid():
	"""Set up the equipment grid with gaps"""
	if not equipment_grid:
		return
	
	# Load slot scene
	var slot_scene = load(SLOT_SCENE_PATH)
	if not slot_scene:
		push_error("Could not load slot scene for equipment grid")
		return
	
	# Set up the grid
	equipment_grid.columns = equipment_columns
	equipment_grid.mouse_filter = Control.MOUSE_FILTER_PASS
	
	var equipment_slot_index = 0  # Track actual slot indices (skipping gaps)
	
	# Create slots for equipment grid
	for i in range(equipment_columns * equipment_rows):
		# Check if this position should be a gap
		if i in equipment_skip_slots:
			# Create an empty Control as a placeholder for the gap
			var spacer = Control.new()
			spacer.custom_minimum_size = Vector2(slot_size, slot_size)
			spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
			equipment_grid.add_child(spacer)
		else:
			# Create actual equipment slot
			var slot = slot_scene.instantiate()
			if not slot:
				continue
			
			slot.set_mouse_filter(Control.MOUSE_FILTER_STOP)
			slot.mouse_filter = Control.MOUSE_FILTER_STOP
			slot.custom_minimum_size = Vector2(slot_size, slot_size)
			slot.slot_index = equipment_slot_index
			slot.set_meta("is_equipment_slot", true)
			slot.add_to_group("equipment_slots")
			equipment_grid.add_child(slot)
			
			# Add slot name label
			if equipment_slot_index < equipment_slot_names.size():
				var slot_name_label = Label.new()
				slot_name_label.name = "SlotNameLabel"
				slot_name_label.text = equipment_slot_names[equipment_slot_index]
				slot_name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
				slot_name_label.vertical_alignment = VERTICAL_ALIGNMENT_TOP
				slot_name_label.add_theme_font_size_override("font_size", 10)
				slot_name_label.add_theme_color_override("font_color", Color(1, 1, 1, 0.5))  # White, 50% transparent
				slot_name_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
				
				# Position at top of slot
				slot_name_label.anchor_left = 0
				slot_name_label.anchor_top = 0
				slot_name_label.anchor_right = 1
				slot_name_label.anchor_bottom = 0
				slot_name_label.offset_left = 2
				slot_name_label.offset_top = 2
				slot_name_label.offset_right = -2
				slot_name_label.offset_bottom = 14
				
				slot.add_child(slot_name_label)
			
			# Set tooltip manager reference
			if slot.has_method("set_tooltip_manager") and slot_tooltip:
				slot.set_tooltip_manager(slot_tooltip)
			
			equipment_slot_index += 1

func _update_inventory():
	var items = Inventory.get_items()
	var slots = grid_container.get_children()
	
	for i in range(min(items.size(), slots.size())):
		if items[i] != null:
			slots[i].set_item(items[i])
		else:
			slots[i].clear_item()

func _update_equipment():
	"""Update equipment slots to display equipped items"""
	var equipped_items = Equipment.get_items()
	
	# Get only the actual equipment slots (not spacers)
	var equipment_slots = []
	for child in equipment_grid.get_children():
		if child.has_method("set_item"):  # Only actual slots, not spacers
			equipment_slots.append(child)
	
	for i in range(min(equipped_items.size(), equipment_slots.size())):
		var slot = equipment_slots[i]
		if equipped_items[i] != null:
			slot.set_item(equipped_items[i])
		else:
			slot.clear_item()

func _update_weight_display(current_weight: float, max_weight: float):
	if weight_label:
		# Format: "Weight: 5.5 / 10.0"
		weight_label.text = "Weight: %.1f / %.1f" % [current_weight, max_weight]
		
		# Optional: Change color based on weight
		var weight_percent = current_weight / max_weight
		if weight_percent >= 1.0:
			weight_label.modulate = Color.DARK_RED  # Over soft limit
		elif weight_percent >= 0.9:
			weight_label.modulate = Color.RED  # High warning
		elif weight_percent >= 0.75:
			weight_label.modulate = Color.YELLOW  # Low warning
		else:
			weight_label.modulate = Color.WHITE  # Normal

func _update_gold_display(amount: int):
	if gold_label:
		gold_label.text = "Gold: %d" % amount
