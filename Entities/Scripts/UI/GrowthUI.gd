extends CanvasLayer
class_name GrowthUI

# Growth UI displays the player's current growth level, stored chemicals, and active effects

# References to UI elements
var growth_bar: ProgressBar
var level_label: Label
var chemical_container: HBoxContainer
var effect_label: Label
var effect_timer: Label

# Chemical colors for visualization (instead of textures)
const CHEMICAL_COLORS = {
	0: Color(1.0, 0.2, 0.2),  # RED
	1: Color(0.2, 1.0, 0.2),  # GREEN
	2: Color(0.2, 0.2, 1.0),  # BLUE
	3: Color(1.0, 1.0, 0.2),  # YELLOW
	4: Color(0.8, 0.2, 0.8)   # PURPLE
}

# Effect colors for visualization (instead of textures)
const EFFECT_COLORS = {
	1: Color(0.0, 0.8, 1.0),   # SPEED_BOOST
	2: Color(1.0, 0.3, 0.3),   # DAMAGE_BOOST
	3: Color(1.0, 0.5, 0.0),   # FIRE_RESISTANCE
	4: Color(1.0, 0.0, 0.0),   # EXPLOSION
	5: Color(0.0, 1.0, 0.5),   # HEALTH_REGEN
	6: Color(0.5, 1.0, 0.0),   # JUMP_BOOST
	7: Color(0.7, 0.0, 0.7),   # TOXIC_CLOUD
	8: Color(1.0, 0.8, 0.0),   # ELECTRIC_ATTACKS
	9: Color(0.0, 0.5, 1.0),   # SHIELD
	10: Color(0.6, 0.6, 0.6)   # INVISIBILITY
}

# Chemical icons
var chemical_icons = []
const MAX_CHEMICALS = 2

# Chemical and effect type enums defined directly
enum ChemicalType {
	RED = 0,
	GREEN = 1,
	BLUE = 2,
	YELLOW = 3,
	PURPLE = 4
}

enum EffectType {
	NONE = 0,
	SPEED_BOOST = 1,
	DAMAGE_BOOST = 2,
	FIRE_RESISTANCE = 3,
	EXPLOSION = 4,
	HEALTH_REGEN = 5,
	JUMP_BOOST = 6,
	TOXIC_CLOUD = 7,
	ELECTRIC_ATTACKS = 8,
	SHIELD = 9,
	INVISIBILITY = 10
}

# Called when the node enters the scene tree
func _ready():
	# Create UI container
	var ui_container = Control.new()
	ui_container.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(ui_container)
	
	# Create margin container
	var margin = MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_top", 20)
	margin.add_theme_constant_override("margin_left", 20)
	margin.add_theme_constant_override("margin_right", 20)
	margin.add_theme_constant_override("margin_bottom", 20)
	ui_container.add_child(margin)
	
	# Create VBox for layout
	var vbox = VBoxContainer.new()
	margin.add_child(vbox)
	
	# Create growth section
	var growth_section = HBoxContainer.new()
	growth_section.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vbox.add_child(growth_section)
	
	# Growth label
	var growth_title = Label.new()
	growth_title.text = "Growth:"
	growth_title.add_theme_font_size_override("font_size", 18)
	growth_section.add_child(growth_title)
	
	# Growth bar
	growth_bar = ProgressBar.new()
	growth_bar.max_value = 100
	growth_bar.value = 0
	growth_bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	growth_bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	growth_section.add_child(growth_bar)
	
	# Level label
	level_label = Label.new()
	level_label.text = "Level 1"
	level_label.add_theme_font_size_override("font_size", 18)
	growth_section.add_child(level_label)
	
	# Spacer
	var spacer = Control.new()
	spacer.custom_minimum_size = Vector2(0, 10)
	vbox.add_child(spacer)
	
	# Chemical section
	var chemical_section = HBoxContainer.new()
	vbox.add_child(chemical_section)
	
	# Chemical label
	var chemical_title = Label.new()
	chemical_title.text = "Chemicals:"
	chemical_title.add_theme_font_size_override("font_size", 18)
	chemical_section.add_child(chemical_title)
	
	# Chemical container for icons
	chemical_container = HBoxContainer.new()
	chemical_container.add_theme_constant_override("separation", 10)
	chemical_section.add_child(chemical_container)
	
	# Add empty slots for chemicals
	for i in range(MAX_CHEMICALS):
		var slot = Panel.new()
		slot.custom_minimum_size = Vector2(40, 40)
		chemical_container.add_child(slot)
		chemical_icons.append(null)  # No icon in slot yet
	
	# Effect section 
	var effect_section = HBoxContainer.new()
	vbox.add_child(effect_section)
	
	# Effect label
	var effect_title = Label.new()
	effect_title.text = "Effect:"
	effect_title.add_theme_font_size_override("font_size", 18)
	effect_section.add_child(effect_title)
	
	# Current effect label
	effect_label = Label.new()
	effect_label.text = "None"
	effect_label.add_theme_font_size_override("font_size", 18)
	effect_section.add_child(effect_label)
	
	# Effect timer
	effect_timer = Label.new()
	effect_timer.text = ""
	effect_timer.add_theme_font_size_override("font_size", 18)
	effect_section.add_child(effect_timer)
	
	# Connect to signals
	SignalBus.player_grew.connect(_on_player_grew)
	SignalBus.player_shrank.connect(_on_player_shrank)
	SignalBus.growth_level_changed.connect(_on_growth_level_changed)
	SignalBus.growth_reset.connect(_on_growth_reset)
	SignalBus.chemical_collected.connect(_on_chemical_collected)
	SignalBus.chemicals_mixed.connect(_on_chemicals_mixed)
	
	print("GrowthUI initialized")

# Update the growth bar and level
func _on_growth_level_changed(level, scale):
	# Update level label
	level_label.text = "Level " + str(level)
	
	# Update progress bar (simple mapping from scale to percentage)
	var percentage = ((scale.x - 1.0) / 2.0) * 100  # Assuming max scale is 3.0
	growth_bar.value = percentage
	
	# Add color based on level
	var color = Color.from_hsv((level - 1) / 10.0, 0.8, 0.9)
	growth_bar.modulate = color

# Update UI when player grows
func _on_player_grew(amount, new_scale):
	# Flash the growth bar
	growth_bar.modulate = Color(0.2, 1.0, 0.2)
	var tween = create_tween()
	tween.tween_property(growth_bar, "modulate", Color(1, 1, 1), 0.5)

# Update UI when player shrinks
func _on_player_shrank(amount, new_scale):
	# Flash the growth bar
	growth_bar.modulate = Color(1.0, 0.2, 0.2)
	var tween = create_tween()
	tween.tween_property(growth_bar, "modulate", Color(1, 1, 1), 0.5)

# Reset the growth UI
func _on_growth_reset():
	growth_bar.value = 0
	level_label.text = "Level 1"
	growth_bar.modulate = Color(1, 1, 1)

# Update chemical display when collected
func _on_chemical_collected(chemical_type, chemical_position):
	# Find the first empty slot
	var slot_index = -1
	for i in range(chemical_icons.size()):
		if chemical_icons[i] == null:
			slot_index = i
			break
	
	if slot_index >= 0:
		# Create chemical icon in the slot (using ColorRect for simplicity)
		var icon = ColorRect.new()
		icon.custom_minimum_size = Vector2(36, 36)
		
		# Set color based on chemical type
		if chemical_type in CHEMICAL_COLORS:
			icon.color = CHEMICAL_COLORS[chemical_type]
		else:
			icon.color = Color(0.7, 0.7, 0.7)  # Default gray
		
		# Store the chemical type in the icon metadata
		icon.set_meta("chemical_type", chemical_type)
		
		# Add icon to slot
		chemical_container.get_child(slot_index).add_child(icon)
		chemical_icons[slot_index] = icon
		
		# Flash effect
		icon.modulate.a = 0
		var tween = create_tween()
		tween.tween_property(icon, "modulate:a", 1.0, 0.3)

# Update UI when chemicals are mixed
func _on_chemicals_mixed(chemical_types, effect_name):
	# Clear chemical slots
	for i in range(chemical_icons.size()):
		if chemical_icons[i]:
			chemical_icons[i].queue_free()
			chemical_icons[i] = null
	
	# Update effect display
	if effect_name and effect_name != "None":
		# Format the effect name for display (convert from camelCase if needed)
		var display_name = effect_name
		# Insert spaces before capital letters (e.g., "FireResist" -> "Fire Resist")
		for i in range(display_name.length() - 1, 0, -1):
			if display_name[i].is_upper():
				display_name = display_name.insert(i, " ")
		
		effect_label.text = display_name
		
		# Set color based on effect name
		var effect_type = EffectType.NONE
		for type_id in EffectType:
			if type_id.to_lower().replace("_", "") == effect_name.to_lower().replace(" ", ""):
				effect_type = EffectType[type_id]
				break
		
		if effect_type in EFFECT_COLORS:
			effect_label.modulate = EFFECT_COLORS[effect_type]
		else:
			effect_label.modulate = Color(1, 1, 1)
	else:
		effect_label.text = "None"
		effect_label.modulate = Color(1, 1, 1)

# Process function to update effect timer
func _process(delta):
	# Check if there's a chemical_mixer in the player
	var player = get_tree().get_first_node_in_group("player")
	if player:
		var mixer = player.get_node_or_null("ChemicalMixer")
		if mixer:
			var active_effects = mixer.get_active_effects() if mixer.has_method("get_active_effects") else []
			if active_effects.size() > 0:
				# Display the first active effect's name
				var effect_name = active_effects[0]
				
				# Get the effect time remaining
				if effect_name in mixer.active_effects:
					var time_left = mixer.active_effects[effect_name]
					if time_left > 0:
						effect_timer.text = "(" + str(ceil(time_left)) + "s)"
					else:
						effect_timer.text = ""
				else:
					effect_timer.text = ""
			else:
				effect_timer.text = ""
		else:
			effect_timer.text = "" 