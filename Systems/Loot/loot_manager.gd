# res://systems/loot_manager.gd
extends Node

# Master loot table - all items in the game
@export var all_items: Array[LootItem] = []

# Cached items by type for fast filtering
var items_by_type: Dictionary = {}


func _ready():
	_build_lookup_tables()


func _build_lookup_tables():
	# Group items by type for fast filtering
	items_by_type.clear()
	
	for item in all_items:
		var type = item.item_type
		if type == "":
			type = "none"
		
		if not items_by_type.has(type):
			items_by_type[type] = []
		items_by_type[type].append(item)


func generate_loot(enemy_level: int, loot_profile: LootProfile, player_luck: float = 0.0) -> Array[Dictionary]:
	"""
	Generate loot from an enemy/chest based on level and profile.
	
	Generation Steps:
	1. Check drop chance - does any loot drop at all?
	2. Determine number of items to drop (min_drops to max_drops)
	3. For each item drop:
	   a. Roll item type (from item_type_pool with weights)
	   b. Roll specific item (from items of that type)
	   c. Roll item level (enemy_level ± variance)
	   d. Roll item quality (based on player luck)
	   e. Roll stack size (if stackable)
	   f. Calculate final value
	4. Return array of item data dictionaries
	"""
	print("[LOOT MANAGER] generate_loot - enemy_level: %d, player_luck: %.1f" % [enemy_level, player_luck])
	
	# STEP 1: Check if any loot drops at all
	var drop_roll = randf()
	print("[LOOT MANAGER] Drop chance roll: %.2f vs %.2f" % [drop_roll, loot_profile.drop_chance])
	
	if drop_roll > loot_profile.drop_chance:
		print("[LOOT MANAGER] ❌ Failed drop chance")
		return []
	
	print("[LOOT MANAGER] ✓ Passed drop chance")
	
	# STEP 2: Determine number of items to drop
	var dropped_items: Array[Dictionary] = []
	var num_drops = randi_range(loot_profile.min_drops, loot_profile.max_drops)
	print("[LOOT MANAGER] Rolling for %d items" % num_drops)
	
	# STEP 3: Roll each item
	for i in range(num_drops):
		print("[LOOT MANAGER] Rolling item %d/%d..." % [i + 1, num_drops])
		var item_data = _roll_single_item(enemy_level, loot_profile, player_luck)
		if item_data:
			dropped_items.append(item_data)
			var stack_info = ""
			if item_data.has("stack_size") and item_data.stack_size > 1:
				stack_info = " x%d" % item_data.stack_size
			print("[LOOT MANAGER] ✓ Rolled: %s (Lv.%d, %s)%s" % [
				item_data.item.item_name,
				item_data.item_level,
				ItemQuality.get_quality_name(item_data.item_quality),
				stack_info
			])
		else:
			print("[LOOT MANAGER] ❌ Failed to roll item")
	
	print("[LOOT MANAGER] Total items generated: %d" % dropped_items.size())
	return dropped_items

func _roll_single_item(enemy_level: int, profile: LootProfile, player_luck: float) -> Dictionary:
	"""
	Roll a single item drop.
	
	Sub-steps:
	a. Get eligible items (from item_pool or filtered all_items)
	b. Select specific item (weighted random)
	c. Roll item level (enemy_level ± variance)
	d. Roll item quality (based on luck)
	e. Roll stack size (if stackable)
	f. Calculate final value
	"""
	
	# STEP 3a & 3b: Get eligible items and select one
	var eligible_items = _filter_eligible_items(profile)
	
	if eligible_items.is_empty():
		print("[LOOT MANAGER] No eligible items to drop")
		return {}
	
	# STEP 3c: Weighted random selection of specific item
	var selected_item = _weighted_select(eligible_items, profile)
	
	if not selected_item:
		return {}
	
	# Check if this item type should skip level/quality rolls
	var skip_level_quality = _should_skip_level_quality(selected_item.item_type)
	
	# STEP 3d: Calculate item level (enemy_level ± variance)
	var item_level = 1  # Default level for items that skip this step
	if not skip_level_quality:  # Roll level if NOT skipping
		item_level = enemy_level
		if profile.level_variance > 0:
			item_level += randi_range(-profile.level_variance, profile.level_variance)
		item_level = max(1, item_level)  # Minimum level 1
	
	# STEP 3e: Roll item quality based on player luck
	var item_quality = ItemQuality.Quality.NORMAL  # Default quality for items that skip this step
	if not skip_level_quality:  # Roll quality if NOT skipping
		item_quality = ItemQuality.roll_quality(player_luck)
	
	# STEP 3f: Calculate stack size if stackable
	var stack_size = 1
	if selected_item.stackable:
		var min_amount = selected_item.min_drop_amount
		var max_amount = selected_item.max_drop_amount
		
		print("[LOOT MANAGER]   Item is stackable: %s" % selected_item.item_name)
		print("[LOOT MANAGER]   Base min/max: %d-%d" % [min_amount, max_amount])
		
		# Scale by enemy level if enabled
		if selected_item.scaled_quantity:
			min_amount = max(1, int(min_amount * enemy_level))
			max_amount = max(1, int(max_amount * enemy_level))
			print("[LOOT MANAGER]   Scaled by level %d: %d-%d" % [enemy_level, min_amount, max_amount])
		
		# Ensure min doesn't exceed max
		min_amount = min(min_amount, max_amount)
		
		# Roll random stack size
		stack_size = randi_range(min_amount, max_amount)
		print("[LOOT MANAGER]   Final stack size: %d" % stack_size)
		
		# Cap at max_stack_size
		stack_size = min(stack_size, selected_item.max_stack_size)
	
	# STEP 3g: Calculate final value
	# For items that skip level/quality, just use base_value
	var final_value = selected_item.base_value
	if not skip_level_quality:
		# Standard calculation: base_value * (item_level * 0.1) * quality_mod
		var quality_mod = ItemQuality.get_value_modifier(item_quality)
		final_value = int(selected_item.base_value * (item_level * 0.1) * quality_mod)
	
	return {
		"item": selected_item,
		"item_level": item_level,
		"item_quality": item_quality,
		"item_value": final_value,
		"stack_size": stack_size
	}

func _should_skip_level_quality(item_type: String) -> bool:
	"""
	Determine if an item type should skip level and quality rolls.
	
	These item types are not affected by level or quality:
	- Bag: Inventory expansion items
	- Food: Consumable food items
	- Potion: Healing/buff potions
	- Gold: Currency
	- Gemstone: Crafting gems/materials
	"""
	var skip_types = ["bag", "food", "potion", "gold", "gemstone"]
	return item_type.to_lower() in skip_types



func _filter_eligible_items(profile: LootProfile, selected_type: String = "") -> Array[LootItem]:
	"""
	Filter items based on profile settings.
	Priority:
	1. If item_pool exists, use only those items
	2. Otherwise, use all_items and filter by type/tags
	"""
	var eligible: Array[LootItem] = []
	var source_items: Array[LootItem] = []
	
	# Determine source of items
	if not profile.item_pool.is_empty():
		# Use specific item pool
		print("[LOOT MANAGER] Using item_pool with %d items" % profile.item_pool.size())
		source_items = profile.item_pool
	else:
		# Use all items from loot manager
		print("[LOOT MANAGER] Using all_items from LootManager")
		source_items = all_items
	
	# Now filter the source items
	for item in source_items:
		# Check item type filtering (if using all_items)
		if profile.item_pool.is_empty():  # Only apply type filtering if not using item_pool
			if not profile.allowed_item_types.is_empty():
				if not item.item_type in profile.allowed_item_types:
					continue
			
			if item.item_type in profile.excluded_item_types:
				continue
		
		# Check required tags (always apply)
		if not profile.required_tags.is_empty():
			var has_required = false
			for tag in profile.required_tags:
				if tag in item.item_tags:
					has_required = true
					break
			if not has_required:
				continue
		
		# Check excluded tags (always apply)
		var has_excluded = false
		for tag in profile.excluded_tags:
			if tag in item.item_tags:
				has_excluded = true
				break
		if has_excluded:
			continue
		
		eligible.append(item)
	
	print("[LOOT MANAGER] Filtered to %d eligible items" % eligible.size())
	return eligible

func _weighted_select(items: Array[LootItem], profile: LootProfile) -> LootItem:
	if items.is_empty():
		return null
	
	if items.size() == 1:
		return items[0]
	
	var weights: Array[float] = []
	var total_weight = 0.0
	
	for item in items:
		var weight = item.item_drop_weight
		
		# Apply tag bonuses
		for tag in item.item_tags:
			if profile.bonus_tags.has(tag):
				weight *= profile.bonus_tags[tag]
		
		weight = max(0.001, weight)
		weights.append(weight)
		total_weight += weight
	
	# Weighted random selection
	var roll = randf() * total_weight
	var cumulative = 0.0
	
	for i in range(items.size()):
		cumulative += weights[i]
		if roll <= cumulative:
			return items[i]
	
	return items[-1]
