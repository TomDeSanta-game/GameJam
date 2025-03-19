extends "res://Entities/Scripts/Enemies/EnemyBase/enemy_base.gd"

# Get access to the EnemyBase class
class_name NightBorneEnemy

@onready var animated_sprite = $AnimatedSprite2D

# Attack properties
var attack_damage = 40.0
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
		print("NightBorne: Removed behavior tree in favor of direct control")
	
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
		
		print("NightBorne: Initialized hitbox with collision_layer=16, collision_mask=8, no_flip=true")
		
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
			
		print("NightBorne: Initialized hurtbox with collision_layer=4, collision_mask=2")
		
	# Initialize attack state
	can_attack = true
	last_attack_time = 0.0
	
	# Enable debug mode
	debug_mode = true
	
	# Force to ground on startup
	if force_to_ground:
		# Apply initial gravity to ensure the enemy is on the ground
		velocity.y = 100
		
	# Perform initial ground check
	call_deferred("initial_ground_check")
	
	# Force attack cooldown reset to ensure we can attack immediately
	call_deferred("reset_attack_cooldown")
	
	# Print initial stats for debugging
	print("NightBorne: Initialized with health=", current_health, ", damage=", attack_damage, ", can_attack=", can_attack)
	
	# Create debug label if debug_mode is on
	if debug_mode:
		debug_label = Label.new()
		debug_label.position = Vector2(-50, -70)
		debug_label.z_index = 100
		debug_label.add_theme_color_override("font_color", Color(0, 1, 0))
		add_child(debug_label)

# Fix spawn position to ensure the NightBorne doesn't spawn under platforms
func fix_spawn_position():
	print("NightBorne: Fixing spawn position. Original position:", global_position)
	
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
		print("NightBorne: Detected platform above at y=", result.position.y)
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
				print("NightBorne: Found floor based on player position at y=", floor_y)
		
		if not found_floor:
			# Try a fixed position - the main level floor is typically around y=270-280
			floor_y = 272.9  # Common floor y-position in the level
			print("NightBorne: Using default floor position y=", floor_y)
		
		# Adjust our position to be on the floor
		global_position.y = floor_y
		print("NightBorne: Corrected position to:", global_position)
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
			print("NightBorne: Found floor below, adjusted position to:", global_position)
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
					print("NightBorne: Adjusted to player's floor level, position:", global_position)
				else:
					# Last resort - use the common floor position
					global_position.y = 272.9
					print("NightBorne: Used default floor position as fallback:", global_position)

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
		print("NightBorne: Final ground adjustment, position:", global_position)

# Perform an initial ground check after a short delay to let physics settle
func initial_ground_check():
	await get_tree().create_timer(0.2).timeout
	# Force a thorough ground check
	check_ground_position(true)
	print("NightBorne: Initial ground check complete at position " + str(global_position))

func _physics_process(delta):
	# Apply enhanced gravity if enabled - FIXED to prevent floating
	if gravity_enabled:
		if !is_on_floor():
			# Apply stronger base gravity to prevent floating
			var gravity_strength = 1200  # Increased base gravity (was 980)
			
			# Additional gravity when above the player to prevent floating
			if target and global_position.y < target.global_position.y - 30:
				gravity_strength += 500  # Extra gravity when above player
				if debug_mode and Engine.get_physics_frames() % 30 == 0:
					print("NightBorne: Applying extra gravity to prevent floating above player")
			
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
					print("NightBorne: Force downward movement to prevent floating")
		else:
			# On floor - reset counters and timers
			collision_retry_attempts = 0
			float_prevention_timer = 0.0
	
	# Update standing timer
	if is_active and velocity.length() < 5.0:
		standing_timer += delta
	else:
		standing_timer = 0.0
		
	# If stuck for too long (2 seconds), force movement
	if standing_timer > 2.0 and target != null:
		print("NightBorne: Stuck for too long, forcing movement")
		var force_direction = global_position.direction_to(target.global_position)
		velocity.x = force_direction.x * max_speed * 1.5
		standing_timer = 0.0  # Reset timer
	
	# CRITICAL: Update safe position if currently in a valid location - lower frequency
	if Engine.get_physics_frames() % 10 == 0:  # Only update every 10 frames
		update_safe_position()
		check_ground_position()
		
	# If we've failed many ground checks, try to teleport
	if ground_check_failed_count > 20:
		print("NightBorne: Failed too many ground checks, attempting to teleport")
		teleport_to_safe_position()
		ground_check_failed_count = 0
		
	# If we've been stuck at an edge for too long, teleport
	if edge_detected and stuck_edge_counter > 40:  # About 2/3 of a second at 60 FPS
		print("NightBorne: Stuck at edge for too long, attempting to teleport")
		teleport_to_safe_position()
		stuck_edge_counter = 0
	
	# Find player if we don't have a target
	if target == null:
		target = get_tree().get_first_node_in_group("Player")
		if target and debug_mode:
			print("NightBorne: Found player at position " + str(target.global_position))
	
	# Skip physics process if we have no target
	if target == null or !is_active:
		return
	
	# Emergency attack reset - if it's been more than 3 seconds since attack was called
	# and we still can't attack, force reset it
	if !can_attack and (Time.get_ticks_msec() - last_attack_time) > 3000:
		print("NightBorne: Emergency reset of attack cooldown - was stuck")
		can_attack = true
		# Cancel any lingering timers
		if attack_timer != null and attack_timer.time_left > 0:
			attack_timer.timeout.disconnect(func(): can_attack = true; print("NightBorne: Attack cooldown finished, can attack again"))
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
	
	# Debug output every 30 frames
	if debug_mode and Engine.get_physics_frames() % 30 == 0:
		print("NightBorne: Distance to player: " + str(distance) + 
			  ", direction: " + str(direction) + 
			  ", position: " + str(global_position) +
			  ", can_attack: " + str(can_attack) +
			  ", is_on_floor: " + str(is_on_floor()))
	
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
			print("NightBorne: Attacking player at distance " + str(distance))
		else:
			if debug_mode and Engine.get_physics_frames() % 30 == 0:
				print("NightBorne: In range but can't attack - cooldown active")
	# Otherwise, move toward the player if we don't detect an edge
	elif not edge_detected:
		# Reset edge counter when not at an edge
		stuck_edge_counter = 0
		
		# Calculate horizontal movement only
		var target_speed = direction.x * max_speed
		
		# Boost speed if far from player
		if distance > 150:
			target_speed *= 1.5
			print("NightBorne: Boosting speed to catch up to player")
		
		velocity.x = move_toward(velocity.x, target_speed, acceleration * delta)
		
		if debug_mode and Engine.get_physics_frames() % 30 == 0:
			print("NightBorne: Moving toward player, velocity: " + str(velocity))
	else:
		# We detected an edge - increment the stuck counter
		stuck_edge_counter += 1
		
		# Modified to prevent unwanted following down platforms - NEW
		if target.global_position.y > global_position.y + 30:
			# Only attempt to follow down if the player is not too far down
			# AND if we're actually at an edge (not just floating)
			if target.global_position.y - global_position.y < 150 and is_on_floor():
				print("NightBorne: Attempting to follow player down to platform")
				velocity.x = direction.x * 60 # Move slowly toward player
				velocity.y = 50 # Add slight downward force
			else:
				# If the player is too far down, stop and consider teleporting
				velocity.x = move_toward(velocity.x, 0, acceleration * delta)
				print("NightBorne: Player too far below, stopping at edge")
		else:
			# Player is at our level or above - slow down
			velocity.x = move_toward(velocity.x, 0, acceleration * delta)
			if debug_mode and Engine.get_physics_frames() % 30 == 0:
				print("NightBorne: Edge detected, stopping")
		
		# If stuck at an edge for some time but not too long yet, try small jump
		if stuck_edge_counter > 20 and stuck_edge_counter < 40 and is_on_floor():
			print("NightBorne: Stuck at edge, attempting small jump")
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
		print("NightBorne: Just landed on floor")
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
	# Distance threshold to detect if we're stuck
	var distance_threshold = 2.0
	var position_changed = global_position.distance_to(pre_move_position) > distance_threshold
	
	# Check if we're stuck against a wall or in a corner
	if (is_on_wall() or collision_retry_attempts > 0) and abs(velocity.x) > 10.0 and !position_changed:
		collision_retry_attempts += 1
		
		# Record collision position if this is a new collision
		if collision_retry_attempts == 1:
			last_collision_position = global_position
		
		# If we've been stuck for several frames, try to resolve
		if collision_retry_attempts > 5:
			print("NightBorne: Detected collision issue - attempting to resolve")
			
			# If we're stuck at wall, first try a jump
			if is_on_floor() and collision_retry_attempts < 10:
				print("NightBorne: Attempting to jump over obstacle")
				velocity.y = -350  # Strong jump
				
				# Also reverse horizontal direction slightly
				velocity.x = -velocity.x * 0.5
			
			# If still stuck after several attempts, try teleporting
			if collision_retry_attempts > 15:
				print("NightBorne: Multiple collision resolution attempts failed, teleporting")
				teleport_to_safe_position()
				collision_retry_attempts = 0
		
		# If we're stuck in a corner or against a wall but NOT on floor, apply stronger upward force
		if !is_on_floor() and collision_retry_attempts > 3:
			if get_real_velocity().y > 0:  # Only if we're falling
				velocity.y = -500  # Strong upward boost to escape
				print("NightBorne: Applying upward boost to escape collision")
	else:
		# Reset collision attempts if we're moving normally
		if position_changed and collision_retry_attempts > 0:
			collision_retry_attempts = 0
			
	# Additional check for getting trapped in geometry - if we're in the same position for too long
	if global_position.distance_to(last_collision_position) < 5.0 and collision_retry_attempts > 20:
		print("NightBorne: Detected potential geometry trap, teleporting")
		teleport_to_safe_position()
		collision_retry_attempts = 0

# Improved check for ground beneath the NightBorne
func check_ground_position(force_check = false):
	if is_on_floor():
		# We're on solid ground - update the ground position
		ground_y_position = global_position.y
		is_in_deep_pit = false
		ground_check_failed_count = 0
		if debug_mode and force_check:
			print("NightBorne: On floor at position y=" + str(ground_y_position))
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
					print("NightBorne: Ground detected at y=" + str(best_ground_y) + " with offset " + str(offset))
	
	if found_ground:
		# Found ground - remember its position
		ground_y_position = best_ground_y
		ground_check_failed_count = 0
	else:
		# No ground found below - we might be over a pit
		is_in_deep_pit = true
		ground_check_failed_count += 1
		
		if debug_mode and (force_check or ground_check_failed_count > 3):
			print("NightBorne: No ground detected below enemy after " + str(ground_check_failed_count) + " attempts")

# Enhanced edge detection with improved accuracy and vertical awareness
func detect_edges():
	# If we're not on the floor, we can't detect edges reliably
	if not is_on_floor() and ground_check_failed_count < 5:
		edge_detected = false
		return
	
	# Only check for edges every 0.1 seconds for better performance
	if platform_check_timer > 0:
		return
	
	platform_check_timer = 0.1  # Reduced from 0.2 to 0.1 for more frequent checks
		
	# Get movement direction
	var direction = Vector2.ZERO
	if target:
		direction = global_position.direction_to(target.global_position)
	else:
		edge_detected = false
		return
	
	# Check if there's an edge ahead, but only if we're moving in that direction
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
	
	# Use multiple raycasts at different distances for more reliable edge detection
	var space_state = get_world_2d().direct_space_state
	var edge_checks = []
	
	# Cast 4 rays at increasing distances
	for distance in [15, 30, 45, 60]:
		var ray_start = global_position + Vector2(sign(direction.x) * distance, 0)
		var ray_end = ray_start + Vector2(0, 70)
		
		var query = PhysicsRayQueryParameters2D.create(ray_start, ray_end)
		query.exclude = [self]
		query.collision_mask = 1
		
		var result = space_state.intersect_ray(query)
		edge_checks.append(result)
	
	# Check if player is below us on a platform
	if player_is_on_platform and target.global_position.y > global_position.y + 20:
		# Player is below us - check if we can safely follow
		var platform_diff = player_platform_y - global_position.y
		
		if platform_diff > 0 and platform_diff < 100:
			# Platform is not too far down, set edge_detected to false to follow
			edge_detected = false
			return
	
	# Determine edge detection based on multiple rays
	if edge_checks[0] and edge_checks[1] and edge_checks[2] and edge_checks[3]:
		# All rays hit, check for steep slopes
		var height_diff = abs(edge_checks[0].position.y - edge_checks[3].position.y)
		if height_diff > 30:
			# This is a steep slope, treat it as an edge
			edge_detected = true
			print("NightBorne: Detected steep slope ahead")
		else:
			edge_detected = false
	elif edge_checks[0] and !edge_checks[1]:
		# Close ray hit but next one didn't - short edge
		edge_detected = true
		print("NightBorne: Short edge detected ahead")
	elif !edge_checks[0]:
		# First ray didn't hit - immediate edge
		edge_detected = true
		print("NightBorne: Immediate edge detected")
	elif !edge_checks[3]:
		# Far ray didn't hit - approaching drop-off
		edge_detected = true
		print("NightBorne: Approaching drop-off")
	else:
		edge_detected = false
		
	# Additional check for floating state - not a true edge if we're not on floor
	if edge_detected and !is_on_floor() and ground_check_failed_count < 3:
		# This is likely a false edge detection while floating
		edge_detected = false
		if debug_mode:
			print("NightBorne: Ignoring edge detection while not on floor")

# Improved teleport function with more reliable positioning
func teleport_to_safe_position():
	# Try to find the player first
	var player = get_tree().get_first_node_in_group("Player")
	if player:
		# Get a position on the same level as the player but at a safe distance
		var player_pos = player.global_position
		var direction = -1 if randf() < 0.5 else 1  # Random direction
		var distance = randf_range(250, 400)  # More variable distance
		var new_pos = Vector2(player_pos.x + direction * distance, player_pos.y - 20)
		
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
		query.collision_mask = 1
		
		var result = space_state.intersect_ray(query)
		if result:
			floor_found = true
			target_y = result.position.y - 20  # Position above floor
			print("NightBorne: Found player's floor at y=", result.position.y)
		
		# Now check multiple positions around our teleport destination
		var best_floor_y = 0
		var best_floor_found = false
		
		for x_offset in [-50, -25, 0, 25, 50]:
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
			print("NightBorne: Teleported to best floor position: ", global_position)
		elif floor_found:
			# No floor at teleport point, try player's x position instead
			ray_start = Vector2(player_pos.x + (direction * 100), target_y - 100)
			ray_end = Vector2(player_pos.x + (direction * 100), target_y + 150)
			
			query = PhysicsRayQueryParameters2D.create(ray_start, ray_end)
			query.exclude = [self, player]
			query.collision_mask = 1
			
			result = space_state.intersect_ray(query)
			if result:
				global_position = Vector2(player_pos.x + (direction * 100), result.position.y - 20)
				print("NightBorne: Teleported near player: ", global_position)
			else:
				# No ground found at all - use player's exact level
				global_position = Vector2(player_pos.x + (direction * 100), target_y)
				print("NightBorne: Teleported to player level (fallback): ", global_position)
		else:
			# Complete fallback - use hard-coded floor position
			global_position = Vector2(new_pos.x, 272.9)
			print("NightBorne: Teleported to default floor level: ", global_position)
		
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
			hitbox.damage = attack_damage  # Make sure damage is set
			hitbox.activate()
			print("NightBorne: Activated hitbox with damage value: ", attack_damage)
		else:
			print("NightBorne: WARNING - Missing HitBox node!")
		
		# Deal damage to target directly (as backup method)
		if target and target.has_method("take_damage"):
			# Calculate direction for knockback
			var knockback_direction = target.global_position - global_position
			knockback_direction = knockback_direction.normalized()
			
			# Apply damage and knockback directly with no_flip flag
			print("NightBorne: Attempting to damage player directly with damage: ", attack_damage)
			
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
				print("NightBorne: Used take_damage_with_info to prevent flipping")
			elif target.has_method("take_damage_no_flip"):
				# Fallback to specialized no-flip method
				target.call("take_damage_no_flip", attack_damage, knockback_direction * attack_knockback)
				print("NightBorne: Used take_damage_no_flip method")
			else:
				# Last resort: standard damage method (may cause flipping)
				target.call("take_damage", attack_damage, knockback_direction * attack_knockback)
				print("NightBorne: Used standard take_damage method - might cause flipping")
		else:
			print("NightBorne: Target is null or missing take_damage method")

# Handle taking damage with improved knockback handling
func take_damage(damage_amount: float, knockback_force: Vector2 = Vector2.ZERO) -> void:
	if not is_active:
		return
	
	# Apply damage to self first
	current_health -= damage_amount
	print("NightBorne: Took damage: ", damage_amount, " Health: ", current_health, " From direction: ", knockback_force.normalized())
	
	# ENHANCED KNOCKBACK FIX: Check if player has Growth Burst active and reduce knockback even more
	var player = get_tree().get_first_node_in_group("Player")
	if player and player.has_node("GrowthSystem"):
		var growth_system = player.get_node("GrowthSystem")
		if growth_system and "effects" in growth_system and "Growth Burst" in growth_system.effects:
			# Apply EXTREME knockback resistance against Growth Burst
			knockback_force *= 0.2  # Further reduce knockback by 80%
			print("NightBorne: Detected Growth Burst effect, applying extreme knockback reduction")
		
		# Also check player's growth level and apply additional resistance
		if growth_system and "growth_level" in growth_system and growth_system.growth_level > 3:
			# Apply more aggressive reduction for large players
			var reduction_factor = min(0.8, (growth_system.growth_level * 0.08))  # 8% per level, max 80%
			knockback_force *= (1.0 - reduction_factor)
			print("NightBorne: Detected large player size: ", growth_system.growth_level, ", applying extra knockback resistance: ", reduction_factor * 100, "%")
	
	# Apply hard limit to knockback force magnitude - reduced from 400
	if knockback_force.length() > 400:
		knockback_force = knockback_force.normalized() * 400
		print("NightBorne: Capped excessive knockback at 400")
	
	# REMOVED: No longer convert downward knockback to upward
	# Just apply reduced knockback
	knockback_force *= (1.0 - knockback_resistance)
	
	# Apply knockback (horizontal only)
	velocity.x += knockback_force.x
	# Do not apply vertical knockback component at all
	
	# Check if we're in the middle of an attack animation
	var cannot_cancel_attack = true
	if animated_sprite.animation == "Attack" and cannot_cancel_attack:
		# Don't play hurt animation during attack, just flash
		apply_damage_flash()
	else:
		# Play hurt animation
		animated_sprite.play("Hurt")
	
	# Check if dead after damage is applied
	if current_health <= 0:
		die()
		return
		
	# Call parent method to handle damage logic
	super.take_damage(damage_amount, knockback_force)

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
		print("NightBorne: Attack animation finished, starting cooldown")
		
		# Use a shorter cooldown for more frequent attacks
		attack_cooldown = 0.7  # Reduced from 1.0 to 0.7 for more frequent attacks
		
		# Deactivate hitbox after attack animation ends
		var hitbox = get_node_or_null("HitBox")
		if hitbox:
			hitbox.deactivate()
		
		# Explicitly create timer for better reliability
		if attack_timer != null and attack_timer.time_left > 0:
			attack_timer.timeout.disconnect(func(): can_attack = true; print("NightBorne: Attack cooldown finished, can attack again"))
		
		attack_timer = get_tree().create_timer(attack_cooldown)
		print("NightBorne: Created attack cooldown timer for " + str(attack_cooldown) + " seconds")
		attack_timer.timeout.connect(func(): 
			can_attack = true
			print("NightBorne: Attack cooldown finished, can attack again"))
		
		# CRITICAL FIX: Explicitly switch to a different animation after attack finishes
		if is_active:
			# Choose animation based on movement
			if velocity.length() > 10:
				animated_sprite.play("Run")
				print("NightBorne: Switching to Run animation after attack")
			else:
				animated_sprite.play("Idle")
				print("NightBorne: Switching to Idle animation after attack")
			
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
		print("NightBorne: Move called with direction " + str(dir) + " and speed " + str(speed))
	
	# If we detected an edge and trying to move towards it, be more careful
	if edge_detected and sign(dir.x) == sign(velocity.x):
		# Still move toward target, but at reduced speed near edges
		velocity.x = move_toward(velocity.x, dir.x * speed * 0.3, 200 * get_process_delta_time())
		if debug_mode:
			print("NightBorne: Edge detected, moving with caution")
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
				print("NightBorne: Target far away, increasing speed to " + str(movement_speed))
	
	# Normal movement with enhanced acceleration - only horizontal movement
	var target_velocity = Vector2(dir.x * movement_speed, velocity.y)
	velocity = velocity.move_toward(target_velocity, acceleration * get_process_delta_time())
	
	# Print debug info periodically
	if debug_mode and Engine.get_physics_frames() % 30 == 0:
		print("NightBorne: velocity = " + str(velocity) + ", position = " + str(global_position))

# Force reset attack cooldown for testing
func reset_attack_cooldown():
	can_attack = true
	if attack_timer != null and attack_timer.time_left > 0:
		attack_timer.timeout.disconnect(func(): can_attack = true; print("NightBorne: Attack cooldown finished, can attack again"))
		attack_timer = null
	print("NightBorne: Attack cooldown forcibly reset")

# Force take damage (for debugging)
func force_damage_test(amount: float = 10.0):
	var knockback = Vector2(300, -100) if global_position.x < 300 else Vector2(-300, -100)
	print("NightBorne: Taking test damage: ", amount)
	take_damage(amount, knockback)
	return current_health

# Test damage functionality with input
func _input(event):
	if event is InputEventKey and event.pressed:
		if event.keycode == KEY_T:
			print("NightBorne: TEST - Taking damage via key press")
			force_damage_test(20.0)

# Handle hurtbox collisions
func _on_hurtbox_area_entered(area):
	print("NightBorne Hurtbox: Detected collision with ", area.name)
	
	# Check if it's a player hitbox
	if area.has_method("activate") and "is_player_hitbox" in area and area.is_player_hitbox:
		print("NightBorne Hurtbox: Hit by player hitbox with active=", area.active, ", damage=", area.damage)
		
	# Manually print out collision layers and masks to verify
	print("NightBorne Hurtbox: My collision_layer=", $HurtBox.collision_layer, ", collision_mask=", $HurtBox.collision_mask)
	if area.has_method("activate"):
		print("NightBorne Hurtbox: Hitbox collision_layer=", area.collision_layer, ", collision_mask=", area.collision_mask)

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
			print("NightBorne: Found player target at position " + str(target.global_position))
	
	# Debug output about current state
	if debug_mode and Engine.get_physics_frames() % 60 == 0:
		print("NightBorne: Current state - position: " + str(global_position) + 
			  ", velocity: " + str(velocity) + 
			  ", on_floor: " + str(is_on_floor()) + 
			  ", edge_detected: " + str(edge_detected))
		
		# Debug behavior tree state
		if has_node("BTPlayer"):
			var bt_player = $BTPlayer
			print("NightBorne: BTPlayer status - " + 
				  "has target: " + str(target != null) + 
				  ", position: " + str(global_position))
	
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
				print("NightBorne: Hit bottom screen boundary, capping position")
				
				# Count frames stuck at the bottom
				stuck_at_bottom_counter += 1
				
				# If we're stuck at the bottom for too long, try to teleport to a valid position
				if stuck_at_bottom_counter > 30:  # Reduced from 60 to 30 frames (about 0.5 seconds)
					print("NightBorne: Stuck at bottom for too long, attempting to teleport")
					teleport_to_safe_position()
					stuck_at_bottom_counter = 0  # Reset counter
			else:
				# Reset stuck counter if not at bottom
				stuck_at_bottom_counter = 0
