extends EnemyBase

@export var grunt_sfx: AudioStream
@export var attack_sfx: AudioStream
@export var hit_sfx: AudioStream

# Enemy 2
func _ready():
	max_health = 25
	damage_amount = 5
	crit_chance = 0.1
	crit_multiplier = 2.0
	
	rotation_change_interval = 2.0
	rotation_speed = 80.0
	combat_rotation_speed = 180.0
	detection_range = 10.0
	aggro_range = 20.0
	attack_range = 2.5
	move_speed = 8.0
	attack_cooldown = 0.5

	# Uncomment sounds if you want to override them
	vocal_sounds = {
		#"grunt": grunt_sfx
	}
	combat_sounds = {
		#"attack": attack_sfx,
		#"hit": hit_sfx
	}

	super._ready()
