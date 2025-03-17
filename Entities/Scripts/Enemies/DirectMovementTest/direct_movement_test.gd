extends Node

# This is a simple test script to add to the NightBorne enemy
# It will directly move the enemy towards the player, bypassing the behavior tree
# and any method calls that might not be working

@export var enabled: bool = true
@export var move_speed: float = 80.0
@export var debug: bool = false  # Set to false to disable debug prints
@export var acceleration: float = 300.0
@export var gravity_strength: float = 980.0  # Default gravity (pixels/sec²)
@export var is_affected_by_gravity: bool = true
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
	
	# IMPORTANT: Set debug to false for performance
	debug = false
	
	# Set up hurtbox connection to damage function
	var parent = get_parent()
	if parent:
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
	
	# Calculate direction to player
	var direction = parent.global_position.direction_to(target_player.global_position)
	var distance = parent.global_position.distance_to(target_player.global_position)
	
	# Handle coyote time and jump buffer
	handle_jump_mechanics(parent, delta, direction)
	
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
	
	# Calculate horizontal movement
	var target_velocity = Vector2(direction.x * move_speed, parent.velocity.y)
	
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
		var ray_length = 40.0  # How far to check ahead
		var height_check_offset = 32.0  # How far down to check
		
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
	# Check if we're already invincible
	if is_invincible:
		if debug:
			print("Enemy is invincible, ignoring damage")
		return
	
	if debug:
		print("Enemy taking damage: ", damage_amount, " current health: ", current_health)
	
	# Apply damage
	current_health -= damage_amount
	
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
			
			# IMMEDIATE SCREEN BOUNDARY CHECK: Call it twice for safety
			ensure_on_screen(enemy_body)
	
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

# Function to be called every physics frame to keep enemies within screen
func ensure_on_screen(parent) -> void:
	# OPTIMIZATION: Update safe position less frequently (every 30 frames)
	if frame_counter % 30 == 0:
		update_safe_position(parent)
	
	var viewport = get_viewport()
	if not viewport:
		return
		
	var camera = viewport.get_camera_2d()
	if not camera:
		return
	
	# Use smaller margins for tighter control
	var h_margin = 25  # Horizontal margin (reduced from 50 to 25)
	var top_margin = 25  # Top margin
	var bottom_margin = 40  # Larger bottom margin to prevent falling off screen
	
	var screen_size = viewport.get_visible_rect().size
	var camera_pos = camera.global_position
	var half_width = screen_size.x / 2
	var half_height = screen_size.y / 2
	
	# Calculate screen boundaries
	var left_bound = camera_pos.x - half_width + h_margin
	var right_bound = camera_pos.x + half_width - h_margin
	var top_bound = camera_pos.y - half_height + top_margin
	var bottom_bound = camera_pos.y + half_height - bottom_margin
	
	var was_off_screen = false
	var hit_vertical_bound = false
	
	# Check if enemy is below the screen - CRITICAL PRIORITY
	var seriously_below_screen = parent.global_position.y > bottom_bound + 20
	var extremely_below_screen = parent.global_position.y > bottom_bound + 150
	
	# EXTREME CASE - teleport for emergency recovery with cooldown
	if extremely_below_screen and teleport_cooldown <= 0:
		if emergency_teleport(parent):
			return
	
	# Critical case that ignores cooldown - if we're below screen or falling very fast
	if (seriously_below_screen or parent.velocity.y > 400) and recovery_cooldown <= 0:
		is_seriously_below_screen = true
		parent.velocity.y = -500
		parent.velocity.x *= 0.5
		was_off_screen = true
		hit_vertical_bound = true
		recovery_cooldown = 1.0  # Longer cooldown for better performance
	# Update cooldown
	elif recovery_cooldown > 0:
		recovery_cooldown -= get_process_delta_time()
		if teleport_cooldown > 0:
			teleport_cooldown -= get_process_delta_time()
			
		# If we were below screen but now we're not, reset the flag
		if is_seriously_below_screen and not seriously_below_screen:
			is_seriously_below_screen = false
	else:
		# Standard boundary checks only happen if not in critical mode and cooldown expired
		is_seriously_below_screen = seriously_below_screen
		
		# Check and correct horizontal position with bounce - ALWAYS HAPPENS
		if parent.global_position.x < left_bound:
			parent.global_position.x = left_bound
			parent.velocity.x = abs(parent.velocity.x) * 0.5 + 50  # Stronger bounce right
			was_off_screen = true
		elif parent.global_position.x > right_bound:
			parent.global_position.x = right_bound
			parent.velocity.x = -abs(parent.velocity.x) * 0.5 - 50  # Stronger bounce left
			was_off_screen = true
		
		# Check and correct vertical position if not already handled by pit detection
		if not hit_vertical_bound:
			if parent.global_position.y < top_bound:
				parent.global_position.y = top_bound
				parent.velocity.y = abs(parent.velocity.y) * 0.5 + 20  # Stronger bounce down
				was_off_screen = true
			elif parent.global_position.y > bottom_bound:
				# This is critical - enforce no matter what
				parent.global_position.y = bottom_bound
				parent.velocity.y = -350  # Strong upward bounce
				recovery_cooldown = 0.3  # Short cooldown
				was_off_screen = true
				if debug:
					print("BOUNDARY: Enemy at bottom edge - applying critical recovery")
		
		# Cap falling velocity regardless of other checks - important to prevent falling too fast
		if parent.velocity.y > 200:  # More aggressive capping (reduced from 300)
			parent.velocity.y = 200
	
	# OPTIMIZATION: Reduce debug print frequency 
	if was_off_screen and debug and frame_counter % 10 == 0:
		print("SCREEN BOUNDARY: Kept enemy on screen")

# Override _physics_process to intercept and cap falling velocity
func _physics_process(delta):
	# OPTIMIZATION: Reduce debug calls frequency
	if debug and frame_counter % 60 == 0:
		update_debug_status()
	
	# Increment frame counter for periodic debug messages
	frame_counter = (frame_counter + 1) % 60
	
	# Get parent reference
	var parent = get_parent()
	if not parent or not (parent is CharacterBody2D):
		return
	
	# Safety: Cap maximum falling velocity to prevent falling through boundaries
	if parent.velocity.y > 300:
		parent.velocity.y = 300
	
	# CRITICAL: Screen boundary check ONCE per frame (not twice)
	ensure_on_screen(parent)
	
	# Apply gravity first
	if is_affected_by_gravity:
		# Cap falling speed to prevent excessive velocity
		if parent.velocity.y < 200:  # More aggressive capping (reduced from 300)
			parent.velocity.y += gravity_strength * delta
		else:
			parent.velocity.y = 200  # Cap falling speed - more aggressive capping
	
	# Calculate direction to player
	var direction = Vector2.ZERO
	var distance = 999999
	
	if target_player != null:
		direction = parent.global_position.direction_to(target_player.global_position)
		distance = parent.global_position.distance_to(target_player.global_position)
	
	# Always check screen bounds one more time after applying gravity but before movement
	ensure_on_screen(parent)

# Function to update last safe position
func update_safe_position(parent):
	# Only store position if on floor and not in a pit
	if parent.is_on_floor() and not is_seriously_below_screen:
		# Check if we're at a reasonable height relative to player
		var current_player = get_tree().get_first_node_in_group("Player")
		if current_player and abs(parent.global_position.y - current_player.global_position.y) < 100:
			last_safe_position = parent.global_position
			if debug and frame_counter % 30 == 0:  # Limit debug spam
				print("DirectMovementTest: Updated safe position to ", last_safe_position)

# Emergency teleport function for extreme cases
func emergency_teleport(parent):
	# If we have a valid last safe position, teleport there
	if last_safe_position != Vector2.ZERO:
		parent.global_position = last_safe_position
		parent.velocity = Vector2.ZERO
		is_seriously_below_screen = false
		teleport_cooldown = 2.0  # Longer cooldown between teleports
		if debug:
			print("EMERGENCY: Teleported enemy to last safe position")
		return true
	
	# Fallback: Try to teleport to player with offset
	var current_player = get_tree().get_first_node_in_group("Player")
	if current_player:
		# Teleport slightly to the left or right of the player
		var offset_x = 50  # Base X offset
		if randf() > 0.5:  # 50% chance to flip direction
			offset_x = -offset_x
		
		parent.global_position = current_player.global_position + Vector2(offset_x, -20)
		parent.velocity = Vector2.ZERO
		is_seriously_below_screen = false
		teleport_cooldown = 2.0  # Longer cooldown between teleports
		if debug:
			print("EMERGENCY: Teleported enemy to player position with offset")
		return true
	
	return false
