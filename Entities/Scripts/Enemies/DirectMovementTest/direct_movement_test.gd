extends Node

# This is a simple test script to add to the NightBorne enemy
# It will directly move the enemy towards the player, bypassing the behavior tree
# and any method calls that might not be working

@export var enabled: bool = true
@export var move_speed: float = 80.0
@export var debug: bool = true  # Always enable debug for better tracking
@export var acceleration: float = 300.0
@export var gravity_strength: float = 980.0  # Default gravity (pixels/sec²)
@export var is_affected_by_gravity: bool = false  # COMPLETELY DISABLE GRAVITY
@export var attack_range: float = 50.0  # Range at which enemy stops to attack
@export var attack_cooldown: float = 1.5  # Time between attacks in seconds

# Attack animation frame control
@export var hitbox_active_frame_start: int = 8  # Activate hitbox on frame 8 (counting from 1)
@export var hitbox_active_frame_end: int = 9    # Deactivate after frame 9 (counting from 1)

# Health and damage settings
@export var max_health: float = 40.0  # DECREASED from 100.0 to make enemies more dangerous in ambush scenarios
@export var current_health: float = 40.0  # DECREASED to match max_health
@export var damage: float = 20.0  # Damage to deal with attacks
@export var knockback_resistance: float = 0.5  # Default knockback resistance

# Damage effect settings
@export var damage_flash_duration: float = 0.15  # How long the damage flash lasts
@export var damage_flash_intensity: float = 0.8  # How intense the red flash is (0-1)
@export var invincibility_time: float = 0.5     # SHORTER invincibility after taking damage (was 0.3)

# Jump parameters
@export var can_jump: bool = false              # Whether this enemy can jump to navigate (disabled by default)
@export var jump_strength: float = 300.0       # Jump force
@export var coyote_time: float = 0.15          # Time in seconds enemy can jump after leaving ledge
@export var jump_buffer_time: float = 0.15     # Time in seconds to buffer a jump input

var target_player = null
var frame_counter = 0
var can_attack = true
var attack_timer = 0.0
var current_attack_frame = 0     # Track the current frame of the attack animation
var is_attacking = false         # Flag to track if we're in attack state

# Jump variables
var was_on_floor: bool = false        # Was the enemy on floor last frame
var coyote_timer: float = 0.0         # Timer for coyote time
var jump_buffer_timer: float = 0.0    # Timer for jump buffer
var want_to_jump: bool = false        # Enemy AI wants to jump

# Damage effect variables
var invincibility_timer: float = 0.0  # Timer for tracking invincibility duration
var is_invincible: bool = false      # Whether currently invincible
var is_flashing: bool = false         # Currently showing damage flash
var flash_timer: float = 0.0          # Timer for damage flash
var damage_shader: ShaderMaterial = null # Shader material for damage effect
var cannot_cancel_attack: bool = true  # NEW: Prevent attack animation from being canceled

var enemy_animated_sprite = null
var orig_modulate = Color(1, 1, 1, 1)
var hurtbox = null

# Define class variables to track velocity and friction for screen boundary checks
var velocity: Vector2 = Vector2.ZERO
var friction: float = 600.0  # Default friction value

# Basic screen boundary settings
var screen_margin = 50  # Screen edge margin
var recovery_active = false  # Whether recovery is active
var recovery_cooldown = 0.0  # Cooldown for recovery actions

# Add a property to track if we're seriously below screen
var is_seriously_below_screen = false

# Add property to track last safe position
var last_safe_position = Vector2.ZERO

# Add property to track teleportation cooldown
var teleport_cooldown = 0.0

# Add property to track continuous falling frames
var falling_frames = 0

# Add variables for platform anchoring system
var is_anchored_to_platform = false
var current_platform = null
var platform_check_cooldown = 0.0
var edge_detected = false
var allow_y_movement = false
var max_edge_detection_distance = 60.0  # Maximum distance to check for edges
var current_platform_width = 0.0  # Width of current platform
var last_ground_position = Vector2.ZERO  # Last known position that had ground below

# Add variables for the aggressive platform locking system
var strict_platform_lock = true  # Always true - enforce staying on platforms with extreme measures
var was_falling = false  # Track if the enemy was falling in the previous frame
var frames_falling = 0  # Count consecutive frames of falling
var max_falling_frames = 5  # Maximum allowed falling frames before teleporting (extremely aggressive)
var ground_check_timer = 0.0  # Timer for ground checks
var ground_check_interval = 0.05  # Check for ground every 0.05 seconds (20 times per second)
var last_safe_y_position = 0.0  # Last known safe Y position

# Add variable to track if the enemy has touched the floor since spawning
var has_touched_floor_since_spawn: bool = false
var consecutive_floor_frames: int = 0  # Count how many consecutive frames we're on a floor
var required_floor_frames: int = 3     # Require multiple frames on floor before disabling gravity

var fixed_y_position: float = 250.0  # FIXED Y POSITION - ABSOLUTE POSITION LOCK
var allowed_y_variation: float = 5.0  # How much variation in Y to allow (very little)

func _ready():
	if not enabled:
		set_process(false)
		return
	
	# Initialize health
	current_health = max_health
	
	# Initialize invincibility timer to 0
	invincibility_timer = 0.0
	is_invincible = false
	
	# Set up damage shader
	damage_shader = ShaderMaterial.new()
	damage_shader.shader = load("res://Shaders/Enemies/enemy_damage.gdshader")
	damage_shader.set_shader_parameter("flash_intensity", 0.0)
	
	# Add tracking for falling frames
	falling_frames = 0
	
	# FORCE debug to true for reliability
	debug = true
	
	# COMPLETELY DISABLE GRAVITY - CRITICAL FIX
	is_affected_by_gravity = false
	
	# Set up hurtbox connection to damage function
	var parent = get_parent()
	if parent:
		# Store the spawn Y position for absolute Y locking
		fixed_y_position = parent.global_position.y
		print("ABSOLUTE Y-LOCK: Initial position set to Y=", fixed_y_position)
		
		# CRITICAL: Force the parent to have zero Y velocity 
		parent.velocity.y = 0
		
		# Store initial position as last safe ground position
		last_ground_position = parent.global_position
		last_safe_y_position = parent.global_position.y
		
		# We start with gravity enabled so we land correctly
		
		hurtbox = parent.get_node_or_null("HurtBox")
		if hurtbox:
			# Enable debug mode on hurtbox if debug is enabled
			if debug and "debug" in hurtbox:
				hurtbox.debug = true
				print("DEBUG: Enabled debug on hurtbox")
			
			# Make sure HurtBox has proper collision settings
			hurtbox.collision_layer = 4  # Layer 4 for enemy hurtboxes
			hurtbox.collision_mask = 2   # Mask 2 to detect player hitboxes
			
			# Make sure monitoring is enabled
			hurtbox.monitoring = true
			hurtbox.monitorable = true
			
			# Fix for disabled collision shape
			var hurtbox_collision = hurtbox.get_node_or_null("CollisionShape2D")
			if hurtbox_collision and hurtbox_collision.disabled:
				hurtbox_collision.disabled = false
				if debug:
					# Keep CRITICAL print but make conditional
					print("CRITICAL FIX: Enabled disabled hurtbox collision")
			
			# Make sure the hurtbox is registered with the entity
			hurtbox.set_meta("entity", self)
		
		# Setup hitbox as well
		var hitbox = parent.get_node_or_null("HitBox")
		if hitbox:
			# Enable debug mode on hitbox if debug is enabled
			if debug and "debug" in hitbox:
				hitbox.debug = true
				print("DEBUG: Enabled debug on hitbox")
				
			# Set proper collision settings
			hitbox.collision_layer = 16  # Layer 16 for enemy hitboxes
			hitbox.collision_mask = 8    # Mask 8 to detect player hurtboxes
			
			# Set damage value
			hitbox.damage = damage
			
			# Register entity to prevent self-damage
			hitbox.set_meta("entity", self)
			
	# Print debug info for collision layer setup
	if debug:
		print("DEBUG: DirectMovementTest initialized")
		print("DEBUG: damage = ", damage)
		print("DEBUG: attack_range = ", attack_range)
		print("DEBUG: max_health = ", max_health)
		if hurtbox:
			print("DEBUG: hurtbox.collision_layer = ", hurtbox.collision_layer)
			print("DEBUG: hurtbox.collision_mask = ", hurtbox.collision_mask)
	
	# Give time for the scene to initialize
	await get_tree().create_timer(0.5).timeout
	find_player()

func find_player():
	var players = get_tree().get_nodes_in_group("Player")
	if not players.is_empty():
		target_player = players[0]
	else:
		# No player found logic
		pass

func _process(delta):
	if debug:
		update_debug_status()
	
	# Increment frame counter for periodic debug messages
	frame_counter = (frame_counter + 1) % 60
	
	# Handle damage flash effect
	if is_flashing:
		flash_timer -= delta
		if flash_timer <= 0:
			is_flashing = false
			
			# Reset shader
			var enemy_parent = get_parent()
			var enemy_sprite = enemy_parent.get_node_or_null("AnimatedSprite2D")
			if enemy_sprite:
				# Important: Remove the shader when flash effect is over
				enemy_sprite.material = null
				damage_shader.set_shader_parameter("flash_intensity", 0.0)
				
			if debug and frame_counter % 10 == 0:
				print("Damage flash ended")
	
	# Handle invincibility timer
	if is_invincible:
		# Print invincibility timer every 10 frames when it's active
		if debug and frame_counter % 10 == 0:
			print("Invincibility timer: ", invincibility_timer, " seconds remaining")
		
		invincibility_timer -= delta
		if invincibility_timer <= 0:
			end_invincibility()
	
	# Handle attack cooldown
	if not can_attack:
		attack_timer -= delta
		if attack_timer <= 0:
			can_attack = true
			if debug and frame_counter == 0:
				print("Attack cooldown finished, can attack again")
	
	if not enabled or not target_player:
		if not target_player and frame_counter == 0:  # Try to find player every 60 frames
			find_player()
		return
	
	var parent = get_parent()
	if not (parent is CharacterBody2D):
		return
	
	# IMPORTANT: Periodically check if hurtbox is enabled (as a safety measure)
	# This ensures the enemy can always be hit even if something goes wrong
	if frame_counter == 0 and !is_attacking:  # Check every 60 frames
		var enemy_hurtbox = parent.get_node_or_null("HurtBox")
		if enemy_hurtbox and enemy_hurtbox.has_node("CollisionShape2D"):
			var enemy_hurtbox_collision = enemy_hurtbox.get_node("CollisionShape2D")
			if enemy_hurtbox_collision.disabled:
				enemy_hurtbox_collision.set_deferred("disabled", false)
				if debug:
					print("CRITICAL FIX: Re-enabled incorrectly disabled hurtbox")
	
	# Track attack animation frames for precise hitbox timing
	if is_attacking:
		var current_animated_sprite = parent.get_node_or_null("AnimatedSprite2D")
		if current_animated_sprite and current_animated_sprite.animation == "Attack":
			# Get the current frame of the attack animation
			var new_frame = current_animated_sprite.frame
			
			# If the frame changed, update our tracking
			if new_frame != current_attack_frame:
				current_attack_frame = new_frame
				if debug:
					print("Attack animation frame changed to: ", current_attack_frame)
				
				# Activate hitbox only on specific frames
				var hitbox = parent.get_node_or_null("HitBox")
				if hitbox:
					var frame_one_indexed = current_attack_frame + 1
					
					# Activate on start frame
					if frame_one_indexed == hitbox_active_frame_start and not hitbox.active:
						var collision_shape = hitbox.get_node_or_null("CollisionShape2D")
						if collision_shape:
							collision_shape.disabled = false
						
							# Do NOT disable hurtbox - use metadata instead
							hitbox.set_meta("owner_entity", self)
						
						if hitbox.has_method("activate"):
							hitbox.activate()
						else:
							# Fallback if activate method doesn't exist - enable collision directly
							var collision = hitbox.get_node_or_null("CollisionShape2D")
							if collision:
								collision.disabled = false
						
						if debug:
							print("Activating hitbox on frame: ", frame_one_indexed)
					
					# Deactivate after end frame
					elif frame_one_indexed > hitbox_active_frame_end and hitbox.active:
						var collision_shape = hitbox.get_node_or_null("CollisionShape2D")
						if collision_shape:
							collision_shape.disabled = true
						
						# Make sure the hitbox is properly deactivated
						if hitbox.has_method("deactivate"):
							# Check if active property exists and is true, or just call deactivate to be safe
							if "active" in hitbox and hitbox.active:
								hitbox.call_deferred("deactivate")
							elif not "active" in hitbox:  # Fallback if property doesn't exist
								hitbox.call_deferred("deactivate")
					
						if debug:
							print("Deactivating hitbox after frame: ", frame_one_indexed)
			
			# Check if animation is done
			if current_animated_sprite.frame >= current_animated_sprite.sprite_frames.get_frame_count("Attack") - 1 and !current_animated_sprite.is_playing():
				if debug:
					print("Attack animation completed, ending attack state")
				end_attack(parent)
			# Also check if animation changed unexpectedly
			elif current_animated_sprite.animation != "Attack":
				if debug:
					print("Attack animation changed unexpectedly to: ", current_animated_sprite.animation)
				end_attack(parent)
		else:
			# If we're in attack state but animation is not Attack, end the attack
			if debug:
				print("In attack state but not playing Attack animation - ending attack")
			end_attack(parent)
	
	# Apply gravity first
	if is_affected_by_gravity:
		parent.velocity.y += gravity_strength * delta
	
	# Calculate safer direction to player that prioritizes horizontal movement
	var direction = Vector2.ZERO
	var distance = 999999  # Default to large value
	
	if target_player != null:
		var raw_direction = parent.global_position.direction_to(target_player.global_position)
		distance = parent.global_position.distance_to(target_player.global_position)
		
		# Get direct horizontal and vertical components
		var horiz_dir = raw_direction.x
		var vert_dir = raw_direction.y
		
		# ENHANCED EDGE DETECTION: Perform a comprehensive edge check BEFORE calculating direction
		var should_stop_at_edge = false
		var should_back_up = false
		
		if parent.is_on_floor():
			# Cast THREE rays to detect edges more accurately
			var space_state = parent.get_world_2d().direct_space_state
			
			# Try to detect edges ahead of movement direction
			var ray_distance = 40  # More conservative (reduced from 50)
			var ray_positions = [
				Vector2(horiz_dir * ray_distance, -5),    # Far ahead
				Vector2(horiz_dir * (ray_distance * 0.7), -5),  # Closer ahead
				Vector2(horiz_dir * (ray_distance * 0.4), -5)   # Very close
			]
			
			var found_edge = false
			var edge_detected_at = -1 # Track which check found the edge
			
			# Check all three positions for edge detection
			for i in range(ray_positions.size()):
				var ray_pos = ray_positions[i]
				var ray_start = parent.global_position + ray_pos
				var ray_end = ray_start + Vector2(0, 60)  # Check 60 pixels down (increased from 30)
				
				var query = PhysicsRayQueryParameters2D.create(ray_start, ray_end)
				query.exclude = [parent]
				
				var result = space_state.intersect_ray(query)
				if !result:
					# Edge detected at this position
					found_edge = true
					edge_detected_at = i
					break
			
			if found_edge:
				should_stop_at_edge = true
				
				# If edge detected at the far or middle check, back up
				if edge_detected_at <= 1:
					should_back_up = true
					if debug:
						print("CRITICAL: Edge detected at position " + str(edge_detected_at) + " - backing up")
				else:
					if debug:
						print("URGENT: Edge detected very close - stopping")
		
		# Modified direction logic with enhanced edge awareness
		direction.x = horiz_dir  # Start with horizontal component
		
		# If edge detected, modify horizontal movement
		if should_stop_at_edge:
			if should_back_up:
				direction.x = -sign(horiz_dir) * 0.5  # Back up at half speed
			else:
				direction.x = 0  # Just stop
		
		# ULTRA-CONSERVATIVE VERTICAL MOVEMENT: Only move downward in very specific cases
		
		# Only consider downward vertical movement if directly underneath
		var is_player_directly_below = abs(parent.global_position.x - target_player.global_position.x) < 30  # More strict (was 40)
		var is_player_slightly_below = target_player.global_position.y > parent.global_position.y + 20
		var is_player_far_below = target_player.global_position.y > parent.global_position.y + 100
		
		# Determine if we should apply vertical movement
		if is_player_directly_below:
			# Extra check: Verify there's actually ground below the player
			var can_safely_go_down = false
			
			if is_player_slightly_below:
				var space_state = parent.get_world_2d().direct_space_state
				var check_pos = target_player.global_position + Vector2(0, -30)  # Position above player
				var ray_start = check_pos
				var ray_end = ray_start + Vector2(0, 70)  # Check far below
				
				var query = PhysicsRayQueryParameters2D.create(ray_start, ray_end)
				query.exclude = [parent, target_player]
				
				var result = space_state.intersect_ray(query)
				if result:
					# There is ground below the player - safe to follow
					can_safely_go_down = true
					if debug and frame_counter % 20 == 0:
						print("Ground found below player - safe to follow down")
				else:
					# No ground below player - UNSAFE to follow
					can_safely_go_down = false
					if debug and frame_counter % 20 == 0:
						print("WARNING: No ground below player - NOT safe to follow down")
			
			# Player is directly below, but only move down if safe
			if can_safely_go_down:
				direction.y = vert_dir
			elif is_player_far_below:
				# Player is very far below but directly aligned - try teleporting instead of falling
				if teleport_cooldown <= 0:
					if force_safe_teleport(parent):
						teleport_cooldown = 1.0  # Shorter cooldown for more frequent teleporting
						direction = Vector2.ZERO  # Stop movement after teleport
						if debug:
							print("Player far below - teleported instead of falling")
				else:
					direction.y = 0  # Don't fall if teleport is on cooldown
			else:
				direction.y = 0  # Safest option when uncertain
		elif !parent.is_on_floor() and is_player_far_below:
			# If already in air and player is far below, try to recover
			if parent.velocity.y > 0:
				parent.velocity.y = -350  # Strong upward boost
				if debug:
					print("SAFETY: Applied recovery jump while in air above pit")
		else:
			# Never intentionally move downward unless directly above player with ground
			direction.y = min(0, vert_dir * 0.2)  # Extremely reduced downward movement, allow upward
		
		# One final safety check for dangerous downward movement
		if direction.y > 0 and parent.is_on_floor() and !is_player_directly_below:
			# Absolute safety override - NEVER move downward off a platform when player isn't directly below
			direction.y = 0
			
			if debug and frame_counter % 15 == 0:
				print("SAFETY OVERRIDE: Prevented downward movement off platform")

	# Handle coyote time and jump buffering
	handle_jump_mechanics(parent, delta, direction)
	
	# Enhanced recovery mechanics - check if we've been falling for too long
	if parent.velocity.y > 200 and is_affected_by_gravity:
		# Count consecutive falling frames
		falling_frames += 1
		
		# If falling for more than 30 frames (0.5 seconds), attempt recovery
		if falling_frames > 30 and recovery_cooldown <= 0:
			# Try teleporting first
			if teleport_cooldown <= 0:
				if force_safe_teleport(parent):
					teleport_cooldown = 1.0
					falling_frames = 0
					if debug:
						print("CRITICAL RECOVERY: Teleported after falling too long")
			
			# If teleport fails or is on cooldown, try strong upward boost
			if falling_frames > 45:  # If still falling after teleport attempt
				parent.velocity.y = -500
				recovery_cooldown = 0.5
				falling_frames = 0
				if debug:
					print("EMERGENCY RECOVERY: Strong upward boost after falling too long")
	elif parent.is_on_floor():
		falling_frames = 0  # Reset when on floor
	
	# EDGE DETECTION: Check if we're about to walk off a platform
	var should_stop_at_edge = true  # Don't walk off platforms
	if parent.is_on_floor() and abs(direction.x) > 0.1:
		var space_state = parent.get_world_2d().direct_space_state
		var ray_start = parent.global_position + Vector2(direction.x * 25, -5)  # Farther ahead check
		var ray_end = ray_start + Vector2(0, 40)  # Looking down for ground
		
		var query = PhysicsRayQueryParameters2D.create(ray_start, ray_end)
		query.exclude = [parent]
		
		var result = space_state.intersect_ray(query)
		if !result:
			# No ground ahead - we're about to walk off the edge
			if debug:
				print("Edge detected ahead - stopping horizontal movement")
			should_stop_at_edge = true
			direction.x = 0  # Stop horizontal movement
			
			# Turn around if we're getting close to an edge
			var player_is_below = target_player.global_position.y > parent.global_position.y + 50
			if !player_is_below:
				# Try moving in the opposite direction if the player isn't below us
				direction.x = -sign(direction.x) * 0.5  # Move away from edge at reduced speed
				if debug:
					print("Moving away from edge")
	
	# Stop moving when very close to player and try to attack
	if distance < attack_range:
		# Even when stopping horizontal movement, maintain gravity
		if is_affected_by_gravity:
			parent.velocity.x = 0  # Only zero out horizontal velocity
		else:
			parent.velocity = Vector2.ZERO  # Zero out all velocity if not affected by gravity
		
		# Try to attack if in range and cooldown is finished
		if can_attack and not is_attacking:
			attempt_attack(parent)
		
		# Call move_and_slide to apply gravity even when stopped horizontally
		parent.move_and_slide()
		return
	
	# Calculate horizontal movement with edge awareness
	var target_velocity
	if should_stop_at_edge:
		target_velocity = Vector2(direction.x * move_speed, parent.velocity.y)
	else:
		# If we should stop at the edge and we detected an edge
		target_velocity = Vector2(0, parent.velocity.y)
	
	# If we're not using gravity, use the full direction vector
	if not is_affected_by_gravity:
		target_velocity = direction * move_speed
	
	# Apply horizontal movement with acceleration
	if is_affected_by_gravity:
		parent.velocity.x = move_toward(parent.velocity.x, target_velocity.x, acceleration * delta)
	else:
		parent.velocity = parent.velocity.move_toward(target_velocity, acceleration * delta)
	
	# Ensure velocity is significant enough to trigger animation
	if parent.velocity.length() < 15 and distance > attack_range:
		if is_affected_by_gravity:
			parent.velocity.x = direction.x * 15  # Minimum velocity to trigger animation, only horizontal
		else:
			parent.velocity = direction * 15  # Minimum velocity in all directions
	
	# Call move_and_slide directly
	parent.move_and_slide()
	
	# Check if there's an AnimatedSprite2D child and manually trigger animation
	var animated_sprite = parent.get_node_or_null("AnimatedSprite2D")
	if animated_sprite:
		# Apply damage shader if it hasn't been applied yet
		if is_flashing and animated_sprite.material != damage_shader:
			animated_sprite.material = damage_shader
		
		# Change animation based on state
		if parent.velocity.y < -10 and is_affected_by_gravity:  # If jumping upward
			if animated_sprite.sprite_frames.has_animation("Jump"):
				animated_sprite.play("Jump")
			else:
				animated_sprite.play("Idle")  # Fallback animation
		elif parent.velocity.y > 10 and is_affected_by_gravity and not parent.is_on_floor():  # If falling
			if animated_sprite.sprite_frames.has_animation("Fall"):
				animated_sprite.play("Fall")
			else:
				animated_sprite.play("Idle")  # Fallback animation
		elif abs(parent.velocity.x) > 10:  # Only check horizontal velocity for animation
			animated_sprite.play("Run")
		else:
			animated_sprite.play("Idle")
		
		# Set sprite direction based on movement
		var facing_changed = false
		var was_facing_left = animated_sprite.flip_h
		var now_facing_left = false
		
		# Always use player position for direction when in attack range
		if target_player and parent.global_position.distance_to(target_player.global_position) < attack_range * 1.5:
			var direction_to_player = parent.global_position.direction_to(target_player.global_position)
			if direction_to_player.x < 0:
				now_facing_left = true
			elif direction_to_player.x > 0:
				now_facing_left = false
		else:
			# Use movement direction when not in attack range
			if parent.velocity.x < 0:
				now_facing_left = true
			elif parent.velocity.x > 0:
				now_facing_left = false
		
		# Check if direction changed
		if was_facing_left != now_facing_left:
			facing_changed = true
			
			# If direction changed while attacking, force end attack
			# This will let us start a new attack in the correct direction
			if is_attacking:
				is_attacking = false
				can_attack = true  # Allow immediate attack in new direction
				if debug:
					print("Direction changed during attack - resetting attack state")
		
		# Apply the flip
		animated_sprite.flip_h = now_facing_left
		
		# Update hitbox position when direction changes
		if facing_changed:
			var hitbox = parent.get_node_or_null("HitBox")
			if hitbox and hitbox.has_node("CollisionShape2D"):
				var hitbox_collision = hitbox.get_node("CollisionShape2D")
				# Flip the hitbox position to match sprite direction
				hitbox_collision.position.x = -hitbox_collision.position.x
				
				# Debug print
				if debug:
					print("Enemy changed direction, flipping hitbox position to: ", hitbox_collision.position)

# Handle coyote time and jump buffering
func handle_jump_mechanics(parent, delta, direction):
	if not can_jump or not is_affected_by_gravity:
		return
		
	# Update floor status for coyote time
	var is_on_floor = parent.is_on_floor()
	
	# Start coyote timer when leaving the ground
	if was_on_floor and not is_on_floor:
		coyote_timer = coyote_time
	
	# Decrease coyote timer when in air
	if not is_on_floor and coyote_timer > 0:
		coyote_timer -= delta
	
	# Always reset coyote timer when on floor
	if is_on_floor:
		coyote_timer = coyote_time
	
	# Decrease jump buffer timer
	if jump_buffer_timer > 0:
		jump_buffer_timer -= delta
	
	# Determine if we want to jump (AI logic)
	want_to_jump = false
	if target_player and parent:
		# Check if there's an obstacle or pit ahead
		var space_state = parent.get_world_2d().direct_space_state
		var ray_length = 60.0  # Increased from 40 to check farther ahead
		var height_check_offset = 45.0  # Increased from 32 for better pit detection
		
		# Calculate ray endpoints for object detection
		var ray_start = parent.global_position + Vector2(direction.x * 10, -5)  # Slightly ahead and up
		var ray_end = ray_start + Vector2(direction.x * ray_length, 0)
		
		# Calculate ray endpoints for ground detection
		var ground_check_start = ray_end + Vector2(0, 5)  # Start slightly below the forward point
		var ground_check_end = ground_check_start + Vector2(0, height_check_offset)
		
		# Ray parameters
		var query = PhysicsRayQueryParameters2D.create(ray_start, ray_end)
		query.exclude = [parent]
		
		var ground_query = PhysicsRayQueryParameters2D.create(ground_check_start, ground_check_end)
		ground_query.exclude = [parent]
		
		# Cast rays
		var result = space_state.intersect_ray(query)
		var ground_result = space_state.intersect_ray(ground_query)
		
		# If there's an obstacle ahead but no ground ahead, we want to jump
		if result or not ground_result:
			want_to_jump = true
			jump_buffer_timer = jump_buffer_time
	
	# Execute jump if conditions are met (using coyote time and jump buffer)
	if (is_on_floor or coyote_timer > 0) and (want_to_jump or jump_buffer_timer > 0):
		parent.velocity.y = -jump_strength
		jump_buffer_timer = 0  # Reset jump buffer
		
		# Play jump animation
		var animated_sprite = parent.get_node_or_null("AnimatedSprite2D")
		if animated_sprite:
			if animated_sprite.sprite_frames.has_animation("Jump"):
				animated_sprite.play("Jump")
			# If no jump animation, let the main process animation logic handle it
	
	# Update floor status for next frame
	was_on_floor = is_on_floor

# Try multiple ways to trigger an attack
func attempt_attack(parent):
	# Set parent target
	if target_player and "target" in parent:
		parent.target = target_player
	
	# Double-check we're not already attacking
	if is_attacking:
		if debug:
			print("Already attacking, skipping attack attempt")
		return
	
	# Verify we're actually facing the player before attacking
	var sprite = parent.get_node_or_null("AnimatedSprite2D")
	if sprite and target_player:
		var direction_to_player = parent.global_position.direction_to(target_player.global_position)
		var facing_left = sprite.flip_h
		var facing_wrong_way = (direction_to_player.x < 0 and !facing_left) or (direction_to_player.x > 0 and facing_left)
		
		if facing_wrong_way:
			# Force direction update before attacking
			sprite.flip_h = direction_to_player.x < 0
			if debug:
				print("Fixed sprite direction before attack")
		
		# Make sure we don't have the damage shader active during attack
		if is_flashing:
			sprite.material = null
			is_flashing = false
	
	# Get hitbox if it exists and ensure it starts deactivated
	var hitbox = parent.get_node_or_null("HitBox")
	if hitbox:
		var collision_shape = hitbox.get_node_or_null("CollisionShape2D")
		if collision_shape:
			# Ensure collision is disabled until we explicitly activate it
			collision_shape.disabled = true
			
			# Ensure hitbox is on the correct side of the sprite based on direction to player
			if sprite and target_player:
				var facing_left = sprite.flip_h
				
				# Calculate correct position based on facing direction
				var correct_x = abs(collision_shape.position.x)
				if facing_left:
					correct_x = -correct_x
				
				# Set position directly rather than flipping
				collision_shape.position.x = correct_x
				
				if debug:
					print("Set hitbox position for attack: ", collision_shape.position, " facing_left: ", facing_left)
		
		# Make sure the hitbox is properly deactivated
		if "active" in hitbox and hitbox.active:
			# Since we can't directly call deactivate during physics query flushing,
			# use call_deferred to schedule it for the next frame
			hitbox.call_deferred("deactivate")
		
		# Important: Set up hitbox to identify its owner to prevent self-damage
		var parent_hurtbox = parent.get_node_or_null("HurtBox")
		if parent_hurtbox:
			# Store reference to parent's hurtbox in the hitbox
			hitbox.set_meta("parent_hurtbox", parent_hurtbox)
			# Store reference to the direct_movement_test component
			hitbox.set_meta("owner_entity", self)
			
			if debug:
				print("Set up hitbox to identify owner to prevent self-damage")
	
	# Start attack sequence
	is_attacking = true
	current_attack_frame = 0
	
	# Try calling attack() directly
	if parent.has_method("attack"):
		var _result = parent.attack()
		
		# Start cooldown
		can_attack = false
		attack_timer = attack_cooldown
		return
	
	# If no attack method, try playing the attack animation directly
	if sprite and sprite.sprite_frames.has_animation("Attack"):
		# Ensure we don't have damage shader active
		sprite.material = null
		sprite.play("Attack")
		
		# Start cooldown
		can_attack = false
		attack_timer = attack_cooldown

# Called when attack animation ends
func end_attack(parent):
	is_attacking = false
	current_attack_frame = 0
	
	# Ensure hitbox is deactivated
	var hitbox = parent.get_node_or_null("HitBox")
	if hitbox:
		var collision_shape = hitbox.get_node_or_null("CollisionShape2D")
		if collision_shape:
			# Use set_deferred to avoid changing physics properties during physics processing
			collision_shape.set_deferred("disabled", true)
		if hitbox.active:
			# Since we can't directly call deactivate during physics query flushing,
			# use call_deferred to schedule it for the next frame
			hitbox.call_deferred("deactivate")
	
	# Make sure hurtbox is ALWAYS re-enabled when attack ends
	var end_attack_hurtbox = parent.get_node_or_null("HurtBox")
	if end_attack_hurtbox and end_attack_hurtbox.has_node("CollisionShape2D"):
		var end_attack_hurtbox_collision = end_attack_hurtbox.get_node("CollisionShape2D")
		# Use set_deferred to avoid changing physics properties during physics processing
		end_attack_hurtbox_collision.set_deferred("disabled", false)
		if debug:
			print("Re-enabled hurtbox at end of attack")

# Function to take damage - called by the hurtbox
func take_damage(damage_amount: float, knockback_force: Vector2 = Vector2.ZERO) -> void:
	# Print detailed debugging info
	print("DIRECT MOVEMENT DAMAGE: Receiving damage: ", damage_amount, " from knockback direction: ", knockback_force)
	
	# Check if we're already invincible
	if is_invincible:
		if debug:
			print("Enemy is invincible, ignoring damage")
		return
	
	if debug:
		print("Enemy taking damage: ", damage_amount, " current health: ", current_health)
	
	# Apply damage
	current_health -= damage_amount
	print("ENEMY HEALTH REDUCED: New health = ", current_health)
	
	# ENHANCED KNOCKBACK PROTECTION
	var max_knockback = 400.0  # Further reduced from 500.0 to 400.0
	if knockback_force.length() > max_knockback:
		knockback_force = knockback_force.normalized() * max_knockback
		if debug:
			print("Limited excessive knockback force to: ", max_knockback)
	
	# Check if player has Growth Burst active and further reduce knockback
	var player = get_tree().get_first_node_in_group("Player")
	if player and player.has_node("GrowthSystem"):
		var growth_system = player.get_node("GrowthSystem")
		if growth_system and "active_effect" in growth_system and growth_system.active_effect == "Growth Burst":
			knockback_force *= 0.2  # Reduce knockback by 80% during Growth Burst (was 0.3 - 70%)
			if debug:
				print("Detected Growth Burst, applying 80% knockback reduction")
	
	# ENHANCED PIT PROTECTION: Always convert downward knockback to upward
	if knockback_force.y > 0:  # If knockback would push downward
		knockback_force.y = -100  # Stronger upward force (was -50)
		if debug:
			print("Converting downward knockback to upward for enhanced pit protection")
	
	# Apply knockback if provided
	if knockback_force != Vector2.ZERO:
		var enemy_body = get_parent()
		if enemy_body is CharacterBody2D:
			# Apply knockback with resistance factor
			var applied_force = knockback_force * (1.0 - knockback_resistance)
			enemy_body.velocity += applied_force
			
			if debug:
				print("Applied knockback: ", applied_force)
	
	# Set invincibility
	is_invincible = true
	invincibility_timer = invincibility_time
	if debug:
		print("Enemy became invincible for ", invincibility_time, " seconds")
	
	# Get parent reference
	var parent = get_parent()
	if parent:
		# IMPORTANT: Always ensure the hurtbox is enabled for future hits
		# This is critical if something is incorrectly disabling it
		var damage_hurtbox = parent.get_node_or_null("HurtBox")
		if damage_hurtbox and damage_hurtbox.has_node("CollisionShape2D"):
			var damage_hurtbox_collision = damage_hurtbox.get_node("CollisionShape2D")
			if damage_hurtbox_collision.disabled:
				# Use set_deferred to avoid physics state changes during physics callbacks
				damage_hurtbox_collision.set_deferred("disabled", false)
			if debug:
					print("Re-enabled disabled hurtbox during damage")
		
		# Get sprite reference
		var sprite = parent.get_node_or_null("AnimatedSprite2D")
		
		# Check if enemy is currently attacking
		if is_attacking and cannot_cancel_attack:
			# Only apply damage shader during attack, don't change animation
			apply_damage_flash()
			if debug:
				print("Enemy was hit during attack but continued attacking (RPG ambush style)")
		else:
			# Normal damage response when not attacking
			if sprite and sprite.sprite_frames.has_animation("Hurt"):
				sprite.play("Hurt")
				# Apply damage flash during hurt animation
				apply_damage_flash()
			else:
				# No hurt animation, just apply flash effect
				apply_damage_flash()
	
	# Check if dead
	if current_health <= 0:
		if debug:
			print("Enemy health reached zero, calling die()")
		die()
		return
	
	# Emit signal if it exists
	if parent.has_signal("enemy_damaged"):
		parent.emit_signal("enemy_damaged", parent, damage_amount)
	else:
		# Try to find SignalBus using get_node instead of 'in' operator
		var signal_bus = parent.get_tree().root.get_node_or_null("SignalBus")
		if signal_bus and signal_bus.has_signal("enemy_damaged"):
			signal_bus.enemy_damaged.emit(parent, damage_amount)

# Function to handle death
func die() -> void:
	var parent = get_parent()
	if parent:
		if debug:
			print("Enemy died with health: ", current_health)
		
		# Disable processing to prevent movement
		enabled = false
		
		# Stop any ongoing attack
		if is_attacking:
			end_attack(parent)
		
		# Change to death animation if available
		var sprite = parent.get_node_or_null("AnimatedSprite2D")
		if sprite and sprite.sprite_frames.has_animation("Death"):
			# Remove any active material/shader
			sprite.material = null
			
			# Reset modulate in case it was changed
			sprite.modulate = Color(1, 1, 1, 1)
			
			# Play death animation
			sprite.play("Death")
			
			# Check if signal is connected safely
			if sprite.has_signal("animation_finished") and not sprite.is_connected("animation_finished", _on_death_animation_finished):
				sprite.animation_finished.connect(_on_death_animation_finished)
		else:
			# No death animation, just a short delay
			await get_tree().create_timer(0.5).timeout
		
		# Emit signal if it exists
		if parent.has_signal("enemy_died"):
			parent.emit_signal("enemy_died", parent)
		else:
			# Try to find SignalBus using get_node instead of 'in' operator
			var signal_bus = parent.get_tree().root.get_node_or_null("SignalBus")
			if signal_bus and signal_bus.has_signal("enemy_died"):
				signal_bus.enemy_died.emit(parent)
		
		# Queue free the parent
		if debug:
			print("Enemy destroyed")
		parent.queue_free()

# Apply damage flash effect
func apply_damage_flash() -> void:
	is_flashing = true
	flash_timer = damage_flash_duration
	
	var parent = get_parent()
	var sprite = parent.get_node_or_null("AnimatedSprite2D")
	if sprite:
		# Apply the shader
		sprite.material = damage_shader
		
		# Set the flash intensity
		damage_shader.set_shader_parameter("flash_intensity", damage_flash_intensity)
		
		if debug:
			print("Applied damage flash effect")
	
	# IMPORTANT: Don't end attack if cannot_cancel_attack is true
	if is_attacking and !cannot_cancel_attack:
		# Use call_deferred to avoid changing physics state during physics callbacks
		call_deferred("end_attack", parent)
		if debug:
			print("Forcing attack to end due to taking damage")

# Handle death animation completion
func _on_death_animation_finished():
	# Queue free after death animation
	queue_free()

# DEBUG function to handle input for testing damage
func _input(event):
	if debug and event is InputEvent:
		if event.is_action_pressed("ui_focus_next"):  # F3 key by default
			print("DEBUG: Manual damage test triggered")
			force_damage_test()

# DEBUG function to manually apply damage for testing
func force_damage_test():
	if debug:
		print("DEBUG: Forcing test damage of 10")
		take_damage(10.0, Vector2(100, 0))
		print("DEBUG: Health after test damage: ", current_health)

func update_debug_status():
	var current_player = get_tree().get_first_node_in_group("Player")
	if current_player:
		var parent = get_parent()
		var _dist_to_player = parent.global_position.distance_to(current_player.global_position)
		
		# Remove print

		if hurtbox:
			var hurtbox_collision = hurtbox.get_node_or_null("CollisionShape2D") 
			if hurtbox_collision:
				# Remove print
				
				# Check if player's hitbox is active
				var player_hitbox = current_player.get_node_or_null("HitBox")
				if player_hitbox:
					var player_state = ""
					if current_player.has_method("get_current_state_name"):
						player_state = current_player.get_current_state_name()
					
					var _player_attacking = player_state == "attack"
					# Remove print

func end_invincibility():
	is_invincible = false
	
	# Fix for invincibility leaving hurtbox disabled
	if hurtbox:
		var current_hurtbox_collision = hurtbox.get_node_or_null("CollisionShape2D")
		if current_hurtbox_collision and current_hurtbox_collision.disabled:
			current_hurtbox_collision.set_deferred("disabled", false)
			if debug:
				print("CRITICAL FIX: Re-enabled hurtbox after invincibility ended")
		else:
			if debug:
				# Remove print
				pass
		
		if debug:
			# Remove print
			pass
			
	# Restore normal appearance
	if enemy_animated_sprite:
		enemy_animated_sprite.modulate = orig_modulate

func update_enemy_attack_state():
	if !enemy_animated_sprite:
		return
		
	var parent = get_parent()
	var enemy_hitbox = parent.get_node_or_null("HitBox")
		
	# Track attack animation frames
	if is_attacking:
		if enemy_animated_sprite.animation == "Attack":
			var new_frame = enemy_animated_sprite.frame
			if new_frame != current_attack_frame:
				current_attack_frame = new_frame
				if debug:
					# Remove print
					pass
				
				# Check if we need to enable/disable hitbox based on the frame
				if enemy_hitbox:
					# Get the 1-indexed frame number (animators typically use 1-indexed)
					var frame_one_indexed = current_attack_frame + 1
					
					# Enable hitbox on specific frames (these would depend on the animation)
					if frame_one_indexed == 7 or frame_one_indexed == 8:
						if !enemy_hitbox.active:
							enemy_hitbox.activate()
							if debug:
								# Remove print
								pass
					
					# Disable hitbox after attack frames
					elif frame_one_indexed == 10:
						if enemy_hitbox.active:
							enemy_hitbox.deactivate()
							if debug:
								# Remove print
								pass
				
				# Check if the attack animation is done
				if new_frame == enemy_animated_sprite.sprite_frames.get_frame_count("Attack") - 1:
					if debug:
						# Remove print
						pass
					end_attack(parent)
		else:
			# We're in the attack state but not playing the attack animation
			if debug:
				# Remove print
				pass
			end_attack(parent)

# Emergency teleport function to recover from pit falls
func force_safe_teleport(parent) -> bool:
	if debug:
		print("DirectMovementTest: Force teleport requested")
	
	# First try to find a safe position near the player
	var player = get_tree().get_first_node_in_group("Player")
	if player:
		# First, check if player is standing on solid ground
		var space_state = parent.get_world_2d().direct_space_state
		var player_ground_start = player.global_position
		var player_ground_end = player_ground_start + Vector2(0, 30)
		
		var ground_query = PhysicsRayQueryParameters2D.create(player_ground_start, player_ground_end)
		ground_query.exclude = [parent, player]
		
		var ground_result = space_state.intersect_ray(ground_query)
		if ground_result:
			# Player is on ground - teleport near them but at their Y level or slightly above
			# Try several horizontal offsets but preserve Y position
			var horizontal_offsets = [50, -50, 75, -75, 100, -100, 25, -25]
			
			for h_offset in horizontal_offsets:
				var test_pos = Vector2(player.global_position.x + h_offset, player.global_position.y - 10)
				
				# Check if this position is safe
				if verify_safe_position(parent, player, test_pos, space_state):
					parent.global_position = test_pos
					parent.velocity = Vector2.ZERO
					frames_falling = 0
					was_falling = false
					if debug:
						print("TELEPORT: Moved to same Y level as player at offset ", h_offset)
					return true
						
			# If no horizontal offset worked, try directly above player
			var above_pos = player.global_position + Vector2(0, -50)
			if verify_safe_position(parent, player, above_pos, space_state):
				parent.global_position = above_pos
				parent.velocity = Vector2.ZERO
				frames_falling = 0
				was_falling = false
				if debug:
					print("TELEPORT: Moved directly above player")
				return true
		
		# If player isn't on ground or above positions didn't work, try extensive offsets
		var offsets = [
			Vector2(70, -20),   # Right side
			Vector2(-70, -20),  # Left side
			Vector2(100, -20),  # Further right
			Vector2(-100, -20), # Further left
			Vector2(40, -20),   # Closer right
			Vector2(-40, -20),  # Closer left
			Vector2(0, -50),    # Above player
			Vector2(0, -100),   # Higher above player
			Vector2(0, -30),    # Just above player
			Vector2(40, -50),   # Upper right
			Vector2(-40, -50),  # Upper left
			Vector2(0, 0)       # At player position (last resort)
		]
		
		for offset in offsets:
			var test_pos = player.global_position + offset
			
			# Triple-verify safety with comprehensive checks
			if verify_safe_position(parent, player, test_pos, space_state):
				parent.global_position = test_pos
				parent.velocity = Vector2.ZERO
				frames_falling = 0
				was_falling = false
				if debug:
					print("TELEPORT: Safe position found at offset ", offset)
				return true
		
		# Last resort - move VERY high above player and let gravity bring us down
		var emergency_pos = player.global_position + Vector2(0, -150)
		parent.global_position = emergency_pos
		parent.velocity = Vector2.ZERO
		frames_falling = 0
		was_falling = false
		if debug:
			print("TELEPORT: Emergency high teleport as last resort")
		return true
	
	# If we still have a last_ground_position, use that
	if last_ground_position != Vector2.ZERO:
		parent.global_position = last_ground_position
		parent.velocity = Vector2.ZERO
		frames_falling = 0
		was_falling = false
		if debug:
			print("TELEPORT: Using last known ground position as fallback")
		return true
	
	if debug:
		print("TELEPORT FAILED: No player and no saved ground position")
	return false

# New helper function to thoroughly verify position safety
func verify_safe_position(parent, player, pos, space_state) -> bool:
	# Don't teleport inside colliders
	var inside_check = PhysicsRayQueryParameters2D.create(pos, pos)
	inside_check.exclude = [parent, player]
	var inside_result = space_state.intersect_ray(inside_check)
	if inside_result:
		return false  # Position is inside a collider
	
	# Check for ground below with multiple rays
	var ground_found = false
	var ground_points = [
		Vector2(0, 0),    # Center
		Vector2(-5, 0),   # Slight left
		Vector2(5, 0)     # Slight right
	]
	
	for point in ground_points:
		var ray_start = pos + point
		var ray_end = ray_start + Vector2(0, 80)  # Check 80 pixels down
		
		var query = PhysicsRayQueryParameters2D.create(ray_start, ray_end)
		query.exclude = [parent, player]
		
		var result = space_state.intersect_ray(query)
		if result:
			ground_found = true
			break
	
	return ground_found  # Safe if we found ground with any ray

# New function to update platform anchoring state
func update_platform_state(parent, delta):
	# Update cooldown for platform checks
	if platform_check_cooldown > 0:
		platform_check_cooldown -= delta
	
	# Only do platform checks every so often to save performance
	if platform_check_cooldown <= 0:
		platform_check_cooldown = 0.1  # Check 10 times per second
		
		# Check if we're on a platform
		if parent.is_on_floor():
			is_anchored_to_platform = true
			
			# Measure platform width
			detect_platform_width(parent)
			
			# Reset falling frames
			falling_frames = 0
		else:
			# Count falling frames for emergency recovery
			falling_frames += 1
			
			# After falling more than 10 frames without being on floor, deactivate anchoring
			if falling_frames > 10:
				is_anchored_to_platform = false
			
			# SUPER AGGRESSIVE ANTI-FALL: If falling for more than 20 frames, force teleport back
			if falling_frames > 20 and teleport_cooldown <= 0:
				# First try standard teleport
				if force_safe_teleport(parent):
					teleport_cooldown = 1.0
					falling_frames = 0
					if debug:
						print("EMERGENCY: Teleported after falling for 20 frames")
				# If teleport fails, go back to last known ground position
				elif last_ground_position != Vector2.ZERO:
					parent.global_position = last_ground_position
					parent.velocity = Vector2.ZERO
					falling_frames = 0
					teleport_cooldown = 1.0
					if debug:
						print("CRITICAL RECOVERY: Returned to last ground position after failed teleport")
	
	# EXTREME MEASURE: If we're falling fast, immediately apply recovery
	if parent.velocity.y > 250 and falling_frames > 10 and recovery_cooldown <= 0:
		parent.velocity.y = -400
		recovery_cooldown = 0.5
		if debug:
			print("EXTREME FALL DETECTED: Applied immediate upward force")

# New function to measure platform width
func detect_platform_width(parent):
	var space_state = parent.get_world_2d().direct_space_state
	var platform_left_edge = -1
	var platform_right_edge = -1
	
	# Check to the left
	for i in range(1, 21):  # Check up to 20 steps left
		var check_pos = parent.global_position + Vector2(-i * 10, 5)  # 10 pixels per step, 5 pixels down
		var ray_start = check_pos
		var ray_end = ray_start + Vector2(0, 10)
		
		var query = PhysicsRayQueryParameters2D.create(ray_start, ray_end)
		query.exclude = [parent]
		
		var result = space_state.intersect_ray(query)
		if !result:
			platform_left_edge = check_pos.x + 10  # The edge is 10px to the right of this position
			break
	
	# Check to the right
	for i in range(1, 21):  # Check up to 20 steps right
		var check_pos = parent.global_position + Vector2(i * 10, 5)  # 10 pixels per step, 5 pixels down
		var ray_start = check_pos
		var ray_end = ray_start + Vector2(0, 10)
		
		var query = PhysicsRayQueryParameters2D.create(ray_start, ray_end)
		query.exclude = [parent]
		
		var result = space_state.intersect_ray(query)
		if !result:
			platform_right_edge = check_pos.x - 10  # The edge is 10px to the left of this position
			break
	
	# Calculate platform width if both edges were found
	if platform_left_edge != -1 and platform_right_edge != -1:
		current_platform_width = platform_right_edge - platform_left_edge
		if debug and frame_counter % 30 == 0:
			print("PLATFORM: Detected width = ", current_platform_width)
	else:
		# If can't determine width, use a conservative default
		current_platform_width = 200

# New function to check for platform edges in movement direction
func check_platform_edge(parent, dir_x) -> bool:
	if dir_x == 0:
		return false  # No horizontal movement, no edge to detect
		
	var space_state = parent.get_world_2d().direct_space_state
	
	# Check multiple distances ahead for more reliable edge detection
	var check_distances = [20, 30, 40, 50]  # Check at 20, 30, 40, and 50 pixels ahead
	
	for distance in check_distances:
		var ray_start = parent.global_position + Vector2(sign(dir_x) * distance, -5)
		var ray_end = ray_start + Vector2(0, 30)  # Check 30 pixels down
		
		var query = PhysicsRayQueryParameters2D.create(ray_start, ray_end)
		query.exclude = [parent]
		
		var result = space_state.intersect_ray(query)
		if !result:
			if debug and frame_counter % 15 == 0:
				print("EDGE DETECTED at distance ", distance, " in direction ", sign(dir_x))
			edge_detected = true
			return true  # Edge detected
	
	# No edge detected at any of the distances
	edge_detected = false
	return false

# Function to check if a position is outside screen bounds
func is_outside_screen_bounds(pos):
	var viewport = get_viewport()
	if not viewport:
		return false
		
	var camera = viewport.get_camera_2d()
	if not camera:
		return false
		
	var margin = screen_margin  # Use the class variable for margin
	var screen_size = viewport.get_visible_rect().size
	var camera_pos = camera.global_position
	var half_width = screen_size.x / 2
	var half_height = screen_size.y / 2
	
	# Calculate screen boundaries
	var left_bound = camera_pos.x - half_width + margin
	var right_bound = camera_pos.x + half_width - margin
	var top_bound = camera_pos.y - half_height + margin
	var bottom_bound = camera_pos.y + half_height - margin
	
	# Check if position is outside bounds
	return (pos.x < left_bound or pos.x > right_bound or 
			pos.y < top_bound or pos.y > bottom_bound)

# Simplified function to enforce screen bounds with gentle bounce
func enforce_screen_bounds(parent):
	var viewport = get_viewport()
	if not viewport:
		return
		
	var camera = viewport.get_camera_2d()
	if not camera:
		return
		
	var margin = screen_margin  # Use the class variable for margin
	var screen_size = viewport.get_visible_rect().size
	var camera_pos = camera.global_position
	var half_width = screen_size.x / 2
	var half_height = screen_size.y / 2
	
	# Calculate screen boundaries
	var left_bound = camera_pos.x - half_width + margin
	var right_bound = camera_pos.x + half_width - margin
	var top_bound = camera_pos.y - half_height + margin
	var bottom_bound = camera_pos.y + half_height - margin
	
	var was_off_screen = false
	
	# Check and correct position with gentle bounce
	if parent.global_position.x < left_bound:
		parent.global_position.x = left_bound
		parent.velocity.x = 20.0  # Gentle bounce right
		was_off_screen = true
	elif parent.global_position.x > right_bound:
		parent.global_position.x = right_bound
		parent.velocity.x = -20.0  # Gentle bounce left
		was_off_screen = true
		
	if parent.global_position.y < top_bound:
		parent.global_position.y = top_bound
		parent.velocity.y = 20.0  # Gentle bounce down
		was_off_screen = true
	elif parent.global_position.y > bottom_bound:
		parent.global_position.y = bottom_bound
		parent.velocity.y = -100.0  # Stronger upward bounce for pits
		was_off_screen = true
		
	if was_off_screen and debug:
		print("Enforced screen bounds - position corrected")

# Override _physics_process to intercept and cap falling velocity
func _physics_process(delta):
	# Get parent reference
	var parent = get_parent()
	if not parent or not (parent is CharacterBody2D):
		return
	
	# PLATFORM DETECTION: Periodically check for ground beneath
	if frame_counter % 30 == 0:  # Check every 30 frames
		find_ground_position(parent)
	
	# ABSOLUTE Y-POSITION LOCK: Never let the NightBorne change its Y position
	parent.global_position.y = fixed_y_position
	parent.velocity.y = 0
	
	# Normal processing for debug output
	if debug and frame_counter % 30 == 0:
		update_debug_status()
		if debug:
			print("NightBorne at fixed Y=", fixed_y_position)
	
	# Increment frame counter for periodic debug messages
	frame_counter = (frame_counter + 1) % 60
	
	# Continue with normal behavior for horizontal movement
	var direction = Vector2.ZERO
	var distance = 999999
	
	if target_player != null:
		direction.x = parent.global_position.direction_to(target_player.global_position).x
		direction.y = 0  # NEVER allow vertical movement
		distance = parent.global_position.distance_to(target_player.global_position)
	
	# Stop moving when very close to player and try to attack
	if distance < attack_range:
		parent.velocity.x = 0
		
		# Try to attack if in range and cooldown is finished
		if can_attack and not is_attacking:
			attempt_attack(parent)
			
		parent.move_and_slide()
		# Re-lock Y position after move_and_slide
		parent.global_position.y = fixed_y_position
		return
	
	# Check for edges before moving
	var edge_ahead = check_edge_ahead(parent, direction.x)
	if edge_ahead:
		# Stop horizontal movement at edges
		direction.x = 0
		parent.velocity.x = 0
		if debug and frame_counter % 15 == 0:
			print("EDGE DETECTED: Stopped movement")
	
	# Calculate horizontal movement only
	var target_velocity = Vector2(direction.x * move_speed, 0)
	
	# Apply horizontal movement with acceleration
	parent.velocity.x = move_toward(parent.velocity.x, target_velocity.x, acceleration * delta)
	
	# Ensure velocity is significant enough to trigger animation
	if parent.velocity.length() < 15 and distance > attack_range:
		parent.velocity.x = direction.x * 15
	
	# Call move_and_slide directly
	parent.move_and_slide()
	
	# CRITICAL: Re-lock Y position after move_and_slide
	parent.global_position.y = fixed_y_position

# Add a new function to find the ground position beneath the enemy
func find_ground_position(parent):
	# Create multiple ray casts to find the ground beneath the enemy
	var space_state = parent.get_world_2d().direct_space_state
	
	# Track the best ground position found
	var best_ground_y = null
	var ground_found = false
	
	# Multiple ray checks at different horizontal offsets for better platform detection
	var check_offsets = [-15, 0, 15]  # Left, center, right
	
	for offset in check_offsets:
		var ray_start = parent.global_position + Vector2(offset, -10)  # Start from slightly above
		var ray_end = ray_start + Vector2(0, 120)  # Check up to 120 pixels down (increased from 100)
		
		var query = PhysicsRayQueryParameters2D.create(ray_start, ray_end)
		query.exclude = [parent]
		
		var result = space_state.intersect_ray(query)
		if result:
			# Found ground - update the position if it's the highest ground point
			ground_found = true
			var ground_y = result.position.y - 1  # Subtract 1 pixel to stay just above ground
			
			if best_ground_y == null or ground_y < best_ground_y:
				best_ground_y = ground_y
	
	if ground_found and best_ground_y != null:
		# Found ground - set the Y position to be right at ground level
		fixed_y_position = best_ground_y
		print("GROUND DETECTION: Adjusted Y position to match ground at Y=", fixed_y_position)
		
		# Store this as a good position
		last_ground_position = parent.global_position
		last_ground_position.y = fixed_y_position
		
		return true
	else:
		print("WARNING: No ground detected below enemy")
		return false

# Improved edge detection with multiple rays for better reliability
func check_edge_ahead(parent, dir_x):
	if dir_x == 0:
		return false
		
	var space_state = parent.get_world_2d().direct_space_state
	
	# Cast multiple rays at different distances for better detection
	var edge_detected = false
	var check_distances = [20, 30, 40]  # Check at 20, 30, and 40 pixels ahead
	
	for distance in check_distances:
		# Calculate ray position ahead of movement direction
		var check_pos = parent.global_position + Vector2(sign(dir_x) * distance, 0)
		
		# Ray starts at the check position and goes downward
		var ray_start = check_pos
		var ray_end = ray_start + Vector2(0, 60)  # Increased from 50 to 60 pixels down for better detection
		
		var query = PhysicsRayQueryParameters2D.create(ray_start, ray_end)
		query.exclude = [parent]
		
		var result = space_state.intersect_ray(query)
		if !result:
			# No ground detected ahead at this distance - edge detected
			if debug and frame_counter % 15 == 0:
				print("EDGE DETECTED at distance: ", distance)
			edge_detected = true
			break
	
	return edge_detected
