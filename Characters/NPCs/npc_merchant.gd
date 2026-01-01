# npc_merchant.gd
extends BaseNPC
class_name NPCMerchant

@export var shop_data: ShopData  # Assign in editor
@export var interaction_range: float = 3.0

var player_in_range: bool = false
var interaction_prompt_shown: bool = false

func _ready():
	super._ready()  # Call parent _ready
	display_name = "Merchant"
	
	# Validate shop data
	if not shop_data:
		push_warning("NPCMerchant has no shop_data assigned!")

func _physics_process(delta):
	super._physics_process(delta)  # Call parent physics
	check_player_proximity()
	
	# Handle interaction input
	if player_in_range and Input.is_action_just_pressed("interact"):
		open_shop()

func check_player_proximity():
	var player = get_tree().get_first_node_in_group("player")
	if player:
		var distance = global_position.distance_to(player.global_position)
		var was_in_range = player_in_range
		player_in_range = distance <= interaction_range
		
		# Show/hide interaction prompt
		if player_in_range and not was_in_range:
			show_interaction_prompt()
		elif not player_in_range and was_in_range:
			hide_interaction_prompt()

func open_shop():
	"""Open this merchant's shop"""
	if not shop_data:
		print("[NPCMerchant] No shop data configured!")
		return
	
	ShopManager.open_shop(shop_data, self)

func show_interaction_prompt():
	interaction_prompt_shown = true
	# TODO: Show UI prompt above merchant
	# Example: $InteractionPrompt.visible = true

func hide_interaction_prompt():
	"""Hide interaction prompt"""
	interaction_prompt_shown = false
	# TODO: Hide UI prompt
	# Example: $InteractionPrompt.visible = false
