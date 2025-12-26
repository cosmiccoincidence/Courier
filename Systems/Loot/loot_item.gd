# res://resources/loot_item.gd
extends Resource
class_name LootItem  # This makes it globally accessible in Godot

@export var item_name: String = ""
@export var item_scene: PackedScene  # Reference to your BaseItem scene
@export var icon: Texture2D
@export var item_type: String = ""  # helmet, weapon, armor, ring, consumable, material, etc.

# Level-based properties
@export_group("Level Properties")
@export var base_item_level: int = 1  # Base level this item is designed for
@export var level_variance: int = 3  # Can drop from entities ±3 levels from base

# Drop properties
@export_group("Drop Properties")
@export var base_weight: float = 1.0  # Base drop weight
@export var item_tags: Array[String] = []  # e.g., ["goblin_specific"], ["weapon"], ["consumable"]

# Item properties (should match BaseItem)
@export_group("Item Properties")
@export var base_value: int = 10
@export var weight: float = 1.0
@export var stackable: bool = false
@export var max_stack_size: int = 99
