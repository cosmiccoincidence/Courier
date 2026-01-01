# stats_panel.gd
# Displays player stats in the inventory UI
extends PanelContainer

# Node references
@onready var hero_name_label: Label = $"../HeroNameLabel"  # Sibling label node

# Player reference
var player_ref: CharacterBody3D = null
var stats_container: VBoxContainer = null

func _ready():
	# Setup panel styling
	_setup_panel_style()
	_setup_stats_panel()
	
	# Setup hero name label styling
	if hero_name_label:
		hero_name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		hero_name_label.add_theme_font_size_override("font_size", 18)
		hero_name_label.add_theme_color_override("font_color", Color.GOLD)

func set_player_reference(player: CharacterBody3D):
	"""Set the player reference and update display"""
	player_ref = player
	if player_ref:
		_update_hero_name()
		_update_stats_display()

func _update_hero_name():
	"""Update hero name from player"""
	if not player_ref or not hero_name_label:
		return
	
	var hero_name = "Hero"  # Default
	if "hero_name" in player_ref:
		hero_name = player_ref.hero_name
	
	hero_name_label.text = hero_name

func _setup_panel_style():
	"""Setup panel background and border"""
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0, 0, 0, 0.8)
	style.border_color = Color(0.5, 0.5, 0.5, 1.0)  # Grey border
	style.set_border_width_all(2)
	style.set_corner_radius_all(4)
	style.content_margin_left = 10
	style.content_margin_right = 10
	style.content_margin_top = 10
	style.content_margin_bottom = 10
	add_theme_stylebox_override("panel", style)

func _setup_stats_panel():
	"""Create labels in the stats panel"""
	# Clear existing children
	for child in get_children():
		child.queue_free()
	
	# Create container
	stats_container = VBoxContainer.new()
	stats_container.name = "StatsContainer"
	add_child(stats_container)
	
	# Core Stats Section
	_create_section_label(stats_container, "Core Stats")
	_create_stat_label(stats_container, "StrengthLabel", "Strength: 0", 16, Color.GRAY)
	_create_stat_label(stats_container, "DexterityLabel", "Dexterity: 0", 16, Color.GRAY)
	_create_stat_label(stats_container, "LuckLabel", "Luck: 0", 16, Color(0.5, 1.0, 0.5))
	
	_create_spacer(stats_container, 10)
	
	# Combat Stats Section
	_create_section_label(stats_container, "Combat")
	_create_stat_label(stats_container, "DamageLabel", "Damage: 0", 14)
	_create_stat_label(stats_container, "ArmorLabel", "Armor: 0", 14)
	_create_stat_label(stats_container, "AttackRangeLabel", "Attack Range: 0", 14)
	_create_stat_label(stats_container, "AttackSpeedLabel", "Attack Speed: 0", 14)
	_create_stat_label(stats_container, "CritChanceLabel", "Crit Chance: 0%", 14)
	_create_stat_label(stats_container, "CritDamageLabel", "Crit Damage: 0x", 14)
	
	_create_spacer(stats_container, 10)
	
	# Health & Stamina Section
	_create_section_label(stats_container, "Health & Stamina")
	_create_stat_label(stats_container, "MaxHealthLabel", "Max Health: 0", 14)
	_create_stat_label(stats_container, "HealthRegenLabel", "Health Regen: 0 / 0s", 14)
	_create_stat_label(stats_container, "MaxStaminaLabel", "Max Stamina: 0", 14)
	_create_stat_label(stats_container, "StaminaRegenLabel", "Stamina Regen: 0 / 0s", 14)

func _create_section_label(parent: VBoxContainer, text: String):
	"""Create a centered section header label"""
	var label = Label.new()
	label.text = text
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 14)
	label.add_theme_color_override("font_color", Color.ORANGE)
	parent.add_child(label)

func _create_stat_label(parent: VBoxContainer, label_name: String, text: String, font_size: int = 14, color: Color = Color.WHITE):
	"""Create a stat label"""
	var label = Label.new()
	label.name = label_name
	label.text = text
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	parent.add_child(label)

func _create_spacer(parent: VBoxContainer, height: int):
	"""Create vertical spacer"""
	var spacer = Control.new()
	spacer.custom_minimum_size = Vector2(0, height)
	parent.add_child(spacer)

func _update_stats_display():
	"""Update the stats panel with current player stats"""
	if not player_ref or not stats_container:
		return
	
	# Core Stats
	_update_label("StrengthLabel", "Strength: %d" % player_ref.strength)
	_update_label("DexterityLabel", "Dexterity: %d" % player_ref.dexterity)
	_update_luck_label()
	
	# Combat Stats
	_update_label("DamageLabel", "Damage: %d" % player_ref.damage)
	_update_label("ArmorLabel", "Armor: %d" % player_ref.armor)
	_update_label("AttackRangeLabel", "Attack Range: %.1f" % player_ref.attack_range)
	_update_label("AttackSpeedLabel", "Attack Speed: %.1fx" % player_ref.attack_speed)
	_update_label("CritChanceLabel", "Crit Chance: %.1f%%" % (player_ref.crit_chance * 100))
	_update_label("CritDamageLabel", "Crit Damage: %.1fx" % player_ref.crit_multiplier)
	
	# Health & Stamina
	_update_label("MaxHealthLabel", "Max Health: %d" % player_ref.max_health)
	_update_label("HealthRegenLabel", "Health Regen: %.0f / %.0fs" % [player_ref.health_regen, player_ref.health_regen_interval])
	_update_label("MaxStaminaLabel", "Max Stamina: %d" % int(player_ref.max_stamina))
	_update_label("StaminaRegenLabel", "Stamina Regen: %.1f / %.1fs" % [player_ref.stamina_regen, player_ref.stamina_regen_interval])

func _update_label(label_name: String, text: String):
	"""Helper to update a label's text"""
	if not stats_container:
		return
	var label = stats_container.get_node_or_null(label_name)
	if label:
		label.text = text

func _update_luck_label():
	"""Update luck label with color based on value"""
	if not stats_container:
		return
	var luck_label = stats_container.get_node_or_null("LuckLabel")
	if not luck_label:
		return
	
	var luck_value = player_ref.luck
	
	# Color based on positive/negative luck
	if luck_value > 0:
		luck_label.add_theme_color_override("font_color", Color(0.5, 1.0, 0.5))  # Green
	elif luck_value < 0:
		luck_label.add_theme_color_override("font_color", Color(1.0, 0.5, 0.5))  # Red
	else:
		luck_label.add_theme_color_override("font_color", Color.WHITE)  # White
	
	luck_label.text = "Luck: %.1f" % luck_value

func _process(_delta):
	"""Update stats every frame"""
	if player_ref and visible:
		_update_stats_display()
	
	# Update hero name position to stay centered above panel
	_update_hero_name_position()

func _update_hero_name_position():
	"""Position hero name label centered above the stats panel"""
	if not hero_name_label:
		return
	
	# Get panel position and size
	var panel_pos = global_position
	var panel_size = size
	
	# Calculate centered position above panel
	var label_x = panel_pos.x + (panel_size.x / 2) - (hero_name_label.size.x / 2)
	var label_y = panel_pos.y - hero_name_label.size.y - 5  # 5px gap above panel
	
	hero_name_label.global_position = Vector2(label_x, label_y)
