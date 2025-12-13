extends CharacterBody3D
class_name EnemyBase

@onready var audio_vocal: AudioStreamPlayer3D = $AudioVocal
@onready var audio_combat: AudioStreamPlayer3D = $AudioCombat

# NEW: Loot system using LootTable resource
@export var loot_table: LootTable
@export var legacy_item_scenes: Array[PackedScene] = []  # Keep for backwards compatibility
@export var use_legacy_loot := false  # Toggle between old and new system

@export var display_name: String = "Enemy"
@export var max_health := 10
@export var damage_amount := 2
@export var crit_chance := 0.1
@export var crit_multiplier := 2.0
@export var rotation_speed := 50.0
@export var combat_rotation_speed := 150.0
@export var rotation_change_interval := 2.0

@export var detection_range := 5.0
@export var aggro_range := 20.0
@export var attack_range := 2.0
@export var move_speed := 5.0
@export var attack_cooldown := 1.0

@export var vocal_sounds := {}
@export var combat_sounds := {}

signal health_changed(new_health: int, max_health: int)
signal died()

enum State { IDLE, ALERT, AGGRO, ATTACKING }
var current_state = State.IDLE
var player: CharacterBody3D = null
var is_dying: bool = false
var current_health: int
var target_yaw := 0.0
var time_since_last_change := 0.0
var time_since_last_attack := 0.0

var gravity = ProjectSettings.get_setting("physics/3d/default_gravity")

func _ready():
	if vocal_sounds.is_empty():
		vocal_sounds = {
			"grunt": preload("res://Assets/Audio/Characters/Grunt.wav")
		}
	if combat_sounds.is_empty():
		combat_sounds = {
			"attack": preload("res://Assets/Audio/Characters/Attack.wav"),
			"hit": preload("res://Assets/Audio/Characters/Hit.wav")
		}
	
	randomize()
	target_yaw = randf_range(0, 360)
	current_health = max_health
	
	player = get_tree().get_first_node_in_group("player")

func _physics_process(delta):
	if is_dying:
		return
	
	if not is_on_floor():
		velocity.y -= gravity * delta
	
	if player:
		var distance_to_player = global_position.distance_to(player.global_position)
		
		match current_state:
			State.IDLE:
				idle_behavior(delta, distance_to_player)
			State.ALERT:
				alert_behavior(delta, distance_to_player)
			State.AGGRO:
				aggro_behavior(delta, distance_to_player)
			State.ATTACKING:
				attacking_behavior(delta, distance_to_player)
	else:
		idle_behavior(delta, 999)
	
	move_and_slide()

func idle_behavior(delta: float, distance: float):
	time_since_last_change += delta
	if time_since_last_change >= rotation_change_interval:
		time_since_last_change = 0
		target_yaw = fposmod(rotation_degrees.y + randf_range(-90, 90), 360.0)
	
	smooth_rotate_to_yaw(delta)
	
	if distance <= detection_range:
		current_state = State.ALERT

func alert_behavior(delta: float, distance: float):
	look_at_player()
	smooth_rotate_to_yaw(delta, combat_rotation_speed)
	
	if distance > detection_range:
		current_state = State.IDLE

func aggro_behavior(delta: float, distance: float):
	look_at_player()
	smooth_rotate_to_yaw(delta, combat_rotation_speed)
	
	if distance > attack_range:
		var direction = (player.global_position - global_position).normalized()
		direction.y = 0
		velocity.x = direction.x * move_speed
		velocity.z = direction.z * move_speed
	else:
		velocity.x = 0
		velocity.z = 0
		current_state = State.ATTACKING
	
	if distance > aggro_range:
		current_state = State.IDLE
		velocity.x = 0
		velocity.z = 0

func attacking_behavior(delta: float, distance: float):
	look_at_player()
	smooth_rotate_to_yaw(delta, combat_rotation_speed)
	velocity.x = 0
	velocity.z = 0
	
	time_since_last_attack += delta
	
	if distance <= attack_range and time_since_last_attack >= attack_cooldown:
		attack_player()
		time_since_last_attack = 0
	
	if distance > attack_range:
		current_state = State.AGGRO
	
	if distance > aggro_range:
		current_state = State.IDLE

func look_at_player():
	if not player:
		return
	
	var look_dir = player.global_position - global_position
	look_dir.y = 0
	
	if look_dir.length() > 0.001:
		target_yaw = rad_to_deg(atan2(-look_dir.x, -look_dir.z))

func smooth_rotate_to_yaw(delta: float, speed: float = rotation_speed):
	var current_yaw = rotation_degrees.y
	var difference = fposmod((target_yaw - current_yaw + 180.0), 360.0) - 180.0
	var step = speed * delta
	
	if abs(difference) < step:
		rotation_degrees.y = target_yaw
	else:
		rotation_degrees.y += step * sign(difference)

func attack_player():
	if not player or player.is_dying:
		return
	
	var distance_to_player = global_position.distance_to(player.global_position)
	
	if distance_to_player <= attack_range:
		play_combat("hit")
		
		if player.has_method("take_damage"):
			player.take_damage(damage_amount)
	else:
		play_combat("attack")

func play_combat(name: String):
	if combat_sounds.has(name):
		audio_combat.stream = combat_sounds[name]
		audio_combat.play()

func play_vocal(name: String):
	if vocal_sounds.has(name):
		audio_vocal.stream = vocal_sounds[name]
		audio_vocal.play()

func take_damage(amount: int, is_crit: bool = false):
	if is_dying:
		return
	
	current_state = State.AGGRO
	
	current_health -= amount
	current_health = max(0, current_health)
	spawn_damage_number(amount, is_crit)
	
	# EMIT SIGNAL - notify tooltip system of HP change
	health_changed.emit(current_health, max_health)
	
	if is_crit:
		print(display_name, " took CRITICAL damage: ", amount)
	else:
		print(display_name, " took damage: ", amount)
	print(display_name, "'s HP updated: ", current_health)
	
	play_vocal("grunt")
	
	if current_health <= 0:
		is_dying = true
		call_deferred("die")

func spawn_damage_number(amount: int, is_crit: bool=false):
	var dmg_scene = preload("res://Systems/UserInterface/damage_number.tscn")
	var dmg_instance = dmg_scene.instantiate()
	
	add_child(dmg_instance)
	dmg_instance.position = Vector3(0, 2, 0)
	
	dmg_instance.setup(amount, is_crit)

func die():
	if is_dying == false:
		return
	
	if vocal_sounds.has("grunt"):
		audio_vocal.stream = vocal_sounds["grunt"]
		audio_vocal.pitch_scale = randf_range(0.95, 1.05)
		audio_vocal.play()
	
	var death_delay := 0.0
	if audio_vocal.stream:
		death_delay = audio_vocal.stream.get_length()
	
	# Spawn loot first
	spawn_loot()
	
	# Wait for audio to finish before removing enemy
	if death_delay > 0:
		var timer = Timer.new()
		timer.wait_time = death_delay
		timer.one_shot = true
		add_child(timer)
		timer.start()
		await timer.timeout
	else:
		# Small delay even without audio to ensure loot spawns
		await get_tree().create_timer(0.1).timeout
	
	# EMIT DIED SIGNAL - hide tooltip right before removing enemy
	died.emit()
	
	queue_free()

func spawn_loot():
	# NEW: Use the LootTable system if available
	if not use_legacy_loot and loot_table:
		# Pass spawner_height for enemies (they spawn items higher)
		LootSpawner.spawn_loot_from_table(loot_table, global_position, get_tree().current_scene, 1.0, 0.5)
	# LEGACY: Fall back to old item_scenes array
	elif use_legacy_loot and legacy_item_scenes.size() > 0:
		spawn_legacy_item()

func spawn_legacy_item():
	# Old system kept for backwards compatibility
	if legacy_item_scenes.size() > 0:
		var random_item = legacy_item_scenes[randi() % legacy_item_scenes.size()]
		var item_instance = random_item.instantiate()
		
		if item_instance is Node3D:
			get_tree().current_scene.add_child(item_instance)
			item_instance.global_position = global_position + Vector3(0, 0.5, 0)
