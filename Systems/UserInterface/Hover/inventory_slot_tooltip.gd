extends Control
class_name InventorySlotTooltip

## Tooltip that appears when hovering over inventory slots
## Shows item name, level, quality, value, type, subtype, and mass

var tooltip_panel: PanelContainer = null
var price_panel: PanelContainer = null  # Separate panel for buy/sell price
var item_label: RichTextLabel = null
var current_slot: Control = null  # Which slot we're showing tooltip for

func _ready():
	# Ensure this Control is fully opaque and doesn't inherit modulation
	modulate = Color(1, 1, 1, 1)
	self_modulate = Color(1, 1, 1, 1)
	visibility_layer = 1
	top_level = false  # Make sure we're not detached from tree
	
	# Try to find existing panels
	tooltip_panel = get_node_or_null("TooltipPanel")
	price_panel = get_node_or_null("PricePanel")
	if not tooltip_panel or not price_panel:
		_create_tooltip_ui()
	
	# Start hidden
	if tooltip_panel:
		tooltip_panel.visible = false
		# Force panel to be opaque
		tooltip_panel.modulate = Color(1, 1, 1, 1)
		tooltip_panel.self_modulate = Color(1, 1, 1, 1)
		tooltip_panel.visibility_layer = 1
	
	if price_panel:
		price_panel.visible = false
		price_panel.modulate = Color(1, 1, 1, 1)
		price_panel.self_modulate = Color(1, 1, 1, 1)
		price_panel.visibility_layer = 1

func _create_label():
	"""Create the content container"""
	var vbox = VBoxContainer.new()
	vbox.name = "ContentVBox"
	vbox.add_theme_constant_override("separation", 2)
	tooltip_panel.add_child(vbox)

func _create_tooltip_ui():
	"""Create the tooltip UI programmatically"""
	# Create main tooltip panel
	tooltip_panel = PanelContainer.new()
	tooltip_panel.name = "TooltipPanel"
	tooltip_panel.visible = false
	tooltip_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tooltip_panel.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	tooltip_panel.custom_minimum_size = Vector2(220, 0)
	add_child(tooltip_panel)
	
	# Create VBoxContainer for content
	var vbox = VBoxContainer.new()
	vbox.name = "ContentVBox"
	vbox.add_theme_constant_override("separation", 2)
	tooltip_panel.add_child(vbox)
	
	# Style the main panel
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0, 0, 0, 0.8)
	style.draw_center = true
	style.border_color = Color(1, 1, 1, 0.8)
	style.set_border_width_all(2)
	style.set_corner_radius_all(4)
	style.content_margin_left = 15
	style.content_margin_right = 15
	style.content_margin_top = 8
	style.content_margin_bottom = 8
	tooltip_panel.add_theme_stylebox_override("panel", style)
	tooltip_panel.modulate = Color(1, 1, 1, 1)
	tooltip_panel.self_modulate = Color(1, 1, 1, 1)
	tooltip_panel.material = null
	tooltip_panel.use_parent_material = false
	
	# Create price panel (separate panel below main tooltip)
	price_panel = PanelContainer.new()
	price_panel.name = "PricePanel"
	price_panel.visible = false
	price_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	price_panel.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	price_panel.custom_minimum_size = Vector2(220, 0)
	add_child(price_panel)
	
	# Create label for price panel
	var price_label = RichTextLabel.new()
	price_label.name = "PriceLabel"
	price_label.bbcode_enabled = true
	price_label.fit_content = true
	price_label.scroll_active = false
	price_label.add_theme_font_size_override("normal_font_size", 14)
	price_label.add_theme_font_size_override("bold_font_size", 14)
	price_panel.add_child(price_label)
	
	# Style the price panel
	var price_style = StyleBoxFlat.new()
	price_style.bg_color = Color(0, 0, 0, 0.8)
	price_style.draw_center = true
	price_style.border_color = Color(1.0, 0.843, 0.0, 0.8)
	price_style.set_border_width_all(2)
	price_style.set_corner_radius_all(4)
	price_style.content_margin_left = 15
	price_style.content_margin_right = 15
	price_style.content_margin_top = 8
	price_style.content_margin_bottom = 8
	price_panel.add_theme_stylebox_override("panel", price_style)
	price_panel.modulate = Color(1, 1, 1, 1)
	price_panel.self_modulate = Color(1, 1, 1, 1)
	price_panel.material = null
	price_panel.use_parent_material = false

func _process(_delta):
	"""Position tooltip near mouse cursor every frame when visible"""
	if not tooltip_panel:
		return
		
	if tooltip_panel.visible and current_slot:
		# Get mouse position
		var mouse_pos = get_viewport().get_mouse_position()
		
		# Offset tooltip so it doesn't cover the mouse
		var offset = Vector2(15, 15)
		tooltip_panel.global_position = mouse_pos + offset
		
		# Keep tooltip on screen
		var viewport_size = get_viewport_rect().size
		var tooltip_size = tooltip_panel.size
		
		# Check right edge
		if tooltip_panel.global_position.x + tooltip_size.x > viewport_size.x:
			tooltip_panel.global_position.x = mouse_pos.x - tooltip_size.x - 5
		
		# Check bottom edge  
		if tooltip_panel.global_position.y + tooltip_size.y > viewport_size.y:
			tooltip_panel.global_position.y = mouse_pos.y - tooltip_size.y - 5
		
		# Position price panel directly below main tooltip (if visible)
		if price_panel and price_panel.visible:
			# Match width to main tooltip
			price_panel.custom_minimum_size.x = tooltip_panel.size.x
			
			# Position directly below with 2px gap
			price_panel.global_position = Vector2(
				tooltip_panel.global_position.x,
				tooltip_panel.global_position.y + tooltip_panel.size.y + 2
			)

func show_tooltip(slot: Control, item_data: Dictionary):
	"""Show tooltip with item data using UI elements for proper alignment"""
	if not tooltip_panel:
		return
	
	# Get item quality and color FIRST for border
	var item_quality = item_data.get("item_quality", ItemQuality.Quality.NORMAL)
	var quality_color = ItemQuality.get_quality_color(item_quality)
	
	quality_color.a = 0.8
	
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0, 0, 0, 0.8)
	style.draw_center = true
	style.border_color = quality_color
	style.set_border_width_all(3)
	style.set_corner_radius_all(4)
	style.content_margin_left = 15
	style.content_margin_right = 15
	style.content_margin_top = 8
	style.content_margin_bottom = 8
	tooltip_panel.add_theme_stylebox_override("panel", style)
	
	# Clear existing content
	var vbox = tooltip_panel.get_node_or_null("ContentVBox")
	if not vbox:
		vbox = VBoxContainer.new()
		vbox.name = "ContentVBox"
		vbox.add_theme_constant_override("separation", 2)
		tooltip_panel.add_child(vbox)
	
	# Clear children
	for child in vbox.get_children():
		child.queue_free()
	
	current_slot = slot
	
	# === ITEM NAME ===
	var quality_name = ItemQuality.get_quality_name(item_quality)
	var name_text = item_data.get("name", "Unknown Item")
	if item_data.get("stackable", false) and item_data.get("stack_count", 1) > 1:
		name_text = "%s (x%d)" % [name_text, item_data.get("stack_count", 1)]
	if item_quality != ItemQuality.Quality.NORMAL:
		name_text = "%s %s" % [quality_name, name_text]
	
	_add_label(vbox, name_text, 22, quality_color, HORIZONTAL_ALIGNMENT_CENTER)
	_add_spacer(vbox, 5)
	
	# === SUBTYPE + HAND ===
	var item_subtype = item_data.get("item_subtype", "")
	if item_subtype != "":
		var subtype_text = item_subtype.capitalize()
		if item_data.has("weapon_hand") and item_data.get("weapon_damage", 0) > 0:
			var weapon_hand = item_data.weapon_hand
			var hand_text = ""
			match weapon_hand:
				1: hand_text = "Primary"
				2: hand_text = "Offhand"
				3: hand_text = "Two-Handed"
				_: hand_text = "Any Hand"
			subtype_text = "%s (%s)" % [subtype_text, hand_text]
		_add_label(vbox, subtype_text, 14, Color.DARK_GRAY, HORIZONTAL_ALIGNMENT_CENTER)
	
	# === WEAPON/ARMOR CLASS ===
	if item_data.has("weapon_class") and item_data.weapon_class != "" and item_data.get("weapon_damage", 0) > 0:
		var class_text = item_data.weapon_class.capitalize()
		if item_data.has("weapon_speed"):
			var speed = item_data.weapon_speed
			if speed != 1.0:
				var speed_descriptor = ""
				if speed >= 1.5: speed_descriptor = "Very Fast"
				elif speed >= 1.2: speed_descriptor = "Fast"
				elif speed >= 1.0: speed_descriptor = "Normal"
				elif speed >= 0.8: speed_descriptor = "Slow"
				else: speed_descriptor = "Very Slow"
				class_text = "%s - %.1fx (%s)" % [class_text, speed, speed_descriptor]
		_add_label(vbox, class_text, 14, Color("#bb88ff"), HORIZONTAL_ALIGNMENT_CENTER)
	
	if item_data.has("armor_class") and item_data.armor_class != "":
		_add_label(vbox, item_data.armor_class.capitalize(), 14, Color("#88ddff"), HORIZONTAL_ALIGNMENT_CENTER)
	
	# === BREAK 2 ===
	if (item_data.has("weapon_class") and item_data.weapon_class != "" and item_data.get("weapon_damage", 0) > 0) or (item_data.has("armor_class") and item_data.armor_class != ""):
		_add_spacer(vbox, 5)
	
	# === REQUIREMENTS ===
	var req_str = item_data.get("required_strength", 0)
	var req_dex = item_data.get("required_dexterity", 0)
	if req_str > 0 or req_dex > 0:
		var req_parts = []
		if req_str > 0: req_parts.append("Str: %d" % req_str)
		if req_dex > 0: req_parts.append("Dex: %d" % req_dex)
		_add_label(vbox, "Requires: %s" % ", ".join(req_parts), 14, Color("#ff6b6b"), HORIZONTAL_ALIGNMENT_CENTER)
	
	# === STATS ===
	if item_data.has("weapon_damage") and item_data.weapon_damage > 0:
		_add_label(vbox, "Damage: %d" % item_data.weapon_damage, 14, Color("#ff6b6b"), HORIZONTAL_ALIGNMENT_CENTER)
	
	if item_data.has("weapon_range") and item_data.get("weapon_damage", 0) > 0:
		_add_label(vbox, "Range: %.1f" % item_data.weapon_range, 14, Color("#ffaa55"), HORIZONTAL_ALIGNMENT_CENTER)
	
	if item_data.has("weapon_block_rating") and item_data.get("weapon_damage", 0) > 0 and item_data.weapon_block_rating > 0.0:
		_add_label(vbox, "Block Rating: %.0f%%" % (item_data.weapon_block_rating * 100), 14, Color("#77ffff"), HORIZONTAL_ALIGNMENT_CENTER)
	
	if item_data.has("weapon_parry_window") and item_data.get("weapon_damage", 0) > 0 and item_data.weapon_parry_window > 0.0:
		_add_label(vbox, "Parry Window: %.1fs" % item_data.weapon_parry_window, 14, Color("#77ffff"), HORIZONTAL_ALIGNMENT_CENTER)
	
	if item_data.has("weapon_crit_chance") and item_data.get("weapon_damage", 0) > 0 and item_data.weapon_crit_chance > 0.0:
		var crit_pct = item_data.weapon_crit_chance * 100
		_add_label(vbox, "Crit Chance: %.0f%%" % crit_pct, 14, Color("#ff77ff"), HORIZONTAL_ALIGNMENT_CENTER)
	
	if item_data.has("weapon_crit_multiplier") and item_data.get("weapon_damage", 0) > 0 and item_data.weapon_crit_multiplier > 1.0:
		_add_label(vbox, "Crit Multiplier: %.1fx" % item_data.weapon_crit_multiplier, 14, Color("#ff55ff"), HORIZONTAL_ALIGNMENT_CENTER)
	
	if item_data.has("armor_rating") and item_data.armor_rating > 0:
		_add_label(vbox, "Defense: %d" % item_data.armor_rating, 14, Color("#6bb6ff"), HORIZONTAL_ALIGNMENT_CENTER)
	
	# === BREAK 3 ===
	_add_spacer(vbox, 5)
	
	# === MASS + LEVEL (SAME LINE) ===
	var mass = item_data.get("mass", 0.0)
	var item_level = item_data.get("item_level", 1)
	_add_two_column_row(vbox, "Mass: %.1f" % mass, Color.GRAY, "Level: %d" % item_level, Color.WHITE)
	
	# === VALUE + DURABILITY (SAME LINE) ===
	var value = item_data.get("value", 0)
	if item_data.has("durability") and not item_data.get("stackable", false):
		var durability_val = item_data.get("durability", 100)
		var durability_color = Color.GREEN
		if durability_val < 75: durability_color = Color.YELLOW
		if durability_val < 50: durability_color = Color.ORANGE
		if durability_val < 25: durability_color = Color.RED
		
		_add_two_column_row(vbox, "Value: %d" % value, Color.GOLD, "Dur: %d/100" % durability_val, durability_color)
	else:
		_add_label(vbox, "Value: %d" % value, 14, Color.GOLD, HORIZONTAL_ALIGNMENT_CENTER)
	
	# Show main tooltip
	tooltip_panel.visible = true
	await get_tree().process_frame
	tooltip_panel.reset_size()
	
	# === PRICE PANEL (SEPARATE WINDOW BELOW) ===
	if price_panel:
		var price_label = price_panel.get_node_or_null("PriceLabel")
		if price_label:
			# Check if this is a shop item or if shop is open
			if item_data.get("is_shop_item", false):
				# Shop item - show buy price with color coding
				var buy_price = item_data.get("buy_price", 0)
				var base_value = item_data.get("value", 0)
				var item_name = item_data.get("name", "Unknown")
				
				# Calculate what the standard price would be (1.25x)
				var standard_price = int(base_value * 1.25)
				
				# Compare actual price vs standard price
				var price_color = "#ffd700"  # Gold (default)
				if buy_price < standard_price * 0.95:
					price_color = "#90EE90"  # Green (5%+ below standard)
				elif buy_price > standard_price * 1.05:
					price_color = "#FF6B6B"  # Red (5%+ above standard)
				
				print("[Tooltip] %s: value=%d, standard=%d, buy_price=%d, color=%s" % [item_name, base_value, standard_price, buy_price, "GREEN" if price_color == "#90EE90" else ("RED" if price_color == "#FF6B6B" else "GOLD")])
				
				price_label.text = "[center]Buy Price: [color=%s]%d gold[/color][/center]" % [price_color, buy_price]
				price_panel.visible = true
			elif ShopManager.is_shop_open() and not item_data.get("is_shop_item", false):
				# Player item when shop open - show sell price with markup/markdown
				var item_name = item_data.get("base_name", item_data.get("name", ""))
				var item_value = item_data.get("value", 0)
				
				# Get actual sell price (may have markup/markdown applied)
				var sell_price = ShopManager.current_shop.get_sell_price_for_item(item_name, item_value)
				var base_sell_price = int(item_value * 0.75)
				
				# Determine color based on comparison to base sell price
				var price_color = "#ffd700"
				if sell_price > base_sell_price * 1.05:
					price_color = "#90EE90"
				elif sell_price < base_sell_price * 0.95:
					price_color = "#FF6B6B"
				
				price_label.text = "[center]Sell Price: [color=%s]%d gold[/color][/center]" % [price_color, sell_price]
				price_panel.visible = true
			else:
				# No shop interaction - hide price panel
				price_panel.visible = false
		
		await get_tree().process_frame
		if price_panel.visible:
			price_panel.reset_size()

func _add_label(parent: VBoxContainer, text: String, font_size: int, color: Color, alignment: HorizontalAlignment) -> Label:
	"""Add a centered label"""
	var label = Label.new()
	label.text = text
	label.horizontal_alignment = alignment
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	parent.add_child(label)
	return label

func _add_spacer(parent: VBoxContainer, height: int):
	"""Add vertical spacer"""
	var spacer = Control.new()
	spacer.custom_minimum_size = Vector2(0, height)
	parent.add_child(spacer)

func _add_two_column_row(parent: VBoxContainer, left_text: String, left_color: Color, right_text: String, right_color: Color):
	"""Add a row with left-aligned and right-aligned text"""
	var hbox = HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 0)
	parent.add_child(hbox)
	
	# Left label
	var left_label = Label.new()
	left_label.text = left_text
	left_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	left_label.add_theme_font_size_override("font_size", 14)
	left_label.add_theme_color_override("font_color", left_color)
	hbox.add_child(left_label)
	
	# Right label
	var right_label = Label.new()
	right_label.text = right_text
	right_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	right_label.add_theme_font_size_override("font_size", 14)
	right_label.add_theme_color_override("font_color", right_color)
	hbox.add_child(right_label)

func hide_tooltip():
	"""Hide the tooltip"""
	if tooltip_panel:
		tooltip_panel.visible = false
	if price_panel:
		price_panel.visible = false
	current_slot = null
