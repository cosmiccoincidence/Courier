extends CanvasLayer
# HUD
@onready var health_bar: ProgressBar = $StatBars/Health/HealthBar
@onready var stamina_bar: ProgressBar = $StatBars/Stamina/StaminaBar
@onready var health_label: Label = $StatBars/Health/HealthBar/HealthLabel
@onready var stamina_label: Label = $StatBars/Stamina/StaminaBar/StaminaLabel
@onready var time_label: Label = $TimeLabel
@onready var map_label: Label = $MapLabel
@onready var encumbered_label: Label = $EncumberedLabel
@onready var death_label: Label = $DeathLabel
@onready var ending_label: Label = $EndingLabel 

@export var player: CharacterBody3D

func _ready():
	health_bar.show_percentage = false
	stamina_bar.show_percentage = false
	
	if player:
		update_health(player.current_health, player.max_health)
		update_stamina(player.current_stamina, player.max_stamina)
	
	# Connect to time changes
	TimeManager.time_changed.connect(_on_time_changed)
	update_time_display()
	
	# Connect to map loaded signal
	var map_generator = get_tree().get_first_node_in_group("map_generator")
	if map_generator:
		if map_generator.has_signal("map_loaded"):
			map_generator.map_loaded.connect(_on_map_loaded)
	
	# Update map label initially
	update_map_label()

func update_health(current: int, maximum: int):
	health_bar.max_value = maximum
	health_bar.value = current
	health_label.text = "%d/%d" % [current, maximum]

func update_stamina(current: float, maximum: float):
	stamina_bar.max_value = maximum
	stamina_bar.value = current
	stamina_label.text = "%.0f/%.0f" % [current, maximum]

func update_encumbered_status(is_encumbered: bool, effects_active: bool = true):
	if encumbered_label:
		if is_encumbered:
			encumbered_label.text = "ENCUMBERED!"
			encumbered_label.modulate = Color(1.0, 0.3, 0.3)  # Red tint - penalties active
			encumbered_label.visible = true
		else:
			encumbered_label.visible = false

func show_death_message():
	death_label.visible = true

func update_time_display():
	if time_label:
		time_label.text = TimeManager.get_full_time_string()

func _on_time_changed(hour: int, minute: int, day: int):
	update_time_display()

func show_ending_message():
	ending_label.visible = true

func _on_map_loaded(act_num: int, map_num: int, map_name: String = ""):
	"""Called when a new map is loaded"""
	if map_label:
		if map_name != "":
			# Show map name for special maps (towns, start, end)
			map_label.text = map_name
		else:
			# Show act:map format for regular levels
			map_label.text = "Map %d:%d" % [act_num, map_num]

func update_map_label():
	if not map_label:
		return
	
	# Find the map generator in the scene
	var map_generator = get_tree().get_first_node_in_group("map_generator")
	
	if map_generator:
		var act_num = 1  # Default
		var map_num = 1  # Default
		
		# Get act_number if it exists
		if map_generator.has_method("get") and map_generator.get("act_number") != null:
			act_num = map_generator.get("act_number")
		
		# Get map_number if it exists
		if map_generator.has_method("get") and map_generator.get("map_number") != null:
			map_num = map_generator.get("map_number")
		
		map_label.text = "Map %d:%d" % [act_num, map_num]
	else:
		map_label.text = "Map 1:1"  # Fallback
