# res://resources/loot_profile.gd
extends Resource
class_name LootProfile  # This makes it globally accessible in Godot

# How items are selected based on level matching
@export_group("Level Matching")
@export var level_range: int = 5  # Will consider items within ±5 levels of target level
@export var level_curve: Curve  # Drop probability based on level difference (optional, for fine control)
@export var prefer_exact_level: bool = true  # Higher weight for items matching target level

# Quality shift - makes drops skew higher/lower than entity level
@export_group("Quality Adjustment")
@export var level_offset: int = 0  # +5 = drops items 5 levels higher, -5 = 5 levels lower
@export var allow_higher_level: bool = true  # Can drop items above target level
@export var allow_lower_level: bool = true  # Can drop items below target level

# Item level calculation
@export_group("Item Level Formula")
@export var item_level_multiplier: float = 2.0  # item_level = enemy_level * multiplier
@export var item_level_bonus: int = 0  # Additional flat bonus to item level

# Quantity
@export_group("Drop Quantity")
@export var min_drops: int = 1
@export var max_drops: int = 3
@export var drop_chance: float = 1.0  # 0.0-1.0, chance that ANY loot drops at all

# Tag filtering (for enemy-specific or special drops)
@export_group("Filters")
@export var required_tags: Array[String] = []  # Must have at least one of these tags
@export var excluded_tags: Array[String] = []  # Cannot have any of these tags
@export var bonus_tags: Dictionary = {}  # e.g., {"goblin_favorite": 2.0} multiplies weight by 2.0

# Advanced
@export_group("Advanced")
@export var weight_falloff_rate: float = 0.15  # How quickly weight decreases with level difference
