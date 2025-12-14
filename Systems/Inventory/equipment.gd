extends Node
# Equipment System

var equipped_items: Array = []
var max_equipment_slots: int = 13  # 13 actual slots after gaps

signal equipment_changed

func _ready():
	# Initialize equipment array with nulls for all slots
	equipped_items.resize(max_equipment_slots)
	for i in range(max_equipment_slots):
		equipped_items[i] = null

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
	# Notify inventory system to update weight
	Inventory._update_weight_signals()

func set_item_at_slot(slot_index: int, item_data):
	"""Set an item at a specific equipment slot"""
	if slot_index >= 0 and slot_index < max_equipment_slots:
		equipped_items[slot_index] = item_data
		equipment_changed.emit()
		# Notify inventory system to update weight
		Inventory._update_weight_signals()

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
		# Notify inventory system to update weight
		Inventory._update_weight_signals()

func get_items() -> Array:
	"""Get all equipped items"""
	return equipped_items

func clear():
	"""Clear all equipment"""
	for i in range(max_equipment_slots):
		equipped_items[i] = null
	equipment_changed.emit()
