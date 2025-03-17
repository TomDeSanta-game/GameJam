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

# Toggle state
var is_expanded: bool = false  # Start in collapsed state
var toggle_tween: Tween
var chemicals_section: VBoxContainer
var effects_section: VBoxContainer
var collapsed_width: float = 78  # Width when collapsed
var expanded_width: float = 130  # Width when expanded
var toggle_duration: float = 0.35  # Slightly longer for new effects
var last_toggle_time: float = 0.0  # To prevent double-toggling
var toggle_cooldown: float = 0.4  # Minimum time between toggles

# Animation variables - completely different style
var is_animating: bool = false
var animation_start_time: float = 0.0
var animation_start_width: float = 0.0
var animation_target_width: float = 0.0

# Animation settings
var use_rotation: bool = true  # Enable rotation effect
var use_scale: bool = true     # Enable scale effect

# Spacing and styling
const MARGIN = 5
const SECTION_SPACING = 6
const ITEM_SPACING = 2
const PANEL_COLOR = Color(0.07, 0.08, 0.12, 1.0)  # Richer dark blue-black
const GROWTH_BAR_COLOR = Color(0.2, 0.9, 0.4, 1.0)  # Brighter green
const TITLE_COLOR = Color(1.0, 0.95, 0.8, 1.0)  # Warm cream color
const TEXT_COLOR = Color(0.9, 0.9, 0.95, 1.0)  # Slightly blue-tinted white
const BORDER_COLOR = Color(0.4, 0.5, 0.7, 1.0)  # Blue-tinted border

# Animation settings
var expand_ease = Tween.EASE_OUT
var expand_trans = Tween.TRANS_BACK  # Changed to BACK for a very noticeable effect
var collapse_ease = Tween.EASE_IN
var collapse_trans = Tween.TRANS_BACK  # Changed to BACK for a very noticeable effect

func _ready():
	# Initialize UI elements right away
	# Load default fonts if not assigned
	if regular_font == null:
		regular_font = load("res://assets/Fonts/static/Oswald-Regular.ttf")
	if bold_font == null:
		bold_font = load("res://assets/Fonts/static/Oswald-Bold.ttf")
	
	initialize()
	
	# Connect to SignalBus signals
	if get_node_or_null("/root/SignalBus") != null:
		# Check if signals are already connected before connecting them
		if not SignalBus.is_connected("chemical_collected", _on_chemical_collected):
			print("GROWTH UI: Connecting to chemical_collected signal")
			SignalBus.connect("chemical_collected", _on_chemical_collected)
		else:
			print("GROWTH UI: Already connected to chemical_collected signal")
		
		# Force reconnect to chemicals_mixed signal
		if SignalBus.is_connected("chemicals_mixed", _on_chemicals_mixed):
			print("GROWTH UI: Disconnecting from existing chemicals_mixed signal")
			SignalBus.disconnect("chemicals_mixed", _on_chemicals_mixed)
		
		print("GROWTH UI: Connecting to chemicals_mixed signal")
		SignalBus.connect("chemicals_mixed", _on_chemicals_mixed)
		
		# Connect to the fallback effect_applied signal if it exists
		if SignalBus.has_signal("effect_applied"):
			print("GROWTH UI: Connecting to fallback effect_applied signal")
			if SignalBus.is_connected("effect_applied", _on_chemicals_mixed):
				SignalBus.disconnect("effect_applied", _on_chemicals_mixed)
			SignalBus.connect("effect_applied", _on_chemicals_mixed)
		
		if not SignalBus.is_connected("player_grew", _on_player_grew):
			SignalBus.connect("player_grew", _on_player_grew)
		
		if not SignalBus.is_connected("player_shrank", _on_player_shrank):
			SignalBus.connect("player_shrank", _on_player_shrank)
		
		if not SignalBus.is_connected("growth_level_changed", _on_growth_level_changed):
			SignalBus.connect("growth_level_changed", _on_growth_level_changed)
		
		if not SignalBus.is_connected("growth_reset", _on_growth_reset):
			SignalBus.connect("growth_reset", _on_growth_reset)
	else:
		print("ERROR: SignalBus not found. GrowthUI will not function properly.")
	
	# IMPORTANT: Always stay expanded
	call_deferred("set_expanded", true, false)
	
	# Get initial growth value from player if available
	call_deferred("update_growth_from_player")
	
	# Test the effect display after a short delay to ensure UI is fully initialized
	get_tree().create_timer(1.0).timeout.connect(func(): test_effect_display())
	
	# Add a periodic check for effect display issues
	var timer = Timer.new()
	timer.wait_time = 2.0
	timer.autostart = true
	timer.timeout.connect(func(): debug_check_effect_display())
	add_child(timer)

func _process(_delta):
	# Handle toggle input with cooldown to prevent double-toggling
	if Input.is_action_just_pressed("toggle_growth_ui"):
		var current_time = Time.get_ticks_msec() / 1000.0
		if current_time - last_toggle_time > toggle_cooldown:
			toggle_ui()
			last_toggle_time = current_time
	
	# Update effect timer if needed
	if effect_label.text != "None" and effect_label.text != "":
		# Find GrowthSystem to get the actual timer value
		var player = get_node_or_null("/root/Player") # Try to find the player
		if player == null:
			# If not found at root, try to find any player in the scene
			var players = get_tree().get_nodes_in_group("Player")
			if players.size() > 0:
				player = players[0]
		
		if player and player.has_node("GrowthSystem"):
			var gs = player.get_node("GrowthSystem")
			if gs.effect_timer > 0:
				effect_timer.text = str(int(gs.effect_timer)) + "s"
			else:
				effect_label.text = "None"
				effect_timer.text = ""
		else:
			# Fallback option if we can't find the player
			effect_timer.text = ""
	
	# Manual animation update
	if is_animating:
		var current_time = Time.get_ticks_msec() / 1000.0
		var elapsed_time = current_time - animation_start_time
		var progress = min(elapsed_time / toggle_duration, 1.0)
		
		# Use different easing for expand/collapse
		var eased_progress: float
		if is_expanded:
			# For expansion - elastic effect
			eased_progress = elastic_out(progress)
		else:
			# For collapse - anticipation then quick collapse
			eased_progress = back_in(progress)
		
		# Apply width change
		var current_width = animation_start_width + (animation_target_width - animation_start_width) * eased_progress
		main_panel.custom_minimum_size.x = current_width
		
		# Apply rotation effect
		if use_rotation:
			if is_expanded:
				# Rotate in when expanding
				main_panel.rotation_degrees = 10.0 * (1.0 - eased_progress)
			else:
				# Rotate out when collapsing
				main_panel.rotation_degrees = -5.0 * eased_progress
		
		# Apply scale effect
		if use_scale:
			if is_expanded:
				# Scale from smaller to normal when expanding
				main_panel.scale.x = 0.9 + 0.1 * eased_progress
				main_panel.scale.y = 0.95 + 0.05 * eased_progress
			else:
				# Scale down slightly when collapsing
				main_panel.scale.x = 1.0 - 0.05 * eased_progress
				main_panel.scale.y = 1.0 - 0.02 * eased_progress
		
		# Section visibility with different timing
		if is_expanded:
			if chemicals_section:
				chemicals_section.visible = true
				# Delayed fade in - only start showing after panel has expanded 40%
				var fade_progress = max(0, (eased_progress - 0.4) / 0.6)
				chemicals_section.modulate.a = fade_progress
			if effects_section:
				effects_section.visible = true
				# Even more delayed fade for effects - staggered effect
				var fade_progress = max(0, (eased_progress - 0.6) / 0.4)
				effects_section.modulate.a = fade_progress
		else:
			# Quick fade out for sections
			if chemicals_section:
				chemicals_section.modulate.a = 1.0 - (eased_progress * 2.0) # Fade out twice as fast
				if eased_progress > 0.5: # Hide after 50% through animation
					chemicals_section.visible = false
			if effects_section:
				effects_section.modulate.a = 1.0 - (eased_progress * 3.0) # Fade out three times as fast
				if eased_progress > 0.33: # Hide after 33% through animation
					effects_section.visible = false
		
		# Animation complete
		if progress >= 1.0:
			is_animating = false
			
			# Reset transform properties when done
			main_panel.rotation_degrees = 0
			main_panel.scale = Vector2(1, 1)
			
			# Ensure sections are properly visible/hidden
			if chemicals_section:
				chemicals_section.visible = is_expanded
				chemicals_section.modulate.a = 1.0 if is_expanded else 0.0
			if effects_section:
				effects_section.visible = is_expanded
				effects_section.modulate.a = 1.0 if is_expanded else 0.0

# Custom easing functions for completely different animation feel
func elastic_out(t: float) -> float:
	# Elastic out effect
	var p = 0.3
	return pow(2.0, -10.0 * t) * sin((t - p / 4.0) * (2.0 * PI) / p) + 1.0

func back_in(t: float) -> float:
	# Back in effect with anticipation
	var s = 1.70158
	return t * t * ((s + 1.0) * t - s)

func toggle_ui():
	print("GROWTH UI: Toggle UI called")
	set_expanded(!is_expanded)
	
func set_expanded(expanded: bool, animate: bool = true):
	is_expanded = expanded
	
	# Target width based on state
	var target_width = expanded_width if is_expanded else collapsed_width
	
	if animate:
		# Start the animation
		is_animating = true
		animation_start_time = Time.get_ticks_msec() / 1000.0
		animation_start_width = main_panel.custom_minimum_size.x  # Current width
		animation_target_width = target_width
		
		# Set pivot point for effects
		main_panel.pivot_offset = Vector2(main_panel.size.x, main_panel.size.y / 2)
		
		# If expanding, make sections visible immediately (but transparent)
		if is_expanded:
			if chemicals_section:
				chemicals_section.visible = true
				chemicals_section.modulate.a = 0.0
			if effects_section:
				effects_section.visible = true
				effects_section.modulate.a = 0.0
	else:
		# No animation - set directly
		main_panel.custom_minimum_size.x = target_width
		main_panel.rotation_degrees = 0
		main_panel.scale = Vector2(1, 1)
		
		# Update visibility instantly
		if chemicals_section:
			chemicals_section.visible = is_expanded
			chemicals_section.modulate.a = 1.0 if is_expanded else 0.0
		if effects_section:
			effects_section.visible = is_expanded
			effects_section.modulate.a = 1.0 if is_expanded else 0.0

func initialize():
	# Reset any existing UI elements
	for child in get_children():
		child.queue_free()
	
	# Reset chemical tracking
	chemical_icons = []
	
	# Create main panel
	main_panel = PanelContainer.new()
	add_child(main_panel)
	
	# Set up panel style
	var panel_style = StyleBoxFlat.new()
	panel_style.bg_color = PANEL_COLOR
	panel_style.border_width_left = 2
	panel_style.border_width_top = 2
	panel_style.border_width_right = 2
	panel_style.border_width_bottom = 2
	panel_style.border_color = BORDER_COLOR
	panel_style.corner_radius_top_left = 5
	panel_style.corner_radius_top_right = 5
	panel_style.corner_radius_bottom_left = 5
	panel_style.corner_radius_bottom_right = 5
	main_panel.add_theme_stylebox_override("panel", panel_style)
	
	# Position the panel in the top-right corner - FIXED POSITIONING
	main_panel.size_flags_horizontal = SIZE_SHRINK_END
	main_panel.size_flags_vertical = SIZE_SHRINK_BEGIN
	main_panel.position = Vector2(-150, 10) # Position relative to the right edge
	
	# Create main vertical container
	vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", SECTION_SPACING)
	main_panel.add_child(vbox)
	
	# Add title
	var title = Label.new()
	title.text = "GROWTH"
	title.add_theme_font_override("font", bold_font)
	title.add_theme_font_size_override("font_size", 16)
	title.add_theme_color_override("font_color", TITLE_COLOR)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(title)
	
	# Add level label
	level_label = Label.new()
	level_label.text = "Level 1"
	level_label.add_theme_font_override("font", regular_font)
	level_label.add_theme_font_size_override("font_size", 14)
	level_label.add_theme_color_override("font_color", TEXT_COLOR)
	level_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(level_label)
	
	# Add growth bar
	growth_bar = ProgressBar.new()
	growth_bar.max_value = 100
	growth_bar.value = 0  # Starts at 0% growth
	growth_bar.custom_minimum_size = Vector2(130, 10)
	
	# Add tooltip to explain what growth bar represents
	growth_bar.tooltip_text = "Growth progress to next level"
	
	# Style the growth bar
	var bar_style = StyleBoxFlat.new()
	bar_style.bg_color = GROWTH_BAR_COLOR
	bar_style.corner_radius_top_left = 3
	bar_style.corner_radius_top_right = 3
	bar_style.corner_radius_bottom_left = 3
	bar_style.corner_radius_bottom_right = 3
	growth_bar.add_theme_stylebox_override("fill", bar_style)
	
	var bg_style = StyleBoxFlat.new()
	bg_style.bg_color = Color(0.1, 0.1, 0.1, 0.5)
	bg_style.corner_radius_top_left = 3
	bg_style.corner_radius_top_right = 3
	bg_style.corner_radius_bottom_left = 3
	bg_style.corner_radius_bottom_right = 3
	growth_bar.add_theme_stylebox_override("background", bg_style)
	
	vbox.add_child(growth_bar)
	
	# Create chemicals section
	chemicals_section = VBoxContainer.new()
	chemicals_section.add_theme_constant_override("separation", ITEM_SPACING)
	vbox.add_child(chemicals_section)
	
	# Add chemicals label
	var chemicals_label = Label.new()
	chemicals_label.text = "CHEMICALS"
	chemicals_label.add_theme_font_override("font", bold_font)
	chemicals_label.add_theme_font_size_override("font_size", 14)
	chemicals_label.add_theme_color_override("font_color", TITLE_COLOR)
	chemicals_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	chemicals_section.add_child(chemicals_label)
	
	# Create chemical slots container - WITH EXPLICIT CENTER ALIGNMENT
	chemical_container = HBoxContainer.new()
	chemical_container.add_theme_constant_override("separation", ITEM_SPACING)
	chemical_container.alignment = BoxContainer.ALIGNMENT_CENTER
	chemicals_section.add_child(chemical_container)
	
	# Create chemical slots
	chemical_icons.clear()  # Reset chemical icons array
	for i in range(MAX_CHEMICALS):
		var slot = create_chemical_slot()
		chemical_container.add_child(slot)
		chemical_icons.append(null)  # Track empty slots as null
	
	# Create effects section
	effects_section = VBoxContainer.new()
	effects_section.add_theme_constant_override("separation", ITEM_SPACING)
	vbox.add_child(effects_section)
	
	# Add effects label
	var effects_label = Label.new()
	effects_label.text = "EFFECT"
	effects_label.add_theme_font_override("font", bold_font)
	effects_label.add_theme_font_size_override("font_size", 14)
	effects_label.add_theme_color_override("font_color", TITLE_COLOR)
	effects_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	effects_section.add_child(effects_label)
	
	# Create effect panel with enhanced styling
	effect_panel = PanelContainer.new()
	effects_section.add_child(effect_panel)
	
	# Add enhanced styling to make effects more prominent
	var effect_style = StyleBoxFlat.new()
	effect_style.bg_color = Color(0.12, 0.14, 0.18, 1.0)  # Slightly different background
	effect_style.border_width_left = 2
	effect_style.border_width_top = 2
	effect_style.border_width_right = 2
	effect_style.border_width_bottom = 2
	effect_style.border_color = Color(0.5, 0.5, 0.7, 1.0)  # Highlighted border
	effect_style.corner_radius_top_left = 4
	effect_style.corner_radius_top_right = 4
	effect_style.corner_radius_bottom_left = 4
	effect_style.corner_radius_bottom_right = 4
	effect_panel.add_theme_stylebox_override("panel", effect_style)
	
	# Create effect container
	var effect_container = HBoxContainer.new()
	effect_container.alignment = BoxContainer.ALIGNMENT_CENTER
	effect_container.add_theme_constant_override("separation", 4)
	effect_panel.add_child(effect_container)
	
	# Add effect name label with enhanced styling
	effect_label = Label.new()
	effect_label.text = "None"
	effect_label.add_theme_font_override("font", bold_font)  # Use bold font to stand out
	effect_label.add_theme_font_size_override("font_size", 14)  # Larger text
	effect_label.add_theme_color_override("font_color", TEXT_COLOR)
	effect_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	effect_container.add_child(effect_label)
	
	# Add effect timer label
	effect_timer = Label.new()
	effect_timer.text = ""
	effect_timer.add_theme_font_override("font", regular_font)
	effect_timer.add_theme_font_size_override("font_size", 12)
	effect_timer.add_theme_color_override("font_color", TEXT_COLOR)
	effect_timer.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	effect_container.add_child(effect_timer)
	
	# EXPLICITLY SET WIDTH AND ENSURE UI IS EXPANDED
	main_panel.custom_minimum_size = Vector2(expanded_width, 0)
	is_expanded = true
	print("GROWTH UI: Initialized with effect_label=", effect_label != null, " effect_timer=", effect_timer != null)

# Create container for chemical icons
func create_chemical_container():
	# Create a VBox for the chemicals section
	chemicals_section = VBoxContainer.new()
	vbox.add_child(chemicals_section)
	chemicals_section.add_theme_constant_override("separation", ITEM_SPACING)
	
	# Create section title with improved styling
	var title = Label.new()
	chemicals_section.add_child(title)
	title.text = "CHEMICALS"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	
	# Apply font if available
	if bold_font != null:
		title.add_theme_font_override("font", bold_font)
		title.add_theme_font_size_override("font_size", 12)
	
	title.add_theme_color_override("font_color", TITLE_COLOR)
	
	# Add subtle shadow to the text
	title.add_theme_constant_override("shadow_offset_x", 1)
	title.add_theme_constant_override("shadow_offset_y", 1)
	title.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.3))
	
	# Panel background for chemicals with improved styling
	var chemical_panel = PanelContainer.new()
	chemicals_section.add_child(chemical_panel)
	var panel_style = StyleBoxFlat.new()
	panel_style.bg_color = Color(0.09, 0.1, 0.14, 1.0)  # Deeper dark color
	panel_style.corner_radius_top_left = 3
	panel_style.corner_radius_top_right = 3
	panel_style.corner_radius_bottom_left = 3
	panel_style.corner_radius_bottom_right = 3
	
	# Add subtle inner shadow
	panel_style.shadow_color = Color(0.0, 0.0, 0.0, 0.25)
	panel_style.shadow_size = 2
	panel_style.shadow_offset = Vector2(0, 1)
	
	chemical_panel.add_theme_stylebox_override("panel", panel_style)
	
	# Add padding with slight adjustments
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
	chemical_container.add_theme_constant_override("separation", 3)
	
	# Initialize empty slots with improved styling
	for i in range(MAX_CHEMICALS):
		var slot = Panel.new()
		chemical_container.add_child(slot)
		slot.custom_minimum_size = Vector2(18, 18)
		
		var slot_style = StyleBoxFlat.new()
		slot_style.bg_color = Color(0.15, 0.16, 0.20, 1.0)  # Richer dark background
		slot_style.border_width_left = 1
		slot_style.border_width_top = 1
		slot_style.border_width_right = 1
		slot_style.border_width_bottom = 1
		slot_style.border_color = Color(0.35, 0.35, 0.4, 1.0)  # Slightly blue-tinted border
		slot_style.corner_radius_top_left = 2
		slot_style.corner_radius_top_right = 2
		slot_style.corner_radius_bottom_left = 2
		slot_style.corner_radius_bottom_right = 2
		
		# Add subtle inset effect
		slot_style.shadow_color = Color(0, 0, 0, 0.2)
		slot_style.shadow_size = 1
		slot_style.shadow_offset = Vector2(0, 1)
		
		slot.add_theme_stylebox_override("panel", slot_style)
		
		chemical_icons.append(null)

# Create the effect display for showing active effects
func create_effect_display():
	# Create a VBox for the effect section with improved styling
	effects_section = VBoxContainer.new()
	vbox.add_child(effects_section)
	effects_section.add_theme_constant_override("separation", ITEM_SPACING)
	
	# Create section title with improved styling
	var title = Label.new()
	effects_section.add_child(title)
	title.text = "EFFECT"  # Shortened
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	
	# Apply font if available
	if bold_font != null:
		title.add_theme_font_override("font", bold_font)
		title.add_theme_font_size_override("font_size", 12)
	
	title.add_theme_color_override("font_color", TITLE_COLOR)
	
	# Add subtle shadow to the text
	title.add_theme_constant_override("shadow_offset_x", 1)
	title.add_theme_constant_override("shadow_offset_y", 1)
	title.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.3))
	
	# Create effect panel with enhanced styling
	effect_panel = PanelContainer.new()
	effects_section.add_child(effect_panel)
	
	var panel_style = StyleBoxFlat.new()
	panel_style.bg_color = Color(0.09, 0.1, 0.14, 1.0)  # Deeper dark color
	panel_style.corner_radius_top_left = 3
	panel_style.corner_radius_top_right = 3
	panel_style.corner_radius_bottom_left = 3
	panel_style.corner_radius_bottom_right = 3
	
	# Add subtle inner shadow
	panel_style.shadow_color = Color(0.0, 0.0, 0.0, 0.25)
	panel_style.shadow_size = 2
	panel_style.shadow_offset = Vector2(0, 1)
	
	effect_panel.add_theme_stylebox_override("panel", panel_style)
	
	# Add padding to the panel
	var padding = MarginContainer.new()
	effect_panel.add_child(padding)
	padding.add_theme_constant_override("margin_left", 5)
	padding.add_theme_constant_override("margin_right", 5)
	padding.add_theme_constant_override("margin_top", 5)
	padding.add_theme_constant_override("margin_bottom", 5)
	
	# Container for the effect info
	var effect_container = VBoxContainer.new()
	padding.add_child(effect_container)
	effect_container.add_theme_constant_override("separation", 3)
	
	# Create effect label with enhanced styling
	effect_label = Label.new()
	effect_container.add_child(effect_label)
	
	effect_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	effect_label.text = "None"  # Shortened
	
	# Apply font if available
	if regular_font != null:
		effect_label.add_theme_font_override("font", regular_font)
		effect_label.add_theme_font_size_override("font_size", 11)
	
	effect_label.add_theme_color_override("font_color", TEXT_COLOR)
	
	# Add subtle shadow to the text
	effect_label.add_theme_constant_override("shadow_offset_x", 1)
	effect_label.add_theme_constant_override("shadow_offset_y", 1)
	effect_label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.3))
	
	# Create effect timer with enhanced styling
	effect_timer = Label.new()
	effect_container.add_child(effect_timer)
	
	effect_timer.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	effect_timer.text = ""
	
	# Apply font if available
	if regular_font != null:
		effect_timer.add_theme_font_override("font", regular_font)
		effect_timer.add_theme_font_size_override("font_size", 10)
	
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
	# Update growth bar and ensure it's visible
	growth_bar.value = growth_amount
	# Make sure the effect is visible by using a small animation
	var flash = create_tween()
	flash.tween_property(growth_bar, "modulate", Color(1.2, 1.2, 1.2), 0.1)
	flash.tween_property(growth_bar, "modulate", Color(1, 1, 1), 0.1)
	flash.play()

func _on_player_shrank(_player, growth_amount):
	# Simple direct value change - no animation
	growth_bar.value = growth_amount

func _on_growth_level_changed(_player, new_level, _level_percent):
	# Just update the text - no animation
	level_label.text = "Level " + str(new_level)

func _on_growth_reset():
	growth_bar.value = 0
	level_label.text = "Level 1"

# Signal handlers for chemical events
func _on_chemical_collected(chemical_type, param2):
	# Handle different parameter types
	var slot_index = -1
	
	# Convert string to enum if needed
	if chemical_type is String:
		match chemical_type.to_lower():
			"red": chemical_type = 0
			"green": chemical_type = 1
			"blue": chemical_type = 2
			"yellow": chemical_type = 3
			"purple": chemical_type = 4
	
	# Use the provided slot from param2 if it's an integer
	if param2 is Vector2:
		# This is a position, find an empty slot
		for i in range(chemical_icons.size()):
			if chemical_icons[i] == null:
				slot_index = i
				break
				
		if slot_index == -1:
			# No empty slot found, use slot 0
			slot_index = 0
	else:
		# Assume it's a slot index
		slot_index = param2
	
	# Update the UI for this chemical
	update_chemical_slot(slot_index, chemical_type)

func _on_chemicals_mixed(effect_name: String, duration: float) -> void:
	_on_effect_applied(effect_name, duration)

# Also handle direct effect_applied signal as fallback
func _on_effect_applied(effect_name: String, duration: float) -> void:
	# Clear the display for empty effects or zero duration
	if effect_name == "None" or duration <= 0:
		# Clear effect display
		if effect_label:
			effect_label.text = ""
		if effect_timer:
			effect_timer.text = ""
		if effects_section:
			effects_section.visible = false
		return
	
	# Make effects section visible with full opacity
	if effects_section:
		effects_section.visible = true
		effects_section.modulate.a = 1.0
	
	# Find panel to style
	var parent_panel = null
	if effects_section and effects_section.get_parent() is PanelContainer:
		parent_panel = effects_section.get_parent()
	
	# Update effect label
	if effect_label:
		effect_label.text = effect_name.to_upper()
		
		# Apply styling based on effect type
		if parent_panel:
			# Reset any previous styling
			var style = StyleBoxFlat.new()
			style.bg_color = Color(0.15, 0.17, 0.19, 0.9)
			style.corner_radius_top_left = 5
			style.corner_radius_top_right = 5
			style.corner_radius_bottom_left = 5
			style.corner_radius_bottom_right = 5
			parent_panel.add_theme_stylebox_override("panel", style)
			
			# Apply effect-specific styling
			match effect_name:
				"Speed Boost", "Speed":
					style.bg_color = Color(0.0, 0.3, 0.8, 0.9)
				"Growth Burst":
					style.bg_color = Color(0.8, 0.2, 0.5, 0.9)
				"Health Regen", "Healing":
					style.bg_color = Color(0.2, 0.7, 0.3, 0.9)
				"Power Attack", "Strength":
					style.bg_color = Color(0.8, 0.1, 0.1, 0.9)
				"Ultimate Power":
					style.bg_color = Color(0.8, 0.6, 0.0, 0.9)
	
	# Update timer
	if effect_timer:
		effect_timer.text = str(int(duration)) + "s"
	
	# Show UI if it was hidden
	if not is_expanded:
		toggle_ui()

# Updates a chemical slot with the given chemical type
func update_chemical_slot(slot_index, chemical_type):
	print("GrowthUI: Updating chemical slot", slot_index, " with type ", chemical_type)
	
	if slot_index < 0 or slot_index >= MAX_CHEMICALS:
		print("GrowthUI: ERROR - Slot index out of range:", slot_index)
		return
	
	# Make sure we have enough slots
	while chemical_container.get_child_count() < MAX_CHEMICALS:
		var new_slot = create_chemical_slot()
		chemical_container.add_child(new_slot)
		print("GrowthUI: Added missing slot")
	
	# Get the slot panel
	var slot = chemical_container.get_child(slot_index)
	if not slot:
		print("GrowthUI: ERROR - Couldn't find slot at index", slot_index)
		return
	
	# Clear the slot first
	for child in slot.get_children():
		child.queue_free()
	
	# Remove from tracking array
	if slot_index < chemical_icons.size():
		chemical_icons[slot_index] = null
	
	# Create a centering container
	var centering_container = CenterContainer.new()
	centering_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	centering_container.size_flags_vertical = Control.SIZE_EXPAND_FILL
	slot.add_child(centering_container)
	
	# Create slot style with high contrast
	var slot_style = StyleBoxFlat.new()
	slot_style.bg_color = Color(0.15, 0.16, 0.20, 1.0)
	slot_style.border_width_left = 2
	slot_style.border_width_top = 2
	slot_style.border_width_right = 2
	slot_style.border_width_bottom = 2
	slot_style.border_color = Color(0.6, 0.6, 0.6, 1.0)
	slot_style.corner_radius_top_left = 2
	slot_style.corner_radius_top_right = 2
	slot_style.corner_radius_bottom_left = 2
	slot_style.corner_radius_bottom_right = 2
	
	# Apply style
	slot.add_theme_stylebox_override("panel", slot_style)
	
	# If a chemical type is provided, create and add a new icon
	if chemical_type != null:
		print("GrowthUI: Creating new icon for chemical type:", chemical_type)
		var color = get_chemical_color(chemical_type)
		print("GrowthUI: Chemical color:", color)
		
		# Update slot style based on chemical type (more vibrant)
		slot_style.bg_color = Color(color.r * 0.3, color.g * 0.3, color.b * 0.3, 1.0)
		slot_style.border_color = Color(color.r, color.g, color.b, 1.0)
		slot.add_theme_stylebox_override("panel", slot_style)
		
		# Create the icon with better visibility
		var icon = ColorRect.new()
		centering_container.add_child(icon)
		icon.color = color
		icon.custom_minimum_size = Vector2(16, 16)
		
		# Store the icon in tracking array
		if slot_index >= chemical_icons.size():
			while chemical_icons.size() <= slot_index:
				chemical_icons.append(null)
		chemical_icons[slot_index] = icon
		print("GrowthUI: Successfully added chemical icon to slot", slot_index)
	else:
		# Add empty placeholder with better visibility
		var placeholder = ColorRect.new()
		placeholder.color = Color(0.3, 0.3, 0.3, 1.0)
		placeholder.custom_minimum_size = Vector2(16, 16)
		centering_container.add_child(placeholder)
		
		# Store null in tracking array
		if slot_index >= chemical_icons.size():
			while chemical_icons.size() <= slot_index:
				chemical_icons.append(null)
		chemical_icons[slot_index] = null

# Returns a color based on the chemical type
func get_chemical_color(chemical_type):
	# Handle both string and enum integer types
	if chemical_type is String:
		# Handle string types (from old code)
		match chemical_type:
			"red": return Color(1, 0.2, 0.2)
			"blue": return Color(0.2, 0.4, 1)
			"green": return Color(0.2, 0.8, 0.2)
			"yellow": return Color(1, 0.9, 0.2)
			"purple": return Color(0.8, 0.2, 0.8)
			_: return Color(0.7, 0.7, 0.7)
	else:
		# Handle enum integer types (from ChemicalItem)
		match chemical_type:
			0: return Color(1, 0.2, 0.2)    # RED
			1: return Color(0.2, 0.8, 0.2)  # GREEN
			2: return Color(0.2, 0.4, 1)    # BLUE
			3: return Color(1, 0.9, 0.2)    # YELLOW
			4: return Color(0.8, 0.2, 0.8)  # PURPLE
			_: return Color(0.7, 0.7, 0.7)

func create_chemical_slot() -> PanelContainer:
	# Create slot container with better visibility
	var slot = PanelContainer.new()
	slot.custom_minimum_size = Vector2(24, 24)  # Larger square slots for visibility
	
	# Style the slot with high contrast
	var slot_style = StyleBoxFlat.new()
	slot_style.bg_color = Color(0.18, 0.18, 0.20, 1.0)  # Slightly brighter background
	slot_style.border_width_left = 2
	slot_style.border_width_top = 2
	slot_style.border_width_right = 2
	slot_style.border_width_bottom = 2
	slot_style.border_color = Color(0.6, 0.6, 0.6, 1.0)  # Bright, visible border
	slot_style.corner_radius_top_left = 3
	slot_style.corner_radius_top_right = 3
	slot_style.corner_radius_bottom_left = 3
	slot_style.corner_radius_bottom_right = 3
	
	# Add subtle shadow for depth
	slot_style.shadow_color = Color(0, 0, 0, 0.3)
	slot_style.shadow_size = 1
	slot_style.shadow_offset = Vector2(1, 1)
	
	slot.add_theme_stylebox_override("panel", slot_style)
	
	# Add a placeholder icon that's more visible
	var placeholder = ColorRect.new()
	placeholder.color = Color(0.3, 0.3, 0.35, 1.0)  # Slightly blueish gray
	placeholder.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	placeholder.size_flags_vertical = Control.SIZE_EXPAND_FILL
	placeholder.custom_minimum_size = Vector2(16, 16)
	
	# Center the placeholder
	var centering_container = CenterContainer.new()
	centering_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	centering_container.size_flags_vertical = Control.SIZE_EXPAND_FILL
	slot.add_child(centering_container)
	centering_container.add_child(placeholder)
	
	return slot

func update_growth_from_player():
	# Get initial growth value from player if available
	var player = get_node_or_null("/root/Player")
	if not player:
		# Try to find player in the scene
		var players = get_tree().get_nodes_in_group("Player")
		if players.size() > 0:
			player = players[0]
	
	if player and player.has_node("GrowthSystem"):
		var gs = player.get_node("GrowthSystem")
		growth_bar.value = gs.current_growth
		level_label.text = "Level " + str(gs.growth_level)
		print("GROWTH UI: Updated growth bar to: ", gs.current_growth)
	else:
		print("GROWTH UI: ERROR - Player not found or GrowthSystem not available")
		
		# If we can't find the player, try to find it after a short delay
		var timer = get_tree().create_timer(0.5)
		timer.timeout.connect(func(): update_growth_from_player())

# Test function to verify effect display is working
func test_effect_display():
	print("GROWTH UI: Testing effect display")
	
	# Make sure UI is expanded
	set_expanded(true, false)
	
	# Make sure effect display is created and visible
	if effect_label and effect_timer:
		# Display a test effect
		effect_label.text = "TEST EFFECT"
		effect_timer.text = "10s"
		
		# Make sure effects section is visible
		if effects_section:
			effects_section.visible = true
			effects_section.modulate.a = 1.0
		
		# Add a visual flash effect
		var effect_flash = create_tween()
		effect_flash.tween_property(effect_label, "modulate", Color(1.5, 1.5, 1.5), 0.2)
		effect_flash.tween_property(effect_label, "modulate", Color(1, 1, 1), 0.3)
		effect_flash.play()
		
		print("GROWTH UI: Test effect displayed. If you see this in the UI, the effect display is working!")
		
		# Reset after 3 seconds
		get_tree().create_timer(3.0).timeout.connect(func(): 
			effect_label.text = "None"
			effect_timer.text = ""
			print("GROWTH UI: Test effect cleared")
		)
	else:
		print("GROWTH UI: ERROR - effect_label or effect_timer is null!")

# New debug function to periodically check the effect display
func debug_check_effect_display():
	print("GROWTH UI: DEBUG STATE CHECK (TIMESTAMP: ", Time.get_ticks_msec(), ")")
	
	if effect_label:
		print("  - effect_label text: '", effect_label.text, "'")
	else:
		print("  - effect_label is NULL!")
	
	if effect_timer:
		print("  - effect_timer text: '", effect_timer.text, "'")
	else:
		print("  - effect_timer is NULL!")
	
	if effects_section:
		print("  - effects_section visible: ", effects_section.visible, ", alpha: ", effects_section.modulate.a)
	else:
		print("  - effects_section is NULL!")
	
	# Check GrowthSystem 
	var player = get_tree().get_first_node_in_group("Player")
	if player and player.has_node("GrowthSystem"):
		var gs = player.get_node("GrowthSystem") 
		print("  - GrowthSystem effect: '", gs.current_effect, "', timer: ", gs.effect_timer)
		
		# Check signals
		if get_node_or_null("/root/SignalBus") != null:
			var chemicals_mixed_connections = SignalBus.get_signal_connection_list("chemicals_mixed")
			print("  - chemicals_mixed signal connections: ", chemicals_mixed_connections.size())
	else:
		print("  - GrowthSystem not found!")
