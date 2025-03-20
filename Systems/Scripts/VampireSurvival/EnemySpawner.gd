extends Node2D

class_name EnemySpawner

# Enemy spawning parameters
@export var initial_spawn_time: float = 5.0     # Initial time between spawns
@export var min_spawn_time: float = 1.0         # Minimum time between spawns
@export var difficulty_increase_rate: float = 0.03  # How quickly spawn time decreases (reduced from 0.05)
@export var max_enemies: int = 10               # Maximum number of enemies at once (reduced from 25)
@export var spawn_radius: float = 800.0         # Radius around player to spawn enemies
@export var min_spawn_distance: float = 500.0    # Minimum distance from player (increased from 400)

# Enemy scenes
@export var enemy_scenes: Array[PackedScene] = []
@export var boss_multiplier: float = 3.0  # Boss health/damage multiplier

# Tracked variables
var spawn_timer: float = 0.0
var current_spawn_time: float
var difficulty_timer: float = 0.0
var difficulty_increase_interval: float = 10.0  # Increase difficulty every 10 seconds
var total_spawned: int = 0
var current_wave: int = 1
var game_time: float = 0.0
var is_boss_wave: bool = false
var boss_enemies: Array = []

# Reference to player
var player: Node2D

# Add this variable to track the vampire survival mode node
var vampire_mode: Node

func _ready():
	current_spawn_time = initial_spawn_time
	
	# Find player in the scene
	player = get_tree().get_first_node_in_group("Player")
	if not player:
		# Player not found
		set_process(false)
	
	# Signal connection
	var signal_bus = get_node_or_null("/root/SignalBus")
	if signal_bus and signal_bus.has_signal("enemy_died"):
		signal_bus.enemy_died.connect(_on_enemy_died)

	# Find the vampire mode controller
	vampire_mode = get_parent()
	if not vampire_mode or not vampire_mode.has_method("apply_damage_scaling_to_enemy"):
		vampire_mode = get_tree().get_first_node_in_group("vampire_mode")
		if not vampire_mode:
			# Search for it
			var nodes = get_tree().get_nodes_in_group("game_mode")
			for node in nodes:
				if node.has_method("apply_damage_scaling_to_enemy"):
					vampire_mode = node
					break

func _process(delta: float):
	if not player or not is_instance_valid(player):
		# Try to find player again
		player = get_tree().get_first_node_in_group("Player")
		if not player:
			return
	
	game_time += delta
	
	# Update spawn timer
	spawn_timer += delta
	if spawn_timer >= current_spawn_time:
		spawn_timer = 0.0
		spawn_enemy()
	
	# Increase difficulty over time
	difficulty_timer += delta
	if difficulty_timer >= difficulty_increase_interval:
		difficulty_timer = 0.0
		increase_difficulty()
		
		# Every 30 seconds, trigger a new wave
		if game_time > current_wave * 30:
			current_wave += 1
			spawn_wave()

func spawn_enemy(wave_num: int = 0, pos: Vector2 = Vector2.ZERO, is_boss: bool = false, enemy_type: String = "") -> void:
	# Check if we're at max enemies
	var current_enemies = get_tree().get_nodes_in_group("enemies").size()
	if current_enemies >= max_enemies:
		return
		
	# Ensure we have a valid player
	if not player or not is_instance_valid(player):
		player = get_tree().get_first_node_in_group("Player")
		if not player:
			return
	
	# Use current wave if no wave number is provided
	var current_wave_num = current_wave
	if wave_num > 0:
		current_wave_num = wave_num
	
	# Choose random enemy type (weighted toward current wave)
	var enemy_type_index = min(enemy_scenes.size() - 1, randi() % (current_wave_num + 1))
	
	# If there are no enemy scenes, return
	if enemy_scenes.size() == 0:
		return
		
	var enemy_scene = enemy_scenes[enemy_type_index]
	
	# Determine spawn position
	var spawn_position = pos
	if spawn_position == Vector2.ZERO:
		spawn_position = get_spawn_position()
	
	# Check if this is a NightBorne enemy before creating it
	if "NightBorne" in enemy_scene.resource_path:
		# For NightBorne enemies, find a safe floor position first
		spawn_position = find_valid_ground_position_for_nightborne(spawn_position.x)
	
	# Create visual portal effect for spawn
	create_spawn_portal(spawn_position, is_boss)
	
	# Create enemy with delay (wait for portal animation)
	await get_tree().create_timer(0.5).timeout
	
	# Check if player still exists after the delay
	if not is_instance_valid(player):
		return
	
	# Create enemy
	var enemy = enemy_scene.instantiate()
	enemy.position = spawn_position
	
	# Configure the enemy
	if "player" in enemy:
		enemy.player = player
		
	# Apply damage scaling if vampire mode is active
	if vampire_mode and vampire_mode.has_method("apply_damage_scaling_to_enemy"):
		vampire_mode.apply_damage_scaling_to_enemy(enemy)
	
	# Boss configuration
	if is_boss:
		# Configure boss stats
		if "max_health" in enemy:
			enemy.max_health *= boss_multiplier
			enemy.current_health = enemy.max_health
		if "damage" in enemy:
			enemy.damage *= boss_multiplier
		
		# Scale boss size
		if enemy is Node2D:
			enemy.scale = Vector2(1.5, 1.5)
		
		# Apply boss visuals/effects
		# Apply any VFX or other boss indicators here...
		setup_boss_enemy(enemy)
		boss_enemies.append(enemy)
	else:
		# Scale regular enemies based on wave
		scale_enemy_to_wave(enemy)
	
	get_parent().add_child(enemy)
	total_spawned += 1

func setup_boss_enemy(enemy):
	# Make it bigger
	enemy.scale = Vector2(1.5, 1.5)
	
	# Set boss flag
	enemy.set("is_boss", true)
	
	# Increase health and damage
	if enemy.has_method("set_stats"):
		enemy.set_stats(enemy.max_health * boss_multiplier, enemy.base_damage * boss_multiplier)
	else:
		if "max_health" in enemy:
			enemy.max_health *= boss_multiplier
			enemy.current_health = enemy.max_health
		
		if "base_damage" in enemy:
			enemy.base_damage *= boss_multiplier
	
	# Add visual indicator
	var aura = create_boss_aura()
	enemy.add_child(aura)
	
	# Make boss persistent
	if "disappears" in enemy:
		enemy.disappears = false

func create_boss_aura():
	# Create a circular aura effect
	var aura = Node2D.new()
	aura.z_index = -1  # Behind the boss
	
	# Create particles
	var particles = GPUParticles2D.new()
	particles.amount = 40
	particles.lifetime = 2.0
	
	var material = ParticleProcessMaterial.new()
	material.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	material.emission_sphere_radius = 50.0
	material.gravity = Vector3(0, 0, 0)
	material.orbit_velocity_min = 0.3
	material.orbit_velocity_max = 0.5
	material.scale_min = 3.0
	material.scale_max = 6.0
	material.color = Color(1.0, 0.3, 0.3, 0.8)
	
	particles.process_material = material
	particles.emitting = true
	aura.add_child(particles)
	
	return aura

func scale_enemy_to_wave(enemy):
	# Gradually make enemies stronger with each wave - reduced scaling
	var health_scale = 1.0 + (current_wave - 1) * 0.15   # Reduced from 0.2
	var damage_scale = 1.0 + (current_wave - 1) * 0.1    # Reduced from 0.15
	
	if enemy.has_method("set_stats"):
		enemy.set_stats(enemy.max_health * health_scale, enemy.base_damage * damage_scale)
	else:
		if "max_health" in enemy:
			enemy.max_health *= health_scale
			enemy.current_health = enemy.max_health
		
		if "base_damage" in enemy:
			enemy.base_damage *= damage_scale

func create_spawn_portal(position: Vector2, is_boss: bool = false):
	# First ensure we have a valid parent
	if not is_instance_valid(get_parent()):
		return
		
	# Create a portal effect at the spawn position
	var portal = Node2D.new()
	portal.position = position
	portal.z_index = 5  # Above enemies
	get_parent().add_child(portal)
	
	# Create circle
	var circle = ColorRect.new()
	circle.size = Vector2(10, 10)
	circle.position = Vector2(-5, -5)  # Center the circle
	circle.pivot_offset = Vector2(5, 5)
	circle.color = Color(0.2, 0.4, 0.8, 0.8) if not is_boss else Color(0.8, 0.2, 0.2, 0.8)
	portal.add_child(circle)
	
	# Create particles
	var particles = GPUParticles2D.new()
	particles.amount = 30 if not is_boss else 50
	particles.lifetime = 0.5
	particles.explosiveness = 0.8
	
	var material = ParticleProcessMaterial.new()
	material.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	material.emission_sphere_radius = 10.0
	material.gravity = Vector3(0, 0, 0)
	material.initial_velocity_min = 20.0
	material.initial_velocity_max = 50.0
	material.scale_min = 2.0
	material.scale_max = 5.0
	material.color = Color(0.3, 0.6, 1.0, 0.8) if not is_boss else Color(1.0, 0.3, 0.3, 0.8)
	
	particles.process_material = material
	portal.add_child(particles)
	
	# Animate portal
	var tween = create_tween()
	tween.tween_property(circle, "size", Vector2(100, 100) if not is_boss else Vector2(150, 150), 0.4)
	tween.parallel().tween_property(circle, "position", Vector2(-50, -50) if not is_boss else Vector2(-75, -75), 0.4)
	tween.parallel().tween_property(particles, "emitting", true, 0.01)
	tween.tween_interval(0.3)
	tween.tween_property(circle, "color:a", 0.0, 0.2)
	tween.tween_callback(portal.queue_free)

func get_spawn_position() -> Vector2:
	# Check if player exists
	if not player or not is_instance_valid(player):
		# Try to find player again
		player = get_tree().get_first_node_in_group("Player")
		# If still not found, use a default position
		if not player or not is_instance_valid(player):
			return Vector2(0, 0)  # Default position
	
	# Get random angle
	var angle = randf() * TAU
	
	# Get random distance between min and max
	var distance = randf_range(min_spawn_distance, spawn_radius)
	
	# Calculate position
	var offset = Vector2(cos(angle), sin(angle)) * distance
	
	# Use player position as center
	return player.global_position + offset

func increase_difficulty():
	# Decrease spawn time (more frequent enemies)
	current_spawn_time = max(min_spawn_time, current_spawn_time - difficulty_increase_rate)

func spawn_wave():
	# Ensure we have a valid player before spawning
	if not player or not is_instance_valid(player):
		player = get_tree().get_first_node_in_group("Player")
		if not player:
			return
	
	# Spawn a group of enemies for a new wave - reduced from 3 to 2 per wave
	var spawn_count = current_wave * 2  # 2, 4, 6, etc. enemies per wave
	
	# Ensure we don't go beyond a reasonable limit
	spawn_count = min(spawn_count, 12)  # Maximum of 12 enemies per wave
	
	# For boss waves, spawn fewer regular enemies but add a boss
	if is_boss_wave:
		spawn_count = int(spawn_count * 0.5)  # Reduced from 0.7 to 0.5 (fewer regular enemies)
		
		# Spawn boss with special effect
		var boss_position = get_spawn_position()
		create_boss_portal(boss_position)
		
		# Wait for portal animation to complete
		await get_tree().create_timer(1.5).timeout
		
		# Check player still exists after delay
		if not is_instance_valid(player):
			return
		
		# Spawn the boss
		spawn_enemy(true)
	
	# Spawn regular enemies
	for i in range(spawn_count):
		# Check player still exists in loop
		if not is_instance_valid(player):
			return
		
		spawn_enemy(false)
		await get_tree().create_timer(0.2).timeout  # Small delay between spawns

func create_boss_portal(position: Vector2):
	# First ensure we have a valid parent
	if not is_instance_valid(get_parent()):
		return
		
	# Create a more elaborate portal for boss spawns
	var portal = Node2D.new()
	portal.position = position
	portal.z_index = 5  # Above enemies
	get_parent().add_child(portal)
	
	# Create multiple circles
	var circles = []
	var colors = [
		Color(0.8, 0.0, 0.0, 0.8),
		Color(1.0, 0.2, 0.0, 0.6),
		Color(0.7, 0.1, 0.1, 0.7)
	]
	
	for i in range(3):
		var circle = ColorRect.new()
		circle.size = Vector2(20, 20)
		circle.position = Vector2(-10, -10)  # Center the circle
		circle.pivot_offset = Vector2(10, 10)
		circle.color = colors[i]
		circle.rotation_degrees = i * 30  # Stagger rotations
		portal.add_child(circle)
		circles.append(circle)
	
	# Create particles
	var particles = GPUParticles2D.new()
	particles.amount = 100
	particles.lifetime = 1.0
	particles.explosiveness = 0.5
	
	var material = ParticleProcessMaterial.new()
	material.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	material.emission_sphere_radius = 20.0
	material.gravity = Vector3(0, -30, 0)
	material.initial_velocity_min = 50.0
	material.initial_velocity_max = 100.0
	material.scale_min = 3.0
	material.scale_max = 8.0
	material.color = Color(1.0, 0.3, 0.1, 0.8)
	
	particles.process_material = material
	portal.add_child(particles)
	
	# Create warning text
	var warning = Label.new()
	warning.text = "BOSS APPROACHING"
	warning.add_theme_font_size_override("font_size", 24)
	warning.add_theme_color_override("font_color", Color(1.0, 0.2, 0.2))
	warning.position = Vector2(-100, -100)
	warning.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	warning.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	portal.add_child(warning)
	
	# Play sound effect if available
	if FileAccess.file_exists("res://assets/sounds/boss_warning.wav"):
		var audio = AudioStreamPlayer2D.new()
		audio.stream = load("res://assets/sounds/boss_warning.wav")
		audio.volume_db = 5.0
		portal.add_child(audio)
		audio.play()
	
	# Animate portal
	var tween = create_tween()
	for i in range(circles.size()):
		var circle = circles[i]
		var delay = i * 0.2
		var final_size = Vector2(200 - i * 30, 200 - i * 30)
		var final_pos = Vector2(-(final_size.x / 2), -(final_size.y / 2))
		
		tween.parallel().tween_property(circle, "size", final_size, 1.0).set_delay(delay)
		tween.parallel().tween_property(circle, "position", final_pos, 1.0).set_delay(delay)
	
	tween.parallel().tween_property(particles, "emitting", true, 0.01)
	tween.parallel().tween_property(warning, "scale", Vector2(1.5, 1.5), 0.5)
	tween.parallel().tween_property(warning, "scale", Vector2(1.0, 1.0), 0.5).set_delay(0.5)
	tween.tween_interval(1.0)
	
	for circle in circles:
		tween.parallel().tween_property(circle, "color:a", 0.0, 0.5)
	
	tween.parallel().tween_property(warning, "modulate:a", 0.0, 0.5)
	tween.tween_callback(portal.queue_free)

func _on_enemy_died(enemy):
	# Remove from boss array if it was a boss
	if enemy in boss_enemies:
		boss_enemies.erase(enemy)
	
	# Chance to spawn a replacement enemy after some delay
	if randf() < 0.5:  # 50% chance
		await get_tree().create_timer(randf_range(1.0, 3.0)).timeout
		spawn_enemy()

# Find a valid ground position for an enemy
func find_valid_ground_position(x_position: float) -> Vector2:
	# Try to find ground at this x position
	var space_state = get_world_2d().direct_space_state
	
	# Raycast from above to find ground
	var ray_start = Vector2(x_position, 100)  # Start high up
	var ray_end = Vector2(x_position, 400)    # Go down past expected floor
	
	var query = PhysicsRayQueryParameters2D.create(ray_start, ray_end)
	query.collision_mask = 1  # Only check against world terrain
	
	var result = space_state.intersect_ray(query)
	if result:
		# Found ground, position slightly above it
		return Vector2(x_position, result.position.y - 20)
	
	# If we couldn't find ground, use the level's default floor position
	var level = get_parent()
	if level and level.has_method("get_valid_ground_position"):
		return level.get_valid_ground_position(x_position)
	
	# Last resort - use common floor position
	return Vector2(x_position, 272.9)  # Common floor level from our analysis

# Enhanced ground detection specifically for NightBorne enemies 
func find_valid_ground_position_for_nightborne(x_position: float) -> Vector2:
	# First, always get player position as reference
	if not player or not is_instance_valid(player):
		player = get_tree().get_first_node_in_group("Player")
		if not player:
			return Vector2(x_position, 272.9)
			
	# Let's try to spawn on the MAIN floor, not on platforms
	var player_y = player.global_position.y
	
	# Cast rays to identify main floor (lowest level in the scene)
	var space_state = get_world_2d().direct_space_state
	var main_floor_y = 0
	
	# Try to find main floor with a few raycasts at different positions
	var screen_width = get_viewport().get_visible_rect().size.x
	var test_positions = [0.25, 0.5, 0.75]  # Check at 1/4, 1/2, and 3/4 of screen width
	var floor_heights = []
	
	for pos_factor in test_positions:
		var test_x = get_viewport().get_canvas_transform().origin.x + (screen_width * pos_factor)
		var ray_start = Vector2(test_x, 100)
		var ray_end = Vector2(test_x, 500)  # Go very far down
		
		var query = PhysicsRayQueryParameters2D.create(ray_start, ray_end)
		query.collision_mask = 1
		
		var result = space_state.intersect_ray(query)
		if result:
			floor_heights.append(result.position.y)
	
	# If we found floor heights, use the highest (most negative Y) as main floor
	if floor_heights.size() > 0:
		# Sort floor heights (highest values will be at the end)
		floor_heights.sort()
		# Use the highest value as our main floor
		main_floor_y = floor_heights[floor_heights.size() - 1]
	else:
		# Fallback to known floor position
		main_floor_y = 272.9
	
	# Now try to spawn at the main floor level, away from edges
	var safe_x = x_position
	var safe_y = main_floor_y - 20  # Offset above floor
	
	# Make sure we're not spawning on an edge or small platform
	var edge_check_offsets = [-30, -15, 0, 15, 30]  # Check multiple points to ensure solid ground
	var is_valid_spawn = true
	
	for offset in edge_check_offsets:
		var check_x = safe_x + offset
		var ray_start = Vector2(check_x, safe_y - 10)
		var ray_end = Vector2(check_x, safe_y + 50)
		
		var query = PhysicsRayQueryParameters2D.create(ray_start, ray_end)
		query.collision_mask = 1
		
		var result = space_state.intersect_ray(query)
		if not result:
			# No floor at this offset - this might be an edge
			is_valid_spawn = false
			break
	
	if is_valid_spawn:
		return Vector2(safe_x, safe_y)
	
	# If we can't find a valid position at the given x, try at player's x
	safe_x = player.global_position.x + (randf_range(-300, 300))
	is_valid_spawn = true
	
	for offset in edge_check_offsets:
		var check_x = safe_x + offset
		var ray_start = Vector2(check_x, safe_y - 10)
		var ray_end = Vector2(check_x, safe_y + 50)
		
		var query = PhysicsRayQueryParameters2D.create(ray_start, ray_end)
		query.collision_mask = 1
		
		var result = space_state.intersect_ray(query)
		if not result:
			is_valid_spawn = false
			break
	
	if is_valid_spawn:
		return Vector2(safe_x, safe_y)
	
	# Last resort - use player's position but at the main floor level
	return Vector2(player.global_position.x, safe_y) 