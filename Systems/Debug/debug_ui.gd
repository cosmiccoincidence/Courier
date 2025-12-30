# debug_ui.gd
# Handles all debug UI elements and displays
extends Control

# UI Elements
var enabled_label: Label
var god_mode_label: Label
var keybind_panel: PanelContainer
var keybind_vbox: VBoxContainer

func _ready():
	# Make sure UI is on top
	z_index = 100
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	
	_create_god_mode_indicator()
	_create_enabled_indicator()
	_create_keybind_panel()
	
	# Hide everything by default
	hide_all()

func _create_god_mode_indicator():
	"""Create the god mode enabled indicator"""
	god_mode_label = Label.new()
	god_mode_label.add_theme_color_override("font_color", Color(1.0, 0.8, 0.2))
	god_mode_label.add_theme_font_size_override("font_size", 14)
	god_mode_label.visible = false
	
	# Position in top right, BELOW debug enabled indicator
	god_mode_label.anchor_left = 1.0
	god_mode_label.anchor_right = 1.0
	god_mode_label.anchor_top = 0.0
	god_mode_label.anchor_bottom = 0.0
	god_mode_label.offset_left = -290
	god_mode_label.offset_right = -10
	god_mode_label.offset_top = 40  # Below debug enabled (which is at 10)
	god_mode_label.offset_bottom = 190
	god_mode_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	
	add_child(god_mode_label)

func _create_enabled_indicator():
	"""Create the debug mode enabled indicator"""
	enabled_label = Label.new()
	enabled_label.text = "🔧 DEBUG MODE ENABLED"
	enabled_label.add_theme_color_override("font_color", Color.GREEN)
	enabled_label.add_theme_font_size_override("font_size", 16)
	enabled_label.visible = false
	
	# Position in top right
	enabled_label.anchor_left = 1.0
	enabled_label.anchor_right = 1.0
	enabled_label.anchor_top = 0.0
	enabled_label.anchor_bottom = 0.0
	enabled_label.offset_left = -250
	enabled_label.offset_right = -10
	enabled_label.offset_top = 10
	enabled_label.offset_bottom = 40
	enabled_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	
	add_child(enabled_label)

func _create_keybind_panel():
	"""Create the keybind reference panel"""
	keybind_panel = PanelContainer.new()
	keybind_panel.custom_minimum_size = Vector2(350, 480)
	keybind_panel.visible = false
	
	# Position in top right, below god mode indicator (which can appear)
	keybind_panel.anchor_left = 1.0
	keybind_panel.anchor_right = 1.0
	keybind_panel.anchor_top = 0.0
	keybind_panel.anchor_bottom = 0.0
	keybind_panel.offset_left = -370
	keybind_panel.offset_right = -10
	keybind_panel.offset_top = 400  # Below god mode display
	keybind_panel.offset_bottom = 700
	
	# Style the panel
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0, 0, 0, 0.85)
	style.border_color = Color(0.2, 0.6, 1.0, 1.0)
	style.border_width_left = 2
	style.border_width_right = 2
	style.border_width_top = 2
	style.border_width_bottom = 2
	style.corner_radius_top_left = 8
	style.corner_radius_top_right = 8
	style.corner_radius_bottom_left = 8
	style.corner_radius_bottom_right = 8
	keybind_panel.add_theme_stylebox_override("panel", style)
	
	add_child(keybind_panel)
	
	# Create content
	var margin = MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 15)
	margin.add_theme_constant_override("margin_right", 15)
	margin.add_theme_constant_override("margin_top", 10)
	margin.add_theme_constant_override("margin_bottom", 10)
	keybind_panel.add_child(margin)
	
	keybind_vbox = VBoxContainer.new()
	keybind_vbox.add_theme_constant_override("separation", 8)
	margin.add_child(keybind_vbox)
	
	# Title
	var title = Label.new()
	title.text = "═══ DEBUG KEYBINDS ═══"
	title.add_theme_color_override("font_color", Color(0.2, 0.8, 1.0))
	title.add_theme_font_size_override("font_size", 18)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	keybind_vbox.add_child(title)
	
	# Add spacing
	var spacer = Control.new()
	spacer.custom_minimum_size = Vector2(0, 5)
	keybind_vbox.add_child(spacer)
	
	# Core keybinds (no section header)
	_add_keybind("F1", "Toggle Debug Mode", Color.YELLOW)
	_add_keybind("F2", "Show/Hide This Panel", Color.WHITE)
	_add_keybind("F3", "Toggle God Mode", Color(1.0, 0.8, 0.2))
	_add_keybind("F4", "Skip Level", Color(0.8, 0.8, 1.0))
	
	# Loot System keybinds
	_add_section_header("LOOT", Color(0.5, 1.0, 0.5))
	_add_keybind("\\", "Spawn Test Loot", Color(0.5, 1.0, 0.5))
	
	# Combat System keybinds
	_add_section_header("COMBAT", Color(1.0, 0.5, 0.5))
	_add_keybind("[", "Heal Self", Color(0.5, 1.0, 0.8))
	_add_keybind("]", "Damage Self", Color(1.0, 0.5, 0.5))
	
	# Time System keybinds
	_add_section_header("TIME", Color(0.7, 0.7, 1.0))
	_add_keybind(",", "Advance Time 3h", Color(0.7, 0.9, 1.0))
	_add_keybind(".", "Freeze/Unfreeze Time", Color(0.9, 0.7, 1.0))
	
	# FOV System keybinds
	_add_section_header("FOG OF WAR", Color(0.6, 0.6, 0.6))
	_add_keybind("M", "Toggle FOV System", Color(0.7, 0.7, 0.7))
	_add_keybind("N", "Reset Explored Map", Color(0.8, 0.6, 0.6))
	_add_keybind("B", "Reveal Entire Map", Color(0.6, 0.8, 0.6))

func _add_section_header(section_name: String, color: Color):
	"""Add a section header to the keybind list"""
	var spacer = Control.new()
	spacer.custom_minimum_size = Vector2(0, 5)
	keybind_vbox.add_child(spacer)
	
	var header = Label.new()
	header.text = "─── %s ───" % section_name
	header.add_theme_color_override("font_color", color)
	header.add_theme_font_size_override("font_size", 12)
	header.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	keybind_vbox.add_child(header)

func _add_keybind(key: String, description: String, color: Color):
	"""Add a keybind entry to the list"""
	var hbox = HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 10)
	keybind_vbox.add_child(hbox)
	
	# Key label
	var key_label = Label.new()
	key_label.text = key
	key_label.add_theme_color_override("font_color", color)
	key_label.add_theme_font_size_override("font_size", 14)
	key_label.custom_minimum_size = Vector2(40, 0)
	hbox.add_child(key_label)
	
	# Description label
	var desc_label = Label.new()
	desc_label.text = description
	desc_label.add_theme_font_size_override("font_size", 14)
	hbox.add_child(desc_label)

func show_debug_enabled():
	"""Show the debug mode enabled indicator"""
	enabled_label.visible = true

func show_god_mode(player: Node):
	"""Show the god mode indicator with player stats"""
	if not player:
		return
	
	var text = "⚡ GOD MODE ENABLED\n"
	text += "─────────────────\n"
	text += "Speed: x%.1f\n" % player.GOD_SPEED_MULT
	text += "Crit: %.0f%% (x%.1f)\n" % [player.GOD_CRIT_CHANCE * 100, player.GOD_CRIT_MULT]
	text += "Max Zoom: %.0f\n" % player.god_zoom_max
	text += "Encumbered: OFF\n"
	text += "Stamina Cost: OFF\n"
	text += "Damage: BLOCKED"
	
	god_mode_label.text = text
	god_mode_label.visible = true

func hide_god_mode():
	"""Hide the god mode indicator"""
	god_mode_label.visible = false

func hide_all():
	"""Hide all debug UI elements"""
	enabled_label.visible = false
	god_mode_label.visible = false
	keybind_panel.visible = false

func show_keybind_panel():
	"""Show the keybind reference panel"""
	keybind_panel.visible = true

func hide_keybind_panel():
	"""Hide the keybind reference panel"""
	keybind_panel.visible = false
