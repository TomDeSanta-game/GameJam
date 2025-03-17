extends "res://Entities/Scripts/Enemies/EnemyBase/enemy_base.gd"

# Get access to the EnemyBase class
class_name NightBorneEnemy

@onready var animated_sprite = $AnimatedSprite2D

# Attack properties
var attack_damage = 40.0
var attack_cooldown = 1.5
var can_attack = true
var attack_range = 60.0
var attack_knockback = 200.0

# Debug variables 
var debug_mode = false  # Set to false to disable debug prints
var last_direction = Vector2.ZERO
var recovery_cooldown = 0.0  # Add cooldown for recovery jumps
var is_in_deep_pit = false    # Track if the enemy is in a deep pit
var last_safe_position = Vector2.ZERO  # Store last known safe position for teleportation
var teleport_cooldown = 0.0   # Prevent too frequent teleportation

func _ready():
	# Set base stats
	max_health = 80.0
	current_health = max_health
	max_speed = 80.0
	base_damage = attack_damage
	
	# KNOCKBACK FIX: Further increase knockback resistance for NightBorne
	knockback_resistance = 0.9  # Increased from 0.8 to 0.9 (90% resistance)
	
	# Store initial position as safe position
	last_safe_position = global_position
	
	# Ensure DirectMovementTest component has the same health values
	var direct_movement = get_node_or_null("DirectMovementTest")
	if direct_movement:
		direct_movement.max_health = max_health
		direct_movement.current_health = max_health
		# Also copy knockback resistance to DirectMovementTest
		direct_movement.knockback_resistance = knockback_resistance
		# Disable debug in DirectMovementTest for performance
		direct_movement.debug = false
	
	# NightBorne is a boss/mini-boss, so it shouldn't disappear when off-screen
	disappears = false
	
	# Connect animation signals
	if animated_sprite:
		animated_sprite.animation_finished.connect(_on_animation_finished)

# Cap velocity to prevent falling off screen
func cap_velocity():
	# Cap falling velocity to safer value
	if velocity.y > 300:  # Not as aggressive as before for better performance
		velocity.y = 300
	
	# Only cap extreme horizontal velocity
	if abs(velocity.x) > 300:
		velocity.x = sign(velocity.x) * 300

func _physics_process(delta):
	# CRITICAL: Update safe position if currently in a valid location - lower frequency
	if Engine.get_physics_frames() % 10 == 0:  # Only update every 10 frames
		update_safe_position()
	
	# Apply velocity capping EVERY frame
	cap_velocity()
	
	# Apply screen boundary protection once per physics frame (not twice)
	enforce_screen_bounds()
	
	# Call move_and_slide to apply movement
	move_and_slide()
	
	# Update cooldowns
	if recovery_cooldown > 0:
		recovery_cooldown -= delta
	if teleport_cooldown > 0:
		teleport_cooldown -= delta

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
	# Update animation based on movement
	if is_active:
		if velocity.length() > 10:
			animated_sprite.play("Run")
		else:
			animated_sprite.play("Idle")

# Emergency teleport function for extreme cases
func emergency_teleport():
	# Prevent frequent teleportation
	if teleport_cooldown > 0:
		return false
		
	# If we have a valid last safe position, teleport there
	if last_safe_position != Vector2.ZERO:
		global_position = last_safe_position
		velocity = Vector2.ZERO
		teleport_cooldown = 2.0  # Longer cooldown between teleports
		is_in_deep_pit = false
		return true
	
	# Fallback: Try to teleport to player with offset
	var player = get_tree().get_first_node_in_group("Player")
	if player:
		# Teleport slightly to the left or right of the player
		var offset = Vector2(50, -20)  # Default to right side, 20 pixels above
		if randf() > 0.5:  # 50% chance for left side
			offset.x = -offset.x
			
		global_position = player.global_position + offset
		velocity = Vector2.ZERO
		teleport_cooldown = 2.0  # Longer cooldown between teleports
		is_in_deep_pit = false
		return true
	
	return false

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
			
			# Check if enemy is in a pit (significantly lower than player)
			var player = get_tree().get_first_node_in_group("Player")
			var in_pit = false
			var critical_pit = false
			var extreme_pit = false
			
			if player:
				# Normal pit detection - somewhat deep
				in_pit = global_position.y > player.global_position.y + 120
				
				# Critical pit detection - very deep
				critical_pit = global_position.y > player.global_position.y + 180
				
				# Extreme pit detection - emergency level
				extreme_pit = global_position.y > player.global_position.y + 300 or global_position.y > bottom_edge + 150
				
				# EXTREME CASE: Teleport if in extreme pit
				if extreme_pit and teleport_cooldown <= 0:
					emergency_teleport()
					return
				
				# CRITICAL CASE: If in a critical pit or falling very fast, apply recovery
				if (critical_pit or velocity.y > 400) and recovery_cooldown <= 0:
					is_in_deep_pit = true
					velocity.y = -500  # Strong upward recovery
					velocity.x *= 0.5  # Reduce horizontal velocity during recovery
					recovery_cooldown = 1.0  # Longer cooldown to reduce frequency
				# STANDARD CASE: If in a normal pit and cooldown expired
				elif in_pit and recovery_cooldown <= 0:
					velocity.y = -350  # Strong upward recovery
					recovery_cooldown = 1.0  # Longer cooldown to reduce frequency
					
				# Reset deep pit flag if no longer in a critical pit
				if is_in_deep_pit and !critical_pit:
					is_in_deep_pit = false
			
			# HORIZONTAL BOUNDARIES - Always apply these regardless of cooldown
			if global_position.x < left_edge:
				global_position.x = left_edge
				velocity.x = abs(velocity.x) * 0.5 + 50  # Stronger bounce right
			elif global_position.x > right_edge:
				global_position.x = right_edge
				velocity.x = -abs(velocity.x) * 0.5 - 50  # Stronger bounce left
				
			# VERTICAL BOUNDARIES - Apply with longer cooldowns
			if global_position.y < top_edge:
				global_position.y = top_edge
				velocity.y = abs(velocity.y) * 0.5 + 20  # Bounce down
			elif global_position.y > bottom_edge and recovery_cooldown <= 0:
				global_position.y = bottom_edge
				velocity.y = -350  # Strong upward bounce
				recovery_cooldown = 1.0  # Longer cooldown

# Called by the behavior tree attack task
func attack():
	if can_attack and is_active:
		# Play attack animation
		animated_sprite.play("Attack")
		
		# Prevent attacking again until animation finishes
		can_attack = false
		
		# Deal damage to target
		if target and target.has_method("take_damage"):
			# Calculate direction for knockback
			var knockback_direction = target.global_position - global_position
			knockback_direction = knockback_direction.normalized()
			
			# Apply damage and knockback
			target.take_damage(attack_damage, knockback_direction * attack_knockback)
		
		return true
	return false

# Handle taking damage with improved knockback handling
func take_damage(damage_amount: float, knockback_force: Vector2 = Vector2.ZERO) -> void:
	if not is_active:
		return
	
	# Apply damage to self first
	current_health -= damage_amount
	print("NightBorne: Took damage: ", damage_amount, " Health: ", current_health)
	
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
	
	# ENHANCED PIT PROTECTION: Always convert knockback to horizontal or upward
	if knockback_force.y > 0:  # If knockback would push downward
		# Completely eliminate downward component and convert to upward
		knockback_force.y = -max(150, abs(knockback_force.y) * 0.5)  # Stronger upward component
		print("NightBorne: Converted downward knockback to upward for enhanced pit protection")
	
	# CRITICAL FIX: Forward damage to DirectMovementTest component
	var direct_movement = get_node_or_null("DirectMovementTest")
	if direct_movement and direct_movement.has_method("take_damage"):
		direct_movement.take_damage(damage_amount, knockback_force)
		# We don't return here anymore, so we handle visualization in both places
	
	# Check if we're in the middle of an attack animation
	if animated_sprite.animation == "Attack" and cannot_cancel_attack:
		# Don't play hurt animation, just apply a damage flash if we have one
		if has_node("DirectMovementTest"):
			var direct_movement_component = get_node("DirectMovementTest")
			if direct_movement_component.has_method("apply_damage_flash"):
				direct_movement_component.apply_damage_flash()
	else:
		# Play hurt animation
		animated_sprite.play("Hurt")
	
	# Check if dead after damage is applied
	if current_health <= 0:
		die()
		return
		
	# Call parent method to handle damage logic
	super.take_damage(damage_amount, knockback_force)

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
		# Reset attack cooldown
		await get_tree().create_timer(attack_cooldown).timeout
		can_attack = true
	elif animation == "Death":
		# Clean up after death animation finishes
		queue_free()
	elif animation == "Hurt":
		# Return to idle after hurt animation
		if is_active:
			animated_sprite.play("Idle")

# Add this function to ensure it can be called from DirectMovementTest
func direct_move(dir: Vector2, speed: float) -> void:
	# Instead of calling parent move, implement movement directly
	if not is_active:
		return
	
	# Normalize direction vector
	if dir.length() > 0:
		dir = dir.normalized()
	
	# Apply movement directly
	velocity = velocity.move_toward(dir * speed, acceleration)
	
	# Move and slide
	move_and_slide()

# Original move call to parent
func move(dir: Vector2, speed: float) -> void:
	direct_move(dir, speed) 
