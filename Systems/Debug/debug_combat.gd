# debug_combat.gd
# Debug subsystem for combat testing
extends Node

# Reference to main debug manager
var debug_manager: Node

func _ready():
	debug_manager = get_node_or_null("/root/DebugManager")
	if debug_manager:
		# Connect to debug signals
		debug_manager.debug_toggled.connect(_on_debug_toggled)
	
	print("[DEBUG COMBAT] Ready")

func _on_debug_toggled(enabled: bool):
	"""Called when debug mode is toggled"""
	if not enabled:
		# Clean up any combat debug visualizations
		pass

func heal_player():
	"""Fully heal the player"""
	if not debug_manager or not debug_manager.debug_enabled:
		return
	
	var player = get_tree().get_first_node_in_group("player")
	if not player:
		print("❌ No player found in scene!")
		return
	
	if not "current_health" in player or not "max_health" in player:
		print("❌ Player missing health variables!")
		return
	
	if player.current_health >= player.max_health:
		print("⚕️  Already at full health (%d/%d)" % [player.current_health, player.max_health])
		return
	
	var old_health = player.current_health
	player.current_health = player.max_health
	
	# Update HUD - use the same method as player script
	var hud = player.get("hud")
	if hud and hud.has_method("update_health"):
		hud.update_health(player.current_health, player.max_health)
	else:
		# Fallback: try to find HUD in scene
		hud = get_node_or_null("/root/World/UI/HUD")
		if hud and hud.has_method("update_health"):
			hud.update_health(player.current_health, player.max_health)
	
	print("⚕️  Player healed: %d → %d HP" % [old_health, player.current_health])

func damage_player(amount: int = 1):
	"""Deal damage to the player"""
	if not debug_manager or not debug_manager.debug_enabled:
		return
	
	var player = get_tree().get_first_node_in_group("player")
	if not player:
		print("❌ No player found in scene!")
		return
	
	if not player.has_method("take_damage"):
		print("❌ Player missing take_damage() method!")
		return
	
	if player.get("god_mode") and player.god_mode:
		print("⚔️  God mode is active - damage blocked")
		return
	
	var old_health = player.current_health
	player.take_damage(amount)
	var new_health = player.current_health
	var actual_damage = old_health - new_health
	
	print("⚔️  Player took %d damage: %d → %d HP" % [actual_damage, old_health, new_health])
	
	if new_health <= 0:
		print("💀 Player died!")

func show_combat_stats():
	"""Display current combat stats"""
	if not debug_manager or not debug_manager.debug_enabled:
		return
	
	print("\n" + "=".repeat(50))
	print("⚔️  COMBAT STATS")
	print("=".repeat(50))
	
	var player = get_tree().get_first_node_in_group("player")
	if not player:
		print("❌ No player found!")
		print("=".repeat(50) + "\n")
		return
	
	print("Health: %d / %d" % [player.current_health, player.max_health])
	print("Stamina: %.1f / %.1f" % [player.current_stamina, player.max_stamina])
	print("\nBase Stats:")
	print("  Damage: %d (base) → %d (total)" % [player.base_damage, player.damage])
	print("  Armor: %d (base) → %d (total)" % [player.base_armor, player.armor])
	print("  Attack Range: %.1f (base) → %.1f (total)" % [player.base_attack_range, player.attack_range])
	print("  Attack Speed: %.1fx (base) → %.1fx (total)" % [player.base_attack_speed, player.attack_speed])
	print("\nCritical Hits:")
	print("  Chance: %.1f%% (base) → %.1f%% (total)" % [player.base_crit_chance * 100, player.crit_chance * 100])
	print("  Multiplier: %.1fx (base) → %.1fx (total)" % [player.base_crit_multiplier, player.crit_multiplier])
	print("\nDefensive:")
	print("  Block Window: %.2fs (base) → %.2fs (total)" % [player.base_block_rating, player.block_rating])
	print("  Parry Window: %.2fs (base) → %.2fs (total)" % [player.base_parry_window, player.parry_window])
	print("\nStatus:")
	print("  God Mode: %s" % ("ENABLED" if player.get("god_mode") else "Disabled"))
	print("  Encumbered: %s" % ("YES" if player.get("is_encumbered") else "No"))
	print("  Sprinting: %s" % ("YES" if player.get("is_sprinting") else "No"))
	
	print("=".repeat(50) + "\n")
