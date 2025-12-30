# debug_manager.gd
# Core debug system manager - handles debug state and delegates to subsystems
extends Node

# Debug state
var debug_enabled: bool = false
var keybind_panel_visible: bool = false

# References
var debug_ui: Control = null

signal debug_toggled(enabled: bool)
signal keybind_panel_toggled(visible: bool)

func _ready():
	print("[DEBUG MANAGER] Ready - Press F1 to enable debug mode")
	
	# Create debug UI
	_setup_debug_ui()

func _input(event):
	if not event is InputEventKey or not event.pressed:
		return
	
	match event.keycode:
		KEY_F1:
			toggle_debug_system()
		KEY_F2:
			if debug_enabled:
				toggle_keybind_panel()
		KEY_F3:
			if debug_enabled:
				toggle_god_mode()
		KEY_F4:
			if debug_enabled:
				skip_level()
		KEY_BACKSLASH:
			if debug_enabled:
				# Delegate to debug_loot subsystem
				var debug_loot = get_node_or_null("DebugLoot")
				if debug_loot and debug_loot.has_method("spawn_test_loot"):
					debug_loot.spawn_test_loot()
				else:
					print("⚠️  DebugLoot subsystem not found")
		KEY_BRACKETLEFT:
			if debug_enabled:
				# Delegate to debug_combat subsystem
				var debug_combat = get_node_or_null("DebugCombat")
				if debug_combat and debug_combat.has_method("heal_player"):
					debug_combat.heal_player()
				else:
					print("⚠️  DebugCombat subsystem not found")
		KEY_BRACKETRIGHT:
			if debug_enabled:
				# Delegate to debug_combat subsystem
				var debug_combat = get_node_or_null("DebugCombat")
				if debug_combat and debug_combat.has_method("damage_player"):
					debug_combat.damage_player()
				else:
					print("⚠️  DebugCombat subsystem not found")

func toggle_debug_system():
	"""Toggle the entire debug system on/off"""
	debug_enabled = !debug_enabled
	
	if debug_enabled:
		print("\n" + "=".repeat(50))
		print("🔧 DEBUG MODE ENABLED")
		print("=".repeat(50))
		print("F1: Toggle Debug Mode")
		print("F2: Show/Hide Keybind Panel")
		print("=".repeat(50) + "\n")
		
		# Show enabled indicator
		if debug_ui:
			debug_ui.show_debug_enabled()
	else:
		print("\n🔧 DEBUG MODE DISABLED\n")
		
		# Hide all debug UI
		keybind_panel_visible = false
		if debug_ui:
			debug_ui.hide_all()
	
	debug_toggled.emit(debug_enabled)

func toggle_keybind_panel():
	"""Toggle the keybind reference panel"""
	if not debug_enabled:
		return
	
	keybind_panel_visible = !keybind_panel_visible
	
	if debug_ui:
		if keybind_panel_visible:
			debug_ui.show_keybind_panel()
		else:
			debug_ui.hide_keybind_panel()
	
	keybind_panel_toggled.emit(keybind_panel_visible)

func toggle_god_mode():
	"""Toggle god mode for the player"""
	if not debug_enabled:
		return
	
	var player = get_tree().get_first_node_in_group("player")
	if not player:
		print("❌ No player found in scene!")
		return
	
	if not "god_mode" in player:
		print("❌ Player doesn't have god_mode variable!")
		return
	
	# Toggle god mode
	player.god_mode = !player.god_mode
	
	# Recalculate player stats
	if player.has_method("_update_combat_stats"):
		player._update_combat_stats()
	
	# Update UI display
	if debug_ui:
		if player.god_mode:
			debug_ui.show_god_mode(player)
		else:
			debug_ui.hide_god_mode()
	
	# Print to console
	if player.god_mode:
		print("\n" + "=".repeat(50))
		print("⚡ GOD MODE ENABLED")
		print("=".repeat(50))
		print("  Speed: x%.1f" % player.GOD_SPEED_MULT)
		print("  Crit Chance: %.0f%%" % (player.GOD_CRIT_CHANCE * 100))
		print("  Crit Multiplier: x%.1f" % player.GOD_CRIT_MULT)
		print("  Max Zoom: %.0f" % player.god_zoom_max)
		print("  Encumbered penalties: DISABLED")
		print("  Stamina cost: DISABLED")
		print("  Damage taken: BLOCKED")
		print("=".repeat(50) + "\n")
	else:
		print("\n⚡ GOD MODE DISABLED\n")
		
		# Clamp zoom if it exceeds normal max
		if player.zoom_target > player.zoom_max:
			player.zoom_target = player.zoom_max
	
	# Refresh encumbered status UI
	if player.has_method("_on_encumbered_status_changed"):
		player._on_encumbered_status_changed(player.is_encumbered)

func skip_level():
	"""Skip to the next map level"""
	if not debug_enabled:
		return
	
	print("\n" + "=".repeat(50))
	print("⏭️  SKIPPING TO NEXT LEVEL")
	print("=".repeat(50))
	
	var world = get_tree().get_first_node_in_group("world")
	if not world:
		print("❌ World not found!")
		print("   Make sure world node is in 'world' group")
		print("=".repeat(50) + "\n")
		return
	
	var current_map = world.get_node_or_null("CurrentMap")
	if current_map and current_map.has_method("is_generation_in_progress"):
		if current_map.is_generation_in_progress():
			print("❌ Cannot skip - map generation in progress!")
			print("   Wait for map to finish generating")
			print("=".repeat(50) + "\n")
			return
	
	var game_manager = world.get_node_or_null("GameManager")
	if not game_manager:
		print("❌ GameManager not found!")
		print("   Expected at: World/GameManager")
		print("=".repeat(50) + "\n")
		return
	
	if not game_manager.has_method("_on_player_reached_exit"):
		print("❌ GameManager missing _on_player_reached_exit() method!")
		print("=".repeat(50) + "\n")
		return
	
	print("✓ Triggering level transition...")
	game_manager._on_player_reached_exit()
	print("=".repeat(50) + "\n")

func _setup_debug_ui():
	"""Create the debug UI node"""
	var ui_scene_path = "res://Systems/Debug/debug_ui.tscn"
	
	if ResourceLoader.exists(ui_scene_path):
		var ui_scene = load(ui_scene_path)
		debug_ui = ui_scene.instantiate()
		add_child(debug_ui)
	else:
		push_error("❌ Debug UI scene not found at: %s" % ui_scene_path)
		push_error("   Create debug_ui.tscn in res://Systems/Debug/")
