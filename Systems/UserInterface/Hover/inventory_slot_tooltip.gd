extends Control
class_name InventorySlotTooltip

## Tooltip that appears when hovering over inventory slots
## Shows item name, level, quality, value, type, and mass

var tooltip_panel: PanelContainer = null
var item_label: RichTextLabel = null
var current_slot: Control = null  # Which slot we're showing tooltip for

func _ready():
	# Try to find existing nodes
	tooltip_panel = get_node_or_null("TooltipPanel")
	if tooltip_panel:
		var existing_label = tooltip_panel.get_node_or_null("ItemLabel")
		# Check if it's the right type
		if existing_label and existing_label is RichTextLabel:
			item_label = existing_label
		elif existing_label:
			# Old Label exists, need to replace it with RichTextLabel
			existing_label.queue_free()
			item_label = null
	
	# If nodes don't exist or need recreation, create them
	if not tooltip_panel or not item_label:
		if not tooltip_panel:
			_create_tooltip_ui()
		else:
			_create_label()
	
	# Start hidden
	if tooltip_panel:
		tooltip_panel.visible = false

func _create_label():
	"""Create just the RichTextLabel"""
	item_label = RichTextLabel.new()
	item_label.name = "ItemLabel"
	item_label.bbcode_enabled = true
	item_label.fit_content = true
	item_label.scroll_active = false
	item_label.custom_minimum_size = Vector2(150, 0)  # Minimum width
	item_label.add_theme_font_size_override("normal_font_size", 14)
	item_label.add_theme_color_override("default_color", Color.WHITE)
	tooltip_panel.add_child(item_label)

func _create_tooltip_ui():
	"""Create the tooltip UI programmatically"""
	# Create panel
	tooltip_panel = PanelContainer.new()
	tooltip_panel.name = "TooltipPanel"
	tooltip_panel.visible = false
	tooltip_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(tooltip_panel)
	
	# Create RichTextLabel for BBCode support
	item_label = RichTextLabel.new()
	item_label.name = "ItemLabel"
	item_label.bbcode_enabled = true
	item_label.fit_content = true
	item_label.scroll_active = false
	item_label.custom_minimum_size = Vector2(150, 0)  # Minimum width
	item_label.add_theme_font_size_override("normal_font_size", 14)
	item_label.add_theme_color_override("default_color", Color.WHITE)
	tooltip_panel.add_child(item_label)
	
	# Style the panel
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0, 0, 0, 0.9)
	style.border_color = Color(1, 1, 1, 0.3)
	style.set_border_width_all(1)
	style.set_corner_radius_all(4)
	style.content_margin_left = 8
	style.content_margin_right = 8
	style.content_margin_top = 4
	style.content_margin_bottom = 4
	tooltip_panel.add_theme_stylebox_override("panel", style)

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

func show_tooltip(slot: Control, item_data: Dictionary):
	"""Show tooltip for an inventory slot"""
	if not tooltip_panel or not item_label:
		return
		
	current_slot = slot
	
	# Build tooltip text with BBCode formatting
	var lines = []
	
	# Get item quality and its color
	var item_quality = item_data.get("item_quality", ItemQuality.Quality.NORMAL)
	var quality_color = ItemQuality.get_quality_color(item_quality)
	var quality_hex = quality_color.to_html(false)  # Get hex color without alpha
	
	# Item name (with stack count if applicable) - larger, underlined, and colored by quality
	var name_text = item_data.get("name", "Unknown Item")
	if item_data.get("stackable", false) and item_data.get("stack_count", 1) > 1:
		name_text = "%s (x%d)" % [name_text, item_data.get("stack_count", 1)]
	lines.append("[center][font_size=22][u][color=#%s]%s[/color][/u][/font_size][/center]" % [quality_hex, name_text])
	
	# Type - gray color
	var item_type = item_data.get("item_type", "")
	if item_type != "":
		lines.append("[center][color=darkgray]Type: %s[/color][/center]" % item_type)
	
	# Item level - below name, white color
	var item_level = item_data.get("item_level", 1)
	lines.append("[center]Level: %d[/center]" % item_level)
	
	# Value - gold color
	var value = item_data.get("value", 0)
	lines.append("[center][color=gold]Value: %d[/color][/center]" % value)
		
	# Mass - gray color
	var mass = item_data.get("mass", 0.0)
	lines.append("[center][color=gray]Mass: %.1f[/color][/center]" % mass)
	
	# Join lines with newlines
	var tooltip_text = "\n".join(lines)
	
	item_label.text = tooltip_text
	tooltip_panel.visible = true

func hide_tooltip():
	"""Hide the tooltip"""
	if tooltip_panel:
		tooltip_panel.visible = false
	current_slot = null
