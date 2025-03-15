extends Node

# This is a simple test script to add to the NightBorne enemy
# It will directly move the enemy towards the player, bypassing the behavior tree
# and any method calls that might not be working

@export var enabled: bool = true
@export var move_speed: float = 80.0
@export var debug: bool = true
@export var acceleration: float = 300.0
@export var gravity_strength: float = 980.0  # Default gravity (pixels/sec²)
@export var is_affected_by_gravity: bool = true
@export var attack_range: float = 50.0  # Range at which enemy stops to attack
@export var attack_cooldown: float = 1.5  # Time between attacks in seconds

# Attack animation frame control
@export var hitbox_active_frame_start: int = 8  # Activate hitbox on frame 8 (counting from 1)
@export var hitbox_active_frame_end: int = 9    # Deactivate after frame 9 (counting from 1)

# Health and damage settings
@export var max_health: float = 100.0
@export var current_health: float = 100.0
@export var knockback_resistance: float = 0.5

# Damage effect settings
@export var damage_flash_duration: float = 0.15  # How long the damage flash lasts
@export var damage_flash_intensity: float = 0.8  # How intense the red flash is (0-1)
@export var invincibility_time: float = 0.3     # Short invincibility after taking damage

# Jump parameters
@export var can_jump: bool = false              # Whether this enemy can jump to navigate (disabled by default)
@export var jump_strength: float = 300.0       # Jump force
@export var coyote_time: float = 0.15          # Time in seconds enemy can jump after leaving ledge
@export var jump_buffer_time: float = 0.15     # Time in seconds to buffer a jump input

var player = null
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
var is_flashing: bool = false         # Currently showing damage flash
var flash_timer: float = 0.0          # Timer for damage flash
var is_invincible: bool = false       # Track invincibility state
var invincibility_timer: float = 0.0  # Track invincibility time
var damage_shader: ShaderMaterial = null # Shader material for damage effect

func _ready():
	if not enabled:
		set_process(false)
		return
	
	# Initialize health
	current_health = max_health
	
	# Set up damage shader
	damage_shader = ShaderMaterial.new()
	damage_shader.shader = load("res://Shaders/Enemies/enemy_damage.gdshader")
	damage_shader.set_shader_parameter("flash_intensity", 0.0)
	
	# Set up hurtbox connection to damage function
	var parent = get_parent()
	if parent:
		var hurtbox = parent.get_node_or_null("HurtBox")
		if hurtbox:
			if debug:
				print("Setting up HurtBox")
			
			# Connect directly to our take_damage function
			if hurtbox.has_method("take_damage"):
				# Add reference to self in the hurtbox
				hurtbox.entity = self
			else:
				if debug:
					print("HurtBox doesn't have take_damage method")
		else:
			if debug:
				print("Enemy doesn't have a HurtBox node")
	
	# Give time for the scene to initialize
	await get_tree().create_timer(0.5).timeout
	find_player()

func find_player():
	var players = get_tree().get_nodes_in_group("Player")
	if not players.is_empty():
		player = players[0]
	else:
		# No player found logic
		pass

func _process(delta):
	# Increment frame counter for periodic debug messages
	frame_counter = (frame_counter + 1) % 60
	
	# Handle damage flash effect
	if is_flashing:
		flash_timer -= delta
		if flash_timer <= 0:
			is_flashing = false
			
			# Reset shader
			var parent = get_parent()
			var sprite = parent.get_node_or_null("AnimatedSprite2D")
			if sprite:
				# Important: Remove the shader when flash effect is over
				sprite.material = null
				damage_shader.set_shader_parameter("flash_intensity", 0.0)
				
			if debug and frame_counter % 10 == 0:
				print("Damage flash ended")
	
	# Handle invincibility timer
	if is_invincible:
		invincibility_timer -= delta
		if invincibility_timer <= 0:
			is_invincible = false
			
			# DEBUG: Check hurtbox state after invincibility ends
			var parent = get_parent()
			var hurtbox = parent.get_node_or_null("HurtBox")
			if hurtbox and hurtbox.has_node("CollisionShape2D"):
				var hurtbox_collision = hurtbox.get_node("CollisionShape2D")
				if hurtbox_collision.disabled:
					hurtbox_collision.set_deferred("disabled", false)
					if debug:
						print("Fixed disabled hurtbox after invincibility ended")
				else:
					if debug:
						print("Invincibility ended, hurtbox is correctly enabled")
			
			if debug:
				print("Invincibility ended, can take damage again")
			
	# Handle attack cooldown
	if not can_attack:
		attack_timer -= delta
		if attack_timer <= 0:
			can_attack = true
			if debug and frame_counter == 0:
				print("Attack cooldown finished, can attack again")
	
	if not enabled or not player:
		if not player and frame_counter == 0:  # Try to find player every 60 frames
			find_player()
		return
	
	var parent = get_parent()
	if not (parent is CharacterBody2D):
		return
	
	# IMPORTANT: Periodically check if hurtbox is enabled (as a safety measure)
	# This ensures the enemy can always be hit even if something goes wrong
	if frame_counter == 0 and !is_attacking:  # Check every 60 frames
		var hurtbox = parent.get_node_or_null("HurtBox")
		if hurtbox and hurtbox.has_node("CollisionShape2D"):
			var hurtbox_collision = hurtbox.get_node("CollisionShape2D")
			if hurtbox_collision.disabled:
				hurtbox_collision.set_deferred("disabled", false)
				if debug:
					print("CRITICAL FIX: Re-enabled incorrectly disabled hurtbox")
	
	# Track attack animation frames for precise hitbox timing
	if is_attacking:
		var animated_sprite = parent.get_node_or_null("AnimatedSprite2D")
		if animated_sprite and animated_sprite.animation == "Attack":
			# Get the current frame of the attack animation
			var new_frame = animated_sprite.frame
			
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
						
							hitbox.activate()
							if debug:
								print("Activating hitbox on frame: ", frame_one_indexed)
					
					# Deactivate after end frame
					elif frame_one_indexed > hitbox_active_frame_end and hitbox.active:
						var collision_shape = hitbox.get_node_or_null("CollisionShape2D")
						if collision_shape:
							collision_shape.disabled = true
						
						hitbox.deactivate()
						if debug:
							print("Deactivating hitbox after frame: ", frame_one_indexed)
			
			# Check if animation is done
			if animated_sprite.frame >= animated_sprite.sprite_frames.get_frame_count("Attack") - 1 and !animated_sprite.is_playing():
				if debug:
					print("Attack animation completed, ending attack state")
				end_attack(parent)
			# Also check if animation changed unexpectedly
			elif animated_sprite.animation != "Attack":
				if debug:
					print("Attack animation changed unexpectedly to: ", animated_sprite.animation)
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
	var direction = parent.global_position.direction_to(player.global_position)
	var distance = parent.global_position.distance_to(player.global_position)
	
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
		if player and parent.global_position.distance_to(player.global_position) < attack_range * 1.5:
			var direction_to_player = parent.global_position.direction_to(player.global_position)
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
	if player and parent:
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
	if player and "target" in parent:
		parent.target = player
	
	# Double-check we're not already attacking
	if is_attacking:
		if debug:
			print("Already attacking, skipping attack attempt")
		return
	
	# Verify we're actually facing the player before attacking
	var sprite = parent.get_node_or_null("AnimatedSprite2D")
	if sprite and player:
		var direction_to_player = parent.global_position.direction_to(player.global_position)
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
			if sprite and player:
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
		if hitbox.active:
			hitbox.deactivate()
			
		# Important: Set up hitbox to ignore its own hurtbox
		var parent_hurtbox = parent.get_node_or_null("HurtBox")
		if parent_hurtbox:
			# Store reference to parent's hurtbox in the hitbox
			# This will be used to prevent self-damage
			hitbox.set_meta("parent_hurtbox", parent_hurtbox)
			
			if debug:
				print("Set up hitbox to ignore parent's hurtbox")
	
	# Start attack sequence
	is_attacking = true
	current_attack_frame = 0
	
	# Try calling attack() directly
	if parent.has_method("attack"):
		var result = parent.attack()
		
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
			collision_shape.disabled = true
		if hitbox.active:
			hitbox.deactivate()
	
	# Make sure hurtbox is re-enabled when attack ends
	var hurtbox = parent.get_node_or_null("HurtBox")
	if hurtbox and hurtbox.has_node("CollisionShape2D"):
		var hurtbox_collision = hurtbox.get_node("CollisionShape2D")
		hurtbox_collision.set_deferred("disabled", false)
		if debug:
			print("Re-enabled hurtbox at end of attack")

# Function to take damage - called by the hurtbox
func take_damage(damage_amount: float, knockback_force: Vector2 = Vector2.ZERO) -> void:
	var parent = get_parent()
	if parent and enabled:
		# Don't take damage while invincible
		if is_invincible:
			if debug:
				print("Ignoring damage, still invincible")
			return
			
		# Check if coming from own hitbox by checking the distance
		# Enemy's own hitbox will be very close to its hurtbox
		if is_attacking and player:
			var hitbox = parent.get_node_or_null("HitBox")
			if hitbox and hitbox.active:
				# Get distance from hitbox center to player
				var hitbox_to_player_dist = hitbox.global_position.distance_to(player.global_position)
				# Get distance from hitbox center to self
				var hitbox_to_self_dist = hitbox.global_position.distance_to(parent.global_position)
				
				# If hitbox is closer to self than to player, it's likely self-damage
				if hitbox_to_self_dist < hitbox_to_player_dist * 0.5:
					if debug:
						print("Prevented self-damage while attacking - hitbox too close to self")
					return
		
		if debug:
			print("Enemy taking damage: ", damage_amount, " current health: ", current_health)
		
		# Apply damage
		current_health -= damage_amount
		
		# Apply knockback based on resistance
		if knockback_force != Vector2.ZERO and parent is CharacterBody2D:
			parent.velocity += knockback_force * (1.0 - knockback_resistance)
		
		# Make temporarily invincible
		is_invincible = true
		invincibility_timer = invincibility_time
		
		# IMPORTANT: Always ensure the hurtbox is enabled for future hits
		# This is critical if something is incorrectly disabling it
		var hurtbox = parent.get_node_or_null("HurtBox")
		if hurtbox and hurtbox.has_node("CollisionShape2D"):
			var hurtbox_collision = hurtbox.get_node("CollisionShape2D")
			if hurtbox_collision.disabled:
				hurtbox_collision.set_deferred("disabled", false)
				if debug:
					print("Re-enabled disabled hurtbox during damage")
		
		# Play hurt animation if available
		var sprite = parent.get_node_or_null("AnimatedSprite2D")
		if sprite and sprite.sprite_frames.has_animation("Hurt"):
			sprite.play("Hurt")
			
			# Only apply damage flash during hurt animation
			apply_damage_flash()
		else:
			# No hurt animation, just apply flash effect
			apply_damage_flash()
		
		# Check if dead
		if current_health <= 0:
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
			
			# Wait for animation to finish before destroying
			if sprite.is_connected("animation_finished", Callable()):
				await sprite.animation_finished
			else:
				# If no animation signal, wait a short time
				await get_tree().create_timer(1.0).timeout
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
	
	# Ensure hurtbox is enabled - we use invincibility instead of disabling
	var hurtbox = parent.get_node_or_null("HurtBox")
	if hurtbox and hurtbox.has_node("CollisionShape2D"):
		var hurtbox_collision = hurtbox.get_node("CollisionShape2D")
		if hurtbox_collision.disabled:
			hurtbox_collision.set_deferred("disabled", false)
			if debug:
				print("Re-enabled hurtbox during damage")
			
	# Make sure we're not in attacking state to avoid confusion
	if is_attacking:
		end_attack(parent)
