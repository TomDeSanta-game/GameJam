extends Node

# Solo Leveling inspired Hunter Mode
# Player grows stronger over time, gains ranks, and faces increasingly difficult enemies

var game_time: float = 0.0
var current_wave: int = 1
var wave_duration: float = 25.0  # Each wave lasts slightly less time
var wave_timer: float = 0.0
var difficulty_multiplier: float = 1.0
var player: Node
var enemy_spawner: Node
var auto_growth: Node
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

# UI Elements
var ui_container: Control
var exp_bar: ProgressBar
var hunter_rank_label: Label
var player_level_label: Label
var stats_label: Label

func _ready():
	# Get references to nodes
	player = $Knight
	enemy_spawner = $EnemySpawner
	auto_growth = $AutoGrowth
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
	
	# Create UI elements
	setup_ui()
	
	# Initialize player properties
	if player:
		# Set initial level
		var growth_system = player.get_node_or_null("GrowthSystem")
		if growth_system:
			# Reset any existing growth
			growth_system.current_growth = 0
			growth_system.growth_level = 0
	
	# Start first wave
	start_wave(1)
	
	# Show gate opening animation
	show_gate_opening()

func setup_ui():
	# Create UI container
	ui_container = Control.new()
	ui_container.set_anchors_preset(Control.PRESET_FULL_RECT)
	ui_container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(ui_container)
	
	# Create Hunter Rank label
	hunter_rank_label = Label.new()
	hunter_rank_label.text = "HUNTER RANK: " + hunter_rank_names[0]
	hunter_rank_label.add_theme_color_override("font_color", Color(0.4, 0.8, 1.0))
	hunter_rank_label.add_theme_font_size_override("font_size", 16)
	hunter_rank_label.position = Vector2(10, 50)
	ui_container.add_child(hunter_rank_label)
	
	# Create Player Level label
	player_level_label = Label.new()
	player_level_label.text = "LEVEL: 1"
	player_level_label.add_theme_color_override("font_color", Color(0.4, 0.8, 1.0))
	player_level_label.add_theme_font_size_override("font_size", 16)
	player_level_label.position = Vector2(10, 70)
	ui_container.add_child(player_level_label)
	
	# Create EXP bar
	exp_bar = ProgressBar.new()
	exp_bar.size = Vector2(200, 10)
	exp_bar.position = Vector2(10, 90)
	exp_bar.max_value = exp_to_next_level
	exp_bar.value = 0
	exp_bar.show_percentage = false
	var style_box = StyleBoxFlat.new()
	style_box.bg_color = Color(0.2, 0.4, 0.7, 0.8)
	style_box.border_width_left = 1
	style_box.border_width_top = 1
	style_box.border_width_right = 1
	style_box.border_width_bottom = 1
	style_box.border_color = Color(0.3, 0.5, 0.8, 1.0)
	style_box.corner_radius_top_left = 2
	style_box.corner_radius_top_right = 2
	style_box.corner_radius_bottom_right = 2
	style_box.corner_radius_bottom_left = 2
	exp_bar.add_theme_stylebox_override("fill", style_box)
	ui_container.add_child(exp_bar)
	
	# Create Stats label
	stats_label = Label.new()
	stats_label.text = "ENEMIES KILLED: 0\nBOSSES KILLED: 0"
	stats_label.add_theme_color_override("font_color", Color(0.8, 0.9, 1.0))
	stats_label.add_theme_font_size_override("font_size", 14)
	stats_label.position = Vector2(10, 110)
	ui_container.add_child(stats_label)
	
	# Update wave label style
	if wave_label:
		wave_label.add_theme_color_override("font_color", Color(0.4, 0.8, 1.0))
		wave_label.add_theme_font_size_override("font_size", 16)

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
	difficulty_multiplier = 1.0 + (current_wave - 1) * 0.25  # Each wave is 25% harder
	
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
	ui_container.add_child(gate)
	
	# Create a blue circle
	var circle = ColorRect.new()
	circle.color = Color(0.2, 0.4, 0.8, 0.2)
	circle.set_anchors_preset(Control.PRESET_CENTER)
	circle.size = Vector2(10, 10)
	circle.position = Vector2(384, 216) - circle.size/2
	circle.pivot_offset = circle.size/2
	ui_container.add_child(circle)
	
	# Create a flash effect
	var flash = ColorRect.new()
	flash.color = Color(0.4, 0.7, 1.0, 0.0)
	flash.set_anchors_preset(Control.PRESET_FULL_RECT)
	ui_container.add_child(flash)
	
	# Create text label
	var gate_text = Label.new()
	gate_text.text = "GATE OPENING"
	gate_text.add_theme_font_size_override("font_size", 32)
	gate_text.add_theme_color_override("font_color", Color(0.4, 0.8, 1.0, 0.0))
	gate_text.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	gate_text.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	gate_text.set_anchors_preset(Control.PRESET_CENTER)
	ui_container.add_child(gate_text)
	
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
		
		# Update label
		wave_label.text = "DUNGEON GATE: " + str(current_wave) + "\nTIME: " + time_str
	
	if hunter_rank_label:
		hunter_rank_label.text = "HUNTER RANK: " + hunter_rank_names[min(hunter_rank - 1, hunter_rank_names.size() - 1)]
	
	if player_level_label:
		player_level_label.text = "LEVEL: " + str(player_level)
	
	if exp_bar:
		exp_bar.max_value = exp_to_next_level
		exp_bar.value = hunter_exp
	
	if stats_label:
		stats_label.text = "ENEMIES KILLED: " + str(total_enemies_killed) + "\nBOSSES KILLED: " + str(total_bosses_killed)

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
		if player.has_method("heal"):
			player.heal(player_level * 5)

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
		if player.has_method("heal"):
			player.heal(50)
			
		if player.has_method("apply_effect"):
			player.apply_effect("Growth Burst", 10.0)

func _on_game_timer_timeout():
	# This is called every second
	pass

func _on_player_died():
	# Game over
	var game_over = Label.new()
	game_over.text = "GATE CLOSED\n\nHUNTER RANK: " + hunter_rank_names[min(hunter_rank - 1, hunter_rank_names.size() - 1)] + \
			"\nWAVE: " + str(current_wave) + \
			"\nLEVEL: " + str(player_level) + \
			"\nTIME SURVIVED: " + str(int(game_time)) + " seconds" + \
			"\nENEMIES DEFEATED: " + str(total_enemies_killed) + \
			"\nBOSSES DEFEATED: " + str(total_bosses_killed)
	
	game_over.add_theme_font_size_override("font_size", 32)
	game_over.add_theme_color_override("font_color", Color(0.4, 0.8, 1.0))
	game_over.add_theme_color_override("font_shadow_color", Color(0.0, 0.2, 0.4))
	game_over.add_theme_constant_override("shadow_offset_x", 2)
	game_over.add_theme_constant_override("shadow_offset_y", 2)
	game_over.add_theme_constant_override("line_spacing", 5)
	game_over.position = Vector2(384, 200)  # Center of screen
	game_over.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	game_over.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	game_over.anchors_preset = Control.PRESET_CENTER
	add_child(game_over)
	
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