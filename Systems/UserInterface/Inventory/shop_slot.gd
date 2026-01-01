# shop_slot.gd
# Individual slot in the shop inventory grid
extends Panel

@onready var icon: TextureRect = $TextureRect
@onready var label: Label = $Label

var item_data: Dictionary = {}
var slot_index: int = 0
var tooltip_manager: Control = null

signal item_purchased(item_key: String, slot_index: int)

func _ready():
	# Force mouse filters
	mouse_filter = Control.MOUSE_FILTER_STOP
	
	# Create UI elements if they don't exist
	if not icon:
		_create_icon()
	if not label:
		_create_label()
	
	# Configure icon
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
	
	# Configure label
	if label:
		label.set_mouse_filter(MOUSE_FILTER_IGNORE)
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
	
	# Style - match inventory slot appearance
	custom_minimum_size = Vector2(64, 64)
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.2, 0.2, 0.2, 0.8)
	style.border_color = Color(0.5, 0.5, 0.5, 1.0)
	style.set_border_width_all(2)
	add_theme_stylebox_override("panel", style)
	
	clear_item()

func _process(_delta):
	# Enforce mouse filter every frame
	if mouse_filter != Control.MOUSE_FILTER_STOP:
		mouse_filter = Control.MOUSE_FILTER_STOP
	
	# Manual tooltip handling
	if visible and is_visible_in_tree():
		var mouse_pos = get_local_mouse_position()
		var rect = Rect2(Vector2.ZERO, size)
		var mouse_over = rect.has_point(mouse_pos)
		
		if mouse_over and not item_data.is_empty():
			if not get_meta("tooltip_showing", false):
				if tooltip_manager and tooltip_manager.has_method("show_tooltip"):
					tooltip_manager.show_tooltip(self, item_data)
					set_meta("tooltip_showing", true)
		else:
			if get_meta("tooltip_showing", false):
				if tooltip_manager and tooltip_manager.has_method("hide_tooltip"):
					tooltip_manager.hide_tooltip()
				set_meta("tooltip_showing", false)

func _create_icon():
	"""Create icon texture rect"""
	icon = TextureRect.new()
	icon.name = "TextureRect"
	add_child(icon)

func _create_label():
	"""Create item name label"""
	label = Label.new()
	label.name = "Label"
	add_child(label)

func set_item(data: Dictionary):
	"""Set item data and display it"""
	item_data = data
	
	# Set icon
	if data.has("icon") and data.icon:
		icon.texture = data.icon
		icon.show()
	else:
		icon.hide()
	
	# Set label with item name
	if data.has("name"):
		var display_name = data.name
		
		# Only show stock count if item is stackable
		if data.get("stackable", false) and data.get("stock", 0) > 1:
			display_name = "%s (x%d)" % [display_name, data.stock]
		
		label.text = display_name
		
		# Set label color based on item quality (if available)
		if data.has("item_quality"):
			label.modulate = ItemQuality.get_quality_color(data.item_quality)
		else:
			label.modulate = Color.WHITE
		
		label.show()
	else:
		label.hide()

func clear_item():
	"""Clear the slot"""
	item_data = {}
	if icon:
		icon.texture = null
		icon.hide()
	if label:
		label.hide()
		label.modulate = Color.WHITE

func set_tooltip_manager(manager: Control):
	"""Set the tooltip manager"""
	tooltip_manager = manager

func _input(event):
	"""Handle buying with click"""
	if not visible or not is_visible_in_tree():
		return
	
	# Check if mouse is over this slot
	var local_pos = get_local_mouse_position()
	var rect = Rect2(Vector2.ZERO, size)
	var mouse_over = rect.has_point(local_pos)
	
	if not mouse_over or item_data.is_empty():
		return
	
	# Left click to buy
	if event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_LEFT:
			# Attempt purchase
			if item_data.has("item_key"):
				item_purchased.emit(item_data.item_key, slot_index)
				get_viewport().set_input_as_handled()
