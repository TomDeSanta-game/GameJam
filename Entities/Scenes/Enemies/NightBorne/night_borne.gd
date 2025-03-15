extends EnemyBase

@onready var animated_sprite = $AnimatedSprite2D

# Attack properties
var attack_damage = 25.0
var attack_cooldown = 1.5
var can_attack = true
var attack_range = 60.0
var attack_knockback = 200.0

# Debug variables 
var debug_mode = true
var last_direction = Vector2.ZERO

func _ready():
	# Set base stats
	max_health = 150.0
	current_health = max_health
	max_speed = 80.0
	base_damage = attack_damage
	
	# NightBorne is a boss/mini-boss, so it shouldn't disappear when off-screen
	disappears = false
	
	# Connect animation signals
	if animated_sprite:
		animated_sprite.animation_finished.connect(_on_animation_finished)
	
	if debug_mode:
		print("NightBorne initialized with max_speed: ", max_speed)
		print("NightBorne script inherit check: is EnemyBase? ", self is EnemyBase)
		print("NightBorne method check: has move method? ", has_method("move"))
		
		# Check if we can access parent properties
		print("NightBorne acceleration: ", acceleration)
		print("NightBorne friction: ", friction)
		
		# Check for player in the scene
		var players = get_tree().get_nodes_in_group("Player")
		print("Found ", players.size(), " player(s) in group Player")
		
		if players.size() > 0:
			print("Player position: ", players[0].global_position)
			print("NightBorne position: ", global_position)
			print("Distance to player: ", global_position.distance_to(players[0].global_position))

func _process(_delta):
	# Update animation based on movement
	if is_active:
		if velocity.length() > 10:
			animated_sprite.play("Run")
			if debug_mode and last_direction != velocity.normalized():
				last_direction = velocity.normalized()
				print("NightBorne running with velocity: ", velocity, " direction: ", last_direction)
		else:
			animated_sprite.play("Idle")
			if debug_mode and last_direction != Vector2.ZERO:
				last_direction = Vector2.ZERO
				print("NightBorne idle with velocity: ", velocity)

# Called by the behavior tree attack task
func attack():
	if debug_mode:
		print("NightBorne attack() called, can_attack: ", can_attack)
		if target:
			print("  Target: ", target, " at position: ", target.global_position)
			print("  Distance to target: ", global_position.distance_to(target.global_position))
		else:
			print("  No target set for attack")
	
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
			
			if debug_mode:
				print("NightBorne dealt damage to target: ", attack_damage)
		
		return true
	return false

# Handle taking damage
func take_damage(damage_amount: float, knockback_force: Vector2 = Vector2.ZERO) -> void:
	if not is_active:
		return
	
	# Play hurt animation
	animated_sprite.play("Hurt")
	
	if debug_mode:
		print("NightBorne taking damage: ", damage_amount)
	
	# Call parent method to handle damage logic
	super.take_damage(damage_amount, knockback_force)

# Override death to play death animation
func die() -> void:
	is_active = false
	
	if debug_mode:
		print("NightBorne dying")
	
	# Play death animation
	animated_sprite.play("Death")
	
	# Use SignalBus to notify of death
	SignalBus.enemy_died.emit(self)
	
	# Don't call queue_free() immediately - wait for animation to finish

# Animation finished callback
func _on_animation_finished():
	var animation = animated_sprite.animation
	
	if debug_mode:
		print("NightBorne animation finished: ", animation)
	
	if animation == "Attack":
		# Reset attack cooldown
		await get_tree().create_timer(attack_cooldown).timeout
		can_attack = true
		if debug_mode:
			print("NightBorne attack cooldown finished, can attack again")
	elif animation == "Death":
		# Clean up after death animation finishes
		if debug_mode:
			print("NightBorne death animation finished, cleaning up")
		queue_free()
	elif animation == "Hurt":
		# Return to idle after hurt animation
		if is_active:
			animated_sprite.play("Idle")

# Add this function to ensure it can be called from DirectMovementTest
func direct_move(dir: Vector2, speed: float) -> void:
	if debug_mode:
		print("NightBorne direct_move called with direction: ", dir, " speed: ", speed)
	
	# Instead of calling parent move, implement movement directly
	if not is_active:
		print("NightBorne not active, cannot move")
		return
	
	# Normalize direction vector
	if dir.length() > 0:
		dir = dir.normalized()
	
	if debug_mode:
		print("NightBorne moving - Direction: ", dir, ", Speed: ", speed)
		print("Current velocity before: ", velocity)
	
	# Apply movement directly
	velocity = velocity.move_toward(dir * speed, acceleration)
	
	if debug_mode:
		print("Target velocity: ", dir * speed)
		print("Current velocity after: ", velocity)
	
	# Move and slide
	move_and_slide()
	
	if debug_mode:
		print("Position after move_and_slide: ", global_position)

# Original move call to parent
func move(dir: Vector2, speed: float) -> void:
	if debug_mode:
		print("NightBorne move called, forwarding to direct_move")
	direct_move(dir, speed) 
