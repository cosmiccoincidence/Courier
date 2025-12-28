# equipment.gd
extends Node

var equipped_items: Array = []
var max_equipment_slots: int = 16  # 16 equipment slots for 4x4 grid

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

func _ready():
	# Initialize equipment array with nulls for all slots
	equipped_items.resize(max_equipment_slots)
	for i in range(max_equipment_slots):
		equipped_items[i] = null

func can_equip_item_in_slot(item_data, slot_index: int) -> bool:
	"""Check if an item can be equipped in a specific slot based on type and subtype"""
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
	
	# Type matches and either subtype matches or no subtype required
	return true

func swap_items(from_slot: int, to_slot: int):
	"""Swap items between two equipment slots"""
	if from_slot < 0 or from_slot >= max_equipment_slots:
		return
	if to_slot < 0 or to_slot >= max_equipment_slots:
		return
	
	# Swap the items (including nulls for empty slots)
	var temp = equipped_items[from_slot]
	equipped_items[from_slot] = equipped_items[to_slot]
	equipped_items[to_slot] = temp
	
	equipment_changed.emit()
	# Notify inventory system to update mass
	Inventory._update_mass_signals()

func set_item_at_slot(slot_index: int, item_data):
	"""Set an item at a specific equipment slot (with type and subtype checking)"""
	if slot_index >= 0 and slot_index < max_equipment_slots:
		# If item_data is null (clearing slot), allow it
		if item_data == null or can_equip_item_in_slot(item_data, slot_index):
			equipped_items[slot_index] = item_data
			equipment_changed.emit()
			# Notify inventory system to update mass
			Inventory._update_mass_signals()
			return true
		else:
			# Item type/subtype doesn't match slot requirement
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
