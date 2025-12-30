extends Node
# inventory.gd

var items: Array = []
var max_slots: int = 32  # Match the UI grid (4 columns × 8 rows)
var player_ref: Node3D = null  # Reference to player for drop position

# Mass system
var soft_max_mass: float = 10.0
var hard_max_mass: float = 11.0  # Calculated below in _redy (currently +10%)

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

func add_item(item_data: Dictionary) -> bool:
	"""
	Add item using a dictionary of properties.
	
	Required keys:
	- name: String
	- mass: float
	
	Common keys:
	- icon: Texture2D
	- scene: PackedScene
	- value: int
	- stackable: bool
	- max_stack_size: int
	- amount: int (how many to add, default: 1)
	
	Optional weapon/armor keys:
	- item_type, item_level, item_quality, item_subtype
	- weapon_damage, armor_rating, weapon_hand
	- weapon_range, weapon_speed
	- weapon_block_rating, weapon_parry_window
	- weapon_crit_chance, weapon_crit_multiplier
	"""
	var item_name = item_data.get("name", "Unknown Item")
	var amount = item_data.get("amount", 1)
	var item_mass = item_data.get("mass", 1.0)
	var is_stackable = item_data.get("stackable", false)
	var max_stack = item_data.get("max_stack_size", 99)
	
	# Special handling for gold
	if item_name.to_lower() == "gold":
		add_gold(amount)
		return true
	
	# Calculate projected mass
	var current_mass = get_total_mass()
	var new_item_mass = item_mass * amount
	var projected_mass = current_mass + new_item_mass
	
	# Check mass limit
	if projected_mass > hard_max_mass:
		print("Cannot add item: Would exceed maximum carry mass (", projected_mass, "/", hard_max_mass, ")")
		return false
	
	# Try to stack with existing items
	if is_stackable:
		for item in items:
			if item != null and item.name == item_name and item.get("stackable", false):
				var space_in_stack = item.max_stack_size - item.stack_count
				var amount_to_add = min(amount, space_in_stack)
				
				if amount_to_add > 0:
					item.stack_count += amount_to_add
					amount -= amount_to_add
					inventory_changed.emit()
					_update_mass_signals()
					
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
			return false
		
		var stack_size = min(amount, max_stack if is_stackable else 1)
		
		# Create item entry from dictionary
		items[empty_slot] = {
			"name": item_name,
			"icon": item_data.get("icon"),
			"scene": item_data.get("scene"),
			"mass": item_mass,
			"durability": item_data.get("durability", 100),
			"value": item_data.get("value", 0),
			"stackable": is_stackable,
			"max_stack_size": max_stack,
			"stack_count": stack_size,
			"item_type": item_data.get("item_type", ""),
			"item_level": item_data.get("item_level", 1),
			"item_quality": item_data.get("item_quality", 1),
			"item_subtype": item_data.get("item_subtype", ""),
			"weapon_damage": item_data.get("weapon_damage", 0),
			"armor_rating": item_data.get("armor_rating", 0),
			"weapon_hand": item_data.get("weapon_hand", 0),
			"weapon_range": item_data.get("weapon_range", 2.0),
			"weapon_speed": item_data.get("weapon_speed", 1.0),
			"weapon_block_rating": item_data.get("weapon_block_rating", 0.0),
			"weapon_parry_window": item_data.get("weapon_parry_window", 0.0),
			"weapon_crit_chance": item_data.get("weapon_crit_chance", 0.0),
			"weapon_crit_multiplier": item_data.get("weapon_crit_multiplier", 1.0)
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
						# Restore basic properties
						if item.has("name"):
							item_instance.item_name = item.name
						if item.has("icon"):
							item_instance.item_icon = item.icon
						if item.has("item_type"):
							item_instance.item_type = item.item_type
						if item.has("item_subtype"):
							item_instance.item_subtype = item.item_subtype
						if item.has("mass"):
							item_instance.mass = item.mass
						if item.has("durability"):
							item_instance.durability = item.durability
						if item.has("value"):
							item_instance.value = item.value
						if item.has("stackable"):
							item_instance.stackable = item.stackable
						if item.has("max_stack_size"):
							item_instance.max_stack_size = item.max_stack_size
						
						# Restore level and quality
						if item.has("item_level"):
							item_instance.item_level = item.item_level
						if item.has("item_quality"):
							item_instance.item_quality = item.item_quality
						
						# Restore weapon/armor stats
						if item.has("weapon_damage"):
							item_instance.weapon_damage = item.weapon_damage
						if item.has("armor_rating"):
							item_instance.armor_rating = item.armor_rating
						if item.has("weapon_hand"):
							item_instance.weapon_hand = item.weapon_hand
						if item.has("weapon_range"):
							item_instance.weapon_range = item.weapon_range
						if item.has("weapon_speed"):
							item_instance.weapon_speed = item.weapon_speed
						if item.has("weapon_block_rating"):
							item_instance.weapon_block_rating = item.weapon_block_rating
						if item.has("weapon_parry_window"):
							item_instance.weapon_parry_window = item.weapon_parry_window
						if item.has("weapon_crit_chance"):
							item_instance.weapon_crit_chance = item.weapon_crit_chance
						if item.has("weapon_crit_multiplier"):
							item_instance.weapon_crit_multiplier = item.weapon_crit_multiplier
						
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
