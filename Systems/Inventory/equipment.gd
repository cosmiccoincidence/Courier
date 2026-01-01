# equipment.gd
extends Node

var equipped_items: Array = []
var max_equipment_slots: int = 16  # 16 equipment slots for 4x4 grid
var active_weapon_set: int = 0  # 0 = slots 10-11 (L/R Hand 1), 1 = slots 14-15 (L/R Hand 2)

# Define what type and subtype each slot accepts
# Format: {"type": "armor", "subtype": "helmet"}
# If subtype is empty string "", any subtype is accepted
var slot_restrictions: Array = [
	{"type": "armor", "subtype": "helmet"},      # Slot 0 - Helmet
	{"type": "bag", "subtype": "bag"},           # Slot 1 - Bag
	{"type": "accessory", "subtype": "amulet"},  # Slot 2 - Amulet
	{"type": "trinket", "subtype": "totem"},     # Slot 3 - Totem
	{"type": "armor", "subtype": "bodyarmor"},   # Slot 4 - Bodyarmor
	{"type": "accessory", "subtype": "cape"},    # Slot 5 - Cape
	{"type": "accessory", "subtype": "ring"},    # Slot 6 - Ring 1
	{"type": "accessory", "subtype": "ring"},    # Slot 7 - Ring 2
	{"type": "armor", "subtype": "pants"},       # Slot 8 - Pants
	{"type": "armor", "subtype": "belt"},        # Slot 9 - Belt
	{"type": "weapon", "subtype": ""},           # Slot 10 - L Hand 1 (any weapon)
	{"type": "weapon", "subtype": ""},           # Slot 11 - R Hand 1 (any weapon)
	{"type": "armor", "subtype": "boots"},       # Slot 12 - Boots
	{"type": "armor", "subtype": "gloves"},      # Slot 13 - Gloves
	{"type": "weapon", "subtype": ""},           # Slot 14 - L Hand 2 (any weapon)
	{"type": "weapon", "subtype": ""}            # Slot 15 - R Hand 2 (any weapon)
]

signal equipment_changed
signal weapon_set_changed(new_set: int)

func _ready():
	# Initialize equipment array with nulls for all slots
	equipped_items.resize(max_equipment_slots)
	for i in range(max_equipment_slots):
		equipped_items[i] = null

func swap_weapon_sets():
	"""Toggle between weapon set 0 (slots 10-11) and set 1 (slots 14-15)"""
	active_weapon_set = 1 if active_weapon_set == 0 else 0
	weapon_set_changed.emit(active_weapon_set)
	equipment_changed.emit()

func get_active_weapon_slots() -> Array[int]:
	"""Get the slot indices for the currently active weapon set"""
	if active_weapon_set == 0:
		return [10, 11]  # L Hand 1, R Hand 1
	else:
		return [14, 15]  # L Hand 2, R Hand 2

func is_weapon_slot_active(slot_index: int) -> bool:
	"""Check if a weapon slot is part of the active set"""
	var weapon_slots = [10, 11, 14, 15]
	if slot_index not in weapon_slots:
		return true  # Non-weapon slots are always active
	
	return slot_index in get_active_weapon_slots()

func get_equipment_stats() -> Dictionary:
	"""Get calculated stats from all equipped items"""
	return EquipmentStatsCalculator.calculate_total_stats(equipped_items, active_weapon_set)

func can_equip_item_in_slot(item_data, slot_index: int) -> bool:
	"""Check if an item can be equipped in a specific slot based on type, subtype, hand restrictions, and stat requirements"""
	if slot_index < 0 or slot_index >= max_equipment_slots:
		return false
	
	if not item_data or not item_data.has("item_type"):
		return false
	
	var item_type = item_data.item_type.to_lower()
	var item_subtype = item_data.get("item_subtype", "").to_lower()
	
	var restriction = slot_restrictions[slot_index]
	var required_type = restriction.type.to_lower()
	var required_subtype = restriction.subtype.to_lower()
	
	# Check type first
	if item_type != required_type:
		return false
	
	# If subtype is required (not empty), check it
	if required_subtype != "":
		if item_subtype != required_subtype:
			return false
	
	# Additional check for weapons: validate hand restrictions
	if item_type == "weapon" and (EquipmentHandHelper.is_primary_slot(slot_index) or EquipmentHandHelper.is_offhand_slot(slot_index)):
		var weapon_hand = item_data.get("weapon_hand", 0)  # 0 = ANY (default)
		if not EquipmentHandHelper.can_equip_in_slot(weapon_hand, slot_index):
			return false
	
	# Check stat requirements
	if not _meets_stat_requirements(item_data):
		return false
	
	# Type matches and either subtype matches or no subtype required
	return true

func _meets_stat_requirements(item_data) -> bool:
	"""Check if player meets stat requirements to equip item"""
	var player = get_tree().get_first_node_in_group("player")
	if not player:
		print("Warning: No player found for stat requirement check")
		return true  # Allow equip if no player (shouldn't happen)
	
	# Check strength requirement
	var req_str = item_data.get("required_strength", 0)
	if req_str > 0:
		var player_str = player.get("strength")
		if player_str == null:
			print("Warning: Player missing strength stat")
			return true  # Allow if stat missing
		if player_str < req_str:
			print("Cannot equip: Requires %d Strength (you have %d)" % [req_str, player_str])
			return false
	
	# Check dexterity requirement
	var req_dex = item_data.get("required_dexterity", 0)
	if req_dex > 0:
		var player_dex = player.get("dexterity")
		if player_dex == null:
			print("Warning: Player missing dexterity stat")
			return true  # Allow if stat missing
		if player_dex < req_dex:
			print("Cannot equip: Requires %d Dexterity (you have %d)" % [req_dex, player_dex])
			return false
	
	# All requirements met
	return true

func swap_items(from_slot: int, to_slot: int):
	"""Swap items between two equipment slots"""
	if from_slot < 0 or from_slot >= max_equipment_slots:
		return
	if to_slot < 0 or to_slot >= max_equipment_slots:
		return
	
	# Check if items can be equipped in their new slots
	var from_item = equipped_items[from_slot]
	var to_item = equipped_items[to_slot]
	
	# If moving an item to a slot, check if it can be equipped there
	if from_item != null and not can_equip_item_in_slot(from_item, to_slot):
		print("Cannot swap: Item cannot be equipped in target slot")
		return
	
	if to_item != null and not can_equip_item_in_slot(to_item, from_slot):
		print("Cannot swap: Item cannot be equipped in source slot")
		return
	
	# Swap the items (including nulls for empty slots)
	var temp = equipped_items[from_slot]
	equipped_items[from_slot] = equipped_items[to_slot]
	equipped_items[to_slot] = temp
	
	equipment_changed.emit()
	# Notify inventory system to update mass
	Inventory._update_mass_signals()

func set_item_at_slot(slot_index: int, item_data):
	"""Set an item at a specific equipment slot (with type, subtype, and hand checking)"""
	if slot_index >= 0 and slot_index < max_equipment_slots:
		# If item_data is null (clearing slot), allow it
		if item_data == null or can_equip_item_in_slot(item_data, slot_index):
			# Handle two-handed weapons
			if item_data and item_data.has("weapon_hand") and item_data.weapon_hand == 3:  # TWOHAND
				# Two-handed weapon: ensure it goes in primary slot
				var primary_slot = slot_index
				if EquipmentHandHelper.is_offhand_slot(slot_index):
					# If placed in offhand, move to corresponding primary
					primary_slot = EquipmentHandHelper.get_primary_slot_for_twohand(slot_index)
				
				var paired_slot = EquipmentHandHelper.get_paired_slot(primary_slot)
				
				# Clear the paired offhand slot
				if paired_slot >= 0:
					equipped_items[paired_slot] = null
				
				# Equip in primary slot
				equipped_items[primary_slot] = item_data
				
				# Mark the paired slot as occupied by setting a reference
				if paired_slot >= 0:
					equipped_items[paired_slot] = {"_twohand_occupant": true, "primary_slot": primary_slot}
			else:
				# Normal equip
				equipped_items[slot_index] = item_data
			
			equipment_changed.emit()
			# Notify inventory system to update mass
			Inventory._update_mass_signals()
			return true
		else:
			# Item type/subtype/hand doesn't match slot requirement
			var restriction = slot_restrictions[slot_index]
			var item_type = item_data.get("item_type", "unknown")
			var item_subtype = item_data.get("item_subtype", "unknown")
			
			if restriction.subtype != "":
				push_warning("Cannot equip %s (%s) in slot %d (requires %s - %s)" % [
					item_type, 
					item_subtype, 
					slot_index, 
					restriction.type, 
					restriction.subtype
				])
			else:
				push_warning("Cannot equip %s in slot %d (requires %s - any subtype)" % [
					item_type, 
					slot_index, 
					restriction.type
				])
			return false
	return false

func get_item_at_slot(slot_index: int):
	"""Get item at a specific equipment slot"""
	if slot_index >= 0 and slot_index < max_equipment_slots:
		return equipped_items[slot_index]
	return null

func remove_item_at_slot(slot_index: int):
	"""Remove item from equipment slot"""
	if slot_index >= 0 and slot_index < max_equipment_slots:
		var item = equipped_items[slot_index]
		
		# Check if this is a two-handed weapon placeholder
		if item and typeof(item) == TYPE_DICTIONARY and item.has("_twohand_occupant"):
			# This is a placeholder - remove the actual item from primary slot
			var primary_slot = item.get("primary_slot", -1)
			if primary_slot >= 0:
				equipped_items[primary_slot] = null
		else:
			# Check if removing a two-handed weapon - also clear paired slot
			if item and item.has("weapon_hand") and item.weapon_hand == 3:  # TWOHAND
				var paired_slot = EquipmentHandHelper.get_paired_slot(slot_index)
				if paired_slot >= 0:
					equipped_items[paired_slot] = null
		
		equipped_items[slot_index] = null
		equipment_changed.emit()
		# Notify inventory system to update mass
		Inventory._update_mass_signals()

func get_items() -> Array:
	"""Get all equipped items"""
	return equipped_items

func clear():
	"""Clear all equipment"""
	for i in range(max_equipment_slots):
		equipped_items[i] = null
	equipment_changed.emit()

func get_slot_requirement(slot_index: int) -> Dictionary:
	"""Get the type/subtype requirement for a specific slot"""
	if slot_index >= 0 and slot_index < max_equipment_slots:
		return slot_restrictions[slot_index]
	return {"type": "", "subtype": ""}
