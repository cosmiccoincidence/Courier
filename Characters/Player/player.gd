extends CharacterBody3D
# Player

const SPEED = 5.0 # character speed
const JUMP_VELOCITY = 4.5

# God Mode stat buffs
const GOD_SPEED_MULT := 2.0
const GOD_CRIT_CHANCE := 1.0

# Encumbered penalties (only applied when not in god mode)
const ENCUMBERED_SPEED_MULT: float = 0.2  # 20% speed
const ENCUMBERED_ROTATION_MULT: float = 0.75  # 75% rotation speed

@onready var audio_vocal: AudioStreamPlayer3D = $AudioVocal
@onready var audio_combat: AudioStreamPlayer3D = $AudioCombat
@onready var cam: Camera3D = $Camera3D
@onready var hud: CanvasLayer = get_node("/root/World/UI/HUD")

# Stats
@export var stat_strength := 5
@export var stat_dexterity := 5


@export var rotation_speed := 5.0  # higher = faster turning
@export var sprint_multiplier := 3.0  # speed multiplier when sprinting
@export var sprint_stamina_cost: float = 1.5  # Stamina consumption per second while sprinting
@export var stamina_regen: float = 1.0  # How much stamina per interval
@export var stamina_regen_interval: float = 0.5  # Seconds between stamina regen
@export var health_regen: float = 1.0  # How much health per interval
@export var health_regen_interval: float = 10.0  # Seconds between health regen
@export var zoom_min := 5
@export var zoom_max := 30
@export var zoom_speed := 10.0
@export var zoom_smooth := 8.0
@export var max_health := 10
@export var max_stamina := 10
@export var crit_chance := 0.1      # 10%
@export var crit_multiplier: float = 2.0  # x2 damage

var god_mode := false
var god_zoom_max := 500.0  # Max zoom in god mode
var is_dying: bool = false
var is_encumbered: bool = false
var current_health: int
var current_stamina: float
var zoom_target := 30.0
var zoom_current := 30.0
var is_sprinting: bool = false
var stamina_regen_delay: float = 1.0 # delay in seconds to start regen after sprint has stopped
var time_since_sprint_stopped: float = 0.0
var time_since_last_stamina_regen: float = 0.0
var time_since_last_health_regen: float = 0.0

# Camera follow settings
var cam_offset: Vector3
var cam_fixed_basis: Basis

# Store originals so you can restore them later
var _original_speed: float
var _original_crit: float

# Dictionary of the character's SFX
var vocal_sounds = {
	"grunt": preload("res://Assets/Audio/Characters/Grunt.wav")
}
var combat_sounds = {
	"attack": preload("res://Assets/Audio/Characters/Attack.wav"),
	"hit": preload("res://Assets/Audio/Characters/Hit.wav")
}

var gravity = ProjectSettings.get_setting("physics/3d/default_gravity")

var nearby_enemy = null

func _ready():
	current_health = max_health
	current_stamina = max_stamina

	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

	# store camera's initial global rotation and offset from player
	cam_fixed_basis = cam.global_transform.basis.orthonormalized()
	cam_offset = cam.global_transform.origin - global_transform.origin
	
	# Register player with inventory
	Inventory.set_player(self)
	print("Player registered with Inventory system")
	
	# Connect to encumbered status signal
	Inventory.encumbered_status_changed.connect(_on_encumbered_status_changed)
	
	# Update HUD LAST (after everything is set up)
	if hud:
		await get_tree().process_frame
		hud.update_health(current_health, max_health)
		hud.update_stamina(current_stamina, max_stamina)

# Handle encumbered status changes
func _on_encumbered_status_changed(encumbered: bool):
	is_encumbered = encumbered
	
	# Always update HUD to show encumbered status (even in god mode, for tracking)
	if hud and hud.has_method("update_encumbered_status"):
		# Pass both encumbered status and whether effects are active
		var effects_active = is_encumbered and not god_mode
		hud.update_encumbered_status(is_encumbered, effects_active)

func apply_god_mode_stats():
	# Speed buff
	if god_mode:
		return {
			"speed_mult": GOD_SPEED_MULT,
			"crit_chance": GOD_CRIT_CHANCE
		}
	
	# Normal stats
	return {
		"speed_mult": 1.0,
		"crit_chance": crit_chance
	}

# Call this whenever health changes
func take_damage(amount: int):
	if god_mode:
		print("God Mode: Damage blocked")
		return
	
	current_health = max(0, current_health - amount)
	if hud:
		hud.update_health(current_health, max_health)
	
	play_vocal("grunt")
	
	if current_health <= 0:
		is_dying = true
		die()

# Call this whenever stamina changes
func use_stamina(amount: float):
	if god_mode:
		return  # Stamina never decreases
	
	current_stamina = max(0, current_stamina - amount)
	if hud:
		hud.update_stamina(current_stamina, max_stamina)

func _physics_process(delta):
	# Always update camera zoom (even when dead) - MOVED TO TOP
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
	
	# Check if player is trying to sprint and has stamina
	var wants_to_sprint = Input.is_action_pressed("sprint")
	var input_dir = Input.get_vector("left", "right", "up", "down")
	var is_moving = input_dir.length() > 0
	
	# NEW: Check if encumbered effects are active (encumbered AND not in god mode)
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
	
	# Regenerate stamina after delay
	if not is_sprinting and time_since_sprint_stopped >= stamina_regen_delay:
		if current_stamina < max_stamina:
			time_since_last_stamina_regen += delta
		
			# Only regenerate when interval is reached
			if time_since_last_stamina_regen >= stamina_regen_interval:
				current_stamina = min(max_stamina, current_stamina + stamina_regen)
				time_since_last_stamina_regen = 0.0  # Reset the interval timer
			
				if hud:
					hud.update_stamina(current_stamina, max_stamina)
	else:
		# Reset regen timer when sprinting or during delay
		time_since_last_stamina_regen = 0.0
	
	# Gravity
	if not is_on_floor():
		velocity.y -= gravity * delta
		
	zoom_current = lerp(zoom_current, zoom_target, 1.0 - exp(-zoom_smooth * delta))
	
	# Jump
	#if Input.is_action_just_pressed("jump") and is_on_floor():
	#	velocity.y = JUMP_VELOCITY

	# Quit
	if Input.is_action_just_pressed("quit"):
		get_tree().quit()

	# ---------------- MOVEMENT ----------------
	var direction = Vector3(input_dir.x, 0, input_dir.y).normalized()

	var stats = apply_god_mode_stats()
	# Determine base speed
	var current_speed := SPEED
	
	# Apply sprint multiplier
	if is_sprinting:
		current_speed *= sprint_multiplier

	# Apply god mode multiplier
	current_speed *= stats.speed_mult
	
	# NEW: Apply encumbered speed penalty (only if not in god mode)
	if encumbered_effects_active:
		current_speed *= ENCUMBERED_SPEED_MULT

	if direction:
		velocity.x = direction.x * current_speed
		velocity.z = direction.z * current_speed
	else:
		velocity.x = move_toward(velocity.x, 0, current_speed)
		velocity.z = move_toward(velocity.z, 0, current_speed)

	# ---------------- ROTATE TOWARD CURSOR (player only) ----------------
	_rotate_toward_mouse(encumbered_effects_active)


	# Move the body
	move_and_slide()

	# ---------------- CAMERA: follow position but KEEP rotation fixed ----------------
	_update_camera_global()


func _rotate_toward_mouse(apply_encumbered_penalty: bool = false):
	var mouse_pos = get_viewport().get_mouse_position()
	var from = cam.project_ray_origin(mouse_pos)
	var to = from + cam.project_ray_normal(mouse_pos) * 2000

	# FIXED: Instead of raycasting to tilemap, intersect with a plane at player's height
	# This works even when cursor is outside the tilemap!
	var hit_pos = intersect_ray_with_plane(from, to, global_position.y)
	
	if hit_pos == Vector3.ZERO:
		return  # Ray didn't intersect plane (shouldn't happen with top-down camera)

	var look_dir = hit_pos - global_transform.origin
	look_dir.y = 0
	if look_dir.length() < 0.001:
		return

	# Correct target yaw so forward (-Z) faces look_dir
	var target_angle = atan2(-look_dir.x, -look_dir.z)

	# Current player yaw
	var current_angle = rotation.y
	
	# NEW: Apply rotation speed with encumbered penalty
	var effective_rotation_speed = rotation_speed
	if apply_encumbered_penalty:
		effective_rotation_speed *= ENCUMBERED_ROTATION_MULT

	# Smoothly interpolate angles
	var new_angle = lerp_angle(current_angle, target_angle, effective_rotation_speed * get_physics_process_delta_time())

	# Apply new smooth rotation
	rotation.y = new_angle

func intersect_ray_with_plane(ray_origin: Vector3, ray_end: Vector3, plane_y: float) -> Vector3:
	# Intersect ray with horizontal plane at height plane_y
	var ray_dir = (ray_end - ray_origin).normalized()
	
	# Check if ray is parallel to plane (would never intersect)
	if abs(ray_dir.y) < 0.001:
		return Vector3.ZERO
	
	# Calculate intersection point
	# Plane equation: y = plane_y
	# Ray equation: point = origin + t * direction
	# Solve for t: plane_y = origin.y + t * direction.y
	var t = (plane_y - ray_origin.y) / ray_dir.y
	
	# Only valid if t is positive (intersection is in front of camera)
	if t < 0:
		return Vector3.ZERO
	
	var intersection = ray_origin + ray_dir * t
	return intersection

func _update_camera_global():
	# Always keep the original rotation
	var basis = cam_fixed_basis

	# Base offset direction stays the same, but magnitude changes with zoom
	var zoom_dir := cam_offset.normalized()

	# Move the camera back/forth along the offset direction
	var zoomed_pos := zoom_dir * zoom_current

	# Add a little upward lift based on zoom
	zoomed_pos.y += zoom_current * 0.4

	# Apply camera position
	var desired_origin = global_transform.origin + zoomed_pos
	cam.global_transform = Transform3D(basis, desired_origin)

# Attack enemy
func _on_area_3d_body_entered(body: Node3D) -> void:
	if body.is_in_group("enemy"):
		nearby_enemy = body

func _on_area_3d_body_exited(body: Node3D) -> void:
	if body == nearby_enemy:
		nearby_enemy = null

func _input(event): # Toggle God Mode with L
	if event is InputEventKey and event.pressed and event.keycode == KEY_L:
		god_mode = !god_mode
		if god_mode:
			print("=== GOD MODE ENABLED ===")
			print("  Speed: x", GOD_SPEED_MULT)
			print("  Crit: 100%")
			print("  Max Zoom: ", god_zoom_max)
			print("  Encumbered penalties: DISABLED")
		else:
			print("=== GOD MODE DISABLED ===")
			# Clamp zoom back to normal max if it's too high
			if zoom_target > zoom_max:
				zoom_target = zoom_max
				print("  Zoom clamped to ", zoom_max)
		
		# NEW: Refresh encumbered status when god mode changes
		if hud and hud.has_method("update_encumbered_status"):
			var effects_active = is_encumbered and not god_mode
			hud.update_encumbered_status(is_encumbered, effects_active)
	
	# Debug: Skip level with semicolon key
	if event is InputEventKey and event.pressed and event.keycode == KEY_SEMICOLON:
		# NEW: Check if map generation is in progress
		var world = get_tree().get_first_node_in_group("world")
		if world:
			var current_map = world.get_node_or_null("CurrentMap")
			if current_map and current_map.has_method("is_generation_in_progress"):
				if current_map.is_generation_in_progress():
					print("=== DEBUG: Cannot skip - map generation in progress ===")
					return
			
			print("=== DEBUG: Skipping to next level ===")
			var game_manager = world.get_node_or_null("GameManager")
			if game_manager and game_manager.has_method("_on_player_reached_exit"):
				game_manager._on_player_reached_exit()
	
	# Allow zoom even when dead - CHECK THIS FIRST
	if event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP:
			zoom_target -= zoom_speed
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			zoom_target += zoom_speed
		
		# Clamp based on god mode
		var current_max = god_zoom_max if god_mode else zoom_max
		zoom_target = clamp(zoom_target, zoom_min, current_max)
	
	# Self-heal with [ key
	if event is InputEventKey and event.pressed and event.keycode == KEY_BRACKETLEFT:
		if current_health < max_health:
			current_health = max_health
			if hud:
				hud.update_health(current_health, max_health)
			print("DEBUG: Player fully healed! HP: ", current_health, "/", max_health)
		else:
			print("DEBUG: Already at full health")
	
	# Block other inputs if dead
	if is_dying:
		return
	
	# Everything below only works when alive
	
	if event.is_action_pressed("attack"):
		if nearby_enemy:
			var stats = apply_god_mode_stats()
			var base_damage = 5
			var is_crit = randf() < stats.crit_chance
			var final_damage = base_damage

			if is_crit:
				final_damage = int(base_damage * crit_multiplier)
				print("Player took CRITICAL HIT!: ", final_damage)
			else:
				print("Player took damage: ", final_damage)
			print("Player's health updated: ", current_health)

			nearby_enemy.take_damage(final_damage, is_crit)
			play_combat("hit")
		else:
			play_combat("attack")
	
	if event.is_action_pressed("pickup"): 
		_try_pickup_item()

	# DEBUG: Test damage with P key
	if event.is_action_pressed("ui_text_backspace") or (event is InputEventKey and event.pressed and event.keycode == KEY_P):
		take_damage(1)
		print("Player took 1 damage. HP: ", current_health, "/", max_health)

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

# Play combat sound
func play_combat(name: String):
	if combat_sounds.has(name):
		audio_combat.stream = combat_sounds[name]
		audio_combat.play()

# Play vocal sound
func play_vocal(name: String):
	if vocal_sounds.has(name):
		audio_vocal.stream = vocal_sounds[name]
		audio_vocal.play()

func _try_pickup_item():
	var mouse_pos = get_viewport().get_mouse_position()
	var from = cam.project_ray_origin(mouse_pos)
	var to = from + cam.project_ray_normal(mouse_pos) * 1000
	
	var space = get_world_3d().direct_space_state
	var query = PhysicsRayQueryParameters3D.create(from, to)
	var result = space.intersect_ray(query)
	
	if result and result.collider:
		# Check if we hit an item's collision body
		var hit_node = result.collider
		
		# If we hit a child collision body, get the parent item
		if hit_node.get_parent() and hit_node.get_parent().has_method("pickup"):
			hit_node.get_parent().pickup()
		elif hit_node.has_method("pickup"):
			hit_node.pickup()
