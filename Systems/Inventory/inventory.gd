extends Node
# inventory.gd

var items: Array = []
var max_slots: int = 32  # Match the UI grid (8 columns × 5 rows)
var player_ref: Node3D = null  # Reference to player for drop position

# Mass system
var soft_max_mass: float = 10.0
var hard_max_mass: float = 11.0  # Will be calculated

# Gold system
var gold: int = 0

signal inventory_changed
signal item_dropped(item_data, position)
signal mass_changed(current_mass, max_mass)
signal gold_changed(amount)
signal encumbered_status_changed(is_encumbered)

# Store reference to item scenes for dropping
var item_scene_lookup: Dictionary = {}

func _ready():
	# Calculate hard max mass
	hard_max_mass = soft_max_mass * 1.1
	
	# Initialize items array with nulls for all slots
	items.resize(max_slots)
	for i in range(max_slots):
		items[i] = null

func swap_items(from_slot: int, to_slot: int):
	"""Swap items between two inventory slots"""
	if from_slot < 0 or from_slot >= max_slots:
		return
	if to_slot < 0 or to_slot >= max_slots:
		return
	
	# Swap the items (including nulls for empty slots)
	var temp = items[from_slot]
	items[from_slot] = items[to_slot]
	items[to_slot] = temp
	
	inventory_changed.emit()

func _update_mass_signals():
	"""Update mass-related signals and encumbrance status"""
	var current_mass = get_total_mass()
	mass_changed.emit(current_mass, soft_max_mass)
	encumbered_status_changed.emit(is_encumbered())

func add_item(item_name: String, icon: Texture2D = null, item_scene: PackedScene = null, item_mass: float = 1.0, item_value: int = 10, is_stackable: bool = false, max_stack: int = 99, amount: int = 1, item_type: String = "", item_level: int = 1, item_quality: int = 1, item_subtype: String = "", weapon_damage: int = 0, armor_defense: int = 0, weapon_hand: int = 0) -> bool:
	# Special handling for gold - add directly to gold counter
	if item_name.to_lower() == "gold" or item_name.to_lower() == "coin":
		add_gold(amount)
		return true
	
	# Calculate what the mass would be if we add this item
	var current_mass = get_total_mass()
	var new_item_mass = item_mass * amount
	var projected_mass = current_mass + new_item_mass
	
	# Check if adding would exceed hard max mass
	if projected_mass > hard_max_mass:
		print("Cannot add item: Would exceed maximum carry mass (", projected_mass, "/", hard_max_mass, ")")
		return false
	
	# If stackable, try to add to existing stack first
	if is_stackable:
		for item in items:
			if item != null and item.name == item_name and item.has("stackable") and item.stackable:
				# Found existing stack - add to it
				var space_in_stack = item.max_stack_size - item.stack_count
				var amount_to_add = min(amount, space_in_stack)
				
				if amount_to_add > 0:
					item.stack_count += amount_to_add
					amount -= amount_to_add
					inventory_changed.emit()
					_update_mass_signals()
					
					# If we added everything, we're done
					if amount <= 0:
						return true
	
	# Create new stack(s) for remaining amount
	while amount > 0:
		# Find first empty slot
		var empty_slot = -1
		for i in range(max_slots):
			if items[i] == null:
				empty_slot = i
				break
		
		if empty_slot == -1:
			print("Cannot add item: Inventory full")
			return false  # No empty slots
		
		var stack_size = min(amount, max_stack if is_stackable else 1)
		
		items[empty_slot] = {
			"name": item_name,
			"icon": icon,
			"scene": item_scene,
			"mass": item_mass,
			"value": item_value,
			"stackable": is_stackable,
			"max_stack_size": max_stack,
			"stack_count": stack_size,
			"item_type": item_type,
			"item_level": item_level,
			"item_quality": item_quality,
			"item_subtype": item_subtype,
			"weapon_damage": weapon_damage,
			"armor_defense": armor_defense,
			"weapon_hand": weapon_hand  
		}
		
		amount -= stack_size
	
	inventory_changed.emit()
	_update_mass_signals()
	return true

func add_gold(amount: int):
	gold += amount
	gold_changed.emit(gold)

func remove_gold(amount: int) -> bool:
	if gold >= amount:
		gold -= amount
		gold_changed.emit(gold)
		return true
	return false

func get_gold() -> int:
	return gold

func remove_item_at_slot(slot_index: int) -> bool:
	if slot_index >= 0 and slot_index < max_slots and items[slot_index] != null:
		items[slot_index] = null
		inventory_changed.emit()
		_update_mass_signals()
		return true
	return false

func drop_item_at_slot(slot_index: int):
	if slot_index >= 0 and slot_index < max_slots and items[slot_index] != null:
		var item = items[slot_index]
		
		# Get player position and spawn slightly above ground
		if player_ref:
			# Drop in front of player slightly above ground
			var forward = -player_ref.global_transform.basis.z
			var drop_position = player_ref.global_position + forward * 1 + Vector3(0, 0.3, 0)
			
			# Actually spawn the item in the world if we have a scene reference
			if item.has("scene") and item.scene:
				var item_instance = item.scene.instantiate()
				
				if item_instance is Node3D:
					get_tree().current_scene.add_child(item_instance)
					
					# Set position
					item_instance.global_position = drop_position
					
					# Restore item properties from inventory data
					if item_instance is BaseItem:
						# Restore level and quality
						if item.has("item_level"):
							item_instance.item_level = item.item_level
						if item.has("item_quality"):
							item_instance.item_quality = item.item_quality
						if item.has("value"):
							item_instance.value = item.value
						
						# NEW: Restore item subtype
						if item.has("item_subtype"):
							item_instance.item_subtype = item.item_subtype
							# NEW: Restore weapon/armor stats
							if item.has("weapon_damage"):
								item_instance.weapon_damage = item.weapon_damage
							if item.has("armor_defense"):
								item_instance.armor_defense = item.armor_defense

						
						# Set stack count if item is stackable
						if item.get("stackable", false) and item.get("stack_count", 1) > 1:
							item_instance.stack_count = item.stack_count
						
						# Update properties after setting everything
						if item_instance.has_method("set_item_properties"):
							item_instance.set_item_properties(
								item.get("item_level", 1),
								item.get("item_quality", ItemQuality.Quality.NORMAL),
								item.get("value", 10)
							)
						elif item_instance.has_method("update_label_text"):
							item_instance.update_label_text()
					
					# Mark as just spawned so FOV doesn't hide it immediately
					if item_instance.has_method("set"):
						item_instance.set("just_spawned", true)
						item_instance.set("spawn_timer", 0.0)
			
			# Also emit signal for other systems that might need it
			item_dropped.emit(item, drop_position)
		
		# Remove from inventory by setting slot to null
		items[slot_index] = null
		inventory_changed.emit()
		_update_mass_signals()

func set_player(player: Node3D):
	player_ref = player

func get_item_at_slot(slot_index: int):
	if slot_index >= 0 and slot_index < items.size():
		return items[slot_index]
	return null

func get_items() -> Array:
	return items

func clear():
	items.clear()
	inventory_changed.emit()
	mass_changed.emit(get_total_mass(), soft_max_mass)

func get_total_mass() -> float:
	var total: float = 0.0
	
	# Add mass from inventory items
	for item in items:
		if item != null and item.has("mass"):
			var item_mass = item.mass
			var count = item.get("stack_count", 1)
			total += item_mass * count
	
	# Add mass from equipped items
	if has_node("/root/Equipment"):
		var equipped_items = Equipment.get_items()
		for item in equipped_items:
			if item != null and item.has("mass"):
				var item_mass = item.mass
				var count = item.get("stack_count", 1)
				total += item_mass * count
	
	return total

func get_total_value() -> int:
	var total: int = 0
	for item in items:
		if item != null and item.has("value"):
			var item_value = item.value
			var count = item.get("stack_count", 1)
			total += item_value * count
	return total

# Check if player is encumbered
func is_encumbered() -> bool:
	return get_total_mass() > soft_max_mass
