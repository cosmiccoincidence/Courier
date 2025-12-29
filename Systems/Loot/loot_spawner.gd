# loot_spawner.gd
# Shared utility for spawning loot items in the world
# Used by both enemies and chests to avoid code duplication
class_name LootSpawner
extends RefCounted

static func spawn_loot_item(item_data: Dictionary, spawn_position: Vector3, parent_node: Node) -> void:
	"""
	Spawn a single loot item in the world.
	
	Parameters:
	- item_data: Dictionary containing item info from LootManager
	- spawn_position: Vector3 world position to spawn the item
	- parent_node: Node to add the spawned item to (usually current_scene)
	"""
	var item: LootItem = item_data["item"]
	var item_level: int = item_data["item_level"]
	var item_quality: int = item_data["item_quality"]
	var item_value: int = item_data["item_value"]
	var stack_size: int = item_data.get("stack_size", 1)
	
	if not item or not item.item_scene:
		push_warning("LootSpawner: Invalid item or missing scene")
		return
	
	# Instantiate the item
	var loot_instance = item.item_scene.instantiate()
	
	if not loot_instance:
		push_warning("LootSpawner: Failed to instantiate item scene")
		return
	
	# Add to scene first
	parent_node.add_child(loot_instance)
	
	# Set position with slight randomness
	var random_offset = Vector3(randf_range(-0.3, 0.3), 0, randf_range(-0.3, 0.3))
	loot_instance.global_position = spawn_position + random_offset
	
	if loot_instance is BaseItem:
		# Copy base properties from LootItem resource
		loot_instance.item_name = item.item_name
		loot_instance.item_icon = item.icon
		loot_instance.item_type = item.item_type
		loot_instance.item_subtype = item.item_subtype
		loot_instance.mass = item.mass
		loot_instance.stackable = item.stackable
		loot_instance.max_stack_size = item.max_stack_size
		
		# Copy weapon stats if weapon
		if item.item_type.to_lower() == "weapon":
			loot_instance.weapon_hand = item.weapon_hand
			loot_instance.weapon_range = item.weapon_range
			loot_instance.weapon_speed = item.weapon_speed
			loot_instance.weapon_block_window = item.weapon_block_window
			loot_instance.weapon_parry_window = item.weapon_parry_window
		
		# Set rolled properties (level, quality, value)
		loot_instance.item_level = item_level
		loot_instance.item_quality = item_quality
		loot_instance.value = item_value
		
		# Set stack size if stackable
		if item.stackable and stack_size > 1:
			loot_instance.stack_count = stack_size
		
		# Update label to reflect stack and quality
		if loot_instance.has_method("update_label_text"):
			loot_instance.update_label_text()
	
	# Roll weapon/armor stats if applicable
	if item.item_type.to_lower() == "weapon" and item.min_weapon_damage > 0:
		var weapon_damage = WeaponStatRoller.roll_weapon_damage(
			item.min_weapon_damage,
			item.max_weapon_damage,
			item_level,
			item_quality
		)
		if "weapon_damage" in loot_instance:
			loot_instance.weapon_damage = weapon_damage
		print("  Rolled weapon damage: ", weapon_damage, " (base: ", item.min_weapon_damage, "-", item.max_weapon_damage, ")")
	
	# Roll armor defense for armor OR shields (weapon type with shield subtype)
	var is_armor = item.item_type.to_lower() == "armor"
	var is_shield = item.item_type.to_lower() == "weapon" and item.item_subtype.to_lower() == "shield"
	
	if (is_armor or is_shield) and item.base_armor_defense > 0:
		var armor_defense = ArmorStatRoller.roll_armor_defense(
			item.base_armor_defense,
			item_level,
			item_quality
		)
		if "armor_defense" in loot_instance:
			loot_instance.armor_defense = armor_defense
		print("  Rolled armor defense: ", armor_defense, " (base: ", item.base_armor_defense, ")")


static func spawn_all_loot(loot_profile: LootProfile, enemy_level: int, spawn_position: Vector3, parent_node: Node, player: Node = null) -> void:
	"""
	Generate and spawn all loot from a loot profile.
	
	Parameters:
	- loot_profile: LootProfile resource defining what can drop
	- enemy_level: Level of enemy/chest for scaling
	- spawn_position: Vector3 world position to spawn items
	- parent_node: Node to add spawned items to
	- player: Optional player reference for luck calculation
	"""
	if not loot_profile:
		return
	
	# Get LootManager autoload singleton
	var loot_manager = parent_node.get_node_or_null("/root/LootManager")
	
	if not loot_manager:
		push_error("LootSpawner: LootManager not found at /root/LootManager!")
		return
	
	# Get player luck stat
	var player_luck = 0.0
	if player:
		if player.has_method("get_total_luck"):
			player_luck = player.get_total_luck()
		elif "luck" in player:
			player_luck = player.luck
	
	# Generate loot based on enemy_level and player_luck
	var loot_data = loot_manager.generate_loot(enemy_level, loot_profile, player_luck)
	
	# Spawn each item
	for item_data in loot_data:
		spawn_loot_item(item_data, spawn_position, parent_node)
