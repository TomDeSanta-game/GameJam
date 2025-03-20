extends Node

class_name VampireSurvivalMode

# Solo Leveling inspired Hunter Mode
# Player grows stronger over time, gains ranks, and faces increasingly difficult enemies

var game_time: float = 0.0
var current_wave: int = 1
var wave_duration: float = 25.0  # Each wave lasts slightly less time
var wave_timer: float = 0.0
var difficulty_multiplier: float = 1.0
var player: Node
var enemy_spawner: Node
var auto_growth: AutoGrowth = null
var wave_label: Label
var game_timer: Timer
var hunter_rank: int = 1      # Hunter rank starts at E
var hunter_rank_names = ["E", "D", "C", "B", "A", "S", "SS"]
var hunter_exp: float = 0     # Experience points
var exp_to_next_rank: float = 100  # Base exp required for next rank
var total_enemies_killed: int = 0
var total_bosses_killed: int = 0
var player_level: int = 1
var exp_to_next_level: float = 50
var boss_wave_interval: int = 5  # Boss appears every 5 waves
var enemy_damage_modifier: float = 1.0  # Base enemy damage modifier
var player_damage_modifier: float = 1.0 # Base player damage modifier
var vampire_mode_active: bool = true    # Vampire mode is on by default in this mode

# Reference to AutoGrowth class
const AutoGrowthScript = preload("res://Systems/Scripts/VampireSurvival/AutoGrowth.gd")

func _ready():
	# Get references to nodes
	player = $Knight
	enemy_spawner = $EnemySpawner
	wave_label = $WaveTimerLabel
	game_timer = $GameTimer
	
	# Connect signals
	game_timer.timeout.connect(_on_game_timer_timeout)
	
	# Get SignalBus
	var signal_bus = get_node_or_null("/root/SignalBus")
	if signal_bus:
		if signal_bus.has_signal("player_died"):
			signal_bus.player_died.connect(_on_player_died)
		if signal_bus.has_signal("enemy_died"):
			signal_bus.enemy_died.connect(_on_enemy_died)
	
	# Initialize AutoGrowth system
	auto_growth = AutoGrowthScript.new()
	add_child(auto_growth)
	
	# Set up the game
	
	# Initialize player properties
	if player:
		# Set initial level
		var growth_system = player.get_node_or_null("GrowthSystem")
		if growth_system:
			# Reset any existing growth
			growth_system.current_growth = 0
			growth_system.growth_level = 0
			
		# Connect auto_growth to player
		if auto_growth:
			auto_growth.player = player
			# AutoGrowth connected to player
	
	# Start first wave
	start_wave(1)
	
	# Show gate opening animation
	show_gate_opening()
	
	# Initialize and activate vampire mode by default
	toggle_vampire_mode(true)
	if player and player.has_method("toggle_vampire_mode"):
		player.toggle_vampire_mode(true)
		# Vampire mode activated for player at start

func _process(delta: float):
	game_time += delta
	wave_timer += delta
	
	# Check if it's time for next wave
	if wave_timer >= wave_duration:
		wave_timer = 0.0
		current_wave += 1
		start_wave(current_wave)
	
	# Update UI
	update_ui()
	
	# Animate blue circle effects
	animate_circle_effects(delta)

func animate_circle_effects(_delta: float):
	# Create subtle pulse animations in the environment
	var blue_circles = get_tree().get_nodes_in_group("blue_circles")
	for circle in blue_circles:
		var pulse = sin(game_time * 0.5 + circle.get_index()) * 0.05 + 0.95
		circle.scale = Vector2(pulse, pulse)

func start_wave(wave_number: int):
	# Update wave properties
	current_wave = wave_number
	difficulty_multiplier = 1.0 + (current_wave - 1) * 0.15  # Reduced from 0.25 to 0.15 (15% harder per wave)
	
	# Check if this is a boss wave
	var is_boss_wave = (wave_number % boss_wave_interval == 0)
	
	# Update enemy spawner
	if enemy_spawner:
		enemy_spawner.current_wave = current_wave
		enemy_spawner.is_boss_wave = is_boss_wave
		enemy_spawner.spawn_wave()  # Spawn a wave of enemies
	
	# Give player a bonus chemical at the start of each wave
	if auto_growth:
		auto_growth.give_random_chemical()
	
	# Display wave notification
	if is_boss_wave:
		show_boss_wave_notification()
	else:
		show_wave_notification()

func show_gate_opening():
	# Create a gate opening visual effect
	var gate = ColorRect.new()
	gate.color = Color(0.0, 0.2, 0.5, 0.0)
	gate.set_anchors_preset(Control.PRESET_FULL_RECT)
	get_tree().get_root().add_child(gate)
	
	# Create a blue circle
	var circle = ColorRect.new()
	circle.color = Color(0.2, 0.4, 0.8, 0.2)
	circle.set_anchors_preset(Control.PRESET_CENTER)
	circle.size = Vector2(10, 10)
	circle.position = Vector2(384, 216) - circle.size/2
	circle.pivot_offset = circle.size/2
	get_tree().get_root().add_child(circle)
	
	# Create a flash effect
	var flash = ColorRect.new()
	flash.color = Color(0.4, 0.7, 1.0, 0.0)
	flash.set_anchors_preset(Control.PRESET_FULL_RECT)
	get_tree().get_root().add_child(flash)
	
	# Create text label
	var gate_text = Label.new()
	gate_text.text = "GATE OPENING"
	gate_text.add_theme_font_size_override("font_size", 32)
	gate_text.add_theme_color_override("font_color", Color(0.4, 0.8, 1.0, 0.0))
	gate_text.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	gate_text.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	gate_text.set_anchors_preset(Control.PRESET_CENTER)
	get_tree().get_root().add_child(gate_text)
	
	# Animate the gate opening
	var tween = create_tween()
	tween.tween_property(gate, "color:a", 0.3, 0.5)
	tween.parallel().tween_property(circle, "size", Vector2(500, 500), 1.5).set_ease(Tween.EASE_OUT)
	tween.parallel().tween_property(circle, "position", Vector2(384, 216) - Vector2(250, 250), 1.5)
	tween.parallel().tween_property(circle, "color:a", 0.0, 1.5)
	tween.parallel().tween_property(gate_text, "modulate:a", 1.0, 0.5)
	tween.tween_property(flash, "color:a", 0.7, 0.1)
	tween.tween_property(flash, "color:a", 0.0, 0.3)
	tween.tween_property(gate_text, "modulate:a", 0.0, 0.5)
	tween.tween_property(gate, "color:a", 0.0, 0.5)
	tween.tween_callback(func(): gate.queue_free())
	tween.tween_callback(func(): circle.queue_free())
	tween.tween_callback(func(): flash.queue_free())
	tween.tween_callback(func(): gate_text.queue_free())

func update_ui():
	if wave_label:
		# Format time as MM:SS
		var minutes = int(game_time) / 60
		var seconds = int(game_time) % 60
		var time_str = "%02d:%02d" % [minutes, seconds]
		
		# Update wave label text
		wave_label.text = "DUNGEON GATE: " + str(current_wave) + " | TIME: " + time_str
	

func show_wave_notification():
	# Create wave notification
	var notification = Label.new()
	notification.text = "GATE " + str(current_wave)
	notification.add_theme_font_size_override("font_size", 32)
	notification.add_theme_color_override("font_color", Color(0.4, 0.8, 1.0))
	notification.add_theme_color_override("font_shadow_color", Color(0.0, 0.2, 0.4))
	notification.add_theme_constant_override("shadow_offset_x", 2)
	notification.add_theme_constant_override("shadow_offset_y", 2)
	notification.add_theme_constant_override("shadow_outline_size", 2)
	notification.position = Vector2(384, 200)  # Center of screen
	notification.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	notification.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	notification.anchors_preset = Control.PRESET_CENTER
	add_child(notification)
	
	# Animate notification
	var tween = create_tween()
	tween.tween_property(notification, "scale", Vector2(1.2, 1.2), 0.5)
	tween.tween_property(notification, "scale", Vector2(1.0, 1.0), 0.3)
	tween.tween_property(notification, "modulate:a", 0.0, 1.2)
	tween.tween_callback(notification.queue_free)

func show_boss_wave_notification():
	# Create boss notification with more dramatic effect
	var notification = Label.new()
	notification.text = "BOSS GATE " + str(current_wave)
	notification.add_theme_font_size_override("font_size", 40)
	notification.add_theme_color_override("font_color", Color(1.0, 0.3, 0.3))
	notification.add_theme_color_override("font_shadow_color", Color(0.4, 0.0, 0.0))
	notification.add_theme_constant_override("shadow_offset_x", 3)
	notification.add_theme_constant_override("shadow_offset_y", 3)
	notification.position = Vector2(384, 200)  # Center of screen
	notification.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	notification.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	notification.anchors_preset = Control.PRESET_CENTER
	notification.modulate.a = 0
	add_child(notification)
	
	# Create flash effect
	var flash = ColorRect.new()
	flash.color = Color(0.7, 0.2, 0.2, 0.0)
	flash.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(flash)
	
	# Animate notification
	var tween = create_tween()
	tween.tween_property(flash, "color:a", 0.4, 0.2)
	tween.tween_property(flash, "color:a", 0.0, 0.3)
	tween.parallel().tween_property(notification, "modulate:a", 1.0, 0.3)
	tween.tween_property(notification, "scale", Vector2(1.3, 1.3), 0.4)
	tween.tween_property(notification, "scale", Vector2(1.0, 1.0), 0.6)
	tween.tween_interval(1.0)
	tween.tween_property(notification, "modulate:a", 0.0, 1.2)
	tween.tween_callback(notification.queue_free)
	tween.tween_callback(flash.queue_free)

func show_level_up_effect():
	# Create level up flash
	var flash = ColorRect.new()
	flash.color = Color(0.4, 0.7, 1.0, 0.0)
	flash.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(flash)
	
	# Create level up text
	var level_text = Label.new()
	level_text.text = "LEVEL UP!"
	level_text.add_theme_font_size_override("font_size", 36)
	level_text.add_theme_color_override("font_color", Color(0.4, 0.8, 1.0))
	level_text.add_theme_color_override("font_shadow_color", Color(0.0, 0.2, 0.4))
	level_text.add_theme_constant_override("shadow_offset_x", 2)
	level_text.add_theme_constant_override("shadow_offset_y", 2)
	level_text.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	level_text.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	level_text.set_anchors_preset(Control.PRESET_CENTER)
	# Position higher in the screen to avoid overlapping with player UI
	level_text.position = Vector2(0, -60)
	level_text.modulate.a = 0
	add_child(level_text)
	
	# Create blue circle effect
	var circle = ColorRect.new()
	circle.color = Color(0.2, 0.5, 1.0, 0.4)
	circle.size = Vector2(20, 20)
	circle.position = Vector2(384, 216) - circle.size/2
	circle.pivot_offset = circle.size/2
	add_child(circle)
	
	# Animate level up
	var tween = create_tween()
	tween.tween_property(flash, "color:a", 0.6, 0.2)
	tween.tween_property(flash, "color:a", 0.0, 0.4)
	tween.parallel().tween_property(level_text, "modulate:a", 1.0, 0.3)
	tween.parallel().tween_property(circle, "size", Vector2(400, 400), 0.8).set_ease(Tween.EASE_OUT)
	tween.parallel().tween_property(circle, "position", Vector2(384, 216) - Vector2(200, 200), 0.8)
	tween.parallel().tween_property(circle, "color:a", 0.0, 0.8)
	tween.tween_property(level_text, "scale", Vector2(1.3, 1.3), 0.4)
	tween.tween_property(level_text, "scale", Vector2(1.0, 1.0), 0.4)
	tween.tween_property(level_text, "modulate:a", 0.0, 0.8)
	tween.tween_callback(flash.queue_free)
	tween.tween_callback(level_text.queue_free)
	tween.tween_callback(circle.queue_free)
	
	# Apply game effects
	if player:
		# Boost player stats
		var growth_system = player.get_node_or_null("GrowthSystem")
		if growth_system:
			var bonus_growth = player_level * 0.5
			growth_system.grow(bonus_growth)
			
		# Restore player health
		if player.has_method("heal") and "current_stats" in player and "MAX_HEALTH" in player.current_stats:
			player.heal(player.current_stats.MAX_HEALTH * 2)  # Heal to double max health
			# Overhealed player beyond full health

func show_rank_up_effect():
	# Create rank up flash
	var flash = ColorRect.new()
	flash.color = Color(0.6, 0.8, 1.0, 0.0)
	flash.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(flash)
	
	# Create rank up text
	var rank_text = Label.new()
	rank_text.text = "HUNTER RANK UP!\n" + hunter_rank_names[min(hunter_rank - 2, hunter_rank_names.size() - 1)] + " → " + hunter_rank_names[min(hunter_rank - 1, hunter_rank_names.size() - 1)]
	rank_text.add_theme_font_size_override("font_size", 40)
	rank_text.add_theme_color_override("font_color", Color(0.6, 1.0, 1.0))
	rank_text.add_theme_color_override("font_shadow_color", Color(0.0, 0.3, 0.6))
	rank_text.add_theme_constant_override("shadow_offset_x", 3)
	rank_text.add_theme_constant_override("shadow_offset_y", 3)
	rank_text.add_theme_constant_override("line_spacing", 10)
	rank_text.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	rank_text.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	rank_text.set_anchors_preset(Control.PRESET_CENTER)
	rank_text.modulate.a = 0
	add_child(rank_text)
	
	# Create particles
	var particles_1 = GPUParticles2D.new()
	var particles_2 = GPUParticles2D.new()
	particles_1.position = Vector2(384, 216)
	particles_2.position = Vector2(384, 216)
	particles_1.amount = 50
	particles_2.amount = 30
	particles_1.lifetime = 2.0
	particles_2.lifetime = 2.0
	particles_1.explosiveness = 0.8
	particles_2.explosiveness = 0.9
	
	var material_1 = ParticleProcessMaterial.new()
	var material_2 = ParticleProcessMaterial.new()
	material_1.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	material_2.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	material_1.emission_sphere_radius = 100.0
	material_2.emission_sphere_radius = 50.0
	
	material_1.gravity = Vector3(0, 0, 0)
	material_2.gravity = Vector3(0, 0, 0)
	material_1.initial_velocity_min = 100.0
	material_1.initial_velocity_max = 150.0
	material_2.initial_velocity_min = 50.0
	material_2.initial_velocity_max = 100.0
	
	material_1.scale_min = 3.0
	material_1.scale_max = 6.0
	material_2.scale_min = 5.0
	material_2.scale_max = 10.0
	
	material_1.color = Color(0.4, 0.8, 1.0, 1.0)
	material_2.color = Color(0.6, 0.9, 1.0, 1.0)
	
	particles_1.process_material = material_1
	particles_2.process_material = material_2
	
	add_child(particles_1)
	add_child(particles_2)
	
	# Animate rank up
	var tween = create_tween()
	tween.tween_property(flash, "color:a", 0.8, 0.3)
	tween.tween_property(flash, "color:a", 0.0, 0.8)
	tween.parallel().tween_property(rank_text, "modulate:a", 1.0, 0.5)
	tween.tween_property(rank_text, "scale", Vector2(1.2, 1.2), 0.6)
	tween.tween_property(rank_text, "scale", Vector2(1.0, 1.0), 0.6)
	tween.tween_interval(1.0)
	tween.tween_property(rank_text, "modulate:a", 0.0, 1.0)
	tween.tween_callback(flash.queue_free)
	tween.tween_callback(rank_text.queue_free)
	
	# Stop particles after a delay
	particles_1.emitting = true
	particles_2.emitting = true
	await get_tree().create_timer(2.0).timeout
	particles_1.emitting = false
	particles_2.emitting = false
	await get_tree().create_timer(2.0).timeout
	particles_1.queue_free()
	particles_2.queue_free()
	
	# Apply game effects
	if player:
		# Major boost to player stats
		var growth_system = player.get_node_or_null("GrowthSystem")
		if growth_system:
			var bonus_growth = hunter_rank * 2.0
			growth_system.grow(bonus_growth)
			
		# Enhance the auto growth rates
		if auto_growth:
			auto_growth.base_growth_rate *= 1.1
			auto_growth.growth_multiplier *= 1.05
			
		# Restore player health and give an effect
		if player.has_method("heal") and "current_stats" in player and "MAX_HEALTH" in player.current_stats:
			player.heal(50)
			
		if player.has_method("apply_effect"):
			player.apply_effect("Growth Burst", 10.0)

func _on_game_timer_timeout():
	# This is called every second
	pass

func _on_player_died():
	# Game over
	var game_over = Label.new()
	game_over.text = "FAILURE!\n\nHUNTER RANK: " + hunter_rank_names[min(hunter_rank - 1, hunter_rank_names.size() - 1)] + \
			"\nWAVE: " + str(current_wave) + \
			"\nLEVEL: " + str(player_level) + \
			"\nTIME SURVIVED: " + str(int(game_time)) + " seconds" + \
			"\nENEMIES DEFEATED: " + str(total_enemies_killed) + \
			"\nBOSSES DEFEATED: " + str(total_bosses_killed)
	
	game_over.add_theme_font_size_override("font_size", 32)
	game_over.add_theme_color_override("font_color", Color(1.0, 0.2, 0.2))  # Red color for FAILURE
	game_over.add_theme_color_override("font_shadow_color", Color(0.4, 0.0, 0.0))
	game_over.add_theme_constant_override("shadow_offset_x", 2)
	game_over.add_theme_constant_override("shadow_offset_y", 2)
	game_over.add_theme_constant_override("line_spacing", 5)
	game_over.position = Vector2(384, 200)  # Center of screen
	game_over.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	game_over.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	game_over.anchors_preset = Control.PRESET_CENTER
	add_child(game_over)
	
	# Add a big "FAILURE" animation
	create_failure_animation()
	
	# Add a return button
	var return_button = Button.new()
	return_button.text = "RETURN TO MENU"
	return_button.size = Vector2(200, 50)
	return_button.position = Vector2(384 - 100, 400)
	return_button.add_theme_color_override("font_color", Color(0.4, 0.8, 1.0))
	return_button.add_theme_color_override("font_hover_color", Color(0.6, 0.9, 1.0))
	return_button.pressed.connect(func(): get_tree().change_scene_to_file("res://Levels/VampireSurvivorsLauncher.tscn"))
	add_child(return_button)
	
	# Show gate closing animation
	show_gate_closing()
	
	# Stop processing
	set_process(false)
	if enemy_spawner:
		enemy_spawner.set_process(false)
	if auto_growth:
		auto_growth.set_process(false)

func create_failure_animation():
	# Create an EXTREME "FAILURE" text animation with maximum visual impact
	var failure = Label.new()
	failure.text = "FAILURE"
	failure.add_theme_font_size_override("font_size", 180)  # Even larger font
	failure.add_theme_color_override("font_color", Color(1.0, 0.0, 0.0))
	failure.add_theme_color_override("font_shadow_color", Color(0.5, 0.0, 0.0))
	failure.add_theme_constant_override("shadow_offset_x", 8)
	failure.add_theme_constant_override("shadow_offset_y", 8)
	failure.add_theme_constant_override("outline_size", 6)
	failure.add_theme_color_override("font_outline_color", Color(0.8, 0.0, 0.0))
	failure.position = Vector2(384, 216)  # Center of screen
	failure.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	failure.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	failure.anchors_preset = Control.PRESET_CENTER
	failure.modulate.a = 0  # Start invisible
	add_child(failure)
	
	# Create skull texture behind the text for added impact
	var skull_icon = TextureRect.new()
	var texture_path = "res://Assets/Textures/skull.png"  # This is just a placeholder path
	if ResourceLoader.exists(texture_path):
		skull_icon.texture = load(texture_path)
	skull_icon.modulate = Color(1.0, 0.0, 0.0, 0.3)
	skull_icon.size = Vector2(300, 300)
	skull_icon.position = Vector2(384 - 150, 216 - 150)  # Center
	skull_icon.modulate.a = 0
	add_child(skull_icon)
	
	# Full-screen red vignette flash
	var flash = ColorRect.new()
	flash.color = Color(1.0, 0.0, 0.0, 0.0)
	flash.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(flash)
	
	# Create background darkening effect
	var dark_overlay = ColorRect.new()
	dark_overlay.color = Color(0.0, 0.0, 0.0, 0.0)
	dark_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(dark_overlay)
	
	# Create impact shockwave effect
	var shockwave = ColorRect.new()
	shockwave.color = Color(1.0, 0.0, 0.0, 0.5)
	shockwave.set_anchors_preset(Control.PRESET_CENTER)
	shockwave.size = Vector2(10, 10)
	shockwave.position = Vector2(384, 216) - Vector2(5, 5)
	shockwave.pivot_offset = Vector2(5, 5)
	add_child(shockwave)
	
	# Create multiple dramatic particle systems
	var particles_1 = GPUParticles2D.new()
	var particles_2 = GPUParticles2D.new()
	particles_1.position = Vector2(384, 216)
	particles_2.position = Vector2(384, 216)
	particles_1.amount = 100
	particles_2.amount = 150
	particles_1.lifetime = 3.0
	particles_2.lifetime = 4.0
	particles_1.explosiveness = 0.9
	particles_2.explosiveness = 0.8
	
	var material_1 = ParticleProcessMaterial.new()
	var material_2 = ParticleProcessMaterial.new()
	material_1.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	material_2.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	material_1.emission_sphere_radius = 10.0
	material_2.emission_sphere_radius = 20.0
	material_1.gravity = Vector3(0, 0, 0)
	material_2.gravity = Vector3(0, 30, 0)
	material_1.initial_velocity_min = 150.0
	material_1.initial_velocity_max = 300.0
	material_2.initial_velocity_min = 100.0
	material_2.initial_velocity_max = 200.0
	material_1.scale_min = 8.0
	material_1.scale_max = 15.0
	material_2.scale_min = 5.0
	material_2.scale_max = 10.0
	material_1.color = Color(1.0, 0.3, 0.0, 1.0)
	material_2.color = Color(0.7, 0.0, 0.0, 1.0)
	
	particles_1.process_material = material_1
	particles_2.process_material = material_2
	add_child(particles_1)
	add_child(particles_2)
	
	# Multiple phases of animation for maximum dramatic effect
	var tween = create_tween()
	
	# Phase 1: Rapid screen shake and dark background
	for i in range(4):
		tween.tween_callback(func(): 
			var camera = get_viewport().get_camera_2d()
			if camera:
				camera.offset = Vector2(randf_range(-15, 15), randf_range(-15, 15))
		).set_delay(0.05 * i)
	
	tween.parallel().tween_property(dark_overlay, "color:a", 0.85, 0.2)
	
	# Phase 2: Massive explosion effect
	tween.tween_property(flash, "color:a", 0.95, 0.1)
	tween.tween_property(flash, "color:a", 0.0, 0.5)
	tween.parallel().tween_callback(func(): particles_1.emitting = true)
	tween.parallel().tween_callback(func(): particles_2.emitting = true)
	
	# Phase 3: Shockwave ripple
	tween.parallel().tween_property(shockwave, "size", Vector2(800, 800), 0.8).set_ease(Tween.EASE_OUT)
	tween.parallel().tween_property(shockwave, "position", Vector2(384, 216) - Vector2(400, 400), 0.8)
	tween.parallel().tween_property(shockwave, "color:a", 0.0, 0.8)
	
	# Phase 4: Skull appears
	tween.parallel().tween_property(skull_icon, "modulate:a", 0.3, 0.3)
	
	# Phase 5: FAILURE text blasts in
	tween.parallel().tween_property(failure, "modulate:a", 0.0, 0.01)
	tween.tween_property(failure, "modulate:a", 1.0, 0.2)
	tween.tween_property(failure, "scale", Vector2(1.8, 1.8), 0.2)
	tween.tween_property(failure, "scale", Vector2(1.0, 1.0), 0.3)
	
	# Phase 6: Text vibrates furiously
	for i in range(5):
		tween.tween_property(failure, "rotation", deg_to_rad(randf_range(5, 10)), 0.05)
		tween.tween_property(failure, "rotation", deg_to_rad(randf_range(-5, -10)), 0.05)
		tween.parallel().tween_property(failure, "position", Vector2(384 + randf_range(-10, 10), 216 + randf_range(-10, 10)), 0.05)
	
	tween.tween_property(failure, "rotation", deg_to_rad(0), 0.2)
	tween.tween_property(failure, "position", Vector2(384, 216), 0.2)
	
	# Phase 7: Pulse animation
	for i in range(3):
		tween.tween_property(failure, "scale", Vector2(1.3, 1.3), 0.15)
		tween.parallel().tween_property(flash, "color:a", 0.3, 0.15)
		tween.tween_property(failure, "scale", Vector2(1.0, 1.0), 0.15)
		tween.parallel().tween_property(flash, "color:a", 0.0, 0.15)
	
	# Phase 8: Flash the text rapidly
	for i in range(4):
		tween.tween_property(failure, "modulate:a", 0.2, 0.08)
		tween.tween_property(failure, "modulate:a", 1.0, 0.08)
	
	# Phase 9: Final position and fade
	tween.tween_interval(0.6)
	tween.tween_property(failure, "position:y", failure.position.y - 100, 2.0)
	tween.parallel().tween_property(failure, "modulate:a", 0.0, 2.0)
	tween.parallel().tween_property(skull_icon, "modulate:a", 0.0, 2.0)
	tween.parallel().tween_property(dark_overlay, "color:a", 0.0, 2.0)
	
	# Reset camera
	tween.tween_callback(func(): 
		var camera = get_viewport().get_camera_2d()
		if camera:
			camera.offset = Vector2(0, 0)
	)
	
	# Clean up
	tween.tween_interval(3.0) # Wait for particles to finish
	tween.tween_callback(particles_1.queue_free)
	tween.tween_callback(particles_2.queue_free)
	tween.tween_callback(shockwave.queue_free)
	tween.tween_callback(skull_icon.queue_free)
	tween.tween_callback(dark_overlay.queue_free)
	tween.tween_callback(flash.queue_free)

func show_gate_closing():
	# Create a gate closing visual effect
	var gate = ColorRect.new()
	gate.color = Color(0.0, 0.2, 0.5, 0.0)
	gate.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(gate)
	
	# Create a blue circle
	var circle = ColorRect.new()
	circle.color = Color(0.2, 0.4, 0.8, 0.0)
	circle.set_anchors_preset(Control.PRESET_CENTER)
	circle.size = Vector2(500, 500)
	circle.position = Vector2(384, 216) - circle.size/2
	circle.pivot_offset = circle.size/2
	add_child(circle)
	
	# Create a flash effect
	var flash = ColorRect.new()
	flash.color = Color(0.4, 0.7, 1.0, 0.0)
	flash.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(flash)
	
	# Create text label
	var gate_text = Label.new()
	gate_text.text = "GATE CLOSING"
	gate_text.add_theme_font_size_override("font_size", 32)
	gate_text.add_theme_color_override("font_color", Color(0.4, 0.8, 1.0, 0.0))
	gate_text.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	gate_text.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	gate_text.set_anchors_preset(Control.PRESET_CENTER)
	add_child(gate_text)
	
	# Animate the gate closing
	var tween = create_tween()
	tween.tween_property(gate, "color:a", 0.3, 0.5)
	tween.parallel().tween_property(circle, "color:a", 0.2, 0.5)
	tween.parallel().tween_property(gate_text, "modulate:a", 1.0, 0.5)
	tween.tween_property(flash, "color:a", 0.7, 0.1)
	tween.tween_property(flash, "color:a", 0.0, 0.3)
	tween.tween_property(circle, "size", Vector2(0, 0), 1.0).set_ease(Tween.EASE_IN)
	tween.parallel().tween_property(circle, "position", Vector2(384, 216), 1.0)
	tween.tween_property(gate_text, "modulate:a", 0.0, 0.5)
	tween.tween_property(gate, "color:a", 0.0, 0.5)

func _on_enemy_died(enemy):
	# Add experience and update stats
	var boss_multiplier = 1.0
	var is_boss = enemy.get("is_boss") if enemy else false
	
	if is_boss:
		boss_multiplier = 5.0
		total_bosses_killed += 1
	else:
		total_enemies_killed += 1
	
	# Calculate experience gain based on enemy level/wave
	var enemy_level = max(1, int(current_wave * 0.7))
	var exp_gain = enemy_level * 10 * boss_multiplier
	
	# Add experience
	hunter_exp += exp_gain
	
	# Show experience gain text
	show_exp_gain_text(enemy.global_position, exp_gain)
	
	# Check for level up
	if hunter_exp >= exp_to_next_level:
		hunter_exp -= exp_to_next_level
		player_level += 1
		exp_to_next_level = 50 + player_level * 25  # Each level requires more exp
		show_level_up_effect()
		
		# Check for rank up (every 5 levels)
		if player_level % 5 == 0 and hunter_rank < hunter_rank_names.size():
			hunter_rank += 1
			exp_to_next_rank = exp_to_next_rank * 2  # Each rank is harder to get
			show_rank_up_effect()

func show_exp_gain_text(position: Vector2, amount: float):
	# Create floating text for exp gain
	var exp_text = Label.new()
	exp_text.text = "+" + str(int(amount)) + " EXP"
	exp_text.add_theme_font_size_override("font_size", 16)
	exp_text.add_theme_color_override("font_color", Color(0.4, 0.8, 1.0))
	exp_text.position = position
	exp_text.z_index = 100
	add_child(exp_text)
	
	# Animate text
	var tween = create_tween()
	tween.tween_property(exp_text, "position", position + Vector2(0, -30), 1.0)
	tween.parallel().tween_property(exp_text, "modulate:a", 0.0, 1.0)
	tween.tween_callback(exp_text.queue_free) 

# Add these functions to handle vampire mode damage scaling
func toggle_vampire_mode(enabled: bool) -> void:
	vampire_mode_active = enabled
	
	if enabled:
		# In GODMODE - extreme settings
		player_damage_modifier = 5.0     # Player does 5x damage
		enemy_damage_modifier = 0.001    # Enemies do virtually no damage
		# GODMODE ACTIVATED
	else:
		# In NORMAL mode - still favorable settings
		player_damage_modifier = 2.0     # Player does double damage
		enemy_damage_modifier = 0.2      # Enemies do 20% damage
		# NORMAL MODE
	
	# Apply to player
	if player and player.has_method("toggle_vampire_mode"):
		player.toggle_vampire_mode(enabled)
	
	# Apply extreme defensive buffs to player
	if player:
		# Add massive damage reduction
		if player.has_method("set_damage_reduction"):
			player.set_damage_reduction(0.95)  # 95% damage reduction
			# Applied 95% damage reduction to player
		
		# Massively increase max health
		if player.has_method("add_max_health"):
			player.add_max_health(200)  # +200 max health
			# Applied +200 max health bonus to player
		
		# Heal player to full and beyond
		if player.has_method("heal") and "current_stats" in player and "MAX_HEALTH" in player.current_stats:
			player.heal(player.current_stats.MAX_HEALTH * 2)  # Heal to double max health
			# Overhealed player beyond full health
		
		# Add temporary invulnerability if possible
		if player.has_method("set_invulnerable"):
			player.set_invulnerable(10.0)  # 10 seconds of invulnerability
			# Applied invulnerability to player
	
	# Apply to all existing enemies
	update_all_enemy_damage()

func apply_damage_scaling_to_enemy(enemy: Node) -> void:
	if not enemy:
		return
	
	# Apply damage scaling based on vampire mode
	var modifier = enemy_damage_modifier
	
	# Special handling for NightBorne enemies
	if enemy.get_class() == "NightBorne" or "NightBorne" in enemy.name:
		if enemy.has_method("apply_damage_scaling"):
			enemy.apply_damage_scaling(modifier)
			# Applied damage scaling to NightBorne enemy
		else:
			# NightBorne has no apply_damage_scaling method
			pass
	
	# Try to set the damage_modifier property
	elif "damage_modifier" in enemy:
		enemy.damage_modifier = modifier
		# Set damage_modifier property on enemy
	
	# Try to scale the base_damage
	elif "base_damage" in enemy and enemy.has_method("update_stats"):
		enemy.base_damage *= modifier
		enemy.update_stats()
		# Updated hitbox damage based on base_damage
	
	# Try to directly modify hitboxes
	elif enemy.has_node("Hitbox"):
		var hitbox = enemy.get_node("Hitbox")
		if "damage" in hitbox:
			hitbox.damage *= modifier
			# Updated hitbox damage with scaling
	
	# Fallback - try to adjust any damage-related property
	else:
		# Could not apply damage scaling to enemy
		pass

func update_all_enemy_damage() -> void:
	var enemies = get_tree().get_nodes_in_group("enemy")
	for enemy in enemies:
		apply_damage_scaling_to_enemy(enemy)
	# Updated damage for X enemies

func apply_vampire_mode(active: bool):
	vampire_mode_active = active
	
	if active:
		# In GODMODE - extreme settings
		player_damage_modifier = 5.0     # Player does 5x damage
		enemy_damage_modifier = 0.001    # Enemies do virtually no damage
		# GODMODE ACTIVATED
	else:
		# In NORMAL mode - still favorable settings
		player_damage_modifier = 2.0     # Player does double damage
		enemy_damage_modifier = 0.2      # Enemies do 20% damage
		# NORMAL MODE
	
	# Apply to player
	if player and player.has_method("toggle_vampire_mode"):
		player.toggle_vampire_mode(active)
	
	# Apply extreme defensive buffs to player
	if player:
		# Add massive damage reduction
		if player.has_method("set_damage_reduction"):
			player.set_damage_reduction(0.95)  # 95% damage reduction
			# Applied 95% damage reduction to player
		
		# Massively increase max health
		if player.has_method("add_max_health"):
			player.add_max_health(200)  # +200 max health
			# Applied +200 max health bonus to player
		
		# Heal player to full and beyond
		if player.has_method("heal") and "current_stats" in player and "MAX_HEALTH" in player.current_stats:
			player.heal(player.current_stats.MAX_HEALTH * 2)  # Heal to double max health
			# Overhealed player beyond full health
		
		# Add temporary invulnerability if possible
		if player.has_method("set_invulnerable"):
			player.set_invulnerable(10.0)  # 10 seconds of invulnerability
			# Applied invulnerability to player
	
	# Apply to all existing enemies
	update_all_enemy_damage()

func update_all_enemies():
	var enemies = get_tree().get_nodes_in_group("enemies")
	for enemy in enemies:
		apply_damage_scaling_to_enemy(enemy)
	
	# Updated damage for X enemies 
