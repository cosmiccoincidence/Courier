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
var rows: int = 6  # Default, overridden by shop_data.grid_rows

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
	ShopManager.shop_inventory_changed.connect(_on_shop_inventory_changed)
	
	# Don't setup grid here - wait for shop to open with correct size

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

func _rebuild_shop_grid():
	"""Rebuild shop grid with the correct number of rows from shop_data"""
	# Clear existing slots immediately (not queue_free which delays)
	for child in shop_grid.get_children():
		shop_grid.remove_child(child)
		child.free()
	
	# Create new slots with correct row count
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
	
	print("[ShopUI] Opening shop: %s" % shop_data.shop_name)
	print("[ShopUI] Grid rows: %d, max slots: %d" % [shop_data.grid_rows, shop_data.max_slots])
	
	# Update UI
	shop_name_label.text = shop_data.shop_name
	shop_gold_label.text = "Gold: %d" % shop_data.shop_gold
	
	# Set rows from shop data and rebuild grid
	rows = shop_data.grid_rows
	print("[ShopUI] Setting rows to: %d" % rows)
	_rebuild_shop_grid()
	print("[ShopUI] Grid rebuilt with %d slots" % shop_grid.get_child_count())
	
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

func _on_shop_inventory_changed():
	"""Refresh shop inventory when items are sold to shop"""
	_populate_shop_inventory()

func _populate_shop_inventory():
	"""Fill shop slots with items from shop data"""
	if not current_shop_data:
		print("[ShopUI] ERROR: No shop data!")
		return
	
	var slots = shop_grid.get_children()
	var slot_index = 0
	
	print("[ShopUI] Populating shop with %d slots available" % slots.size())
	
	# Clear all slots first
	for slot in slots:
		if slot.has_method("clear_item"):
			slot.clear_item()
	
	# Get all items this shop sells (now returns dictionaries with keys)
	var shop_items = current_shop_data.get_all_shop_items()
	print("[ShopUI] Shop has %d items to display" % shop_items.size())
	
	# Add shop items to slots
	for item_data in shop_items:
		if slot_index >= slots.size():
			print("[ShopUI] Ran out of slots at index %d" % slot_index)
			break
		
		var item_key = item_data.key
		var item = item_data.item  # Always a dictionary now
		var stock = item_data.stock
		
		print("[ShopUI]   Item %d: %s (stock: %d)" % [slot_index, item.get("name", "Unknown"), stock])
		
		# Skip out of stock items
		if stock <= 0:
			print("[ShopUI]     Skipping - out of stock")
			continue
		
		# Item is already a full dictionary with all stats rolled
		var display_data = item.duplicate()
		display_data["is_shop_item"] = true
		display_data["item_key"] = item_key
		display_data["buy_price"] = current_shop_data.get_buy_price(item_key)
		display_data["stock"] = stock
		
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
