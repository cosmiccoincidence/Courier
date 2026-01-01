# shop_manager.gd
# Autoload that manages the current shop session
extends Node

var current_shop: ShopData = null
var current_merchant: Node = null

signal shop_opened(shop_data: ShopData)
signal shop_closed
signal transaction_completed(item_name: String, is_purchase: bool, price: int)
signal shop_gold_changed(amount: int)
signal shop_inventory_changed  # Emitted when shop inventory changes (e.g., player sells item)

func open_shop(shop_data: ShopData, merchant: Node):
	"""Open a shop for trading"""
	current_shop = shop_data
	current_merchant = merchant
	
	# Initialize shop stock and prices
	shop_data.initialize()
	
	shop_opened.emit(shop_data)

func close_shop():
	"""Close the current shop"""
	current_shop = null
	current_merchant = null
	shop_closed.emit()

func is_shop_open() -> bool:
	"""Check if a shop is currently open"""
	return current_shop != null

func buy_item_by_key(item_key: String, player_inventory: Node) -> bool:
	"""
	Player buys an item from the shop using item key.
	Returns true if transaction succeeded.
	"""
	if not current_shop:
		return false
	
	# Get the item (always a Dictionary now)
	var item = current_shop.get_item(item_key)
	if not item:
		return false
	
	# Check stock
	if not current_shop.has_stock(item_key):
		return false
	
	# Calculate price
	var price = current_shop.get_buy_price(item_key)
	
	# Check if player has enough gold
	if player_inventory.get_gold() < price:
		return false
	
	# Item is already a full dictionary
	var item_data = item.duplicate()
	
	# Check mass limit
	var current_mass = player_inventory.get_total_mass()
	var item_mass = item_data.get("mass", 0.0)
	if current_mass + item_mass > player_inventory.hard_max_mass:
		return false
	
	# Perform transaction
	player_inventory.remove_gold(price)
	current_shop.shop_gold += price
	current_shop.remove_stock(item_key, 1)
	
	# Add item to player inventory
	var success = player_inventory.add_item(item_data)
	
	if success:
		var item_name = item_data.get("name", "Unknown")
		transaction_completed.emit(item_name, true, price)
		shop_gold_changed.emit(current_shop.shop_gold)
		return true
	else:
		# Refund if add failed
		player_inventory.add_gold(price)
		current_shop.shop_gold -= price
		current_shop.add_stock(item_key, 1)
		return false

func sell_item(slot_index: int, player_inventory: Node) -> bool:
	"""
	Player sells an item from their inventory to the shop.
	Returns true if transaction succeeded.
	"""
	if not current_shop:
		return false
	
	var item_data = player_inventory.get_item_at_slot(slot_index)
	if not item_data:
		return false
	
	# Calculate sell price with markup/markdown matching
	# Use base_name if available, otherwise use full name (quality prefix will be stripped)
	var item_name = item_data.get("base_name", item_data.get("name", ""))
	var item_value = item_data.get("value", 0)
	var price = current_shop.get_sell_price_for_item(item_name, item_value)
	
	# Check if shop has enough gold
	if not current_shop.can_afford_to_buy_from_player(price):
		return false
	
	# Check if shop has space for the item
	if not current_shop.has_space_for_sold_item():
		return false
	
	# Perform transaction
	current_shop.shop_gold -= price
	player_inventory.add_gold(price)
	player_inventory.remove_item_at_slot(slot_index)
	
	# Add sold item to shop inventory
	current_shop.add_sold_item(item_data)
	
	transaction_completed.emit(item_data.get("name", "Unknown"), false, price)
	shop_gold_changed.emit(current_shop.shop_gold)
	shop_inventory_changed.emit()  # Refresh shop UI
	return true

func _loot_item_to_dictionary(item: LootItem) -> Dictionary:
	"""Convert a LootItem to the dictionary format used by inventory"""
	# Roll stats for the item (level 1, normal quality for shops)
	var item_level = 1
	var item_quality = ItemQuality.Quality.NORMAL
	
	# Calculate value
	var item_value = item.base_value
	
	# Build dictionary
	return {
		"name": item.item_name,
		"icon": item.icon,
		"scene": item.item_scene,
		"mass": item.mass,
		"durability": item.durability,
		"value": item_value,
		"stackable": item.stackable,
		"max_stack_size": item.max_stack_size,
		"amount": 1,
		"item_type": item.item_type,
		"item_level": item_level,
		"item_quality": item_quality,
		"item_subtype": item.item_subtype,
		"required_strength": item.required_strength,
		"required_dexterity": item.required_dexterity,
		"weapon_class": item.weapon_class,
		"weapon_damage": 0,  # Will be rolled if weapon
		"armor_class": item.armor_class,
		"armor_rating": 0,  # Will be rolled if armor
		"weapon_hand": item.weapon_hand,
		"weapon_range": item.weapon_range,
		"weapon_speed": item.weapon_speed,
		"weapon_block_rating": item.weapon_block_rating,
		"weapon_parry_window": item.weapon_parry_window,
		"weapon_crit_chance": item.weapon_crit_chance,
		"weapon_crit_multiplier": item.weapon_crit_multiplier
	}

func get_shop_name() -> String:
	if current_shop:
		return current_shop.shop_name
	return ""

func get_shop_gold() -> int:
	if current_shop:
		return current_shop.shop_gold
	return 0
