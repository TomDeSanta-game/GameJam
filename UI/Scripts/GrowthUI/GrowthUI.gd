extends Control

# Font references
@export var regular_font: Font
@export var bold_font: Font

# UI elements
var main_panel: PanelContainer
var vbox: VBoxContainer
var growth_bar: ProgressBar
var level_label: Label

# Chemical UI elements
var chemical_container: HBoxContainer
var chemical_icons = []
var MAX_CHEMICALS = 5

# Effect display
var effect_panel: PanelContainer
var effect_label: Label
var effect_timer: Label

# Spacing and styling
const MARGIN = 8
const SECTION_SPACING = 10
const ITEM_SPACING = 4
const PANEL_COLOR = Color(0.07, 0.07, 0.09, 0.95) # Much darker and nearly opaque
const GROWTH_BAR_COLOR = Color(0.2, 0.8, 0.2)
const TITLE_COLOR = Color(0.95, 0.95, 0.95)
const TEXT_COLOR = Color(0.85, 0.85, 0.85)

func _ready():
	# Initialize UI elements right away
	# Load default fonts if not assigned
	if regular_font == null:
		regular_font = load("res://assets/Fonts/static/Oswald-Regular.ttf")
	if bold_font == null:
		bold_font = load("res://assets/Fonts/static/Oswald-Bold.ttf")
	
	initialize()

func initialize():
	# Create the main structure
	create_main_panel()
	
	# Create the individual UI elements
	create_growth_ui()
	create_chemical_container()
	create_effect_display()
	
	# Connect to signals
	connect_signals()

func create_main_panel():
	# Create the main panel that will contain everything
	main_panel = PanelContainer.new()
	add_child(main_panel)
	
	# Position it on the RIGHT side of the screen
	main_panel.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	main_panel.anchor_right = 1.0
	main_panel.anchor_left = 1.0
	main_panel.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	
	# Size and position
	main_panel.offset_top = 10
	main_panel.offset_left = -170 # 170 pixels from right edge
	main_panel.offset_right = -10 # 10 pixels margin on right
	
	# Style the panel with border
	var panel_style = StyleBoxFlat.new()
	panel_style.bg_color = PANEL_COLOR
	panel_style.corner_radius_top_left = 5
	panel_style.corner_radius_top_right = 5
	panel_style.corner_radius_bottom_left = 5
	panel_style.corner_radius_bottom_right = 5
	panel_style.border_width_left = 1
	panel_style.border_width_right = 1
	panel_style.border_width_top = 1
	panel_style.border_width_bottom = 1
	panel_style.border_color = Color(0.3, 0.3, 0.35, 0.6)
	main_panel.add_theme_stylebox_override("panel", panel_style)
	
	# Add margin container for padding
	var margin = MarginContainer.new()
	main_panel.add_child(margin)
	margin.add_theme_constant_override("margin_left", MARGIN)
	margin.add_theme_constant_override("margin_right", MARGIN)
	margin.add_theme_constant_override("margin_top", MARGIN)
	margin.add_theme_constant_override("margin_bottom", MARGIN)
	
	# Create the content container
	vbox = VBoxContainer.new()
	margin.add_child(vbox)
	vbox.add_theme_constant_override("separation", SECTION_SPACING)
	vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vbox.size_flags_vertical = Control.SIZE_EXPAND_FILL

# Create the growth bar and level display
func create_growth_ui():
	# Create a VBox for the growth section
	var growth_section = VBoxContainer.new()
	vbox.add_child(growth_section)
	growth_section.add_theme_constant_override("separation", ITEM_SPACING)
	
	# Create section title
	var title = Label.new()
	growth_section.add_child(title)
	title.text = "GROWTH STATUS"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	
	# Apply font if available
	if bold_font != null:
		title.add_theme_font_override("font", bold_font)
		title.add_theme_font_size_override("font_size", 14)
	
	title.add_theme_color_override("font_color", TITLE_COLOR)
	
	# Create a background panel for the growth bar
	var bar_panel = PanelContainer.new()
	growth_section.add_child(bar_panel)
	var bar_panel_style = StyleBoxFlat.new()
	bar_panel_style.bg_color = Color(0.12, 0.12, 0.14, 1.0)
	bar_panel_style.corner_radius_top_left = 3
	bar_panel_style.corner_radius_top_right = 3
	bar_panel_style.corner_radius_bottom_left = 3
	bar_panel_style.corner_radius_bottom_right = 3
	bar_panel.add_theme_stylebox_override("panel", bar_panel_style)
	
	# Add margin around the bar
	var bar_margin = MarginContainer.new()
	bar_panel.add_child(bar_margin)
	bar_margin.add_theme_constant_override("margin_left", 4)
	bar_margin.add_theme_constant_override("margin_right", 4)
	bar_margin.add_theme_constant_override("margin_top", 4)
	bar_margin.add_theme_constant_override("margin_bottom", 4)
	
	# Create progress bar
	growth_bar = ProgressBar.new()
	bar_margin.add_child(growth_bar)
	
	growth_bar.min_value = 0
	growth_bar.max_value = 100
	growth_bar.value = 0
	growth_bar.custom_minimum_size = Vector2(0, 10)
	
	# IMPORTANT: Actually hide the percentage text
	growth_bar.show_percentage = false
	
	# Style the progress bar
	var bar_style = StyleBoxFlat.new()
	bar_style.bg_color = Color(0.15, 0.15, 0.15, 1.0)
	bar_style.corner_radius_top_left = 2
	bar_style.corner_radius_top_right = 2
	bar_style.corner_radius_bottom_left = 2
	bar_style.corner_radius_bottom_right = 2
	growth_bar.add_theme_stylebox_override("background", bar_style)
	
	var fill_style = StyleBoxFlat.new()
	fill_style.bg_color = GROWTH_BAR_COLOR
	fill_style.corner_radius_top_left = 2
	fill_style.corner_radius_top_right = 2
	fill_style.corner_radius_bottom_left = 2
	fill_style.corner_radius_bottom_right = 2
	growth_bar.add_theme_stylebox_override("fill", fill_style)
	
	# Create level label
	level_label = Label.new()
	growth_section.add_child(level_label)
	
	level_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	level_label.text = "Level 1"
	
	# Apply font if available
	if bold_font != null:
		level_label.add_theme_font_override("font", bold_font)
		level_label.add_theme_font_size_override("font_size", 16)
	
	level_label.add_theme_color_override("font_color", TEXT_COLOR)

# Create container for chemical icons
func create_chemical_container():
	# Create a VBox for the chemicals section
	var chemical_section = VBoxContainer.new()
	vbox.add_child(chemical_section)
	chemical_section.add_theme_constant_override("separation", ITEM_SPACING)
	
	# Create section title
	var title = Label.new()
	chemical_section.add_child(title)
	title.text = "CHEMICALS"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	
	# Apply font if available
	if bold_font != null:
		title.add_theme_font_override("font", bold_font)
		title.add_theme_font_size_override("font_size", 14)
	
	title.add_theme_color_override("font_color", TITLE_COLOR)
	
	# Panel background for chemicals
	var chemical_panel = PanelContainer.new()
	chemical_section.add_child(chemical_panel)
	var panel_style = StyleBoxFlat.new()
	panel_style.bg_color = Color(0.12, 0.12, 0.14, 1.0)
	panel_style.corner_radius_top_left = 3
	panel_style.corner_radius_top_right = 3
	panel_style.corner_radius_bottom_left = 3
	panel_style.corner_radius_bottom_right = 3
	chemical_panel.add_theme_stylebox_override("panel", panel_style)
	
	# Add padding
	var container_margin = MarginContainer.new()
	chemical_panel.add_child(container_margin)
	container_margin.add_theme_constant_override("margin_left", 4)
	container_margin.add_theme_constant_override("margin_right", 4)
	container_margin.add_theme_constant_override("margin_top", 4)
	container_margin.add_theme_constant_override("margin_bottom", 4)
	
	# Create container
	chemical_container = HBoxContainer.new()
	container_margin.add_child(chemical_container)
	chemical_container.alignment = BoxContainer.ALIGNMENT_CENTER
	chemical_container.add_theme_constant_override("separation", 4)
	
	# Initialize empty slots
	for i in range(MAX_CHEMICALS):
		var slot = Panel.new()
		chemical_container.add_child(slot)
		slot.custom_minimum_size = Vector2(22, 22)
		
		var slot_style = StyleBoxFlat.new()
		slot_style.bg_color = Color(0.2, 0.2, 0.22, 1.0)
		slot_style.border_width_left = 1
		slot_style.border_width_top = 1
		slot_style.border_width_right = 1
		slot_style.border_width_bottom = 1
		slot_style.border_color = Color(0.3, 0.3, 0.3, 1.0)
		slot_style.corner_radius_top_left = 3
		slot_style.corner_radius_top_right = 3
		slot_style.corner_radius_bottom_left = 3
		slot_style.corner_radius_bottom_right = 3
		slot.add_theme_stylebox_override("panel", slot_style)
		
		chemical_icons.append(null)

# Create the effect display for showing active effects
func create_effect_display():
	# Create a VBox for the effect section
	var effect_section = VBoxContainer.new()
	vbox.add_child(effect_section)
	effect_section.add_theme_constant_override("separation", ITEM_SPACING)
	
	# Create section title
	var title = Label.new()
	effect_section.add_child(title)
	title.text = "CURRENT EFFECT"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	
	# Apply font if available
	if bold_font != null:
		title.add_theme_font_override("font", bold_font)
		title.add_theme_font_size_override("font_size", 14)
	
	title.add_theme_color_override("font_color", TITLE_COLOR)
	
	# Create effect panel
	effect_panel = PanelContainer.new()
	effect_section.add_child(effect_panel)
	
	var panel_style = StyleBoxFlat.new()
	panel_style.bg_color = Color(0.12, 0.12, 0.14, 1.0)
	panel_style.corner_radius_top_left = 3
	panel_style.corner_radius_top_right = 3
	panel_style.corner_radius_bottom_left = 3
	panel_style.corner_radius_bottom_right = 3
	effect_panel.add_theme_stylebox_override("panel", panel_style)
	
	# Add padding to the panel
	var padding = MarginContainer.new()
	effect_panel.add_child(padding)
	padding.add_theme_constant_override("margin_left", 6)
	padding.add_theme_constant_override("margin_right", 6)
	padding.add_theme_constant_override("margin_top", 6)
	padding.add_theme_constant_override("margin_bottom", 6)
	
	# Container for the effect info
	var effect_container = VBoxContainer.new()
	padding.add_child(effect_container)
	effect_container.add_theme_constant_override("separation", 3)
	
	# Create effect label
	effect_label = Label.new()
	effect_container.add_child(effect_label)
	
	effect_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	effect_label.text = "Effect: None"
	
	# Apply font if available
	if regular_font != null:
		effect_label.add_theme_font_override("font", regular_font)
		effect_label.add_theme_font_size_override("font_size", 13)
	
	effect_label.add_theme_color_override("font_color", TEXT_COLOR)
	
	# Create effect timer
	effect_timer = Label.new()
	effect_container.add_child(effect_timer)
	
	effect_timer.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	effect_timer.text = ""
	
	# Apply font if available
	if regular_font != null:
		effect_timer.add_theme_font_override("font", regular_font)
		effect_timer.add_theme_font_size_override("font_size", 12)
	
	effect_timer.add_theme_color_override("font_color", TEXT_COLOR)

# Connect to signals from the Growth System and Chemical Mixer
func connect_signals():
	# Connect to SignalBus if it exists
	var signal_bus = get_node_or_null("/root/SignalBus")
	if signal_bus:
		# Connect growth-related signals (only if not already connected)
		if signal_bus.has_signal("player_grew") and not is_connected_to_signal(signal_bus, "player_grew", "_on_player_grew"):
			signal_bus.player_grew.connect(_on_player_grew)
			
		if signal_bus.has_signal("player_shrank") and not is_connected_to_signal(signal_bus, "player_shrank", "_on_player_shrank"):
			signal_bus.player_shrank.connect(_on_player_shrank)
			
		if signal_bus.has_signal("growth_level_changed") and not is_connected_to_signal(signal_bus, "growth_level_changed", "_on_growth_level_changed"):
			signal_bus.growth_level_changed.connect(_on_growth_level_changed)
			
		if signal_bus.has_signal("growth_reset") and not is_connected_to_signal(signal_bus, "growth_reset", "_on_growth_reset"):
			signal_bus.growth_reset.connect(_on_growth_reset)
			
		# Connect chemical-related signals (only if not already connected)
		if signal_bus.has_signal("chemical_collected") and not is_connected_to_signal(signal_bus, "chemical_collected", "_on_chemical_collected"):
			signal_bus.chemical_collected.connect(_on_chemical_collected)
			
		if signal_bus.has_signal("chemicals_mixed") and not is_connected_to_signal(signal_bus, "chemicals_mixed", "_on_chemicals_mixed"):
			signal_bus.chemicals_mixed.connect(_on_chemicals_mixed)

# Helper function to check if already connected to a signal
func is_connected_to_signal(source, signal_name, method_name):
	var signal_connections = source.get_signal_connection_list(signal_name)
	for connection in signal_connections:
		if connection.callable.get_object() == self and connection.callable.get_method() == method_name:
			return true
	return false

# Signal handlers for growth events
func _on_player_grew(_player, growth_amount):
	growth_bar.value = growth_amount

func _on_player_shrank(_player, growth_amount):
	growth_bar.value = growth_amount

func _on_growth_level_changed(_player, new_level, _level_percent):
	level_label.text = "Level " + str(new_level)

func _on_growth_reset():
	growth_bar.value = 0
	level_label.text = "Level 1"

# Signal handlers for chemical events
func _on_chemical_collected(chemical_type, slot_index):
	if slot_index >= 0 and slot_index < MAX_CHEMICALS:
		update_chemical_slot(slot_index, chemical_type)

func _on_chemicals_mixed(effect_name, duration):
	effect_label.text = "Effect: " + effect_name
	
	# Clear all chemical slots
	for i in range(MAX_CHEMICALS):
		update_chemical_slot(i, null)

# Updates a chemical slot with the given chemical type
func update_chemical_slot(slot_index, chemical_type):
	if slot_index < 0 or slot_index >= chemical_icons.size():
		return
		
	var slot = chemical_container.get_child(slot_index)
	
	# Remove any existing icon
	if chemical_icons[slot_index] != null:
		if chemical_icons[slot_index].get_parent() == slot:
			slot.remove_child(chemical_icons[slot_index])
		chemical_icons[slot_index] = null
	
	# Clear the style
	var slot_style = StyleBoxFlat.new()
	slot_style.bg_color = Color(0.2, 0.2, 0.2, 0.8)
	slot_style.border_width_left = 1
	slot_style.border_width_top = 1
	slot_style.border_width_right = 1
	slot_style.border_width_bottom = 1
	slot_style.border_color = Color(0.3, 0.3, 0.3)
	slot_style.corner_radius_top_left = 3
	slot_style.corner_radius_top_right = 3
	slot_style.corner_radius_bottom_left = 3
	slot_style.corner_radius_bottom_right = 3
	slot.add_theme_stylebox_override("panel", slot_style)
	
	# If a chemical type is provided, create and add a new icon
	if chemical_type != null:
		var color = get_chemical_color(chemical_type)
		var icon = ColorRect.new()
		slot.add_child(icon)
		icon.color = color
		icon.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		icon.size_flags_vertical = Control.SIZE_EXPAND_FILL
		icon.custom_minimum_size = Vector2(15, 15)
		
		# Center the icon in the slot
		icon.anchor_left = 0.5
		icon.anchor_top = 0.5
		icon.anchor_right = 0.5
		icon.anchor_bottom = 0.5
		icon.position = Vector2(-7.5, -7.5)
		
		# Store the icon
		chemical_icons[slot_index] = icon
		
		# Update slot style based on chemical type
		slot_style.bg_color = Color(color.r * 0.3, color.g * 0.3, color.b * 0.3, 0.8)
		slot_style.border_color = color
		slot.add_theme_stylebox_override("panel", slot_style)

# Returns a color based on the chemical type
func get_chemical_color(chemical_type):
	match chemical_type:
		"red": return Color(1, 0.2, 0.2)
		"blue": return Color(0.2, 0.4, 1)
		"green": return Color(0.2, 0.8, 0.2)
		"yellow": return Color(1, 0.9, 0.2)
		"purple": return Color(0.8, 0.2, 0.8)
		_: return Color(0.7, 0.7, 0.7) 
