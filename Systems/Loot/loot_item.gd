# loot_item.gd
# Resource definition for loot items
class_name LootItem
extends Resource

# Basic item info
@export var item_name: String = "Item"
@export var icon: Texture2D
@export var item_scene: PackedScene  # The actual item scene to spawn

# Item classification
@export var item_type: String = "misc"  # weapon, armor, consumable, material, etc.
@export var item_subtype: String = ""  # sword, axe, helmet, boots, health_potion, etc.
@export var item_tags: Array[String] = []  # Tags for filtering (e.g., ["common", "starter", "metal"])

# Physical properties
@export var mass: float = 1.0
@export var base_value: int = 10  # Base value before level/quality modifiers

# Weapon stats (only for weapons)
@export_group("Weapon Stats")
@export var min_weapon_damage: int = 0  # Minimum base damage
@export var max_weapon_damage: int = 0  # Maximum base damage
@export var weapon_range: float = 2.0  # Attack range in meters
@export var weapon_speed: float = 1.0  # Attack speed multiplier (1.0 = normal, 2.0 = twice as fast)
@export var weapon_block_window: float = 0.0  # Time window to successfully block (seconds)
@export var weapon_parry_window: float = 0.0  # Time window to successfully parry (seconds)

# Weapon hand restrictions
enum WeaponHand {
	ANY,        # Can equip in either hand (default)
	PRIMARY,    # Left hand only (slots 10, 14)
	OFFHAND,    # Right hand only (slots 11, 15)
	TWOHAND     # Takes both hands (auto-equips to primary + blocks offhand)
}
@export var weapon_hand: WeaponHand = WeaponHand.ANY

# Armor stats (only for armor)
@export_group("Armor Stats")
@export var base_armor_defense: int = 0  # Base defense value

# Stackable item settings
@export_group("Stack Settings")
@export var stackable: bool = false
@export var max_stack_size: int = 1
@export var min_drop_amount: int = 1  # Minimum stack size when dropped
@export var max_drop_amount: int = 1  # Maximum stack size when dropped
@export var scaled_quantity: bool = false  # Scale drop amount by enemy level

# Loot table properties
@export_group("Drop Settings")
@export var item_drop_weight: float = 1.0  # How common this specific item is (higher = more common)
@export var min_quantity: int = 1  # For stackable items
@export var max_quantity: int = 1  # For stackable items
