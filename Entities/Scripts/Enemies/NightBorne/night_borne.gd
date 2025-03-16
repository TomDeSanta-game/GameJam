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
var debug_mode = false
var last_direction = Vector2.ZERO

func _ready():
	# Set base stats
	max_health = 80.0
	current_health = max_health
	max_speed = 80.0
	base_damage = attack_damage
	
	# Ensure DirectMovementTest component has the same health values
	var direct_movement = get_node_or_null("DirectMovementTest")
	if direct_movement:
		direct_movement.max_health = max_health
		direct_movement.current_health = max_health
	
	# NightBorne is a boss/mini-boss, so it shouldn't disappear when off-screen
	disappears = false
	
	# Connect animation signals
	if animated_sprite:
		animated_sprite.animation_finished.connect(_on_animation_finished)

func _process(_delta):
	# Update animation based on movement
	if is_active:
		if velocity.length() > 10:
			animated_sprite.play("Run")
		else:
			animated_sprite.play("Idle")

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

# Handle taking damage
func take_damage(damage_amount: float, knockback_force: Vector2 = Vector2.ZERO) -> void:
	if not is_active:
		return
	
	# CRITICAL FIX: Forward damage to DirectMovementTest component
	var direct_movement = get_node_or_null("DirectMovementTest")
	if direct_movement and direct_movement.has_method("take_damage"):
		direct_movement.take_damage(damage_amount, knockback_force)
		return
	
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
