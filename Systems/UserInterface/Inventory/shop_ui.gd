# shop_ui.gd
# Shop interface for buying and selling items
extends Control

# Node references
@onready var shop_panel: Panel = $ShopPanel
@onready var shop_grid: GridContainer = $ShopPanel/ShopGrid
@onready var shop_name_label: Label = $ShopNameLabel
@onready var shop_gold_label: Label = $ShopGoldLabel
@onready var slot_tooltip: Control = null  # Will be set from inventory UI

# Constants
const SHOP_SLOT_SCENE_PATH = "res://Systems/UserInterface/Inventory/shop_slot.tscn"

# Grid configuration
var slot_size: int = 64
var columns: int = 4
var rows: int = 6  # 24 slots for shop inventory

# Current shop data
var current_shop_data: ShopData = null

func _ready():
	# Add to group for easy access
	add_to_group("shop_ui")
	
	# Start hidden
	hide()
	
	# Connect to ShopManager signals
	ShopManager.shop_opened.connect(_on_shop_opened)
	ShopManager.shop_closed.connect(_on_shop_closed)
	ShopManager.shop_gold_changed.connect(_on_shop_gold_changed)
	
	# Setup shop grid
	_setup_shop_grid()

func _setup_shop_grid():
	"""Create shop inventory slots"""
	var slot_scene: PackedScene = load(SHOP_SLOT_SCENE_PATH)
	if not slot_scene:
		push_error("Could not load shop slot scene from: ", SHOP_SLOT_SCENE_PATH)
		return
	
	shop_grid.columns = columns
	
	for i in range(columns * rows):
		var slot = slot_scene.instantiate()
		if not slot:
			continue
		
		slot.custom_minimum_size = Vector2(slot_size, slot_size)
		slot.slot_index = i
		slot.add_to_group("shop_slots")
		shop_grid.add_child(slot)
		
		# Set tooltip manager if available
		if slot.has_method("set_tooltip_manager") and slot_tooltip:
			slot.set_tooltip_manager(slot_tooltip)
		
		# Connect buy signal
		if slot.has_signal("item_purchased"):
			slot.item_purchased.connect(_on_item_purchased)

func set_tooltip_manager(tooltip: Control):
	"""Set the tooltip manager from inventory UI"""
	slot_tooltip = tooltip
	
	# Update all existing slots with the tooltip manager
	if shop_grid:
		for slot in shop_grid.get_children():
			if slot.has_method("set_tooltip_manager"):
				slot.set_tooltip_manager(slot_tooltip)

func _on_shop_opened(shop_data: ShopData):
	"""Called when a shop is opened"""
	current_shop_data = shop_data
	
	# Update UI
	shop_name_label.text = shop_data.shop_name
	shop_gold_label.text = "Gold: %d" % shop_data.shop_gold
	
	# Populate shop inventory
	_populate_shop_inventory()
	
	# Get tooltip from InventoryUI if we don't have it
	if not slot_tooltip:
		var inv_ui = get_tree().get_first_node_in_group("inventory_ui")
		if inv_ui and "slot_tooltip" in inv_ui:
			slot_tooltip = inv_ui.slot_tooltip
	
	# Set tooltip manager on all slots
	if slot_tooltip:
		for slot in shop_grid.get_children():
			if slot.has_method("set_tooltip_manager"):
				slot.set_tooltip_manager(slot_tooltip)
		
		# Set tooltip z-index to be in front of shop UI
		if slot_tooltip.get_parent():
			slot_tooltip.get_parent().move_child(slot_tooltip, -1)
		slot_tooltip.z_index = 100
	
	# Open inventory UI when shop opens
	var inv_ui = get_tree().get_first_node_in_group("inventory_ui")
	if inv_ui:
		inv_ui.show()
	
	# Show shop UI
	show()

func _on_shop_closed():
	"""Called when shop is closed"""
	current_shop_data = null
	_clear_shop_inventory()
	hide()
	
	# Hide tooltip when shop closes
	if slot_tooltip and slot_tooltip.has_method("hide_tooltip"):
		slot_tooltip.hide_tooltip()
	
	# Always close inventory when shop closes
	var inv_ui = get_tree().get_first_node_in_group("inventory_ui")
	if inv_ui:
		if inv_ui.has_method("close_without_hiding_cursor"):
			inv_ui.close_without_hiding_cursor()
		else:
			inv_ui.visible = false

func _on_shop_gold_changed(new_amount: int):
	"""Update shop gold display"""
	shop_gold_label.text = "Gold: %d" % new_amount

func _populate_shop_inventory():
	"""Fill shop slots with items from shop data"""
	if not current_shop_data:
		return
	
	var slots = shop_grid.get_children()
	var slot_index = 0
	
	# Clear all slots first
	for slot in slots:
		if slot.has_method("clear_item"):
			slot.clear_item()
	
	# Get all items this shop sells (now returns dictionaries with keys)
	var shop_items = current_shop_data.get_all_shop_items()
	
	# Add shop items to slots
	for item_data in shop_items:
		if slot_index >= slots.size():
			break
		
		var item_key = item_data.key
		var item = item_data.item
		var stock = item_data.stock
		
		# Skip out of stock items
		if stock <= 0:
			continue
		
		# Create display data (match format expected by tooltip)
		var display_data = {
			"name": item.item_name,
			"icon": item.icon,
			"item_type": item.item_type,
			"item_subtype": item.item_subtype,
			"item_level": 1,
			"item_quality": ItemQuality.Quality.NORMAL,
			"value": item.base_value,
			"buy_price": current_shop_data.get_buy_price(item_key),
			"stock": stock,
			"stackable": item.stackable,
			"stack_count": stock if item.stackable else 1,
			"is_shop_item": true,
			"item_key": item_key,  # Store key for purchasing
			# Add other stats for tooltip
			"mass": item.mass,
			"durability": item.durability,
			"required_strength": item.required_strength,
			"required_dexterity": item.required_dexterity,
			"weapon_class": item.weapon_class,
			"weapon_damage": 0,
			"armor_class": item.armor_class,
			"armor_rating": 0,
			"weapon_hand": item.weapon_hand,
			"weapon_range": item.weapon_range,
			"weapon_speed": item.weapon_speed,
			"weapon_block_rating": item.weapon_block_rating,
			"weapon_parry_window": item.weapon_parry_window,
			"weapon_crit_chance": item.weapon_crit_chance,
			"weapon_crit_multiplier": item.weapon_crit_multiplier
		}
		
		if slots[slot_index].has_method("set_item"):
			slots[slot_index].set_item(display_data)
		
		slot_index += 1

func _clear_shop_inventory():
	"""Clear all shop slots"""
	for slot in shop_grid.get_children():
		if slot.has_method("clear_item"):
			slot.clear_item()

func _on_item_purchased(item_key: String, slot_index: int):
	"""Called when player buys an item"""
	var success = ShopManager.buy_item_by_key(item_key, Inventory)
	
	if success:
		# Refresh shop inventory to update stock
		_populate_shop_inventory()

func _input(event):
	"""Handle closing shop with Escape or Tab"""
	if not visible:
		return
	
	if event.is_action_pressed("ui_cancel") or event.is_action_pressed("toggle_inventory"):
		ShopManager.close_shop()
		get_viewport().set_input_as_handled()

func _process(_delta):
	"""Check distance from merchant while shop is open"""
	if not visible:
		return
	
	# If shop is open but inventory is closed, close the shop too
	var inv_ui = get_tree().get_first_node_in_group("inventory_ui")
	if inv_ui and not inv_ui.visible:
		ShopManager.close_shop()
		return
	
	if not ShopManager.current_merchant:
		return
	
	# Get player
	var player = get_tree().get_first_node_in_group("player")
	if not player:
		return
	
	# Check distance
	var distance = player.global_position.distance_to(ShopManager.current_merchant.global_position)
	if distance > 5.0:
		ShopManager.close_shop()
