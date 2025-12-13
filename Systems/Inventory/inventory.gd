extends Node
# Inventory System

var items: Array = []
var max_slots: int = 20
var player_ref: Node3D = null  # Reference to player for drop position

# Weight system
var soft_max_weight: float = 10.0
var hard_max_weight: float = 11.0  # Will be calculated

# Gold system
var gold: int = 0

signal inventory_changed
signal item_dropped(item_data, position)
signal weight_changed(current_weight, max_weight)
signal gold_changed(amount)
signal encumbered_status_changed(is_encumbered)  # NEW: Signal for encumbered status

func _ready():
	# Calculate hard max weight
	hard_max_weight = soft_max_weight * 1.1

# Store reference to item scenes for dropping
var item_scene_lookup: Dictionary = {}

func add_item(item_name: String, icon: Texture2D = null, item_scene: PackedScene = null, item_weight: float = 1.0, item_value: int = 10, is_stackable: bool = false, max_stack: int = 99, amount: int = 1) -> bool:
	# Special handling for gold - add directly to gold counter
	if item_name.to_lower() == "gold" or item_name.to_lower() == "coin":
		add_gold(amount)
		return true
	
	# NEW: Calculate what the weight would be if we add this item
	var current_weight = get_total_weight()
	var new_item_weight = item_weight * amount
	var projected_weight = current_weight + new_item_weight
	
	# NEW: Check if adding would exceed hard max weight
	if projected_weight > hard_max_weight:
		print("Cannot add item: Would exceed maximum carry weight (", projected_weight, "/", hard_max_weight, ")")
		return false
	
	# If stackable, try to add to existing stack first
	if is_stackable:
		for item in items:
			if item.name == item_name and item.has("stackable") and item.stackable:
				# Found existing stack - add to it
				var space_in_stack = item.max_stack_size - item.stack_count
				var amount_to_add = min(amount, space_in_stack)
				
				if amount_to_add > 0:
					item.stack_count += amount_to_add
					amount -= amount_to_add
					inventory_changed.emit()
					_update_weight_signals()
					
					# If we added everything, we're done
					if amount <= 0:
						return true
	
	# Create new stack(s) for remaining amount
	while amount > 0:
		if items.size() >= max_slots:
			print("Cannot add item: Inventory full")
			return false
		
		var stack_size = min(amount, max_stack if is_stackable else 1)
		
		items.append({
			"name": item_name,
			"icon": icon,
			"scene": item_scene,
			"weight": item_weight,
			"value": item_value,
			"stackable": is_stackable,
			"max_stack_size": max_stack,
			"stack_count": stack_size
		})
		
		amount -= stack_size
	
	inventory_changed.emit()
	_update_weight_signals()
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
	if slot_index >= 0 and slot_index < items.size():
		var item = items[slot_index]
		items.remove_at(slot_index)
		inventory_changed.emit()
		_update_weight_signals()
		return true
	return false

func drop_item_at_slot(slot_index: int):
	if slot_index >= 0 and slot_index < items.size():
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
					
					# Set stack count if item is stackable
					if item.get("stackable", false) and item.get("stack_count", 1) > 1:
						if item_instance.has_method("set"):
							item_instance.set("stack_count", item.stack_count)
						# Update label to show stack count
						if item_instance.has_method("update_label_text"):
							item_instance.update_label_text()
					
					# Mark as just spawned so FOV doesn't hide it immediately
					if item_instance.has_method("set"):
						item_instance.set("just_spawned", true)
						item_instance.set("spawn_timer", 0.0)
			
			# Also emit signal for other systems that might need it
			item_dropped.emit(item, drop_position)
		
		# Remove from inventory
		remove_item_at_slot(slot_index)

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
	_update_weight_signals()

func get_total_weight() -> float:
	var total: float = 0.0
	for item in items:
		if item.has("weight"):
			var item_weight = item.weight
			var count = item.get("stack_count", 1)
			total += item_weight * count
	return total

func get_total_value() -> int:
	var total: int = 0
	for item in items:
		if item.has("value"):
			var item_value = item.value
			var count = item.get("stack_count", 1)
			total += item_value * count
	return total

# NEW: Check if player is encumbered
func is_encumbered() -> bool:
	return get_total_weight() > soft_max_weight

# NEW: Helper function to emit weight and encumbered signals
func _update_weight_signals():
	var current_weight = get_total_weight()
	weight_changed.emit(current_weight, soft_max_weight)
	encumbered_status_changed.emit(is_encumbered())
