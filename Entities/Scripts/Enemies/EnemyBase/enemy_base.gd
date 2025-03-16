extends CharacterBody2D
class_name EnemyBase

# Basic enemy properties
@export var max_health: float = 40.0  # Decreased from 100.0 to make enemies more RPG-like
@export var current_health: float = 40.0  # Decreased to match max_health
@export var base_damage: float = 20.0  # Increased from 10.0 to make enemies more dangerous
@export var knockback_resistance: float = 0.5

# Movement properties
@export var max_speed: float = 100.0
@export var acceleration: float = 300.0
@export var friction: float = 15.0

# Attack properties
var is_attacking: bool = false
var cannot_cancel_attack: bool = true  # Prevent interruption of attack animations

# Visibility management
@export var disappears: bool = true  # Set to false for bosses or important enemies
var offscreen_timer: Timer

# AI state
var is_active: bool = true
var target = null
var direction: Vector2 = Vector2.ZERO
var is_onscreen: bool = true

func _ready():
	# Initialize the enemy
	current_health = max_health
	
	# Set up the offscreen timer
	offscreen_timer = Timer.new()
	offscreen_timer.wait_time = 3.0
	offscreen_timer.one_shot = true
	offscreen_timer.timeout.connect(_on_offscreen_timer_timeout)
	add_child(offscreen_timer)
	
	# Connect to the VisibleOnScreenNotifier2D
	var notifier = get_node_or_null("VisibleOnScreenNotifier2D")
	if notifier:
		notifier.screen_entered.connect(_on_screen_entered)
		notifier.screen_exited.connect(_on_screen_exited)

# Called when the enemy enters the screen
func _on_screen_entered() -> void:
	is_onscreen = true
	
	if disappears:
		# If the enemy was hidden, show it again
		if not visible:
			show()
		
		# Resume processing
		set_physics_process(true)
		set_process(true)
		
		# Stop the offscreen timer if it's running
		if offscreen_timer.is_stopped() == false:
			offscreen_timer.stop()

# Called when the enemy exits the screen
func _on_screen_exited() -> void:
	is_onscreen = false
	
	if disappears:
		# Start the timer to hide the enemy
		offscreen_timer.start()

# Called when the offscreen timer times out
func _on_offscreen_timer_timeout() -> void:
	if not is_onscreen and disappears:
		# Stop processing to save resources
		set_physics_process(false)
		set_process(false)
		
		# Hide the enemy
		hide()

# Basic movement function that can be called by LimboAI
func move(dir: Vector2, speed: float) -> void:
	if not is_active:
		print("Enemy not active, cannot move")
		return
	
	# Safety check for invalid speed
	if speed <= 0:
		print("Warning: Invalid speed value (", speed, "), using max_speed instead")
		speed = max_speed
	
	# Normalize direction vector
	if dir.length() > 0:
		dir = dir.normalized()
	else:
		print("Warning: Zero direction vector provided to move function")
		# Instead of just returning, we'll apply friction to slow down
		velocity = velocity.move_toward(Vector2.ZERO, friction)
		move_and_slide()
		return
		
	print("EnemyBase.move called - Direction: ", dir, ", Speed: ", speed)
	print("Current velocity before: ", velocity)
	
	# Calculate target velocity
	var target_velocity = dir * speed
	
	# Apply movement with acceleration to smooth it out
	velocity = velocity.move_toward(target_velocity, acceleration)
	
	print("Calculated target velocity: ", target_velocity)
	print("Current velocity after: ", velocity)
	
	# Make sure we're actually moving if we should be
	if velocity.length() < 5 and dir.length() > 0:
		print("Warning: Velocity is very low despite movement command. Forcing minimum velocity.")
		velocity = dir * min(speed * 0.1, 10.0)  # Apply a small immediate force
	
	# Move and slide using Godot's built-in function
	var collision = move_and_slide()
	
	print("Position after move_and_slide: ", global_position)
	print("Collision detected: ", collision)
	
	# Apply friction when not moving
	if dir.length() == 0:
		velocity = velocity.move_toward(Vector2.ZERO, friction)
		print("Applied friction, new velocity: ", velocity)

# Function to take damage
func take_damage(damage_amount: float, knockback_force: Vector2 = Vector2.ZERO) -> void:
	if not is_active:
		return
	
	current_health -= damage_amount
	
	# Apply knockback based on resistance
	if knockback_force != Vector2.ZERO:
		velocity += knockback_force * (1.0 - knockback_resistance)
	
	# Emit signal if SignalBus is available
	if Engine.has_singleton("SignalBus"):
		var signal_bus = Engine.get_singleton("SignalBus")
		signal_bus.enemy_damaged.emit(self, damage_amount)
	
	if current_health <= 0:
		die()

# Function to handle death
func die() -> void:
	is_active = false
	
	# Emit signal if SignalBus is available
	if Engine.has_singleton("SignalBus"):
		var signal_bus = Engine.get_singleton("SignalBus")
		signal_bus.enemy_died.emit(self)
	
	# You can add additional death effects or animations here
	queue_free()

# Function to set the target (usually the player)
func set_target(new_target) -> void:
	target = new_target
	
	# Emit signal if SignalBus is available and target is not null
	if target != null and Engine.has_singleton("SignalBus"):
		var signal_bus = Engine.get_singleton("SignalBus")
		signal_bus.enemy_spotted_player.emit(self, target)

# Function to check if a target is in a specified range
func is_target_in_range(range_distance: float) -> bool:
	if target == null:
		return false
	
	return global_position.distance_to(target.global_position) <= range_distance

# Function to get direction to target
func get_direction_to_target() -> Vector2:
	if target == null:
		return Vector2.ZERO
	
	return (target.global_position - global_position).normalized() 