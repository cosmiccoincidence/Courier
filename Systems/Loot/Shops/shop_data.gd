# shop_data.gd
# Resource that defines a shop's inventory and configuration
class_name ShopData
extends Resource

@export var shop_name: String = "General Store"
@export var shop_gold: int = 1000  # How much gold the shop has

# Item pool - specific items this shop sells
@export_group("Shop Inventory")
@export var item_pool: Array[LootItem] = []  # Specific items to sell (if empty, uses all_items from LootManager)

# Item type filtering - which types of items can be sold
@export_group("Item Type Filtering")
@export var allowed_item_types: Array[String] = []  # If empty, allows all types
@export var excluded_item_types: Array[String] = []  # Blacklist specific types

# Price modifiers
@export_group("Pricing")
@export var buy_price_multiplier: float = 1.25  # Player buys at 125% of base value
@export var sell_price_multiplier: float = 0.75  # Player sells at 75% of base value

# Markup/Markdown system (random price variations)
@export var price_variation_chance: float = 0.3  # 30% chance for price variation
@export var markup_range: Vector2 = Vector2(1.1, 1.5)  # 110% to 150% for marked up items
@export var markdown_range: Vector2 = Vector2(0.7, 0.9)  # 70% to 90% for marked down items

# Stock system
@export_group("Stock Management")
@export var default_stock_min: int = 1  # Minimum stock per item
@export var default_stock_max: int = 5  # Maximum stock per item
@export var infinite_stock_items: Array[String] = []  # Item names that never run out (e.g., ["Bread", "Water"])

# Item level restrictions
@export_group("Level Restrictions")
@export var max_item_level: int = 99  # Don't show items above this level
@export var min_item_level: int = 1   # Don't show items below this level

# Internal data (auto-populated)
var item_stock: Dictionary = {}  # LootItem -> stock count (0 = out of stock)
var special_prices: Dictionary = {}  # LootItem -> float multiplier
var _initialized: bool = false

func _init():
	# Initialize will be called when shop opens
	pass

func initialize():
	"""Initialize stock and prices - call this when shop opens"""
	if _initialized:
		return
	
	_initialized = true
	_initialize_stock()
	_apply_price_variations()

func _initialize_stock():
	"""Set initial stock for all items in the shop"""
	# Clear existing stock
	item_stock.clear()
	
	# Determine source pool
	var source_pool: Array[LootItem] = []
	
	if not item_pool.is_empty():
		source_pool = item_pool
	else:
		# Use all items from LootManager, filtered by type
		if LootManager and "all_items" in LootManager:
			source_pool = _filter_items_by_type(LootManager.all_items)
		else:
			push_warning("ShopData: LootManager not found or has no all_items")
			return
	
	if source_pool.is_empty():
		push_warning("ShopData: No items available for shop!")
		return
	
	# Roll random number of items to stock
	var num_items_to_stock = randi_range(default_stock_min, default_stock_max)
	
	# Randomly select items from pool (can select same item multiple times)
	var item_index = 0
	for i in range(num_items_to_stock):
		# Randomly pick an item from source pool
		var random_item = source_pool[randi() % source_pool.size()]
		
		# Create unique key for this item instance
		var item_key = "%s_%d" % [random_item.resource_path, item_index]
		
		# Determine stock count for this specific item
		var stock_amount = 1
		
		# For stackable items, the stock represents quantity in that slot
		if random_item.stackable:
			stock_amount = randi_range(1, 5)
		
		# Add to item_stock
		item_stock[item_key] = {
			"item": random_item,
			"count": stock_amount,
			"index": item_index
		}
		
		item_index += 1

func _filter_items_by_type(all_items: Array) -> Array[LootItem]:
	"""Filter items by allowed/excluded types"""
	var filtered: Array[LootItem] = []
	
	for item in all_items:
		if not item is LootItem:
			continue
		
		# Check excluded types
		if item.item_type in excluded_item_types:
			continue
		
		# Check allowed types (if specified)
		if not allowed_item_types.is_empty():
			if not item.item_type in allowed_item_types:
				continue
		
		# Note: item_level filtering happens when items are generated, not here
		# LootItem resources don't have item_level - it's assigned during generation
		
		filtered.append(item)
	
	return filtered

func _apply_price_variations():
	"""Randomly mark up or mark down some items"""
	for item_key in item_stock.keys():
		if randf() < price_variation_chance:
			var item = item_stock[item_key].item
			
			# Randomly choose markup or markdown
			if randf() < 0.5:
				# Markup
				special_prices[item_key] = randf_range(markup_range.x, markup_range.y)
			else:
				# Markdown
				special_prices[item_key] = randf_range(markdown_range.x, markdown_range.y)

func get_buy_price(item_key: String) -> int:
	"""Get the price the player pays to buy this item"""
	if not item_stock.has(item_key):
		return 0
	
	var item = item_stock[item_key].item
	var base_price = item.base_value
	var multiplier = buy_price_multiplier
	
	# Check for special pricing using item_key
	if special_prices.has(item_key):
		multiplier = special_prices[item_key]
	
	return int(base_price * multiplier)

func get_sell_price(item_value: int) -> int:
	"""Get the price the shop pays when player sells an item"""
	return int(item_value * sell_price_multiplier)

func has_stock(item_key: String) -> bool:
	"""Check if item is in stock"""
	if not item_stock.has(item_key):
		return false
	return item_stock[item_key].count > 0

func get_stock(item_key: String) -> int:
	"""Get stock count for an item"""
	if not item_stock.has(item_key):
		return 0
	return item_stock[item_key].count

func get_item(item_key: String) -> LootItem:
	"""Get the LootItem for a key"""
	if not item_stock.has(item_key):
		return null
	return item_stock[item_key].item

func remove_stock(item_key: String, amount: int = 1) -> bool:
	"""Remove stock when player buys"""
	if not item_stock.has(item_key):
		return false
	
	var item = item_stock[item_key].item
	
	# Check for infinite stock
	if item.item_name in infinite_stock_items:
		return true  # Never runs out
	
	if item_stock[item_key].count > 0:
		item_stock[item_key].count = max(0, item_stock[item_key].count - amount)
		return true
	return false

func add_stock(item_key: String, amount: int = 1):
	"""Add stock when player sells"""
	if not item_stock.has(item_key):
		return
	
	var item = item_stock[item_key].item
	
	# Don't add to infinite stock items
	if item.item_name in infinite_stock_items:
		return
	
	item_stock[item_key].count += amount

func can_afford_to_buy_from_player(price: int) -> bool:
	"""Check if shop has enough gold to buy from player"""
	return shop_gold >= price

func is_item_level_valid(item_level: int) -> bool:
	"""Check if item level is within shop's range""" 
	return item_level >= min_item_level and item_level <= max_item_level

func get_all_shop_items() -> Array:
	"""Get all item keys and their data for display"""
	var items = []
	for item_key in item_stock.keys():
		items.append({
			"key": item_key,
			"item": item_stock[item_key].item,
			"stock": item_stock[item_key].count
		})
	return items
