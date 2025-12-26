# res://systems/debug_manager.gd
extends Node

# Debug panel visibility
var debug_panel_visible: bool = false
var debug_label: Label

func _ready():
	# Create debug UI
	create_debug_ui()
	print("[DEBUG MANAGER] Ready - Press F1 for debug menu")

func _input(event):
	# Toggle debug panel with F1
	if event.is_action_pressed("ui_cancel") and Input.is_key_pressed(KEY_F1):
		toggle_debug_panel()
	
	# Quick test keys
	if event is InputEventKey and event.pressed:
		match event.keycode:
			KEY_F2:
				debug_check_loot_manager()
			KEY_F3:
				debug_preview_loot(5)
			KEY_F4:
				debug_spawn_test_loot()
			KEY_F5:
				debug_test_nearest_enemy()

func create_debug_ui():
	# Create a CanvasLayer for UI
	var canvas = CanvasLayer.new()
	canvas.name = "DebugCanvas"
	add_child(canvas)
	
	# Create background panel
	var panel = PanelContainer.new()
	panel.position = Vector2(10, 10)
	panel.size = Vector2(500, 300)
	panel.modulate = Color(0, 0, 0, 0.8)
	panel.visible = false
	canvas.add_child(panel)
	
	# Create label for debug text
	debug_label = Label.new()
	debug_label.text = "Debug Manager Ready"
	debug_label.add_theme_font_size_override("font_size", 14)
	panel.add_child(debug_label)
	
	# Store reference to panel
	set_meta("debug_panel", panel)

func toggle_debug_panel():
	var panel = get_meta("debug_panel")
	debug_panel_visible = !debug_panel_visible
	panel.visible = debug_panel_visible
	
	if debug_panel_visible:
		update_debug_text()

func update_debug_text():
	var text = "[DEBUG MANAGER]\n\n"
	text += "F1: Toggle Debug Panel\n"
	text += "F2: Check LootManager\n"
	text += "F3: Preview Loot (Level 5)\n"
	text += "F4: Spawn Test Loot\n"
	text += "F5: Test Nearest Enemy\n"
	text += "\n--- Press a key to run test ---\n"
	debug_label.text = text

# ===== LOOT SYSTEM DEBUG FUNCTIONS =====

func debug_check_loot_manager():
	print("\n" + "=".repeat(50))
	print("=== LOOT MANAGER CHECK ===")
	print("=".repeat(50))
	
	var loot_manager = get_node_or_null("/root/LootManager")
	if not loot_manager:
		print("❌ CRITICAL: LootManager not found!")
		print("   Fix: Project → Project Settings → Autoload")
		print("   Add: res://systems/loot_manager.gd as 'LootManager'")
		return
	
	print("✓ LootManager singleton found")
	print("Total items in database: %d" % loot_manager.all_items.size())
	
	if loot_manager.all_items.is_empty():
		print("\n❌ CRITICAL: No items in LootManager.all_items array!")
		print("   Fix: Select LootManager in scene tree")
		print("   Or: Edit loot_manager.gd and populate all_items in Inspector")
		return
	
	print("\n✓ Items loaded successfully!")
	print("\nFirst 10 items in database:")
	for i in range(min(10, loot_manager.all_items.size())):
		var item = loot_manager.all_items[i]
		if item:
			print("  %2d. %-20s (Lv.%2d, Weight:%.1f, Type:%s)" % [
				i + 1,
				item.item_name,
				item.base_item_level,
				item.base_weight,
				item.item_type
			])
			if not item.item_scene:
				print("      ⚠️  WARNING: No scene assigned!")
		else:
			print("  %2d. ❌ NULL ITEM" % (i + 1))
	
	print("\n" + "=".repeat(50))

func debug_preview_loot(enemy_level: int = 5):
	print("\n" + "=".repeat(50))
	print("=== LOOT PREVIEW (Enemy Level %d) ===" % enemy_level)
	print("=".repeat(50))
	
	var loot_manager = get_node_or_null("/root/LootManager")
	if not loot_manager:
		print("❌ LootManager not found!")
		return
	
	if loot_manager.all_items.is_empty():
		print("❌ No items in LootManager!")
		return
	
	# Try to load a loot profile
	var profile_path = "res://Systems/Loot/Enemies/enemy1.tres"
	var profile = load(profile_path)
	
	if not profile:
		print("❌ Couldn't load loot profile from: %s" % profile_path)
		print("   Create a LootProfile resource and save it there")
		print("   Or: Change the path in debug_manager.gd")
		return
	
	print("✓ Loaded profile: %s" % profile_path)
	print("  Drop chance: %.2f%%" % (profile.drop_chance * 100))
	print("  Level range: ±%d" % profile.level_range)
	print("  Item level multiplier: %.1fx" % profile.item_level_multiplier)
	
	var target_item_level = int(enemy_level * profile.item_level_multiplier)
	print("\nTarget item level: %d (enemy %d × %.1f)" % [
		target_item_level,
		enemy_level,
		profile.item_level_multiplier
	])
	
	var preview = loot_manager.preview_loot_pool(enemy_level, profile, 20)
	
	if preview.is_empty():
		print("\n❌ NO ELIGIBLE ITEMS FOUND!")
		print("   This means no items match the level range.")
		print("   Check your items' base_item_level values.")
		print("   Target: %d, Range: %d to %d" % [
			target_item_level,
			target_item_level - profile.level_range,
			target_item_level + profile.level_range
		])
		return
	
	print("\n✓ Found %d eligible items:\n" % preview.size())
	
	var total_weight = 0.0
	for entry in preview:
		total_weight += entry.weight
	
	for i in range(preview.size()):
		var entry = preview[i]
		var drop_chance = (entry.weight / total_weight) * 100
		print("%2d. %-20s (Base Lv.%-2d → Target Lv.%-2d) Weight:%.3f (%.1f%%)" % [
			i + 1,
			entry.item.item_name,
			entry.base_item_level,
			entry.target_item_level,
			entry.weight,
			drop_chance
		])
	
	print("\n" + "=".repeat(50))

func debug_spawn_test_loot():
	print("\n" + "=".repeat(50))
	print("=== SPAWNING TEST LOOT ===")
	print("=".repeat(50))
	
	var loot_manager = get_node_or_null("/root/LootManager")
	if not loot_manager:
		print("❌ LootManager not found!")
		return
	
	var profile_path = "res://enemies/profiles/goblin_loot_profile.tres"
	var profile = load(profile_path)
	if not profile:
		print("❌ Couldn't load loot profile!")
		return
	
	var enemy_level = 5
	print("Generating loot for level %d enemy..." % enemy_level)
	
	var loot_data = loot_manager.generate_loot(enemy_level, profile)
	
	if loot_data.is_empty():
		print("\n❌ No loot generated!")
		print("   Possible reasons:")
		print("   - Failed drop chance roll (%.0f%% chance)" % (profile.drop_chance * 100))
		print("   - No eligible items in level range")
		return
	
	print("\n✓ Generated %d items:" % loot_data.size())
	
	var player = get_tree().get_first_node_in_group("player")
	if not player:
		print("⚠️  No player found, spawning at origin")
	
	for i in range(loot_data.size()):
		var item_data = loot_data[i]
		var item: LootItem = item_data["item"]
		var item_level: int = item_data["item_level"]
		
		print("\n  Item %d: %s (level %d)" % [i + 1, item.item_name, item_level])
		
		if not item.item_scene:
			print("    ❌ No scene assigned to this item!")
			continue
		
		print("    Scene: %s" % item.item_scene.resource_path)
		
		var instance = item.item_scene.instantiate()
		
		if instance is BaseItem:
			instance.item_name = item.item_name
			instance.item_icon = item.icon
			instance.item_type = item.item_type
			instance.weight = item.weight
			instance.value = item.base_value
			instance.stackable = item.stackable
			instance.max_stack_size = item.max_stack_size
			instance.item_level = item_level
			print("    ✓ Configured as BaseItem")
		else:
			print("    ⚠️  Not a BaseItem: %s" % instance.get_class())
		
		get_tree().current_scene.add_child(instance)
		
		if player:
			var offset = Vector3(randf_range(-2, 2), 1, randf_range(-2, 2))
			instance.global_position = player.global_position + offset
			print("    ✓ Spawned near player at %s" % instance.global_position)
		else:
			instance.global_position = Vector3(0, 1, 0)
			print("    ✓ Spawned at origin")
		
		if instance.has_method("set_item_level"):
			instance.set_item_level(item_level)
	
	print("\n✓ All items spawned successfully!")
	print("=".repeat(50))

func debug_test_nearest_enemy():
	print("\n" + "=".repeat(50))
	print("=== TESTING NEAREST ENEMY ===")
	print("=".repeat(50))
	
	var enemies = get_tree().get_nodes_in_group("enemy")
	if enemies.is_empty():
		print("❌ No enemies found in scene!")
		print("   Make sure enemies are added to 'enemy' group")
		return
	
	var player = get_tree().get_first_node_in_group("player")
	var closest_enemy = null
	var closest_distance = INF
	
	if player:
		for enemy in enemies:
			var distance = player.global_position.distance_to(enemy.global_position)
			if distance < closest_distance:
				closest_distance = distance
				closest_enemy = enemy
	else:
		closest_enemy = enemies[0]
	
	if not closest_enemy:
		print("❌ Couldn't find enemy to test")
		return
	
	print("✓ Testing enemy: %s" % closest_enemy.name)
	print("  Display name: %s" % closest_enemy.display_name)
	print("  Enemy level: %d" % closest_enemy.enemy_level)
	print("  Has loot profile: %s" % (closest_enemy.loot_profile != null))
	
	if closest_enemy.loot_profile:
		var profile = closest_enemy.loot_profile
		print("\n  Profile details:")
		print("    Path: %s" % profile.resource_path)
		print("    Drop chance: %.0f%%" % (profile.drop_chance * 100))
		print("    Level range: ±%d" % profile.level_range)
		print("    Min/Max drops: %d-%d" % [profile.min_drops, profile.max_drops])
		print("    Item level multiplier: %.1fx" % profile.item_level_multiplier)
	else:
		print("\n  ❌ No loot profile assigned!")
		print("     Fix: Select enemy in scene, set 'Loot Profile' in Inspector")
	
	print("\n--- Forcing loot spawn ---")
	if closest_enemy.has_method("spawn_loot"):
		closest_enemy.spawn_loot()
	else:
		print("❌ Enemy doesn't have spawn_loot() method!")
	
	print("=".repeat(50))
