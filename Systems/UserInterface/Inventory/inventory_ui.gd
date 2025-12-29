# inventory_ui.gd
extends Control

# ===== NODE REFERENCES =====
@onready var grid_container: GridContainer = $InventoryPanel/InventoryGrid
@onready var equipment_ui: Panel = $EquipmentPanel  # Now handled by equipment_ui.gd
@onready var stats_panel: Panel = $StatsPanel
@onready var mass_label: Label = $MassLabel
@onready var gold_label: Label = $GoldLabel
@onready var slot_tooltip: Control = $SlotTooltip

# ===== CONSTANTS =====
const SLOT_SCENE_PATH = "res://Systems/UserInterface/Inventory/inventory_slot.tscn"

# ===== GRID CONFIGURATION =====
var slot_size: int = 64
var rows: int = 0  # Calculated from Inventory.max_slots
var columns: int = 5 # Fixed number of columns

# ===== STATE =====
var player_ref: CharacterBody3D = null


# ===== INITIALIZATION =====

func _ready():
	# Add to group for easy access
	add_to_group("inventory_ui")
	
	# Calculate columns based on Inventory.max_slots
	rows = Inventory.max_slots / columns
	
	# Setup tooltip manager
	_setup_tooltip_manager()
	
	# Pass tooltip to equipment UI
	if equipment_ui and equipment_ui.has_method("set_tooltip_manager"):
		equipment_ui.set_tooltip_manager(slot_tooltip)
	
	# Make panels transparent
	_setup_transparent_panels()
	
	# Load and create slots
	var slot_scene = load(SLOT_SCENE_PATH)
	if not slot_scene:
		push_error("Could not load slot scene from: ", SLOT_SCENE_PATH)
		return
	
	# Setup inventory grid
	_setup_inventory_grid(slot_scene)
	
	# Connect signals
	_connect_signals()
	
	# Get player reference and setup stats
	_setup_player_reference()
	
	# Initial updates
	_update_inventory()
	_update_mass_display(Inventory.get_total_mass(), Inventory.soft_max_mass)
	_update_gold_display(Inventory.get_gold())
	
	# Start hidden
	hide()


# ===== SETUP FUNCTIONS =====

func _setup_tooltip_manager():
	"""Create or validate tooltip manager"""
	if not slot_tooltip:
		slot_tooltip = Control.new()
		slot_tooltip.name = "SlotTooltip"
		add_child(slot_tooltip)
		
		var tooltip_script = load("res://Systems/UserInterface/Inventory/inventory_slot_tooltip.gd")
		if tooltip_script:
			slot_tooltip.set_script(tooltip_script)
		else:
			push_warning("Could not load inventory_slot_tooltip.gd - tooltips will not work")

func _setup_transparent_panels():
	"""Make inventory panel transparent"""
	var transparent_style = StyleBoxFlat.new()
	transparent_style.bg_color = Color(0, 0, 0, 0)
	
	var panel = $InventoryPanel
	if panel:
		panel.add_theme_stylebox_override("panel", transparent_style)
		panel.mouse_filter = Control.MOUSE_FILTER_PASS

func _setup_inventory_grid(slot_scene: PackedScene):
	"""Create inventory slots"""
	grid_container.columns = columns
	grid_container.mouse_filter = Control.MOUSE_FILTER_PASS
	
	for i in range(columns * rows):
		var slot = slot_scene.instantiate()
		if not slot:
			continue
		
		slot.set_mouse_filter(Control.MOUSE_FILTER_STOP)
		slot.mouse_filter = Control.MOUSE_FILTER_STOP
		slot.custom_minimum_size = Vector2(slot_size, slot_size)
		slot.slot_index = i
		slot.add_to_group("inventory_slots")
		grid_container.add_child(slot)
		
		if slot.has_method("set_tooltip_manager") and slot_tooltip:
			slot.set_tooltip_manager(slot_tooltip)

func _connect_signals():
	"""Connect to inventory signals"""
	Inventory.inventory_changed.connect(_update_inventory)
	Inventory.mass_changed.connect(_update_mass_display)
	Inventory.gold_changed.connect(_update_gold_display)

func _setup_player_reference():
	"""Get player reference and setup stats panel"""
	player_ref = get_tree().get_first_node_in_group("player")
	if not player_ref:
		push_warning("Player not found - stats panel will not update")
		return
	
	# Pass player reference to equipment UI
	if equipment_ui and "player_ref" in equipment_ui:
		equipment_ui.player_ref = player_ref
	
	if stats_panel:
		_setup_stats_panel()
		_update_stats_display()


# ===== STATS PANEL =====

func _setup_stats_panel():
	"""Create labels in the stats panel"""
	if not stats_panel:
		return
	
	# Clear existing children
	for child in stats_panel.get_children():
		child.queue_free()
	
	var vbox = VBoxContainer.new()
	vbox.name = "StatsVBox"
	stats_panel.add_child(vbox)
	
	# Title
	var title = RichTextLabel.new()
	title.bbcode_enabled = true
	title.text = "[center][color=gold][u]Player Stats[/u][/color][/center]"
	title.fit_content = true
	title.scroll_active = false
	title.add_theme_font_size_override("normal_font_size", 18)
	vbox.add_child(title)
	
	# Core Stats Section
	_create_section_label(vbox, "Core Stats")
	_create_stat_label(vbox, "StrengthLabel", "Strength: 0", 16, Color.GRAY)
	_create_stat_label(vbox, "DexterityLabel", "Dexterity: 0", 16, Color.GRAY)
	_create_stat_label(vbox, "LuckLabel", "Luck: 0", 16, Color(0.5, 1.0, 0.5))
	
	_create_spacer(vbox, 10)
	
	# Combat Stats Section
	_create_section_label(vbox, "Combat")
	_create_stat_label(vbox, "DamageLabel", "Damage: 0", 14)
	_create_stat_label(vbox, "ArmorLabel", "Armor: 0", 14)
	_create_stat_label(vbox, "AttackRangeLabel", "Attack Range: 0", 14)
	_create_stat_label(vbox, "AttackSpeedLabel", "Attack Speed: 0", 14)
	_create_stat_label(vbox, "CritChanceLabel", "Crit Chance: 0%", 14)
	_create_stat_label(vbox, "CritDamageLabel", "Crit Damage: 0x", 14)
	
	_create_spacer(vbox, 10)
	
	# Health & Stamina Section
	_create_section_label(vbox, "Health & Stamina")
	_create_stat_label(vbox, "MaxHealthLabel", "Max Health: 0", 14)
	_create_stat_label(vbox, "HealthRegenLabel", "Health Regen: 0 / 0s", 14)
	_create_stat_label(vbox, "MaxStaminaLabel", "Max Stamina: 0", 14)
	_create_stat_label(vbox, "StaminaRegenLabel", "Stamina Regen: 0 / 0s", 14)

func _create_section_label(parent: VBoxContainer, text: String):
	"""Create a section header label"""
	var label = RichTextLabel.new()
	label.bbcode_enabled = true
	label.text = "[center][color=orange][b]%s[/b][/color][/center]" % text
	label.fit_content = true
	label.scroll_active = false
	label.add_theme_font_size_override("normal_font_size", 14)
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
	if not stats_panel or not player_ref:
		return
	
	var vbox = stats_panel.get_node_or_null("StatsVBox")
	if not vbox:
		return
	
	# Core Stats
	_update_label(vbox, "StrengthLabel", "Strength: %d" % player_ref.strength)
	_update_label(vbox, "DexterityLabel", "Dexterity: %d" % player_ref.dexterity)
	_update_luck_label(vbox)
	
	# Combat Stats
	_update_label(vbox, "DamageLabel", "Damage: %d" % player_ref.damage)
	_update_label(vbox, "ArmorLabel", "Armor: %d" % player_ref.armor)
	_update_label(vbox, "AttackRangeLabel", "Attack Range: %.1f" % player_ref.attack_range)
	_update_label(vbox, "AttackSpeedLabel", "Attack Speed: %.1fx" % player_ref.attack_speed)
	_update_label(vbox, "CritChanceLabel", "Crit Chance: %.1f%%" % (player_ref.crit_chance * 100))
	_update_label(vbox, "CritDamageLabel", "Crit Damage: %.1fx" % player_ref.crit_multiplier)
	
	# Health & Stamina
	_update_label(vbox, "MaxHealthLabel", "Max Health: %d" % player_ref.max_health)
	_update_label(vbox, "HealthRegenLabel", "Health Regen: %.0f / %.0fs" % [player_ref.health_regen, player_ref.health_regen_interval])
	_update_label(vbox, "MaxStaminaLabel", "Max Stamina: %d" % int(player_ref.max_stamina))
	_update_label(vbox, "StaminaRegenLabel", "Stamina Regen: %.1f / %.1fs" % [player_ref.stamina_regen, player_ref.stamina_regen_interval])

func _update_label(vbox: VBoxContainer, label_name: String, text: String):
	"""Helper to update a label's text"""
	var label = vbox.get_node_or_null(label_name)
	if label:
		label.text = text

func _update_luck_label(vbox: VBoxContainer):
	"""Update luck label with color based on value"""
	var luck_label = vbox.get_node_or_null("LuckLabel")
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


# ===== UPDATE FUNCTIONS =====

func _update_inventory():
	"""Update inventory slots to display items"""
	var items = Inventory.get_items()
	var slots = grid_container.get_children()
	
	for i in range(min(items.size(), slots.size())):
		if items[i] != null:
			slots[i].set_item(items[i])
		else:
			slots[i].clear_item()

func _update_mass_display(current_mass: float, max_mass: float):
	"""Update mass label and color"""
	if not mass_label:
		return
	
	mass_label.text = "Mass: %.1f / %.1f" % [current_mass, max_mass]
	
	# Color based on mass percentage
	var mass_percent = current_mass / max_mass
	if mass_percent >= 1.0:
		mass_label.modulate = Color.DARK_RED
	elif mass_percent >= 0.9:
		mass_label.modulate = Color.RED
	elif mass_percent >= 0.75:
		mass_label.modulate = Color.YELLOW
	else:
		mass_label.modulate = Color.WHITE

func _update_gold_display(amount: int):
	"""Update gold label"""
	if gold_label:
		gold_label.text = "Gold: %d" % amount


# ===== INPUT HANDLING =====

func _input(event):
	"""Handle inventory toggle and drops outside grids"""
	# Toggle inventory visibility
	if event.is_action_pressed("toggle_inventory"):
		visible = !visible
		
		if visible:
			Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	
	# Handle drops outside the inventory/equipment grids
	if event is InputEventMouseButton and not event.pressed:
		if event.button_index == MOUSE_BUTTON_LEFT:
			_handle_outside_drop()

func _handle_outside_drop():
	"""Handle dropping items outside both grids"""
	var any_slot = null
	for child in grid_container.get_children():
		if child.has_method("set_item"):
			any_slot = child
			break
	
	if not any_slot:
		return
	
	var dragged_data = any_slot.get("dragged_item_data")
	var dragged_slot = any_slot.get("dragged_from_slot")
	
	if dragged_data == null or not dragged_slot:
		return
	
	var mouse_pos = get_global_mouse_position()
	var inventory_rect = grid_container.get_global_rect()
	var equipment_rect = Rect2()
	
	if equipment_ui and equipment_ui.has_method("get_equipment_rect"):
		equipment_rect = equipment_ui.get_equipment_rect()
	
	var outside_inventory = not inventory_rect.has_point(mouse_pos)
	var outside_equipment = not equipment_rect.has_point(mouse_pos)
	
	# If outside BOTH grids, drop to world
	if outside_inventory and outside_equipment:
		var is_equipment = dragged_slot.get_meta("is_equipment_slot", false)
		
		if is_equipment:
			# Drop from equipment
			if equipment_ui and equipment_ui.has_method("handle_outside_drop"):
				equipment_ui.handle_outside_drop(mouse_pos, dragged_slot)
		else:
			# Drop from inventory
			_drop_item_in_world(dragged_slot)
		
		dragged_slot.modulate = Color(1, 1, 1, 1)
		any_slot.call("_end_drag")

func _drop_item_in_world(dragged_slot: Control):
	"""Drop item from inventory into the game world"""
	var slot_idx = dragged_slot.get("dragged_from_slot_index")
	
	if slot_idx != null:
		Inventory.drop_item_at_slot(slot_idx)


# ===== CONTINUOUS UPDATE =====

func _process(_delta):
	"""Update stats every frame when inventory is visible"""
	if visible and player_ref:
		_update_stats_display()


# ===== UTILITY =====

func _get_slot_by_index(index: int) -> Panel:
	"""Get a slot by its index"""
	var slots = grid_container.get_children()
	if index >= 0 and index < slots.size():
		return slots[index]
	return null
