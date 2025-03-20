extends "res://Entities/Scripts/Enemies/EnemyBase/enemy_base.gd"

# Get access to the EnemyBase class
class_name NightBorneEnemy

@onready var animated_sprite = $AnimatedSprite2D

# Attack properties
var attack_damage = 20.0  # Reduced from 40.0 to 20.0 to be less deadly
var attack_cooldown = 1.5
var can_attack = true
var attack_range = 80.0  # Increased from 60 to 80 to make attacks more likely
var attack_knockback = 200.0
var attack_timer = null
var last_attack_time = 0.0

# Debug variables 
var debug_mode = false  # Set to false to disable debug prints
var last_direction = Vector2.ZERO
var recovery_cooldown = 0.0  # Add cooldown for recovery jumps
var is_in_deep_pit = false    # Track if the enemy is in a deep pit
var last_safe_position = Vector2.ZERO  # Store last known safe position for teleportation
var teleport_cooldown = 0.0   # Prevent too frequent teleportation
var platform_check_timer = 0.0 # Timer for platform checks
var edge_detected = false  # Flag for edge detection
var standing_timer = 0.0    # Timer to detect if enemy is standing still
var debug_label = null      # Label for debug info
var last_velocity = Vector2.ZERO  # For detecting being stuck
var stuck_at_bottom_counter = 0   # Count how many frames we're stuck at bottom

# Platform and ground detection
var ground_check_distance = 60.0 # How far down to check for ground
var edge_check_distance = 40.0  # How far ahead to check for edges
var ground_y_position = 0.0 # Tracked ground position
var gravity_enabled = true   # Enable gravity by default
var force_to_ground = true   # Force enemy to ground on startup
var ground_check_failed_count = 0  # Count consecutive failed ground checks
var stuck_edge_counter = 0   # Count how long we've been stuck at an edge
var enhanced_collision_checks = true  # Enable enhanced collision detection
var collision_retry_attempts = 0  # Track collision resolution attempts
var last_collision_position = Vector2.ZERO  # Last position where collision occurred
var vertical_movement_threshold = 50.0  # Limit for following player vertically
var force_stay_on_floor = true  # Force enemy to stay on floor when possible
var float_prevention_timer = 0.0  # Timer to track and prevent floating

# Damage scaling
var damage_modifier: float = 1.0  # Modifier applied to attack damage

func _ready():
	# Set base stats
	max_health = 80.0
	current_health = max_health
	max_speed = 150.0  # Increased from 120 to 150 for faster movement
	base_damage = attack_damage
	acceleration = 1200.0  # Increased from 800 to 1200 for more responsive movement
	
	# KNOCKBACK FIX: Further increase knockback resistance for NightBorne
	knockback_resistance = 0.9  # Increased from 0.8 to 0.9 (90% resistance)
	
	# Fix spawn position to avoid getting stuck under platforms
	fix_spawn_position()
	
	# Store initial position as safe position
	last_safe_position = global_position
	ground_y_position = global_position.y
	last_collision_position = global_position  # Initialize collision tracking
	
	# We no longer need the behavior tree - direct control is more reliable
	if has_node("BTPlayer"):
		$BTPlayer.queue_free()
	
	# NightBorne is a boss/mini-boss, so it shouldn't disappear when off-screen
	disappears = false
	
	# Initialize animations and connect signals
	if animated_sprite:
		# Make sure we're connected to the animation_finished signal
		if !animated_sprite.animation_finished.is_connected(_on_animation_finished):
			animated_sprite.animation_finished.connect(_on_animation_finished)
		animated_sprite.play("Idle")
	
	# Initialize and setup hitbox properly
	var hitbox = get_node_or_null("HitBox")
	if hitbox:
		hitbox.debug = true
		hitbox.damage = attack_damage
		hitbox.is_player_hitbox = false
		hitbox.collision_layer = 16  # Layer 16 for enemy hitboxes
		hitbox.collision_mask = 8    # Mask 8 to detect player hurtboxes
		
		# CRITICAL FIX: Set metadata to prevent sprite flipping on hit
		hitbox.set_meta("no_flip", true)
		
	# Initialize and setup hurtbox properly
	var hurtbox = get_node_or_null("HurtBox")  
	if hurtbox:
		hurtbox.debug = true
		if "is_player_hurtbox" in hurtbox:
			hurtbox.is_player_hurtbox = false
		hurtbox.collision_layer = 4  # Layer 4 for enemy hurtboxes
		hurtbox.collision_mask = 2   # Mask 2 to detect player hitboxes
		
		# Connect area entered signal for debugging
		if not hurtbox.area_entered.is_connected(_on_hurtbox_area_entered):
			hurtbox.area_entered.connect(_on_hurtbox_area_entered)
		
	# Initialize attack state
	can_attack = true
	last_attack_time = 0.0
	
	# Enable debug mode
	debug_mode = false
	
	# Force to ground on startup
	if force_to_ground:
		# Apply initial gravity to ensure the enemy is on the ground
		velocity.y = 100
		
	# Perform initial ground check
	call_deferred("initial_ground_check")
	
	# Force attack cooldown reset to ensure we can attack immediately
	call_deferred("reset_attack_cooldown")
	
	# Create debug label if debug_mode is on
	if debug_mode:
		debug_label = Label.new()
		debug_label.position = Vector2(-50, -70)
		debug_label.z_index = 100
		debug_label.add_theme_color_override("font_color", Color(0, 1, 0))
		add_child(debug_label)

# Fix spawn position to ensure the NightBorne doesn't spawn under platforms
func fix_spawn_position():
	# First, check if we're currently under a platform
	# Cast a ray upward from our current position
	var space_state = get_world_2d().direct_space_state
	var ray_start = global_position
	var ray_end = ray_start + Vector2(0, -80)  # Check 80 pixels above
	
	var query = PhysicsRayQueryParameters2D.create(ray_start, ray_end)
	query.exclude = [self]
	query.collision_mask = 1  # Only check against world/terrain
	
	var result = space_state.intersect_ray(query)
	if result:
		# We're under a platform, need to move to a valid position
		
		# Try to find main floor level
		var found_floor = false
		var floor_y = 0
		
		# Use player position if available
		var player = get_tree().get_first_node_in_group("Player")
		if player:
			# Cast a ray downward from the player position
			ray_start = player.global_position
			ray_end = ray_start + Vector2(0, 100)
			
			query = PhysicsRayQueryParameters2D.create(ray_start, ray_end)
			query.exclude = [player]
			query.collision_mask = 1  # Only check against world/terrain
			
			result = space_state.intersect_ray(query)
			if result:
				found_floor = true
				floor_y = result.position.y - 20  # Position slightly above the floor
		
		if not found_floor:
			# Try a fixed position - the main level floor is typically around y=270-280
			floor_y = 272.9  # Common floor y-position in the level
		
		# Adjust our position to be on the floor
		global_position.y = floor_y
	else:
		# Check below us for floor
		ray_start = global_position
		ray_end = ray_start + Vector2(0, 80)  # Check 80 pixels below
		
		query = PhysicsRayQueryParameters2D.create(ray_start, ray_end)
		query.exclude = [self]
		query.collision_mask = 1
		
		result = space_state.intersect_ray(query)
		if result:
			# Found floor below, move slightly above it
			global_position.y = result.position.y - 20
		else:
			# No floor found below either, try to find the main level floor
			var player = get_tree().get_first_node_in_group("Player")
			if player:
				ray_start = Vector2(global_position.x, player.global_position.y)
				ray_end = ray_start + Vector2(0, 100)
				
				query = PhysicsRayQueryParameters2D.create(ray_start, ray_end)
				query.exclude = [player]
				query.collision_mask = 1
				
				result = space_state.intersect_ray(query)
				if result:
					global_position.y = result.position.y - 20
				else:
					# Last resort - use the common floor position
					global_position.y = 272.9

	# Additional step: Force a check downward to ensure we're on solid ground
	ray_start = global_position
	ray_end = ray_start + Vector2(0, 100)  # Check 100 pixels below
	
	query = PhysicsRayQueryParameters2D.create(ray_start, ray_end)
	query.exclude = [self]
	query.collision_mask = 1
	
	result = space_state.intersect_ray(query)
	if result:
		# Found ground below, ensure we're properly positioned above it
		global_position.y = result.position.y - 20

# Perform an initial ground check after a short delay to let physics settle
func initial_ground_check():
	await get_tree().create_timer(0.2).timeout
	# Force a thorough ground check
	check_ground_position(true)

func _physics_process(delta):
	# Apply enhanced gravity if enabled - FIXED to prevent floating
	if gravity_enabled:
		if !is_on_floor():
			# Apply stronger base gravity to prevent floating
			var gravity_strength = 1200  # Increased base gravity (was 980)
			
			# Additional gravity when above the player to prevent floating
			if target and global_position.y < target.global_position.y - 30:
				gravity_strength += 500  # Extra gravity when above player
			
			# Progressive gravity for natural falling
			var fall_time = 0
			if velocity.y > 0:
				fall_time = min(2.0, velocity.y / 800)  # Estimate time falling
				gravity_strength += fall_time * 300  # Increase gravity up to extra
			
			velocity.y += gravity_strength * delta
			
			# Apply float prevention system
			float_prevention_timer += delta
			if float_prevention_timer > 0.5 and target:  # Check every half second
				float_prevention_timer = 0.0
				if global_position.y < target.global_position.y - 50:
					# If significantly above player for too long, force downward movement
					velocity.y += 300
		else:
			# On floor - reset counters and timers
			collision_retry_attempts = 0
			float_prevention_timer = 0.0
	
	# Update standing timer
	if is_active and velocity.length() < 5.0:
		standing_timer += delta
	else:
		standing_timer = 0.0
		
	# If stuck for too long (1 second), force movement
	if standing_timer > 1.0 and target != null:
		var force_direction = global_position.direction_to(target.global_position)
		velocity.x = force_direction.x * max_speed * 1.5
		standing_timer = 0.0  # Reset timer
	
	# CRITICAL: Update safe position if currently in a valid location - lower frequency
	if Engine.get_physics_frames() % 10 == 0:  # Only update every 10 frames
		update_safe_position()
		check_ground_position()
		
	# If we've failed many ground checks, try to teleport - REDUCED THRESHOLD
	if ground_check_failed_count > 15:  # Reduced from 20 to teleport sooner
		teleport_to_safe_position()
		ground_check_failed_count = 0
		
	# If we've been stuck at an edge for too long, teleport - SIGNIFICANTLY REDUCED THRESHOLD
	if edge_detected and stuck_edge_counter > 20:  # Reduced from 40 to teleport much sooner
		teleport_to_safe_position()
		stuck_edge_counter = 0
	
	# Find player if we don't have a target
	if target == null:
		target = get_tree().get_first_node_in_group("Player")
	
	# Skip physics process if we have no target
	if target == null or !is_active:
		return
	
	# Emergency attack reset - if it's been more than 3 seconds since attack was called
	# and we still can't attack, force reset it
	if !can_attack and (Time.get_ticks_msec() - last_attack_time) > 3000:
		can_attack = true
		# Cancel any lingering timers
		if attack_timer != null and attack_timer.time_left > 0:
			attack_timer.timeout.disconnect(func(): can_attack = true)
			attack_timer = null
	
	# Calculate distance and direction to player
	var direction = global_position.direction_to(target.global_position)
	var distance = global_position.distance_to(target.global_position)
	
	# Update debug label if enabled
	if debug_mode and debug_label:
		debug_label.text = "Dist: " + str(int(distance)) + "\n" + \
						   "Edge: " + str(edge_detected) + "\n" + \
						   "Vel: " + str(int(velocity.x)) + ", " + str(int(velocity.y)) + "\n" + \
						   "Atk: " + str(can_attack)
	
	# Apply velocity capping EVERY frame
	cap_velocity()
	
	# Detect edges before movement to prevent falling
	detect_edges()
	
	# DIRECT CHASE LOGIC:
	# If we're close enough to attack, try to attack
	if distance <= attack_range:
		velocity.x = 0 # Stop moving
		stuck_edge_counter = 0 # Reset edge counter since we're in attack range
		
		# Ensure we're at the correct height for attacking - NEW
		if force_stay_on_floor and target:
			var height_diff = global_position.y - target.global_position.y
			if height_diff < -30:  # We're significantly above player
				# Apply extra gravity to get down to player level
				velocity.y += 300 * delta
			elif height_diff > 30 and is_on_floor():  # We're significantly below player
				# Don't jump up automatically - stay grounded
				pass
		
		if can_attack:
			attack()
		else:
			pass
	# Otherwise, move toward the player if we don't detect an edge
	elif not edge_detected:
		# Reset edge counter when not at an edge
		stuck_edge_counter = 0
		
		# Calculate horizontal movement only
		var target_speed = direction.x * max_speed
		
		# Boost speed if far from player
		if distance > 150:
			target_speed *= 1.5
		
		velocity.x = move_toward(velocity.x, target_speed, acceleration * delta)
	else:
		# We detected an edge - increment the stuck counter
		stuck_edge_counter += 1
		
		# Modified to prevent unwanted following down platforms - NEW
		if target.global_position.y > global_position.y + 30:
			# Only attempt to follow down if the player is not too far down
			# AND if we're actually at an edge (not just floating)
			if target.global_position.y - global_position.y < 150 and is_on_floor():
				velocity.x = direction.x * 60 # Move slowly toward player
				velocity.y = 50 # Add slight downward force
			else:
				# If the player is too far down, stop and consider teleporting
				velocity.x = move_toward(velocity.x, 0, acceleration * delta)
		else:
			# Player is at our level or above - slow down
			velocity.x = move_toward(velocity.x, 0, acceleration * delta)
		
		# If stuck at an edge for some time but not too long yet, try small jump
		if stuck_edge_counter > 20 and stuck_edge_counter < 40 and is_on_floor():
			velocity.y = -350 # Apply stronger upward force for a more effective jump
	
	# Store last velocity for comparison
	last_velocity = velocity
	
	# Apply screen boundary protection once per physics frame
	enforce_screen_bounds()
	
	# Call move_and_slide to apply movement with enhanced collision handling
	var was_on_floor = is_on_floor()
	var pre_move_position = global_position
	var movement_result = move_and_slide()
	
	# Enhanced collision detection - detect if we're stuck against a wall or in geometry
	if enhanced_collision_checks and is_active and movement_result:
		detect_and_resolve_collision_issues(pre_move_position, delta)
	
	# Check if we just landed on the floor
	if !was_on_floor and is_on_floor():
		ground_y_position = global_position.y
	
	# Update cooldowns
	if recovery_cooldown > 0:
		recovery_cooldown -= delta
	if teleport_cooldown > 0:
		teleport_cooldown -= delta
	if platform_check_timer > 0:
		platform_check_timer -= delta

# New function to detect and resolve collision issues
func detect_and_resolve_collision_issues(pre_move_position: Vector2, delta: float) -> void:
	# Distance threshold to detect if we're stuck - made more sensitive
	var distance_threshold = 1.5  # Reduced from 2.0 to detect stuck situations earlier
	var position_changed = global_position.distance_to(pre_move_position) > distance_threshold
	
	# Check if we're stuck against a wall or in a corner
	if (is_on_wall() or collision_retry_attempts > 0) and abs(velocity.x) > 10.0 and !position_changed:
		collision_retry_attempts += 1
		
		# Record collision position if this is a new collision
		if collision_retry_attempts == 1:
			last_collision_position = global_position
		
		# Try to resolve stuck situations more aggressively with lower thresholds
		if collision_retry_attempts > 3:  # Reduced from 5
			# If we're stuck at wall, first try a jump
			if is_on_floor() and collision_retry_attempts < 7:  # Reduced from 10
				velocity.y = -400  # Stronger jump (was -350)
				
				# Also reverse horizontal direction more strongly
				velocity.x = -velocity.x * 0.7  # Increased multiplier from 0.5
			
			# If still stuck after several attempts, try teleporting sooner
			if collision_retry_attempts > 10:  # Reduced from 15
				teleport_to_safe_position()
				collision_retry_attempts = 0
		
		# If we're stuck in a corner or against a wall but NOT on floor, apply stronger upward force
		if !is_on_floor() and collision_retry_attempts > 2:  # Reduced from 3
			if get_real_velocity().y > 0:  # Only if we're falling
				velocity.y = -600  # Even stronger upward boost (was -500)
	else:
		# Reset collision attempts if we're moving normally
		if position_changed and collision_retry_attempts > 0:
			collision_retry_attempts = 0
	
	# NEW: Check for proximity to other enemies (including NightBornes)
	var enemies_nearby = false
	var enemies = get_tree().get_nodes_in_group("Enemy")
	for enemy in enemies:
		if enemy != self and global_position.distance_to(enemy.global_position) < 30:
			enemies_nearby = true
			break
	
	# NEW: Handle being too close to other enemies or player
	if enemies_nearby or (target and global_position.distance_to(target.global_position) < 30):
		standing_timer += delta * 2  # Accelerate standing timer when close to others
		
		if standing_timer > 0.5 and velocity.length() < 10:  # Quick response when stuck with others
			# First try to jump away
			if is_on_floor():
				velocity.y = -300
				
				# If player is nearby, move away from them
				if target and global_position.distance_to(target.global_position) < 30:
					var away_dir = global_position - target.global_position
					velocity.x = away_dir.normalized().x * max_speed
			
			# If stuck for a while, just teleport
			if standing_timer > 1.0:
				teleport_to_safe_position()
				collision_retry_attempts = 0
				standing_timer = 0.0

# Improved check for ground beneath the NightBorne
func check_ground_position(force_check = false):
	if is_on_floor():
		# We're on solid ground - update the ground position
		ground_y_position = global_position.y
		is_in_deep_pit = false
		ground_check_failed_count = 0
		if debug_mode and force_check:
			# print("NightBorne: On floor at position y=" + str(ground_y_position))
			pass
		return
	
	# Use multiple raycasts for better detection
	var found_ground = false
	var best_ground_y = 0
	
	# Cast multiple rays at different horizontal offsets for better coverage
	for offset in [-30, -20, -10, 0, 10, 20, 30]:
		var space_state = get_world_2d().direct_space_state
		var ray_start = global_position + Vector2(offset, 0)
		var ray_end = ray_start + Vector2(0, ground_check_distance)
		
		var query = PhysicsRayQueryParameters2D.create(ray_start, ray_end)
		query.exclude = [self]
		query.collision_mask = 1  # Only check against world/terrain
		
		var result = space_state.intersect_ray(query)
		if result:
			# Found ground - track closest hit
			found_ground = true
			if best_ground_y == 0 or result.position.y < best_ground_y:
				best_ground_y = result.position.y
				if debug_mode and force_check:
					# print("NightBorne: Ground detected at y=" + str(best_ground_y) + " with offset " + str(offset))
					pass
	
	if found_ground:
		# Found ground - remember its position
		ground_y_position = best_ground_y
		ground_check_failed_count = 0
	else:
		# No ground found below - we might be over a pit
		is_in_deep_pit = true
		ground_check_failed_count += 1
		
		if debug_mode and (force_check or ground_check_failed_count > 3):
			# print("NightBorne: No ground detected below enemy after " + str(ground_check_failed_count) + " attempts")
			pass

# Enhanced edge detection with improved accuracy and vertical awareness
func detect_edges():
	# If we're not on the floor, we can't detect edges reliably
	if not is_on_floor() and ground_check_failed_count < 5:
		edge_detected = false
		return
	
	# Check for edges more frequently - REDUCED TIMER
	if platform_check_timer > 0:
		platform_check_timer -= get_process_delta_time()
		return
	
	platform_check_timer = 0.05  # Reduced from 0.1 for faster response to edges
		
	# Get movement direction
	var direction = Vector2.ZERO
	if target:
		direction = global_position.direction_to(target.global_position)
	else:
		edge_detected = false
		return
	
	# Skip edge detection if we're not moving horizontally
	if abs(direction.x) < 0.1:
		edge_detected = false
		return
	
	# Check if player is on a platform - we need special handling
	var player_is_on_platform = false
	var player_platform_y = 0
	
	if target:
		# Cast ray down from player to find their floor
		var space_state = get_world_2d().direct_space_state
		var ray_start = target.global_position + Vector2(0, 5)  # Start slightly below player
		var ray_end = ray_start + Vector2(0, 80)  # Check below
		
		var query = PhysicsRayQueryParameters2D.create(ray_start, ray_end)
		query.exclude = [target]
		query.collision_mask = 1
		
		var result = space_state.intersect_ray(query)
		if result:
			player_is_on_platform = true
			player_platform_y = result.position.y
	
	# IMPROVED: Use more raycasts at different distances for more reliable edge detection
	var space_state = get_world_2d().direct_space_state
	var edge_checks = []
	
	# Cast 5 rays at increasing distances (added one more ray and shorter distances)
	for distance in [10, 20, 30, 45, 60]:
		var ray_start = global_position + Vector2(sign(direction.x) * distance, 0)
		var ray_end = ray_start + Vector2(0, 70)
		
		var query = PhysicsRayQueryParameters2D.create(ray_start, ray_end)
		query.exclude = [self]
		query.collision_mask = 1
		
		var result = space_state.intersect_ray(query)
		edge_checks.append(result)
	
	# NEW: Check if player is directly below us
	var player_directly_below = false
	var height_diff = 0
	if target:
		height_diff = target.global_position.y - global_position.y
		player_directly_below = height_diff > 30 and abs(target.global_position.x - global_position.x) < 50
	
	# Determine if we're at an edge
	if not edge_checks[0] or not edge_checks[1]:
		# Edge detected close to us - stop immediately
		edge_detected = true
		
		# NEW: If the player is directly below, consider jumping down
		if player_directly_below and height_diff < 150:
			# Check if there's a floor below the player
			var space_state_down = get_world_2d().direct_space_state
			var ray_start_down = target.global_position + Vector2(0, 5)
			var ray_end_down = ray_start_down + Vector2(0, 80)
			
			var query_down = PhysicsRayQueryParameters2D.create(ray_start_down, ray_end_down)
			query_down.exclude = [target, self]
			query_down.collision_mask = 1
			
			var result_down = space_state_down.intersect_ray(query_down)
			if result_down:
				# Player is on solid ground - it might be safe to jump down
				velocity.y = 50  # Add slight downward force to help us fall
				velocity.x = direction.x * 60  # Move slower toward edge
				edge_detected = false  # Allow moving over the edge
			else:
				# No ground below player - don't follow
				velocity.x = 0
		else:
			velocity.x = 0  # Stop at the edge
	elif not edge_checks[2] or not edge_checks[3]:
		# Edge detected further ahead - slow down
		edge_detected = true
		velocity.x = direction.x * (max_speed * 0.3)  # Slow approach
	elif not edge_checks[4]:
		# Edge detected far ahead - be cautious
		edge_detected = true
		velocity.x = direction.x * (max_speed * 0.5)  # Cautious approach
	else:
		# No edge detected
		edge_detected = false
		stuck_edge_counter = 0

# Improved teleport function with more reliable positioning
func teleport_to_safe_position():
	# Try to find the player first
	var player = get_tree().get_first_node_in_group("Player")
	if player:
		# Get a position on the same level as the player but at a LARGER safe distance
		var player_pos = player.global_position
		var direction = -1 if randf() < 0.5 else 1  # Random direction
		var distance = randf_range(300, 450)  # Increased distance (was 250-400)
		var new_pos = Vector2(player_pos.x + direction * distance, player_pos.y - 20)
		
		# ADDED: Check for other NightBornes in the vicinity to avoid teleporting too close to them
		var other_nightbornes = get_tree().get_nodes_in_group("Enemy")
		var too_close_to_others = false
		
		for enemy in other_nightbornes:
			if enemy != self and enemy.name.contains("NightBorne") and enemy.global_position.distance_to(new_pos) < 100:
				too_close_to_others = true
				break
		
		# If too close to others, adjust the position further
		if too_close_to_others:
			new_pos.x += direction * 150
		
		# Ensure we're not teleporting too close to the screen edges
		var viewport = get_viewport()
		if viewport:
			var camera = viewport.get_camera_2d()
			if camera:
				var screen_size = viewport.get_visible_rect().size
				var left_edge = camera.global_position.x - (screen_size.x / 2) + 100
				var right_edge = camera.global_position.x + (screen_size.x / 2) - 100
				
				# Clamp new position to safe screen area
				new_pos.x = clamp(new_pos.x, left_edge, right_edge)
		
		# Find ground at the target position
		var floor_found = false
		var target_y = player_pos.y
		
		# Series of raycasts to find the best floor position
		var space_state = get_world_2d().direct_space_state
		
		# First, find player's floor level
		var ray_start = Vector2(player_pos.x, player_pos.y - 10) # Start above player
		var ray_end = Vector2(player_pos.x, player_pos.y + 100)  # Go well below player
		
		var query = PhysicsRayQueryParameters2D.create(ray_start, ray_end)
		query.exclude = [player]
		query.collision_mask = 1  # Only check against world/terrain
		
		var result = space_state.intersect_ray(query)
		if result:
			floor_found = true
			target_y = result.position.y - 20  # Position above floor
		
		# Now check multiple positions around our teleport destination
		var best_floor_y = 0
		var best_floor_found = false
		
		# IMPROVED: Check more positions with wider range
		for x_offset in [-60, -40, -20, 0, 20, 40, 60]:
			ray_start = Vector2(new_pos.x + x_offset, target_y - 100)
			ray_end = Vector2(new_pos.x + x_offset, target_y + 150)
			
			query = PhysicsRayQueryParameters2D.create(ray_start, ray_end)
			query.exclude = [self]
			query.collision_mask = 1
			
			result = space_state.intersect_ray(query)
			if result:
				best_floor_found = true
				# Prefer floors closer to player's level
				var floor_y = result.position.y - 20
				if best_floor_y == 0 or abs(floor_y - target_y) < abs(best_floor_y - target_y):
					best_floor_y = floor_y
		
		if best_floor_found:
			global_position = Vector2(new_pos.x, best_floor_y)
			# Store this position as the new safe position
			last_safe_position = global_position
		elif floor_found:
			# No floor at teleport point, try player's x position instead but at a safe distance
			var safe_x_offset = direction * 150  # Increased from 100
			ray_start = Vector2(player_pos.x + safe_x_offset, target_y - 100)
			ray_end = Vector2(player_pos.x + safe_x_offset, target_y + 150)
			
			query = PhysicsRayQueryParameters2D.create(ray_start, ray_end)
			query.exclude = [self, player]
			query.collision_mask = 1
			
			result = space_state.intersect_ray(query)
			if result:
				global_position = Vector2(player_pos.x + safe_x_offset, result.position.y - 20)
				last_safe_position = global_position
			else:
				# No ground found at all - use player's exact level at a safe distance
				global_position = Vector2(player_pos.x + safe_x_offset, target_y)
				last_safe_position = global_position
		else:
			# Complete fallback - use hard-coded floor position
			global_position = Vector2(new_pos.x, 272.9)
		
		# ADDED: Double check that we're not stuck in terrain after teleporting
		var inside_check = PhysicsRayQueryParameters2D.create(global_position, global_position)
		inside_check.exclude = [self]
		inside_check.collision_mask = 1
		
		result = space_state.intersect_ray(inside_check)
		if result:
			# We're inside terrain - move up slightly to try to escape
			global_position.y -= 30
		
		# Reset velocity and state
		velocity = Vector2.ZERO
		edge_detected = false
		ground_check_failed_count = 0
		is_in_deep_pit = false
		stuck_edge_counter = 0
		collision_retry_attempts = 0
		
		# Flash the sprite to show teleportation
		if animated_sprite:
			animated_sprite.modulate = Color(0.5, 0.5, 1.5, 1.0)  # Blue flash
			var timer = get_tree().create_timer(0.2)
			timer.timeout.connect(func(): animated_sprite.modulate = Color(1, 1, 1, 1))
	else:
		# If no player found, use last safe position or fix spawn position
		fix_spawn_position()

# Called by the behavior tree attack task
func attack():
	if can_attack and is_active:
		# Record attack time for emergency reset
		last_attack_time = Time.get_ticks_msec()
		
		# Play attack animation
		animated_sprite.play("Attack")
		
		# Prevent attacking again until animation finishes
		can_attack = false
		
		# ENHANCED: Activate hitbox for damage dealing
		var hitbox = get_node_or_null("HitBox")
		if hitbox:
			hitbox.damage = attack_damage * damage_modifier
			hitbox.activate()
			# print("NightBorne: Activated hitbox with damage value: ", hitbox.damage)
		else:
			# print("NightBorne: WARNING - Missing HitBox node!")
			pass
		
		# Deal damage to target directly (as backup method)
		if target and target.has_method("take_damage"):
			# Calculate direction for knockback
			var knockback_direction = target.global_position - global_position
			knockback_direction = knockback_direction.normalized()
			
			# Apply damage and knockback directly with no_flip flag
			# print("NightBorne: Attempting to damage player directly with damage: ", attack_damage)
			
			# FIXED APPROACH: More direct, reliable method to prevent player flipping
			# Try the most specific method first with explicit check
			if target.has_method("take_damage_with_info"):
				# Use the info dictionary approach - most robust option
				var damage_info = {
					"amount": attack_damage,
					"knockback": knockback_direction * attack_knockback,
					"no_flip": true  # Flag to prevent sprite flipping
				}
				target.call("take_damage_with_info", damage_info)
				# print("NightBorne: Used take_damage_with_info to prevent flipping")
			elif target.has_method("take_damage_no_flip"):
				# Fallback to specialized no-flip method
				target.call("take_damage_no_flip", attack_damage, knockback_direction * attack_knockback)
				# print("NightBorne: Used take_damage_no_flip method")
			else:
				# Last resort: standard damage method (may cause flipping)
				target.call("take_damage", attack_damage, knockback_direction * attack_knockback)
				# print("NightBorne: Used standard take_damage method - might cause flipping")
		else:
			# print("NightBorne: Target is null or missing take_damage method")
			pass

# Handle taking damage with improved knockback handling
func take_damage(damage_amount: float, knockback_force: Vector2 = Vector2.ZERO) -> void:
	if not is_active:
		return
	
	# CRITICAL FIX: Print detailed damage logging
	print("NightBorne: take_damage called with damage=", damage_amount, ", knockback=", knockback_force)
	
	# Apply damage to self first with debug output
	current_health -= damage_amount
	print("NightBorne: Took damage: ", damage_amount, " Health: ", current_health)
	
	# CRITICAL FIX: Ensure damage application is visible and effective
	if animated_sprite:
		# Always trigger the hurt effect even if in attack animation
		apply_damage_flash()
		
		# Play hurt animation unless attacking
		if animated_sprite.animation != "Attack":
			animated_sprite.play("Hurt")
	
	# Apply knockback with improved feedback
	knockback_force *= (1.0 - knockback_resistance * 0.5)  # Further reduce effective knockback resistance
	
	# Apply knockback - improved vertical component for better feedback
	velocity.x = knockback_force.x  # Direct assignment for stronger response
	if knockback_force.y < 0:  # Only apply upward knockback, not downward
		velocity.y = knockback_force.y * 0.5  # More pronounced upward knockback
	
	# Check if dead after damage is applied
	if current_health <= 0:
		die()
		return
	
	# Don't call parent method to avoid potential issues
	# super.take_damage(damage_amount, knockback_force)

# Apply damage flash effect
func apply_damage_flash():
	# Flash the sprite red
	if animated_sprite:
		animated_sprite.modulate = Color(1.5, 0.3, 0.3, 1.0)
		
		# Create a timer to reset the color
		var timer = get_tree().create_timer(0.15)
		timer.timeout.connect(func(): animated_sprite.modulate = Color(1, 1, 1, 1))

# Override death to play death animation
func die() -> void:
	is_active = false
	
	# Play death animation
	animated_sprite.play("Death")
	
	# Emit signal if SignalBus is available
	if Engine.has_singleton("SignalBus"):
		var signal_bus = Engine.get_singleton("SignalBus")
		signal_bus.enemy_died.emit(self)
		signal_bus.enemy_killed.emit(global_position, "NightBorne")
	
	# Don't call queue_free() immediately - wait for animation to finish

# Animation finished callback
func _on_animation_finished():
	var animation = animated_sprite.animation
	
	if animation == "Attack":
		# Reset attack cooldown - use a shorter cooldown for more aggressive attacks
		can_attack = false  # Ensure we can't attack during cooldown
		# print("NightBorne: Attack animation finished, starting cooldown")
		
		# Use a shorter cooldown for more frequent attacks
		attack_cooldown = 0.7  # Reduced from 1.0 to 0.7 for more frequent attacks
		
		# Deactivate hitbox after attack animation ends
		var hitbox = get_node_or_null("HitBox")
		if hitbox:
			hitbox.deactivate()
		
		# Explicitly create timer for better reliability
		if attack_timer != null and attack_timer.time_left > 0:
			attack_timer.timeout.disconnect(func(): can_attack = true)
		
		attack_timer = get_tree().create_timer(attack_cooldown)
		# print("NightBorne: Created attack cooldown timer for " + str(attack_cooldown) + " seconds")
		attack_timer.timeout.connect(func(): 
			can_attack = true
			# print("NightBorne: Attack cooldown finished, can attack again")
		)
		
		# CRITICAL FIX: Explicitly switch to a different animation after attack finishes
		if is_active:
			# Choose animation based on movement
			if velocity.length() > 10:
				animated_sprite.play("Run")
				# print("NightBorne: Switching to Run animation after attack")
			else:
				animated_sprite.play("Idle")
				# print("NightBorne: Switching to Idle animation after attack")
	
	elif animation == "Death":
		# Clean up after death animation finishes
		queue_free()
	elif animation == "Hurt":
		# Return to idle after hurt animation
		if is_active:
			animated_sprite.play("Idle")
			
			# Reset attack cooldown after being hurt to ensure we can attack
			reset_attack_cooldown()

# Move to target function for behavior tree - called by the move_to_target task
func move(dir: Vector2, speed: float) -> void:
	if debug_mode:
		# print("NightBorne: Move called with direction " + str(dir) + " and speed " + str(speed))
		pass
	
	# If we detected an edge and trying to move towards it, be more careful
	if edge_detected and sign(dir.x) == sign(velocity.x):
		# Still move toward target, but at reduced speed near edges
		velocity.x = move_toward(velocity.x, dir.x * speed * 0.3, 200 * get_process_delta_time())
		if debug_mode:
			# print("NightBorne: Edge detected, moving with caution")
			pass
		return
	
	# More aggressive movement - slightly higher speed than requested
	var movement_speed = speed * 1.2
	
	# Check if target is the player
	if target and target.is_in_group("Player"):
		var distance = global_position.distance_to(target.global_position)
		
		# If player is far away, move even faster to catch up
		if distance > 150:
			movement_speed = speed * 1.5
			if debug_mode:
				# print("NightBorne: Target far away, increasing speed to " + str(movement_speed))
				pass
	
	# Normal movement with enhanced acceleration - only horizontal movement
	var target_velocity = Vector2(dir.x * movement_speed, velocity.y)
	velocity = velocity.move_toward(target_velocity, acceleration * get_process_delta_time())
	
	# Print debug info periodically
	if debug_mode and Engine.get_physics_frames() % 30 == 0:
		# print("NightBorne: velocity = " + str(velocity) + ", position = " + str(global_position))
		pass

# Force reset attack cooldown for testing
func reset_attack_cooldown():
	can_attack = true
	if attack_timer != null and attack_timer.time_left > 0:
		attack_timer.timeout.disconnect(func(): can_attack = true)
		attack_timer = null
	# print("NightBorne: Attack cooldown forcibly reset")

# Force take damage (for debugging)
func force_damage_test(amount: float = 10.0):
	var knockback = Vector2(300, -100) if global_position.x < 300 else Vector2(-300, -100)
	# print("NightBorne: Taking test damage: ", amount)
	take_damage(amount, knockback)
	return current_health

# Test damage functionality with input
func _input(event):
	if event is InputEventKey and event.pressed:
		if event.keycode == KEY_T:
			# print("NightBorne: TEST - Taking damage via key press")
			force_damage_test(20.0)

# Handle hurtbox collisions
func _on_hurtbox_area_entered(area):
	print("NightBorne Hurtbox: Detected collision with ", area.name)
	
	# Check if it's a player hitbox
	if "is_player_hitbox" in area and area.is_player_hitbox:
		print("NightBorne Hurtbox: Hit by player hitbox with active=", area.active, ", damage=", area.damage)
		
		# CRITICAL FIX: Always take damage from player hitboxes, even if active status isn't set correctly
		var damage_value = area.damage if "damage" in area else 10.0
		
		# Calculate knockback direction from hitbox
		var knockback_dir = global_position - area.global_position
		knockback_dir = knockback_dir.normalized()
		
		# Determine knockback force
		var knockback_amount = 300.0  # Default strong knockback
		if "knockback_force" in area:
			knockback_amount = area.knockback_force
		
		# Apply damage directly
		print("NightBorne Hurtbox: Applying damage=", damage_value, ", knockback=", knockback_dir * knockback_amount)
		take_damage(damage_value, knockback_dir * knockback_amount)

# Cap velocity to prevent falling off screen and limit vertical movement
func cap_velocity():
	# Cap falling velocity to safer value
	if velocity.y > 300:  # Not as aggressive as before for better performance
		velocity.y = 300
	
	# Only cap extreme horizontal velocity
	if abs(velocity.x) > 300:
		velocity.x = sign(velocity.x) * 300
	
	# If edge detected, reduce horizontal velocity
	if edge_detected and is_on_floor():
		# Slow down significantly near edges
		velocity.x = move_toward(velocity.x, 0, 300 * get_process_delta_time())
	
	# ADDITIONAL: Limit vertical velocity when chasing player to prevent extreme jumps/falls
	if target and is_active:
		var height_diff = global_position.y - target.global_position.y
		
		# Prevent excessive upward movement (floating too high above player)
		if velocity.y < 0 and height_diff < -vertical_movement_threshold:
			velocity.y = max(velocity.y, -50)  # Cap upward velocity
			
		# Always allow falling but not excessive jumping
		if velocity.y < -300:
			velocity.y = -300  # Cap jump velocity

func update_safe_position():
	# Only update safe position if we're on a platform and not in a pit
	if is_on_floor() and not is_in_deep_pit:
		# Get player to check vertical distance
		var player = get_tree().get_first_node_in_group("Player")
		if player and abs(global_position.y - player.global_position.y) < 100:
			# This is a good position - update last_safe_position
			last_safe_position = global_position

# Use _ prefix for unused delta parameter to tell the compiler it's intentionally not used
func _process(_delta):
	# Find and track the player as the target
	if target == null:
		target = get_tree().get_first_node_in_group("Player")
		if target:
			# print("NightBorne: Found player target at position " + str(target.global_position))
			pass
	
	# Debug output about current state
	if debug_mode and Engine.get_physics_frames() % 60 == 0:
		# print("NightBorne: Current state - position: " + str(global_position) + 
			  # ", velocity: " + str(velocity) + 
			  # ", on_floor: " + str(is_on_floor()) + 
			  # ", edge_detected: " + str(edge_detected))
		
		# Debug behavior tree state
		if has_node("BTPlayer"):
			var bt_player = $BTPlayer
			# print("NightBorne: BTPlayer status - " + 
				  # "has target: " + str(target != null) + 
				  # ", position: " + str(global_position))
			pass
	
	# Update animation based on movement and state
	if is_active:
		if animated_sprite.animation == "Attack" or animated_sprite.animation == "Hurt":
			# Don't interrupt attack or hurt animations
			pass
		elif velocity.length() > 10:
			animated_sprite.play("Run")
		else:
			animated_sprite.play("Idle")
	
	# Update sprite direction based on target or movement
	if target and is_active:
		var facing_left = animated_sprite.flip_h
		var should_face_left = global_position.x > target.global_position.x
		
		if facing_left != should_face_left:
			animated_sprite.flip_h = should_face_left
			
			# Update hitbox position if direction changed
			var hitbox = get_node_or_null("HitBox")
			if hitbox and hitbox.has_node("CollisionShape2D"):
				var hitbox_collision = hitbox.get_node("CollisionShape2D")
				hitbox_collision.position.x = -abs(hitbox_collision.position.x) if should_face_left else abs(hitbox_collision.position.x)

# Special function to enforce screen boundaries with guaranteed reliability
func enforce_screen_bounds():
	if !is_active:
		return
		
	# Get camera and viewport
	var viewport = get_viewport()
	if viewport:
		var camera = viewport.get_camera_2d()
		if camera:
			var screen_size = viewport.get_visible_rect().size
			var camera_pos = camera.global_position
			
			# Define screen boundaries with smaller margins
			var left_edge = camera_pos.x - (screen_size.x / 2) + 25
			var right_edge = camera_pos.x + (screen_size.x / 2) - 25
			var top_edge = camera_pos.y - (screen_size.y / 2) + 25
			var bottom_edge = camera_pos.y + (screen_size.y / 2) - 40
				
			# HORIZONTAL BOUNDARIES - Always apply these regardless of cooldown
			if global_position.x < left_edge:
				global_position.x = left_edge
				velocity.x = abs(velocity.x) * 0.5 + 70  # Stronger bounce right
			elif global_position.x > right_edge:
				global_position.x = right_edge
				velocity.x = -abs(velocity.x) * 0.5 - 70  # Stronger bounce left
				
			# VERTICAL BOUNDARIES - Only cap position, never apply upward force
			if global_position.y < top_edge:
				global_position.y = top_edge
				velocity.y = abs(velocity.y) * 0.5 + 20  # Bounce down
			elif global_position.y > bottom_edge:
				# Instead of applying upward force, just cap the position at the boundary
				global_position.y = bottom_edge
				velocity.y = 0  # Stop vertical movement
				# print("NightBorne: Hit bottom screen boundary, capping position")
				
				# Count frames stuck at the bottom
				stuck_at_bottom_counter += 1
				
				# If we're stuck at the bottom for too long, try to teleport to a valid position
				if stuck_at_bottom_counter > 30:  # Reduced from 60 to 30 frames (about 0.5 seconds)
					# print("NightBorne: Stuck at bottom for too long, attempting to teleport")
					teleport_to_safe_position()
					stuck_at_bottom_counter = 0  # Reset counter
			else:
				# Reset stuck counter if not at bottom
				stuck_at_bottom_counter = 0

# Add this function to apply damage scaling
func apply_damage_scaling(modifier: float) -> void:
	damage_modifier = modifier
	# print("NightBorne: Damage modifier set to ", damage_modifier)
	
	# Apply the damage modifier to the hitbox
	var hitbox = get_node_or_null("HitBox")
	if hitbox:
		hitbox.damage = attack_damage * damage_modifier
		# print("NightBorne: Hitbox damage updated to ", hitbox.damage)
	else:
		# print("NightBorne: WARNING - Could not find hitbox to update damage")
		pass
