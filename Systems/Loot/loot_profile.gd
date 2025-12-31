# res://Resources/loot_profile.gd
extends Resource
class_name LootProfile

## Loot generation profile - defines what items can drop and how

# Item pool - specific items that can drop (with their own drop weights)
@export_group("Item Pool")
@export var item_pool: Array[LootItem] = []  # Specific items that can drop (uses their item_drop_weight)

# Item type filtering - which types of items can drop
@export_group("Item Type Filtering")
@export var allowed_item_types: Array[String] = []  # If empty, allows all types
@export var excluded_item_types: Array[String] = []  # Blacklist specific types

# Drop quantity
@export_group("Drop Quantity")
@export var min_drops: int = 1
@export var max_drops: int = 3
@export var drop_chance: float = 1.0  # 0.0-1.0, chance that ANY loot drops
@export var level_variance: int = 2  # ±variance from enemy_level (e.g., enemy lv10 drops items lv8-12)

# Optional tag filtering
@export_group("Advanced Filters")
@export var required_tags: Array[String] = []  # Must have at least one of these tags
@export var excluded_tags: Array[String] = []  # Cannot have any of these tags
@export var bonus_tags: Dictionary = {}  # e.g., {"rare": 2.0} multiplies weight by 2.0
