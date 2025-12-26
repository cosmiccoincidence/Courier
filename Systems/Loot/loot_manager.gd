# res://systems/loot_manager.gd
extends Node

# Master loot table - all items in the game
@export var all_items: Array[LootItem] = []

# Precomputed lookup table for performance
var items_by_level_range: Dictionary = {}


func _ready():
	print("[LOOT MANAGER] Initializing...")
	print("[LOOT MANAGER] Total items in all_items array: %d" % all_items.size())
	
	if all_items.is_empty():
		push_error("[LOOT MANAGER] ❌ No items in all_items array! Add LootItem resources to LootManager.")
	else:
		print("[LOOT MANAGER] Sample items:")
		for i in range(min(5, all_items.size())):
			var item = all_items[i]
			print("  - %s (level %d)" % [item.item_name, item.base_item_level])
	
	_build_lookup_tables()
	print("[LOOT MANAGER] ✓ Lookup tables built")
	print("[LOOT MANAGER] Items by level buckets: %d buckets" % items_by_level_range.size())


func _build_lookup_tables():
	# Group items into level buckets (every 10 levels) for faster filtering
	items_by_level_range.clear()
	
	for item in all_items:
		var bucket = int(item.base_item_level / 10)
		if not items_by_level_range.has(bucket):
			items_by_level_range[bucket] = []
		items_by_level_range[bucket].append(item)


func generate_loot(enemy_level: int, loot_profile: LootProfile) -> Array[Dictionary]:
	print("[LOOT MANAGER] generate_loot called - enemy_level: %d" % enemy_level)
	
	# Check if any loot drops at all
	var drop_roll = randf()
	print("[LOOT MANAGER] Drop chance roll: %.2f vs %.2f threshold" % [drop_roll, loot_profile.drop_chance])
	
	if drop_roll > loot_profile.drop_chance:
		print("[LOOT MANAGER] ❌ Failed drop chance check - no loot")
		return []
	
	print("[LOOT MANAGER] ✓ Passed drop chance check")
	
	var dropped_items: Array[Dictionary] = []
	var num_drops = randi_range(loot_profile.min_drops, loot_profile.max_drops)
	print("[LOOT MANAGER] Rolling for %d items" % num_drops)
	
	# Calculate what item level we're targeting based on enemy level
	var target_item_level = int(enemy_level * loot_profile.item_level_multiplier) + loot_profile.item_level_bonus
	print("[LOOT MANAGER] Target item level: %d" % target_item_level)
	
	for i in range(num_drops):
		print("[LOOT MANAGER] Rolling item %d/%d..." % [i + 1, num_drops])
		var item_data = _roll_single_item(target_item_level, loot_profile)
		if item_data:
			dropped_items.append(item_data)
			print("[LOOT MANAGER] ✓ Item %d rolled successfully" % (i + 1))
		else:
			print("[LOOT MANAGER] ❌ Item %d failed to roll" % (i + 1))
	
	print("[LOOT MANAGER] Total items generated: %d" % dropped_items.size())
	return dropped_items


func _roll_single_item(target_item_level: int, profile: LootProfile) -> Dictionary:
	# Apply level offset (e.g., bosses drop items +5 levels higher)
	var effective_level = target_item_level + profile.level_offset
	print("[LOOT MANAGER]   Effective level (with offset): %d" % effective_level)
	
	# Get eligible items within level range
	var eligible_items = _filter_eligible_items(effective_level, profile)
	
	print("[LOOT MANAGER]   Found %d eligible items" % eligible_items.size())
	
	if eligible_items.is_empty():
		push_warning("[LOOT MANAGER]   ❌ No eligible loot items found for target item level %d" % target_item_level)
		print("[LOOT MANAGER]   Check level_range (±%d), allow_higher_level (%s), allow_lower_level (%s)" % [
			profile.level_range,
			profile.allow_higher_level,
			profile.allow_lower_level
		])
		return {}
	
	# Show first few eligible items
	print("[LOOT MANAGER]   Sample eligible items:")
	for i in range(min(3, eligible_items.size())):
		var item = eligible_items[i]
		print("[LOOT MANAGER]     - %s (base_level %d)" % [item.item_name, item.base_item_level])
	
	# Calculate weights for each item based on level proximity
	var selected_item = _weighted_select_by_level(eligible_items, effective_level, profile)
	
	print("[LOOT MANAGER]   ✓ Selected: %s" % selected_item.item_name)
	
	# Return both the item resource and the calculated item_level
	return {
		"item": selected_item,
		"item_level": effective_level
	}


func _filter_eligible_items(effective_level: int, profile: LootProfile) -> Array[LootItem]:
	var eligible: Array[LootItem] = []
	
	# Determine which level buckets to check (optimization)
	var min_check_level = effective_level - profile.level_range
	var max_check_level = effective_level + profile.level_range
	var min_bucket = max(0, int(min_check_level / 10))
	var max_bucket = int(max_check_level / 10)
	
	# Check relevant buckets
	for bucket in range(min_bucket, max_bucket + 1):
		if not items_by_level_range.has(bucket):
			continue
		
		for item in items_by_level_range[bucket]:
			if _is_item_eligible(item, effective_level, profile):
				eligible.append(item)
	
	return eligible


func _is_item_eligible(item: LootItem, target_level: int, profile: LootProfile) -> bool:
	var level_diff = item.base_item_level - target_level
	
	# Check level constraints
	if level_diff > 0 and not profile.allow_higher_level:
		return false
	if level_diff < 0 and not profile.allow_lower_level:
		return false
	
	# Check if within level range
	if abs(level_diff) > profile.level_range:
		return false
	
	# Check required tags (must have at least one)
	if not profile.required_tags.is_empty():
		var has_required = false
		for tag in profile.required_tags:
			if tag in item.item_tags:
				has_required = true
				break
		if not has_required:
			return false
	
	# Check excluded tags (must have none)
	for tag in profile.excluded_tags:
		if tag in item.item_tags:
			return false
	
	return true


func _weighted_select_by_level(items: Array[LootItem], target_level: int, profile: LootProfile) -> LootItem:
	if items.size() == 1:
		return items[0]
	
	var weights: Array[float] = []
	var total_weight = 0.0
	
	for item in items:
		var weight = item.base_weight
		
		# Calculate level difference using base_item_level
		var level_diff = abs(item.base_item_level - target_level)
		
		# Apply level-based weight adjustment
		if profile.prefer_exact_level:
			# Exponential falloff - items closer to target level are heavily preferred
			var level_factor = exp(-profile.weight_falloff_rate * level_diff)
			weight *= level_factor
		
		# Optional: Use custom curve if defined
		if profile.level_curve:
			var normalized_diff = clamp(level_diff / float(profile.level_range), 0.0, 1.0)
			weight *= profile.level_curve.sample(normalized_diff)
		
		# Apply tag bonuses
		for tag in item.item_tags:
			if profile.bonus_tags.has(tag):
				weight *= profile.bonus_tags[tag]
		
		weight = max(0.001, weight)  # Ensure no zero weights
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


# Utility function: Preview what items could drop (useful for debugging/testing)
func preview_loot_pool(enemy_level: int, profile: LootProfile, max_results: int = 20) -> Array[Dictionary]:
	var target_item_level = int(enemy_level * profile.item_level_multiplier) + profile.item_level_bonus
	var effective_level = target_item_level + profile.level_offset
	var eligible_items = _filter_eligible_items(effective_level, profile)
	
	var preview: Array[Dictionary] = []
	
	for item in eligible_items:
		var level_diff = abs(item.base_item_level - effective_level)
		var weight = item.base_weight
		
		if profile.prefer_exact_level:
			weight *= exp(-profile.weight_falloff_rate * level_diff)
		
		preview.append({
			"item": item,
			"base_item_level": item.base_item_level,
			"target_item_level": effective_level,
			"level_diff": item.base_item_level - effective_level,
			"weight": weight
		})
	
	# Sort by weight descending
	preview.sort_custom(func(a, b): return a.weight > b.weight)
	
	return preview.slice(0, max_results)
