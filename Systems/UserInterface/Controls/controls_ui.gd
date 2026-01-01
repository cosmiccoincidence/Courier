# controls_ui.gd
# Displays game controls in a keybind panel
extends Control

# UI Elements
var controls_panel: PanelContainer
var controls_vbox: VBoxContainer

# Reference to debug UI to check if it's open
var debug_ui: Control = null

signal controls_panel_toggled(visible: bool)

func _ready():
	# Make sure UI is on top
	z_index = 100
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	
	# Try to find debug UI
	debug_ui = get_node_or_null("/root/DebugManager/DebugUI")
	
	_create_controls_panel()
	
	# Hide by default
	hide_controls_panel()

func _input(event):
	if event is InputEventKey and event.pressed and event.keycode == KEY_F5:
		toggle_controls_panel()

func _create_controls_panel():
	"""Create the controls reference panel"""
	controls_panel = PanelContainer.new()
	controls_panel.visible = false
	
	# Anchor to BOTTOM right corner and grow upward and leftward
	controls_panel.anchor_left = 1.0
	controls_panel.anchor_right = 1.0
	controls_panel.anchor_top = 1.0
	controls_panel.anchor_bottom = 1.0
	controls_panel.offset_left = 0  # Will be set by content width
	controls_panel.offset_right = -10  # 10px margin from right
	controls_panel.offset_top = 0  # Will be set by content height
	controls_panel.offset_bottom = -10  # 10px margin from bottom
	controls_panel.grow_vertical = Control.GROW_DIRECTION_BEGIN  # Grow upward
	controls_panel.grow_horizontal = Control.GROW_DIRECTION_BEGIN  # Grow leftward
	
	# Style the panel - GREEN border instead of blue
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0, 0, 0, 0.85)
	style.border_color = Color(0.2, 1.0, 0.4, 1.0)  # Green border
	style.border_width_left = 2
	style.border_width_right = 2
	style.border_width_top = 2
	style.border_width_bottom = 2
	style.corner_radius_top_left = 8
	style.corner_radius_top_right = 8
	style.corner_radius_bottom_left = 8
	style.corner_radius_bottom_right = 8
	controls_panel.add_theme_stylebox_override("panel", style)
	
	add_child(controls_panel)
	
	# Create content
	var margin = MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 15)
	margin.add_theme_constant_override("margin_right", 15)
	margin.add_theme_constant_override("margin_top", 10)
	margin.add_theme_constant_override("margin_bottom", 10)
	controls_panel.add_child(margin)
	
	controls_vbox = VBoxContainer.new()
	controls_vbox.add_theme_constant_override("separation", 8)
	margin.add_child(controls_vbox)
	
	# Title
	var title = Label.new()
	title.text = "═══ GAME CONTROLS ═══"
	title.add_theme_color_override("font_color", Color(0.2, 1.0, 0.4))
	title.add_theme_font_size_override("font_size", 18)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	controls_vbox.add_child(title)
	
	# Add spacing
	var spacer = Control.new()
	spacer.custom_minimum_size = Vector2(0, 5)
	controls_vbox.add_child(spacer)
	
	# General controls (no section header)
	_add_control("E", "Interact", Color(1.0, 1.0, 0.8))
	_add_control("Hover", "Entity Info Tooltip", Color(0.9, 0.9, 0.7))
	_add_control("F5", "Game Controls", Color(0.8, 1.0, 0.8))
	
	# MOVEMENT section
	_add_section_header("MOVEMENT", Color(0.6, 0.8, 1.0))
	_add_control("W/A/S/D", "Move", Color(0.7, 0.9, 1.0))
	_add_control("Shift", "Sprint", Color(0.8, 1.0, 1.0))
	
	# INVENTORY section
	_add_section_header("INVENTORY", Color(1.0, 0.8, 0.5))
	_add_control("Tab", "Toggle Inventory", Color(1.0, 0.9, 0.7))
	_add_control("LMB", "Pick Up Item", Color(1.0, 0.9, 0.7))
	_add_control("RMB", "Drop Item", Color(1.0, 0.9, 0.7))
	_add_control("CTRL+LMB", "Buy/Sell Item", Color(1.0, 0.9, 0.7))
	_add_control("Hover", "Item Info Tooltip", Color(0.9, 0.8, 0.6))
	
	# COMBAT section
	_add_section_header("COMBAT", Color(1.0, 0.5, 0.5))
	_add_control("X", "Swap Weapon", Color(1.0, 0.6, 0.6))
	_add_control("F", "Attack", Color(1.0, 0.6, 0.6))

func _add_section_header(section_name: String, color: Color):
	"""Add a section header to the controls list"""
	var spacer = Control.new()
	spacer.custom_minimum_size = Vector2(0, 5)
	controls_vbox.add_child(spacer)
	
	var header = Label.new()
	header.text = "─── %s ───" % section_name
	header.add_theme_color_override("font_color", color)
	header.add_theme_font_size_override("font_size", 12)
	header.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	controls_vbox.add_child(header)

func _add_control(key: String, description: String, color: Color):
	"""Add a control entry to the list"""
	var hbox = HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 10)
	controls_vbox.add_child(hbox)
	
	# Key label
	var key_label = Label.new()
	key_label.text = key
	key_label.add_theme_color_override("font_color", color)
	key_label.add_theme_font_size_override("font_size", 14)
	key_label.custom_minimum_size = Vector2(60, 0)
	hbox.add_child(key_label)
	
	# Description label
	var desc_label = Label.new()
	desc_label.text = description
	desc_label.add_theme_font_size_override("font_size", 14)
	hbox.add_child(desc_label)

func toggle_controls_panel():
	"""Toggle the controls panel visibility"""
	var new_state = !controls_panel.visible
	
	if new_state:
		# Opening controls panel - close debug keybind panel if open
		if debug_ui and debug_ui.has_method("is_keybind_panel_visible"):
			if debug_ui.is_keybind_panel_visible():
				debug_ui.hide_keybind_panel()
		
		show_controls_panel()
	else:
		hide_controls_panel()

func show_controls_panel():
	"""Show the controls panel"""
	controls_panel.visible = true
	controls_panel_toggled.emit(true)

func hide_controls_panel():
	"""Hide the controls panel"""
	controls_panel.visible = false
	controls_panel_toggled.emit(false)

func is_controls_panel_visible() -> bool:
	"""Check if controls panel is currently visible"""
	return controls_panel.visible
