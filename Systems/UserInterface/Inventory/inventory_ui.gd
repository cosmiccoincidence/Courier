extends Control

@onready var grid_container: GridContainer = $InventoryPanel/InventoryGrid
@onready var equipment_grid: GridContainer = $EquipmentPanel/EquipmentGrid
@onready var weight_label: Label = $InventoryPanel/WeightLabel
@onready var gold_label: Label = $InventoryPanel/GoldLabel
@onready var slot_tooltip: Control = $SlotTooltip  # Tooltip manager

# Hardcoded path since export wasn't working
const SLOT_SCENE_PATH = "res://Systems/UserInterface/Inventory/inventory_slot.tscn"

var slot_size: int = 64  # Size of each slot in pixels
var columns: int = 0  # Will be calculated from Inventory.max_slots
var rows: int = 5  # Fixed number of rows

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
					# Mouse released - check if it's outside the inventory
					var mouse_pos = get_global_mouse_position()
					var grid_rect = grid_container.get_global_rect()
					
					if not grid_rect.has_point(mouse_pos):
						# Check if dragged from inventory (not equipment)
						if not dragged_slot.get_meta("is_equipment_slot", false):
							# Dropped outside inventory - drop in world
							var slot_idx = dragged_slot.get("dragged_from_slot_index")
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
