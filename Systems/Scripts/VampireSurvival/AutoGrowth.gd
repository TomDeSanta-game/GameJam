extends Node

class_name AutoGrowth

# Growth parameters
@export var base_growth_rate: float = 1.0  # Growth points per second
@export var growth_multiplier: float = 1.2  # Growth multiplier per level
@export var xp_needed_base: float = 10.0   # Base XP needed for first level
@export var xp_scaling: float = 1.5        # How much more XP is needed per level

# Tracked variables
var current_level: int = 1
var current_xp: float = 0.0
var xp_needed: float = 10.0
var growth_system: GrowthSystem
var player: Node2D
var game_time: float = 0.0
var last_chemical_time: float = 0.0
var chemical_interval: float = 15.0  # Give player a chemical every 15 seconds

# Solo Leveling features
var available_abilities: Array = [
	"Health Regeneration",
	"Attack Boost",
	"Speed Boost",
	"Enhanced Growth",
	"Chemical Potency",
	"Critical Strike",
	"Damage Reduction"
]
var acquired_abilities: Dictionary = {}
var ability_levels: Dictionary = {}
var blue_particles: GPUParticles2D

# UI
var level_label: Label
var xp_bar: ProgressBar
var abilities_container: VBoxContainer

func _ready():
	# Find player and growth system
	player = get_tree().get_first_node_in_group("Player")
	if player:
		growth_system = player.get_node_or_null("GrowthSystem")
		if not growth_system:
			print("AutoGrowth: GrowthSystem not found!")
			set_process(false)
	else:
		print("AutoGrowth: Player not found!")
		set_process(false)
	
	# Set initial values
	xp_needed = xp_needed_base
	
	# Connect to signals
	var signal_bus = get_node_or_null("/root/SignalBus")
	if signal_bus and signal_bus.has_signal("enemy_died"):
		signal_bus.enemy_died.connect(_on_enemy_died)
	
	# Create particles for blue aura
	create_blue_particles()
	
	# Create level label and UI
	create_level_ui()

func create_blue_particles():
	# Create a blue aura around the player
	blue_particles = GPUParticles2D.new()
	blue_particles.amount = 20
	blue_particles.lifetime = 2.0
	blue_particles.local_coords = false
	
	var material = ParticleProcessMaterial.new()
	material.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	material.emission_sphere_radius = 30.0 
	material.gravity = Vector3(0, -5, 0)
	material.orbit_velocity_min = 0.0
	material.orbit_velocity_max = 0.2
	material.scale_min = 2.0
	material.scale_max = 4.0
	material.color = Color(0.3, 0.6, 1.0, 0.6)
	
	blue_particles.process_material = material
	blue_particles.emitting = true
	
	# Add to player if available
	if player:
		player.add_child(blue_particles)

func create_level_ui():
	# Create UI canvas layer for abilities
	var canvas = CanvasLayer.new()
	canvas.layer = 5
	add_child(canvas)
	
	var ui_container = Control.new()
	ui_container.set_anchors_preset(Control.PRESET_FULL_RECT)
	canvas.add_child(ui_container)
	
	# Create level panel
	var level_panel = Panel.new()
	level_panel.size = Vector2(200, 80)
	level_panel.position = Vector2(10, 150)
	
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.1, 0.2, 0.4, 0.7)
	style.border_width_left = 2
	style.border_width_top = 2
	style.border_width_right = 2
	style.border_width_bottom = 2
	style.border_color = Color(0.3, 0.5, 0.8)
	style.corner_radius_top_left = 5
	style.corner_radius_top_right = 5
	style.corner_radius_bottom_right = 5
	style.corner_radius_bottom_left = 5
	
	level_panel.add_theme_stylebox_override("panel", style)
	ui_container.add_child(level_panel)
	
	# Create level label
	level_label = Label.new()
	level_label.text = "Level: " + str(current_level)
	level_label.add_theme_color_override("font_color", Color(0.4, 0.7, 1.0))
	level_label.add_theme_font_size_override("font_size", 16)
	level_label.position = Vector2(10, 10)
	level_panel.add_child(level_label)
	
	# Create XP bar
	xp_bar = ProgressBar.new()
	xp_bar.size = Vector2(180, 10)
	xp_bar.position = Vector2(10, 35)
	xp_bar.max_value = xp_needed
	xp_bar.value = current_xp
	xp_bar.show_percentage = false
	
	var bar_style = StyleBoxFlat.new()
	bar_style.bg_color = Color(0.2, 0.4, 0.7, 0.8)
	bar_style.border_width_left = 1
	bar_style.border_width_top = 1
	bar_style.border_width_right = 1
	bar_style.border_width_bottom = 1
	bar_style.border_color = Color(0.3, 0.5, 0.8)
	bar_style.corner_radius_top_left = 2
	bar_style.corner_radius_top_right = 2
	bar_style.corner_radius_bottom_right = 2
	bar_style.corner_radius_bottom_left = 2
	
	xp_bar.add_theme_stylebox_override("fill", bar_style)
	level_panel.add_child(xp_bar)
	
	# Create XP label
	var xp_label = Label.new()
	xp_label.text = "0 / " + str(int(xp_needed))
	xp_label.add_theme_color_override("font_color", Color(0.6, 0.8, 1.0))
	xp_label.add_theme_font_size_override("font_size", 12)
	xp_label.position = Vector2(10, 50)
	xp_label.name = "XPLabel"
	level_panel.add_child(xp_label)
	
	# Create abilities container (collapsed initially)
	abilities_container = VBoxContainer.new()
	abilities_container.position = Vector2(10, 250)
	abilities_container.size = Vector2(200, 200)
	abilities_container.visible = false
	ui_container.add_child(abilities_container)
	
	# Create abilities button
	var abilities_button = Button.new()
	abilities_button.text = "Abilities"
	abilities_button.size = Vector2(180, 25)
	abilities_button.position = Vector2(10, 45)
	abilities_button.add_theme_color_override("font_color", Color(0.4, 0.7, 1.0))
	abilities_button.pressed.connect(_toggle_abilities_panel)
	level_panel.add_child(abilities_button)

func _toggle_abilities_panel():
	abilities_container.visible = !abilities_container.visible
	update_abilities_display()

func update_abilities_display():
	# Clear existing children
	for child in abilities_container.get_children():
		child.queue_free()
	
	# Create header
	var header = Label.new()
	header.text = "ACQUIRED ABILITIES"
	header.add_theme_color_override("font_color", Color(0.4, 0.7, 1.0))
	header.add_theme_font_size_override("font_size", 16)
	abilities_container.add_child(header)
	
	# Add separator
	var separator = HSeparator.new()
	abilities_container.add_child(separator)
	
	# Add each ability
	for ability_name in acquired_abilities.keys():
		var ability_panel = Panel.new()
		ability_panel.custom_minimum_size = Vector2(190, 30)
		
		var panel_style = StyleBoxFlat.new()
		panel_style.bg_color = Color(0.15, 0.25, 0.45, 0.7)
		panel_style.border_width_left = 1
		panel_style.border_width_top = 1
		panel_style.border_width_right = 1
		panel_style.border_width_bottom = 1
		panel_style.border_color = Color(0.3, 0.5, 0.8, 0.6)
		panel_style.corner_radius_top_left = 3
		panel_style.corner_radius_top_right = 3
		panel_style.corner_radius_bottom_right = 3
		panel_style.corner_radius_bottom_left = 3
		
		ability_panel.add_theme_stylebox_override("panel", panel_style)
		abilities_container.add_child(ability_panel)
		
		var ability_label = Label.new()
		ability_label.text = ability_name + " Lv." + str(ability_levels[ability_name])
		ability_label.add_theme_color_override("font_color", Color(0.6, 0.8, 1.0))
		ability_label.add_theme_font_size_override("font_size", 13)
		ability_label.position = Vector2(5, 5)
		ability_panel.add_child(ability_label)

func _process(delta: float):
	game_time += delta
	
	# Natural growth over time (very slow)
	current_xp += base_growth_rate * delta
	
	# Check for level up
	if current_xp >= xp_needed:
		level_up()
	
	# Give player a chemical every so often
	if game_time - last_chemical_time >= chemical_interval:
		last_chemical_time = game_time
		give_random_chemical()
	
	# Update UI
	update_ui()
	
	# Apply ability effects
	apply_ability_effects(delta)

func update_ui():
	# Update level label
	if level_label:
		level_label.text = "Level: " + str(current_level)
	
	# Update XP bar
	if xp_bar:
		xp_bar.max_value = xp_needed
		xp_bar.value = current_xp
		
		# Update XP label
		var xp_label = xp_bar.get_parent().get_node_or_null("XPLabel")
		if xp_label:
			xp_label.text = str(int(current_xp)) + " / " + str(int(xp_needed))
	
	# Update player aura size based on level
	if blue_particles:
		var base_size = 10.0
		var size_scale = min(1.0 + (current_level * 0.05), 2.5)  # Cap at 2.5x
		
		var material = blue_particles.process_material
		if material:
			material.emission_sphere_radius = base_size * size_scale
			
			# Adjust color intensity with level
			var base_alpha = 0.3
			var alpha = min(base_alpha + (current_level * 0.01), 0.8)  # Cap at 0.8
			material.color = Color(0.3, 0.6, 1.0, alpha)

func level_up():
	current_xp -= xp_needed
	current_level += 1
	
	# Increase XP needed for next level
	xp_needed = xp_needed_base * pow(xp_scaling, current_level - 1)
	
	# Growth burst
	if growth_system:
		var growth_amount = base_growth_rate * growth_multiplier
		growth_system.grow(growth_amount)
	
	# Show level up effect
	show_level_up_effect()
	
	# On certain levels, grant new abilities
	if current_level % 3 == 0:  # Every 3 levels
		grant_random_ability()
	elif current_level % 5 == 0:  # Every 5 levels, upgrade existing
		upgrade_random_ability()

func show_level_up_effect():
	# Create level up effects if player exists
	if player:
		# Flash effect
		var flash = ColorRect.new()
		flash.color = Color(0.3, 0.6, 1.0, 0.0)
		flash.set_anchors_preset(Control.PRESET_FULL_RECT)
		flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(flash)
		
		# Level up text
		var level_text = Label.new()
		level_text.text = "LEVEL UP!"
		level_text.add_theme_font_size_override("font_size", 32)
		level_text.add_theme_color_override("font_color", Color(0.4, 0.7, 1.0))
		level_text.add_theme_color_override("font_shadow_color", Color(0.0, 0.2, 0.5))
		level_text.add_theme_constant_override("shadow_offset_x", 2)
		level_text.add_theme_constant_override("shadow_offset_y", 2)
		level_text.position = player.global_position + Vector2(-100, -100)
		level_text.modulate.a = 0.0
		add_child(level_text)
		
		# Create particles
		var particles = GPUParticles2D.new()
		particles.position = player.global_position
		particles.amount = 50
		particles.lifetime = 1.0
		particles.explosiveness = 0.8
		
		var material = ParticleProcessMaterial.new()
		material.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
		material.emission_sphere_radius = 10.0
		material.gravity = Vector3(0, -30, 0)
		material.initial_velocity_min = 20.0
		material.initial_velocity_max = 50.0
		material.scale_min = 2.0
		material.scale_max = 5.0
		material.color = Color(0.3, 0.6, 1.0, 0.8)
		
		particles.process_material = material
		add_child(particles)
		
		# Animate the effects
		var tween = create_tween()
		tween.tween_property(flash, "color:a", 0.5, 0.2)
		tween.tween_property(flash, "color:a", 0.0, 0.3)
		tween.parallel().tween_property(level_text, "modulate:a", 1.0, 0.3)
		tween.parallel().tween_property(level_text, "position", player.global_position + Vector2(-60, -80), 0.5)
		tween.parallel().tween_property(particles, "emitting", true, 0.01)
		tween.tween_interval(0.5)
		tween.tween_property(level_text, "modulate:a", 0.0, 0.8)
		tween.tween_callback(flash.queue_free)
		tween.tween_callback(level_text.queue_free)
		
		# Wait for particles to finish before removing
		await get_tree().create_timer(particles.lifetime + 0.5).timeout
		particles.queue_free()

func grant_random_ability():
	# Filter out already acquired abilities
	var available = []
	for ability in available_abilities:
		if not acquired_abilities.has(ability):
			available.append(ability)
	
	if available.size() > 0:
		# Choose a random ability
		var random_index = randi() % available.size()
		var chosen_ability = available[random_index]
		
		# Add to acquired abilities
		acquired_abilities[chosen_ability] = true
		ability_levels[chosen_ability] = 1
		
		# Apply initial ability effect
		apply_initial_ability_effect(chosen_ability)
		
		# Show ability gain effect
		show_ability_gain_effect(chosen_ability)
	else:
		# If all abilities are acquired, upgrade a random one
		upgrade_random_ability()

func upgrade_random_ability():
	# Get list of abilities that can be upgraded
	var upgradable = acquired_abilities.keys()
	
	if upgradable.size() > 0:
		# Choose a random ability to upgrade
		var random_index = randi() % upgradable.size()
		var chosen_ability = upgradable[random_index]
		
		# Increment level
		ability_levels[chosen_ability] += 1
		
		# Apply upgrade effect
		apply_ability_upgrade(chosen_ability)
		
		# Show upgrade effect
		show_ability_upgrade_effect(chosen_ability)

func apply_initial_ability_effect(ability_name: String):
	match ability_name:
		"Health Regeneration":
			# Start regenerating health slowly
			if player and player.has_method("set_health_regen"):
				player.set_health_regen(0.5)  # 0.5 health per second
				
		"Attack Boost":
			# Increase attack damage
			if player and player.has_method("modify_attack"):
				player.modify_attack(1.2)  # 20% boost
				
		"Speed Boost":
			# Increase movement speed
			if player:
				if "speed" in player:
					player.set("speed", player.get("speed") * 1.15)
				# Alternative approach:
				# player.set("speed", player.get("speed") * 1.15) if "speed" in player else null
				
		"Enhanced Growth":
			# Increase growth rate even more
			base_growth_rate *= 1.3
			
		"Chemical Potency":
			# Make chemicals more potent
			if growth_system:
				if "effect_multiplier" in growth_system:
					growth_system.set("effect_multiplier", 1.25)
				# Alternative approach:
				# growth_system.set("effect_multiplier", 1.25) if "effect_multiplier" in growth_system else null
				
		"Critical Strike":
			# Add critical hit chance
			if player:
				player.set("critical_chance", 0.1) if player.has_method("set_critical_chance") else null
				
		"Damage Reduction":
			# Reduce incoming damage
			if player and player.has_method("set_damage_reduction"):
				player.set_damage_reduction(0.1)  # 10% reduction

func apply_ability_upgrade(ability_name: String):
	var level = ability_levels[ability_name]
	
	match ability_name:
		"Health Regeneration":
			# Increase regen rate
			if player and player.has_method("set_health_regen"):
				player.set_health_regen(0.5 * level)
				
		"Attack Boost":
			# Increase attack more
			if player and player.has_method("modify_attack"):
				player.modify_attack(1.0 + (level * 0.1))  # +10% per level
				
		"Speed Boost":
			# More speed
			if player:
				if "speed" in player:
					player.set("speed", player.get("speed") * 1.15)
				
		"Enhanced Growth":
			# Increase growth rate even more
			base_growth_rate *= 1.3
			
		"Chemical Potency":
			# Make chemicals even more potent
			if growth_system:
				if "effect_multiplier" in growth_system:
					growth_system.set("effect_multiplier", 1.25)
				# Alternative approach:
				# growth_system.set("effect_multiplier", 1.25) if "effect_multiplier" in growth_system else null
				
		"Critical Strike":
			# Increase crit chance
			if player:
				player.set("critical_chance", level * 0.05) if player.has_method("set_critical_chance") else null
				
		"Damage Reduction":
			# More damage reduction
			if player and player.has_method("set_damage_reduction"):
				player.set_damage_reduction(level * 0.05)  # 5% per level

func apply_ability_effects(delta: float):
	# Apply ongoing effects
	if player:
		# Health regeneration
		if acquired_abilities.get("Health Regeneration", false):
			var regen_level = ability_levels.get("Health Regeneration", 0)
			if player.has_method("heal") and player.has("current_health") and player.has("max_health"):
				var regen_amount = regen_level * 0.5 * delta  # 0.5 per second per level
				if player.current_health < player.max_health:
					player.heal(regen_amount)

func show_ability_gain_effect(ability_name: String):
	if player:
		# Create a special announcement
		var ability_text = Label.new()
		ability_text.text = "NEW ABILITY!\n" + ability_name
		ability_text.add_theme_font_size_override("font_size", 24)
		ability_text.add_theme_color_override("font_color", Color(0.6, 1.0, 0.8))
		ability_text.add_theme_color_override("font_shadow_color", Color(0.0, 0.4, 0.3))
		ability_text.add_theme_constant_override("shadow_offset_x", 2)
		ability_text.add_theme_constant_override("shadow_offset_y", 2)
		ability_text.add_theme_constant_override("line_spacing", 5)
		ability_text.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		ability_text.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		ability_text.set_anchors_preset(Control.PRESET_CENTER)
		ability_text.modulate.a = 0.0
		add_child(ability_text)
		
		# Create particles
		var particles = GPUParticles2D.new()
		particles.position = player.global_position
		particles.amount = 80
		particles.lifetime = 2.0
		particles.explosiveness = 0.6
		
		var material = ParticleProcessMaterial.new()
		material.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
		material.emission_sphere_radius = 20.0
		material.gravity = Vector3(0, -20, 0)
		material.initial_velocity_min = 30.0
		material.initial_velocity_max = 70.0
		material.scale_min = 3.0
		material.scale_max = 6.0
		material.color = Color(0.2, 0.8, 0.6, 0.8)
		
		particles.process_material = material
		add_child(particles)
		
		# Animate
		var tween = create_tween()
		tween.tween_property(ability_text, "modulate:a", 1.0, 0.5)
		tween.parallel().tween_property(particles, "emitting", true, 0.01)
		tween.tween_property(ability_text, "scale", Vector2(1.2, 1.2), 0.5)
		tween.tween_property(ability_text, "scale", Vector2(1.0, 1.0), 0.5)
		tween.tween_interval(1.0)
		tween.tween_property(ability_text, "modulate:a", 0.0, 1.0)
		tween.tween_callback(ability_text.queue_free)
		
		# Update abilities display
		update_abilities_display()
		
		# Wait for particles to finish
		await get_tree().create_timer(particles.lifetime + 0.5).timeout
		particles.queue_free()

func show_ability_upgrade_effect(ability_name: String):
	if player:
		# Create upgrade announcement
		var level = ability_levels[ability_name]
		var upgrade_text = Label.new()
		upgrade_text.text = ability_name + "\nUPGRADED TO LEVEL " + str(level)
		upgrade_text.add_theme_font_size_override("font_size", 20)
		upgrade_text.add_theme_color_override("font_color", Color(0.8, 0.8, 1.0))
		upgrade_text.add_theme_color_override("font_shadow_color", Color(0.2, 0.2, 0.5))
		upgrade_text.add_theme_constant_override("shadow_offset_x", 2)
		upgrade_text.add_theme_constant_override("shadow_offset_y", 2)
		upgrade_text.add_theme_constant_override("line_spacing", 5)
		upgrade_text.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		upgrade_text.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		upgrade_text.set_anchors_preset(Control.PRESET_CENTER)
		upgrade_text.modulate.a = 0.0
		add_child(upgrade_text)
		
		# Create upgrade particles
		var particles = GPUParticles2D.new()
		particles.position = player.global_position
		particles.amount = 50
		particles.lifetime = 1.5
		particles.explosiveness = 0.5
		
		var material = ParticleProcessMaterial.new()
		material.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
		material.emission_sphere_radius = 15.0
		material.gravity = Vector3(0, -15, 0)
		material.initial_velocity_min = 20.0
		material.initial_velocity_max = 50.0
		material.scale_min = 2.0
		material.scale_max = 5.0
		material.color = Color(0.6, 0.5, 1.0, 0.7)
		
		particles.process_material = material
		add_child(particles)
		
		# Animate
		var tween = create_tween()
		tween.tween_property(upgrade_text, "modulate:a", 1.0, 0.4)
		tween.parallel().tween_property(particles, "emitting", true, 0.01)
		tween.tween_property(upgrade_text, "scale", Vector2(1.1, 1.1), 0.4)
		tween.tween_property(upgrade_text, "scale", Vector2(1.0, 1.0), 0.4)
		tween.tween_interval(0.8)
		tween.tween_property(upgrade_text, "modulate:a", 0.0, 0.8)
		tween.tween_callback(upgrade_text.queue_free)
		
		# Update abilities display
		update_abilities_display()
		
		# Wait for particles to finish
		await get_tree().create_timer(particles.lifetime + 0.5).timeout
		particles.queue_free()

func give_random_chemical():
	# Implement giving the player a random chemical
	if player and player.has_method("add_chemical"):
		var chemical_types = ["RED", "BLUE", "GREEN", "PURPLE", "YELLOW"]
		var random_type = chemical_types[randi() % chemical_types.size()]
		player.add_chemical(random_type)
		
		# Show chemical collection visual
		if player.has_method("show_chemical_collection_effect"):
			player.show_chemical_collection_effect(random_type)

func _on_enemy_died(enemy):
	# Calculate XP based on enemy properties
	var xp_gain = 5.0  # Base XP
	
	# Check if it's a boss for bonus XP
	var is_boss = enemy.get("is_boss") if enemy else false
	if is_boss:
		xp_gain *= 5.0  # Bosses give 5x XP
	
	# Add XP
	current_xp += xp_gain
	
	# Show XP gain text
	if enemy:
		show_xp_gain_effect(enemy.global_position, xp_gain)

func show_xp_gain_effect(position: Vector2, amount: float):
	# Create XP text
	var xp_text = Label.new()
	xp_text.text = "+" + str(int(amount)) + " XP"
	xp_text.add_theme_font_size_override("font_size", 14)
	xp_text.add_theme_color_override("font_color", Color(0.4, 0.7, 1.0))
	xp_text.position = position
	xp_text.z_index = 10
	add_child(xp_text)
	
	# Animate the XP text
	var tween = create_tween()
	tween.tween_property(xp_text, "position", position + Vector2(0, -30), 1.0)
	tween.parallel().tween_property(xp_text, "modulate:a", 0.0, 1.0)
	tween.tween_callback(xp_text.queue_free) 
