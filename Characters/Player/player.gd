extends CharacterBody3D
# Player

# ===== CONSTANTS =====
const SPEED = 5.0

# God Mode buffs
const GOD_SPEED_MULT := 2.0
const GOD_CRIT_CHANCE := 1.0  # 100% crit in god mode
const GOD_CRIT_MULT := 2.0  # 2x damage multiplier in god mode

# Encumbered penalties (only applied when not in god mode)
const ENCUMBERED_SPEED_MULT: float = 0.2  # 20% speed
const ENCUMBERED_ROTATION_MULT: float = 0.75  # 75% rotation speed

# ===== NODE REFERENCES =====
@onready var audio_vocal: AudioStreamPlayer3D = $AudioVocal
@onready var audio_combat: AudioStreamPlayer3D = $AudioCombat
@onready var cam: Camera3D = $Camera3D
@onready var hud: CanvasLayer = get_node("/root/World/UI/HUD")

# ===== CORE STATS =====
@export_group("Core Stats")
@export var strength := 5
@export var dexterity := 5
@export var luck: float = 0.0  # Affects item quality rolls

# ===== ENERGY & RESISTENCES =====
@export_group("Health & Stamina")
@export var max_health := 10
@export var health_regen: float = 1.0  # HP per interval
@export var health_regen_interval: float = 10.0  # Seconds between regen

@export var max_stamina := 10
@export var stamina_regen: float = 1.0  # Stamina per interval
@export var stamina_regen_interval: float = 0.5  # Seconds between regen

@export var heat_resistence := 10
@export var cold_resistence := 10
@export var static_resistence := 10
@export var poison_resistence := 10

# ===== COMBAT STATS =====
@export_group("Combat")
@export var base_armor := 5  # Base armor/defense
@export var base_damage := 5  # Base attack damage
@export var base_attack_range := 1.5  # Base attack range in tiles
@export var base_attack_speed := 1.0  # Base attack speed multiplier (1.0 = normal)
@export var base_crit_chance := 0.1  # 10% base crit chance
@export var base_crit_multiplier: float = 1.0  # 1x damage on crit
@export var base_block_rating := 1.0  # Base block window length
@export var base_parry_window := 1.0  # Base parry window length

# Calculated combat stats (modified by gear/buffs/god mode)
var armor: int = 5
var damage: int = 5
var attack_range: float = 1.5
var attack_speed: float = 1.0
var crit_chance: float = 0.1
var crit_multiplier: float = 1.0
var block_rating: float = 1.0
var parry_window: float = 1.0

# ===== MOVEMENT =====
@export_group("Movement")
@export var rotation_speed := 5.0  # Higher = faster turning
@export var sprint_multiplier := 3.0  # Speed multiplier when sprinting
@export var sprint_stamina_cost: float = 1.5  # Stamina per second while sprinting

# ===== CAMERA =====
@export_group("Camera")
@export var zoom_min := 10
@export var zoom_max := 100  # Normal max zoom
@export var zoom_speed := 15.0
@export var zoom_smooth := 8.0

# ===== STATE VARIABLES =====
var god_mode := false
var god_zoom_max := 500.0  # Max zoom in god mode
var is_dying: bool = false
var is_encumbered: bool = false
var is_sprinting: bool = false

var current_health: int
var current_stamina: float

var zoom_target := 75
var zoom_current := 75

# Stamina regen timers
var stamina_regen_delay: float = 1.0  # Delay after sprint stops
var time_since_sprint_stopped: float = 0.0
var time_since_last_stamina_regen: float = 0.0

# Health regen timer
var time_since_last_health_regen: float = 0.0

# Camera follow
var cam_offset: Vector3
var cam_fixed_basis: Basis

# ===== AUDIO =====
var vocal_sounds = {
	"grunt": preload("res://Assets/Audio/Characters/Grunt.wav")
}
var combat_sounds = {
	"attack": preload("res://Assets/Audio/Characters/Attack.wav"),
	"hit": preload("res://Assets/Audio/Characters/Hit.wav")
}

# ===== OTHER =====
var gravity = ProjectSettings.get_setting("physics/3d/default_gravity")
var nearby_enemy = null


# ===== INITIALIZATION =====

func _ready():
	current_health = max_health
	current_stamina = max_stamina
	
	# Initialize combat stats
	_update_combat_stats()

	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

	# Store camera's initial global rotation and offset from player
	cam_fixed_basis = cam.global_transform.basis.orthonormalized()
	cam_offset = cam.global_transform.origin - global_transform.origin
	
	# Register player with inventory
	Inventory.set_player(self)
	print("Player registered with Inventory system")
	
	# Connect to encumbered status signal
	Inventory.encumbered_status_changed.connect(_on_encumbered_status_changed)
	
	# Connect to equipment changes
	Equipment.equipment_changed.connect(_on_equipment_changed)
	
	# Update HUD LAST (after everything is set up)
	if hud:
		await get_tree().process_frame
		hud.update_health(current_health, max_health)
		hud.update_stamina(current_stamina, max_stamina)

# ===== STAT CALCULATIONS =====

func _update_combat_stats():
	"""Recalculate combat stats based on base stats, equipment, buffs, and god mode"""
	# Get equipment stats
	var equip_stats = Equipment.get_equipment_stats()
	
	if god_mode:
		# God mode bonuses
		crit_chance = GOD_CRIT_CHANCE
		crit_multiplier = base_crit_multiplier * GOD_CRIT_MULT
		
		# Equipment still applies in god mode
		damage = base_damage + equip_stats.weapon_damage
		armor = base_armor + equip_stats.base_armor_rating
		
		# Use weapon stats if weapon equipped, otherwise use base
		if equip_stats.has_weapon:
			attack_range = equip_stats.weapon_range
			attack_speed = equip_stats.weapon_speed
			block_rating = equip_stats.weapon_block_rating
			parry_window = equip_stats.weapon_parry_window
		else:
			attack_range = base_attack_range
			attack_speed = base_attack_speed
			block_rating = base_block_rating
			parry_window = base_parry_window
	else:
		# Normal mode - apply equipment bonuses
		damage = base_damage + equip_stats.weapon_damage
		armor = base_armor + equip_stats.base_armor_rating
		
		# Use weapon stats if weapon equipped, otherwise use base
		if equip_stats.has_weapon:
			attack_range = equip_stats.weapon_range
			attack_speed = equip_stats.weapon_speed
			block_rating = equip_stats.weapon_block_rating
			parry_window = equip_stats.weapon_parry_window
			crit_chance = equip_stats.weapon_crit_chance
			crit_multiplier = equip_stats.weapon_crit_multiplier
		else:
			attack_range = base_attack_range
			attack_speed = base_attack_speed
			block_rating = base_block_rating
			parry_window = base_parry_window
			crit_chance = base_crit_chance
			crit_multiplier = base_crit_multiplier
		
		# TODO: Add buff bonuses
	
	# Debug output
	# print("=== STATS UPDATED ===")
	# print("  Damage: %d (base: %d + weapon: %d)" % [damage, base_damage, equip_stats.weapon_damage])
	# print("  Armor: %d (base: %d + armor: %d)" % [armor, base_armor, equip_stats.base_armor_rating])
	# print("  Range: %.1f" % attack_range)
	# print("  Speed: %.1fx" % attack_speed)
	# print("  Block Window: %.1fs" % block_rating)
	# print("  Parry Window: %.1fs" % parry_window)
	# print("  Crit: %.0f%% (x%.1f)" % [crit_chance * 100, crit_multiplier])

func get_total_luck() -> float:
	"""Get total luck including equipment and buffs"""
	var total = luck
	# TODO: Add luck from equipment
	# TODO: Add luck from buffs/debuffs
	return total

func get_effective_speed_mult() -> float:
	"""Get current speed multiplier based on god mode and encumbered status"""
	var mult = 1.0
	
	if god_mode:
		mult *= GOD_SPEED_MULT
	
	# Apply encumbered penalty (only if not in god mode)
	if is_encumbered and not god_mode:
		mult *= ENCUMBERED_SPEED_MULT
	
	return mult


# ===== ENCUMBERED STATUS =====

func _on_encumbered_status_changed(encumbered: bool):
	is_encumbered = encumbered
	
	# Update HUD to show encumbered status
	if hud and hud.has_method("update_encumbered_status"):
		var effects_active = is_encumbered and not god_mode
		hud.update_encumbered_status(is_encumbered, effects_active)


# ===== DAMAGE & HEALING =====

func take_damage(amount: int):
	if god_mode:
		print("God Mode: Damage blocked")
		return
	
	# Apply armor reduction
	# Formula: damage_taken = max(1, damage - armor)
	var damage_taken = max(1, amount - armor)
	
	current_health = max(0, current_health - damage_taken)
	
	print("Player took %d damage (%d reduced by %d armor)" % [damage_taken, amount, armor])
	
	if hud:
		hud.update_health(current_health, max_health)
	
	play_vocal("grunt")
	
	if current_health <= 0:
		is_dying = true
		die()

func use_stamina(amount: float):
	if god_mode:
		return  # Stamina never decreases in god mode
	
	current_stamina = max(0, current_stamina - amount)
	if hud:
		hud.update_stamina(current_stamina, max_stamina)

func die():
	if not is_dying:
		return
	
	print("Player died!")
	
	# Show death message
	if hud:
		hud.show_death_message()
	
	# Play death grunt
	if vocal_sounds.has("grunt"):
		audio_vocal.stream = vocal_sounds["grunt"]
		audio_vocal.pitch_scale = randf_range(0.95, 1.05)
		audio_vocal.play()
	
	# Hide the player mesh but keep the node
	for child in get_children():
		if child is MeshInstance3D:
			child.visible = false
		elif child is CollisionShape3D:
			child.disabled = true


# ===== PHYSICS & MOVEMENT =====

func _physics_process(delta):
	# Always update camera zoom (even when dead)
	zoom_current = lerp(zoom_current, zoom_target, 1.0 - exp(-zoom_smooth * delta))
	_update_camera_global()
	
	# Block everything else if dead
	if is_dying:
		return
	
	# Health regeneration
	if current_health < max_health:
		time_since_last_health_regen += delta
		if time_since_last_health_regen >= health_regen_interval:
			current_health = min(max_health, current_health + int(health_regen))
			time_since_last_health_regen = 0.0
			if hud:
				hud.update_health(current_health, max_health)
	
	# Sprint logic
	var wants_to_sprint = Input.is_action_pressed("sprint")
	var input_dir = Input.get_vector("left", "right", "up", "down")
	var is_moving = input_dir.length() > 0
	var encumbered_effects_active = is_encumbered and not god_mode
	
	# Can only sprint if moving, have stamina (or god mode), AND not encumbered (or god mode)
	if wants_to_sprint and is_moving and (current_stamina > 0 or god_mode) and not encumbered_effects_active:
		is_sprinting = true
		if not god_mode:
			use_stamina(sprint_stamina_cost * delta)
		time_since_sprint_stopped = 0.0
	else:
		is_sprinting = false
		time_since_sprint_stopped += delta
	
	# Stamina regeneration
	if not is_sprinting and time_since_sprint_stopped >= stamina_regen_delay:
		if current_stamina < max_stamina:
			time_since_last_stamina_regen += delta
			if time_since_last_stamina_regen >= stamina_regen_interval:
				current_stamina = min(max_stamina, current_stamina + stamina_regen)
				time_since_last_stamina_regen = 0.0
				if hud:
					hud.update_stamina(current_stamina, max_stamina)
	else:
		time_since_last_stamina_regen = 0.0
	
	# Gravity
	if not is_on_floor():
		velocity.y -= gravity * delta
	
	# Movement
	var direction = Vector3(input_dir.x, 0, input_dir.y).normalized()
	var current_speed := SPEED
	
	# Apply sprint multiplier
	if is_sprinting:
		current_speed *= sprint_multiplier
	
	# Apply speed modifiers (god mode, encumbered)
	current_speed *= get_effective_speed_mult()
	
	if direction:
		velocity.x = direction.x * current_speed
		velocity.z = direction.z * current_speed
	else:
		velocity.x = move_toward(velocity.x, 0, current_speed)
		velocity.z = move_toward(velocity.z, 0, current_speed)
	
	# Rotate toward mouse cursor
	_rotate_toward_mouse(encumbered_effects_active)
	
	# Move the body
	move_and_slide()
	
	# Update camera position
	_update_camera_global()


# ===== ROTATION & CAMERA =====

func _rotate_toward_mouse(apply_encumbered_penalty: bool = false):
	var mouse_pos = get_viewport().get_mouse_position()
	var from = cam.project_ray_origin(mouse_pos)
	var to = from + cam.project_ray_normal(mouse_pos) * 2000
	
	var hit_pos = intersect_ray_with_plane(from, to, global_position.y)
	
	if hit_pos == Vector3.ZERO:
		return
	
	var look_dir = hit_pos - global_transform.origin
	look_dir.y = 0
	if look_dir.length() < 0.001:
		return
	
	var target_angle = atan2(-look_dir.x, -look_dir.z)
	var current_angle = rotation.y
	
	# Apply rotation speed with encumbered penalty
	var effective_rotation_speed = rotation_speed
	if apply_encumbered_penalty:
		effective_rotation_speed *= ENCUMBERED_ROTATION_MULT
	
	var new_angle = lerp_angle(current_angle, target_angle, effective_rotation_speed * get_physics_process_delta_time())
	rotation.y = new_angle

func intersect_ray_with_plane(ray_origin: Vector3, ray_end: Vector3, plane_y: float) -> Vector3:
	var ray_dir = (ray_end - ray_origin).normalized()
	
	if abs(ray_dir.y) < 0.001:
		return Vector3.ZERO
	
	var t = (plane_y - ray_origin.y) / ray_dir.y
	
	if t < 0:
		return Vector3.ZERO
	
	var intersection = ray_origin + ray_dir * t
	return intersection

func _update_camera_global():
	var basis = cam_fixed_basis
	var zoom_dir := cam_offset.normalized()
	var zoomed_pos := zoom_dir * zoom_current
	zoomed_pos.y += zoom_current * 0.4
	var desired_origin = global_transform.origin + zoomed_pos
	cam.global_transform = Transform3D(basis, desired_origin)


# ===== COMBAT =====

func _on_area_3d_body_entered(body: Node3D) -> void:
	if body.is_in_group("enemy"):
		# Check if enemy is within attack range
		var distance = global_position.distance_to(body.global_position)
		if distance <= attack_range:
			nearby_enemy = body

func _on_area_3d_body_exited(body: Node3D) -> void:
	if body == nearby_enemy:
		nearby_enemy = null


# ===== INPUT HANDLING =====

func _input(event):
	# Camera zoom (works even when dead)
	if event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP:
			zoom_target -= zoom_speed
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			zoom_target += zoom_speed
		
		var current_max = god_zoom_max if god_mode else zoom_max
		zoom_target = clamp(zoom_target, zoom_min, current_max)
	
	# Block other inputs if dead
	if is_dying:
		return
	
	# Attack
	if event.is_action_pressed("attack"):
		if nearby_enemy:
			# Check if still in range (enemy might have moved)
			var distance = global_position.distance_to(nearby_enemy.global_position)
			if distance <= attack_range:
				var is_crit = randf() < crit_chance
				var final_damage = damage
				
				if is_crit:
					final_damage = int(damage * crit_multiplier)
					print("Player CRITICAL HIT: %d damage" % final_damage)
				else:
					print("Player hit for %d damage" % final_damage)
				
				nearby_enemy.take_damage(final_damage, is_crit)
				play_combat("hit")
			else:
				print("Enemy out of range (%.1f / %.1f)" % [distance, attack_range])
				play_combat("attack")
		else:
			play_combat("attack")
	
	# Pickup items
	if event.is_action_pressed("pickup"):
		_try_pickup_item()


# ===== INVENTORY =====

func _try_pickup_item():
	var mouse_pos = get_viewport().get_mouse_position()
	var from = cam.project_ray_origin(mouse_pos)
	var to = from + cam.project_ray_normal(mouse_pos) * 1000
	
	var space = get_world_3d().direct_space_state
	var query = PhysicsRayQueryParameters3D.create(from, to)
	var result = space.intersect_ray(query)
	
	if result and result.collider:
		var hit_node = result.collider
		
		if hit_node.get_parent() and hit_node.get_parent().has_method("pickup"):
			hit_node.get_parent().pickup()
		elif hit_node.has_method("pickup"):
			hit_node.pickup()

func _on_equipment_changed():
	"""Called when equipment changes - recalculate stats"""
	_update_combat_stats()

# ===== AUDIO =====

func play_combat(name: String):
	if combat_sounds.has(name):
		audio_combat.stream = combat_sounds[name]
		audio_combat.play()

func play_vocal(name: String):
	if vocal_sounds.has(name):
		audio_vocal.stream = vocal_sounds[name]
		audio_vocal.play()
