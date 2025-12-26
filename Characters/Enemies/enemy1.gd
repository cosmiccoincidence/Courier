extends EnemyBase
# Enemy1.gd

@export var grunt_sfx: AudioStream
@export var attack_sfx: AudioStream
@export var hit_sfx: AudioStream

func _ready():
	# Enemy level determines both stats AND loot item levels
	# If enemy_level = 5, dropped items will be level 10 (5 * 2)
	# If enemy_level = 25, dropped items will be level 50 (25 * 2)
	enemy_level = 1  # Set this per-instance or per-area
	
	# Stats
	max_health = 10
	damage_amount = 2
	crit_chance = 0.1
	crit_multiplier = 2.0
	
	# Behavior
	rotation_change_interval = 5.0
	rotation_speed = 40.0
	combat_rotation_speed = 140.0
	detection_range = 5.0
	aggro_range = 15.0
	attack_range = 2.0
	move_speed = 5.0
	attack_cooldown = 1.0
	
	# Sounds (optional overrides)
	vocal_sounds = {
		#"grunt": grunt_sfx
	}
	combat_sounds = {
		#"attack": attack_sfx,
		#"hit": hit_sfx
	}
	
	super._ready()
