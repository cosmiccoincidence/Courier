# equipment_stats_calculator.gd
# Utility to calculate total stats from equipped items
class_name EquipmentStatsCalculator
extends RefCounted

static func calculate_total_stats(equipped_items: Array, active_weapon_set: int = 0) -> Dictionary:
	"""
	Calculate total stats from all equipped items.
	Only weapons from the active set contribute to stats.
	Returns a dictionary with all calculated stats.
	"""
	var stats = {
		"weapon_damage": 0,
		"base_armor_rating": 0,
		"weapon_range": 0.0,
		"weapon_speed": 0.0,
		"weapon_block_rating": 0.0,
		"weapon_parry_window": 0.0,
		"weapon_crit_chance": 0.0,
		"weapon_crit_multiplier": 1.0,
		"has_weapon": false
	}
	
	# Determine active weapon slots based on set
	var active_weapon_slots: Array[int] = []
	if active_weapon_set == 0:
		active_weapon_slots = [10, 11]  # L Hand 1, R Hand 1
	else:
		active_weapon_slots = [14, 15]  # L Hand 2, R Hand 2
	
	# Track equipped weapons (only from active set)
	var equipped_weapons = []
	
	for slot_idx in active_weapon_slots:
		if slot_idx < equipped_items.size():
			var item = equipped_items[slot_idx]
			if item and not _is_twohand_placeholder(item):
				equipped_weapons.append(item)
	
	# Sum armor defense from all armor pieces
	for item in equipped_items:
		if item and not _is_twohand_placeholder(item):
			if item.has("base_armor_rating") and item.base_armor_rating > 0:
				stats.base_armor_rating += item.base_armor_rating
	
	# Weapon stats - use primary weapon (first equipped weapon found in active set)
	if equipped_weapons.size() > 0:
		var primary_weapon = equipped_weapons[0]
		stats.has_weapon = true
		
		# Weapon damage
		if primary_weapon.has("weapon_damage"):
			stats.weapon_damage = primary_weapon.weapon_damage
		
		# Weapon range
		if primary_weapon.has("weapon_range"):
			stats.weapon_range = primary_weapon.weapon_range
		
		# Weapon speed
		if primary_weapon.has("weapon_speed"):
			stats.weapon_speed = primary_weapon.weapon_speed
		
		# Weapon block window
		if primary_weapon.has("weapon_block_rating"):
			stats.weapon_block_rating = primary_weapon.weapon_block_rating
		
		# Weapon parry window
		if primary_weapon.has("weapon_parry_window"):
			stats.weapon_parry_window = primary_weapon.weapon_parry_window
		
		# Weapon crit chance
		if primary_weapon.has("weapon_crit_chance"):
			stats.weapon_crit_chance = primary_weapon.weapon_crit_chance
		
		# Weapon crit multiplier
		if primary_weapon.has("weapon_crit_multiplier"):
			stats.weapon_crit_multiplier = primary_weapon.weapon_crit_multiplier
	
	return stats

static func _is_twohand_placeholder(item) -> bool:
	"""Check if an item is a two-handed weapon placeholder"""
	return typeof(item) == TYPE_DICTIONARY and item.has("_twohand_occupant")
