extends Panel
# Inventory Slot

var slot_index: int = -1
var item_data = null
var tooltip_manager: Control = null  # Reference to tooltip manager

# Drag and drop state (shared across all slots)
static var dragged_item_data = null  # Item being dragged
static var dragged_from_slot_index: int = -1  # Which slot index it came from
static var dragged_from_slot: Panel = null  # Reference to the actual slot
static var drag_preview: Control = null  # Visual preview following mouse

@onready var icon: TextureRect = $TextureRect
@onready var label: Label = $Label

func _ready():
	# Force mouse filters
	mouse_filter = Control.MOUSE_FILTER_STOP
	
	if icon:
		icon.set_mouse_filter(MOUSE_FILTER_IGNORE)
		icon.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon.custom_minimum_size = Vector2(48, 48)
		# Center the icon in the slot
		icon.anchor_left = 0.5
		icon.anchor_top = 0.5
		icon.anchor_right = 0.5
		icon.anchor_bottom = 0.5
		icon.offset_left = -24
		icon.offset_top = -24
		icon.offset_right = 24
		icon.offset_bottom = 24
		
	if label:
		label.set_mouse_filter(MOUSE_FILTER_IGNORE)
		# Configure label at bottom of slot
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		label.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
		label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		# Position at bottom
		label.anchor_left = 0
		label.anchor_top = 1
		label.anchor_right = 1
		label.anchor_bottom = 1
		label.offset_left = 2
		label.offset_top = -16
		label.offset_right = -2
		label.offset_bottom = -2
		# Smaller font
		label.add_theme_font_size_override("font_size", 12)
	
	# Style
	custom_minimum_size = Vector2(64, 64)
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.2, 0.2, 0.2, 0.8)
	style.border_color = Color(0.5, 0.5, 0.5, 1.0)
	style.set_border_width_all(2)
	add_theme_stylebox_override("panel", style)

func _process(_delta):
	# Enforce mouse filter every frame (something keeps resetting it)
	if mouse_filter != Control.MOUSE_FILTER_STOP:
		mouse_filter = Control.MOUSE_FILTER_STOP
	
	# Update drag preview position if dragging
	if drag_preview and is_instance_valid(drag_preview):
		drag_preview.global_position = get_viewport().get_mouse_position() - drag_preview.size / 2
	
	# WORKAROUND: Since mouse_entered/exited signals aren't working,
	# manually check if mouse is over this slot
	if visible and is_visible_in_tree():
		var mouse_pos = get_local_mouse_position()
		var rect = Rect2(Vector2.ZERO, size)
		var mouse_over = rect.has_point(mouse_pos)
		
		# Only call tooltip functions when hover state CHANGES
		# BUT disable tooltips while dragging an item
		if mouse_over and item_data and tooltip_manager and dragged_item_data == null:
			# Mouse is over slot with item - show tooltip only if not already showing and not dragging
			if not get_meta("tooltip_showing", false):
				if tooltip_manager.has_method("show_tooltip"):
					tooltip_manager.show_tooltip(self, item_data)
					set_meta("tooltip_showing", true)
		else:
			# Mouse not over or no item or dragging - hide tooltip only if currently showing
			if get_meta("tooltip_showing", false):
				if tooltip_manager and tooltip_manager.has_method("hide_tooltip"):
					tooltip_manager.hide_tooltip()
				set_meta("tooltip_showing", false)

func set_tooltip_manager(manager: Control):
	"""Set reference to the tooltip manager"""
	tooltip_manager = manager

func set_item(item):
	item_data = item
	if item and item.has("icon") and item.icon:
		icon.texture = item.icon
		icon.show()
	else:
		icon.hide()
	
	if item and item.has("name"):
		# Show stack count if stackable
		if item.get("stackable", false) and item.get("stack_count", 1) > 1:
			label.text = "%s (x%d)" % [item.name, item.stack_count]
		else:
			label.text = item.name
		
		# NEW: Set label color based on item quality
		if item.has("item_quality"):
			label.modulate = ItemQuality.get_quality_color(item.item_quality)
		else:
			label.modulate = Color.WHITE  # Default to white if no quality
		
		label.show()
	else:
		label.hide()

func clear_item():
	item_data = null
	icon.hide()
	label.hide()

func _input(event):
	if not visible or not is_visible_in_tree():
		return
	
	# Check if mouse is over this slot
	var local_pos = get_local_mouse_position()
	var rect = Rect2(Vector2.ZERO, size)
	var mouse_over = rect.has_point(local_pos)
	
	if not mouse_over:
		return
	
	# Handle mouse button events
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT:
			if event.pressed:
				# Left click pressed - start dragging if there's an item
				if item_data:
					_start_drag()
					get_viewport().set_input_as_handled()
			else:
				# Left click released - drop item (even on empty slots)
				if dragged_item_data != null:
					_drop_on_slot()
					get_viewport().set_input_as_handled()
		
		elif event.button_index == MOUSE_BUTTON_RIGHT and event.pressed:
			# Right click - drop item in world (only if this slot has an item)
			if item_data:
				Inventory.drop_item_at_slot(slot_index)
				get_viewport().set_input_as_handled()

func _start_drag():
	"""Start dragging this slot's item"""
	if not item_data:
		return
	
	# Store drag state
	dragged_item_data = item_data
	dragged_from_slot_index = slot_index
	dragged_from_slot = self  # Store reference to this slot
	
	# Create visual preview
	_create_drag_preview()
	
	# Make this slot semi-transparent to show it's being dragged
	modulate = Color(1, 1, 1, 0.5)

func _drop_on_slot():
	"""Drop the dragged item on this slot"""
	if dragged_item_data == null or not dragged_from_slot:
		return
	
	# Check if both slots are from the same grid type
	var original_is_equipment = dragged_from_slot.get_meta("is_equipment_slot", false)
	var target_is_equipment = get_meta("is_equipment_slot", false)
	
	# Restore original slot's appearance
	dragged_from_slot.modulate = Color(1, 1, 1, 1)
	
	# Handle swapping based on grid types
	if dragged_from_slot_index == slot_index and original_is_equipment == target_is_equipment:
		# Same slot - do nothing
		_end_drag()
		return
	
	if original_is_equipment and target_is_equipment:
		# Equipment to Equipment - check type restrictions before swapping
		var item_from_slot = Equipment.get_item_at_slot(dragged_from_slot_index)
		var item_to_slot = Equipment.get_item_at_slot(slot_index)
		
		# Check if dragged item can go to target slot
		var can_move_to_target = true
		if item_from_slot:
			can_move_to_target = Equipment.can_equip_item_in_slot(item_from_slot, slot_index)
		
		# Check if target item can go to dragged slot (for swap)
		var can_move_to_source = true
		if item_to_slot:
			can_move_to_source = Equipment.can_equip_item_in_slot(item_to_slot, dragged_from_slot_index)
		
		# Only allow swap if both items can fit in their new slots
		if can_move_to_target and can_move_to_source:
			Equipment.swap_items(dragged_from_slot_index, slot_index)
		else:
			# Can't swap - cancel the drag
			dragged_from_slot.modulate = Color(1, 1, 1, 1)
			_end_drag()
			return
	elif not original_is_equipment and not target_is_equipment:
		# Inventory to Inventory - swap in inventory system
		Inventory.swap_items(dragged_from_slot_index, slot_index)
	elif not original_is_equipment and target_is_equipment:
		# Inventory to Equipment - check if item type matches slot
		var item_from_inventory = Inventory.get_item_at_slot(dragged_from_slot_index)
		var item_from_equipment = Equipment.get_item_at_slot(slot_index)
		
		# Check if the item can be equipped in this slot
		if item_from_inventory and not Equipment.can_equip_item_in_slot(item_from_inventory, slot_index):
			# Item type doesn't match - cancel the swap
			dragged_from_slot.modulate = Color(1, 1, 1, 1)
			_end_drag()
			return
		
		# Equipment items can always go to inventory (no restrictions)
		# Perform the swap
		Equipment.set_item_at_slot(slot_index, item_from_inventory)
		Inventory.items[dragged_from_slot_index] = item_from_equipment
		Inventory.inventory_changed.emit()
		Inventory._update_mass_signals()
	elif original_is_equipment and not target_is_equipment:
		# Equipment to Inventory - move item (inventory has no restrictions)
		var item_from_equipment = Equipment.get_item_at_slot(dragged_from_slot_index)
		var item_from_inventory = Inventory.get_item_at_slot(slot_index)
		
		# Check if inventory item can be equipped in equipment slot (if swapping)
		if item_from_inventory and not Equipment.can_equip_item_in_slot(item_from_inventory, dragged_from_slot_index):
			# Item type doesn't match - cancel the swap
			dragged_from_slot.modulate = Color(1, 1, 1, 1)
			_end_drag()
			return
		
		# Set items in new locations
		Inventory.items[slot_index] = item_from_equipment
		Equipment.set_item_at_slot(dragged_from_slot_index, item_from_inventory)
		Inventory.inventory_changed.emit()
		Inventory._update_mass_signals()
	
	# Clean up drag state
	_end_drag()

func _create_drag_preview():
	"""Create a visual preview of the dragged item"""
	if drag_preview:
		drag_preview.queue_free()
	
	# Create preview control
	drag_preview = Control.new()
	drag_preview.mouse_filter = Control.MOUSE_FILTER_IGNORE
	drag_preview.z_index = 100  # Draw on top
	get_tree().root.add_child(drag_preview)
	
	# Add icon
	var preview_icon = TextureRect.new()
	preview_icon.texture = item_data.icon
	preview_icon.custom_minimum_size = Vector2(48, 48)
	preview_icon.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
	preview_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	preview_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	drag_preview.add_child(preview_icon)
	
	# Position at mouse
	drag_preview.global_position = get_viewport().get_mouse_position() - Vector2(24, 24)

static func _end_drag():
	"""Clean up drag state"""
	dragged_item_data = null
	dragged_from_slot_index = -1
	dragged_from_slot = null
	
	if drag_preview:
		drag_preview.queue_free()
		drag_preview = null

static func _get_slot_by_index(index: int) -> Panel:
	"""Helper to get a slot by its index"""
	# Search both inventory and equipment slots
	for group in ["inventory_slots", "equipment_slots"]:
		for node in Engine.get_main_loop().root.get_tree().get_nodes_in_group(group):
			if node.slot_index == index:
				return node
	return null
