extends CharacterBody2D
class_name Knight

# Movement parameters
@export var movement_speed: float = 400.0      # Reduced slightly for better control
@export var acceleration: float = 3000.0       # Dramatically increased for instant response
@export var friction: float = 6000.0           # Massively increased to eliminate sliding
@export var jump_velocity: float = -400.0      # Reduced from -500.0 to -400.0 for less powerful jumps

# Jump mechanics
@export var coyote_time: float = 0.15          # Time window player can still jump after leaving a platform
@export var jump_buffer_time: float = 0.15     # Time window to buffer a jump input before landing
var coyote_timer: float = 0.0                  # Timer for tracking coyote time
var jump_buffer_timer: float = 0.0             # Timer for tracking jump buffer
var was_on_floor: bool = false                 # Track if player was on floor last frame
var wants_to_jump: bool = false                # Track if player wants to jump

# Attack parameters
@export var attack_cooldown: float = 0.5
var can_attack: bool = true
var attack_timer: float = 0.0
var hitbox_active_frame_start: int = 8  # Activate hitbox on this frame (counting from 1)
var hitbox_active_frame_end: int = 9    # Deactivate hitbox after this frame (counting from 1)
var current_attack_frame: int = 0       # Track the current frame of the attack animation
var in_attack_state: bool = false       # Flag to track if we're in attack state

# Health parameters
@export var max_health: float = 100.0
@export var current_health: float = 100.0
@export var knockback_resistance: float = 0.8  # Increased from 0.7 to 0.8
@export var damage_reduction: float = 0.7      # Increased from 0.5 to 0.7
@export var invincible_time: float = 1.0
@export var damage_flash_duration: float = 0.3  # Duration of the white flash effect
var is_invincible: bool = false
var invincible_timer: float = 0.0
var is_hurt: bool = false  # Track hurt state

# Health bar animation
var displayed_health: float = 100.0
var health_lerp_speed: float = 3.0

# UI references
var health_bar: ProgressBar
var debug_label: Label
var ui_canvas: CanvasLayer

# State machine
var main_sm

# Get the gravity from the project settings
var gravity = ProjectSettings.get_setting("physics/2d/default_gravity")

@onready var animated_sprite = $AnimatedSprite2D

# Flash effect variables
var flash_tween
var is_flashing: bool = false
var original_modulate: Color
var flash_color: Color = Color(2.0, 2.0, 2.0, 1.0)  # Super bright white for dramatic effect
var flash_iterations: int = 2  # Number of flash pulses

func _ready():
	# Initialize the state machine
	initialize_state_machine()
	
	# Setup health bar UI
	setup_health_bar()
	
	# Store original modulate color
	original_modulate = animated_sprite.modulate
	
	# Connect to animation signals
	if not animated_sprite.animation_finished.is_connected(_on_animation_finished):
		animated_sprite.animation_finished.connect(_on_animation_finished)
	
	# Initialize jump mechanics
	was_on_floor = is_on_floor()
	coyote_timer = 0.0
	jump_buffer_timer = 0.0
	
	# Add to player group for targeting
	add_to_group("Player")
	
	# Create growth system if it doesn't exist
	if not has_node("GrowthSystem"):
		var growth_system = load("res://Entities/Scripts/Player/GrowthSystem.gd").new()
		growth_system.name = "GrowthSystem"
		add_child(growth_system)
	
	# Create chemical mixer if it doesn't exist
	if not has_node("ChemicalMixer"):
		var chemical_mixer = load("res://Entities/Scripts/Player/ChemicalMixer.gd").new()
		chemical_mixer.name = "ChemicalMixer"
		add_child(chemical_mixer)

func setup_health_bar():
	# Create canvas layer for UI elements
	ui_canvas = CanvasLayer.new()
	ui_canvas.layer = 10  # High layer to stay on top
	add_child(ui_canvas)
	
	# Create ProgressBar
	health_bar = ProgressBar.new()
	ui_canvas.add_child(health_bar)
	
	# Position and size the health bar - larger size
	health_bar.set_anchors_preset(Control.PRESET_TOP_LEFT)
	health_bar.offset_left = 10
	health_bar.offset_top = 10
	health_bar.offset_right = 310  # 300 pixels wide (increased from 200)
	health_bar.offset_bottom = 45  # 35 pixels tall (increased from 25)
	health_bar.value = 100
	health_bar.max_value = max_health
	
	# Hide percentage indicator
	health_bar.show_percentage = false
	
	# Set initial style (friendlier red color)
	var style_box = StyleBoxFlat.new()
	style_box.bg_color = Color(0.9, 0.3, 0.3)  # Softer, friendlier red
	style_box.border_width_bottom = 2
	style_box.border_width_top = 2
	style_box.border_width_left = 2
	style_box.border_width_right = 2
	style_box.border_color = Color(0.1, 0.1, 0.1)  # Darker border instead of pure black
	style_box.corner_radius_top_left = 5     
	style_box.corner_radius_top_right = 5
	style_box.corner_radius_bottom_left = 5
	style_box.corner_radius_bottom_right = 5
	
	# Background style
	var bg_style = StyleBoxFlat.new()
	bg_style.bg_color = Color(0.2, 0.2, 0.2, 0.4)  # Lighter, less obtrusive background
	bg_style.border_width_bottom = 2
	bg_style.border_width_top = 2
	bg_style.border_width_left = 2
	bg_style.border_width_right = 2
	bg_style.border_color = Color(0.1, 0.1, 0.1, 0.5)  # Darker border instead of pure black
	bg_style.corner_radius_top_left = 5
	bg_style.corner_radius_top_right = 5
	bg_style.corner_radius_bottom_left = 5
	bg_style.corner_radius_bottom_right = 5
	
	# Apply styles
	health_bar.add_theme_stylebox_override("fill", style_box)
	health_bar.add_theme_stylebox_override("background", bg_style)
	
	# Create debug label
	setup_debug_label()
	
	# Store as instance variable for later access
	displayed_health = current_health

# Setup debug label for displaying debug information
func setup_debug_label():
	# Create debug label
	debug_label = Label.new()
	ui_canvas.add_child(debug_label)
	
	# Position below health bar
	debug_label.set_anchors_preset(Control.PRESET_TOP_LEFT)
	debug_label.offset_left = 10
	debug_label.offset_top = 50  # Just below health bar
	debug_label.offset_right = 310
	debug_label.offset_bottom = 120
	
	# Make more translucent (reduced from 0.7 to 0.5)
	debug_label.modulate = Color(1, 1, 1, 0.7)
	
	# Load JetBrainsMono font
	var font = load("res://assets/Fonts/static/JetBrainsMono-Regular.ttf")
	if font:
		debug_label.add_theme_font_override("font", font)
		debug_label.add_theme_font_size_override("font_size", 14)  # Slightly smaller for monospace
	else:
		pass
	
	# Add a subtle background for the debug text
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.1, 0.1, 0.1, 0.6)  # Semi-transparent dark background
	style.corner_radius_top_left = 5
	style.corner_radius_top_right = 5
	style.corner_radius_bottom_left = 5
	style.corner_radius_bottom_right = 5
	debug_label.add_theme_stylebox_override("normal", style)
	
	# Initial text
	debug_label.text = "Debug Info..."

# State handlers
func idle_start():
	animated_sprite.play("Idle")

func walk_start():
	animated_sprite.play("Run")

func jump_start():
	animated_sprite.play("Jump")
	velocity.y = jump_velocity

func fall_start():
	animated_sprite.play("Fall")

func attack_start():
	print("KNIGHT: Starting attack animation")
	animated_sprite.play("Attack")
	can_attack = false
	in_attack_state = true
	current_attack_frame = 0
	
	# Immediately activate the hitbox for the full duration of the attack
	var hitbox = get_node_or_null("HitBox")
	if hitbox:
		print("KNIGHT: Found hitbox node, activating for attack")
		
		# Position the hitbox based on facing direction
		var collision_shape = hitbox.get_node_or_null("CollisionShape2D")
		if collision_shape:
			# Position the hitbox based on the direction the player is facing
			var facing_left = animated_sprite.flip_h
			var hitbox_offset = abs(collision_shape.position.x)
			
			# Position hitbox on the correct side
			if facing_left:
				collision_shape.position.x = -hitbox_offset
			else:
				collision_shape.position.x = hitbox_offset
			
			print("KNIGHT: Positioned hitbox for attack at: " + str(collision_shape.position) + " facing_left: " + str(facing_left))
			collision_shape.disabled = false
		else:
			print("ERROR: Could not find collision shape in hitbox")
		
		# Set player attack metadata
		hitbox.is_player_hitbox = true
		hitbox.set_meta("player_attack", true)
		hitbox.set_meta("owner_entity", self)
		print("KNIGHT: Set player metadata on hitbox")
		
		# Activate the hitbox
		if hitbox.has_method("activate"):
			hitbox.activate()
			print("KNIGHT: Explicitly activated player hitbox")
		else:
			print("ERROR: Hitbox missing activate method")
	else:
		print("ERROR: Could not find HitBox node for player attack")

func _physics_process(delta):
	# Add gravity
	if not is_on_floor():
		velocity.y += gravity * delta
	
	# Hard reset horizontal velocity when very small to prevent micro-sliding
	if abs(velocity.x) < 5.0:
		velocity.x = 0
	
	# Update coyote time and jump buffer
	update_jump_mechanics(delta)
		
	# Update attack cooldown
	if !can_attack:
		attack_timer += delta
		if attack_timer >= attack_cooldown:
			can_attack = true
			attack_timer = 0.0
	
	# Track attack animation frames for precise hitbox timing
	if in_attack_state and animated_sprite.animation == "Attack":
		# Get the current frame of the attack animation
		var new_frame = animated_sprite.frame
		
		# If the frame changed, update our tracking
		if new_frame != current_attack_frame:
			current_attack_frame = new_frame
			print("KNIGHT: Attack animation frame: " + str(current_attack_frame))
			
			# Check if hitbox is still active
			var hitbox = get_node_or_null("HitBox")
			if hitbox:
				if current_attack_frame >= 0 and current_attack_frame <= 10: # Keep active for most of the animation
					if not hitbox.active:
						print("KNIGHT: Ensuring hitbox remains active during frame " + str(current_attack_frame))
						hitbox.activate()
				elif hitbox.active: # Last frame - deactivate
					print("KNIGHT: Deactivating hitbox at end of attack animation")
					hitbox.deactivate()
	
	# Handle invincibility timer and visual effects
	if is_invincible:
		invincible_timer -= delta
		
		# Blink effect during invincibility (after the initial flash)
		if invincible_timer <= invincible_time - damage_flash_duration and !is_flashing:
			# Create a blinking effect during invincibility
			var blink_rate = 8.0  # Blinks per second
			var should_show = fmod(invincible_timer * blink_rate, 1.0) > 0.5
			animated_sprite.visible = should_show
		
		if invincible_timer <= 0:
			is_invincible = false
			is_hurt = false
			animated_sprite.visible = true  # Ensure visibility
			animated_sprite.modulate = original_modulate  # Reset color

	# Get movement direction using custom actions
	var direction = Input.get_action_strength("right") - Input.get_action_strength("left")
	
	# Handle movement with immediate response
	if direction:
		# Use steeper acceleration when changing direction
		var target_speed = direction * movement_speed
		if (velocity.x > 0 and direction < 0) or (velocity.x < 0 and direction > 0):
			# Changing direction - use even higher acceleration
			velocity.x = move_toward(velocity.x, target_speed, acceleration * 2 * delta)
		else:
			velocity.x = move_toward(velocity.x, target_speed, acceleration * delta)
		
		if direction < 0:
			animated_sprite.flip_h = true
		else:
			animated_sprite.flip_h = false
	else:
		# Apply extreme friction when not moving for immediate stop
		velocity.x = move_toward(velocity.x, 0, friction * delta)
	
	move_and_slide()
	
	# Update health bar
	update_health_bar(delta)
	
	# Update debug label
	update_debug_label()

# Function to update health bar appearance and animation
func update_health_bar(delta):
	if health_bar == null:
		return
		
	# Smooth animation for health loss
	displayed_health = lerp(displayed_health, current_health, delta * health_lerp_speed)
	health_bar.value = displayed_health
	
	# Update color based on health percentage
	var health_percent = current_health / max_health
	var style = health_bar.get_theme_stylebox("fill") as StyleBoxFlat
	
	if style:
		if health_percent <= 0.1:
			# Less than 10% health - deeper but still friendly red
			style.bg_color = Color(0.95, 0.2, 0.2)
		elif health_percent <= 0.5:
			# Less than 50% health - softer yellow
			style.bg_color = Color(1.0, 0.8, 0.2)
		else:
			# Above 50% health - friendly red
			style.bg_color = Color(0.9, 0.3, 0.3)

# Function to handle taking damage from enemies
func take_damage(damage_amount: float, knockback_force: Vector2 = Vector2.ZERO) -> void:
	# Check if player is currently invincible
	if is_invincible:
		return
	
	# Cancel any existing animations or effects
	if flash_tween and flash_tween.is_valid():
		flash_tween.kill()
	
	# Apply damage reduction with better precision 
	var reduced_damage = round(damage_amount * (1.0 - damage_reduction))
	# Ensure minimum damage is applied to avoid inconsistencies
	reduced_damage = max(reduced_damage, 1.0)
	
	# Apply damage
	current_health = max(current_health - reduced_damage, 0)  # Prevent negative health
	
	# Apply knockback with resistance
	if knockback_force != Vector2.ZERO:
		velocity += knockback_force * (1.0 - knockback_resistance)
	
	# Set hurt state
	is_hurt = true
	
	# Make sure we're visible for the initial flash
	animated_sprite.visible = true
	
	# Apply damage flash effect first
	apply_damage_effect()
	
	# Trigger invincibility
	is_invincible = true
	invincible_timer = invincible_time
	
	# Play hurt animation - safely check and change state
	if main_sm and main_sm.has_method("change_state"):
		var hurt_state = "hurt"
		if main_sm.has_method("get_state_name") and main_sm.get_state_name() != hurt_state:
			main_sm.change_state(main_sm.states.hurt)
		elif main_sm.active_state and main_sm.active_state.name != hurt_state:
			main_sm.change_state(main_sm.states.hurt)
	else:
		# Fallback if state machine isn't available
		animated_sprite.play("Hurt")
	
	# Check if player is dead
	if current_health <= 0:
		die()
	
	# Emit signal for UI updates
	SignalBus.player_damaged.emit(self, reduced_damage)
	
	# Shrink the player using the growth system when taking damage
	var growth_system = get_node_or_null("GrowthSystem")
	if growth_system and growth_system.has_method("_on_player_damaged"):
		growth_system._on_player_damaged(reduced_damage)

# Apply white flash damage effect using advanced tweening
func apply_damage_effect() -> void:
	# Cancel any existing tween
	if flash_tween and flash_tween.is_valid():
		flash_tween.kill()
	
	# Store the original color if not already stored
	if original_modulate == Color():
		original_modulate = animated_sprite.modulate
	
	# Make sure we're visible
	animated_sprite.visible = true
	
	# Set the sprite to flash white
	animated_sprite.modulate = flash_color
	is_flashing = true
	
	# Create a multi-stage flash effect
	flash_tween = create_tween()
	
	# Quick flash to white
	flash_tween.tween_property(animated_sprite, "modulate", flash_color, damage_flash_duration * 0.2)
	
	# Pulse multiple times for more impact
	for i in range(flash_iterations):
		# Fade partway back
		flash_tween.tween_property(animated_sprite, "modulate", 
			Color(1.5, 1.0, 1.0, 1.0), damage_flash_duration * 0.2)
		# Flash white again
		flash_tween.tween_property(animated_sprite, "modulate", 
			flash_color, damage_flash_duration * 0.2)
	
	# Fade back to normal
	flash_tween.tween_property(animated_sprite, "modulate", 
		original_modulate, damage_flash_duration * 0.2)
	
	# Mark flash as complete
	flash_tween.tween_callback(func():
		is_flashing = false
		# Ensure color is fully reset
		animated_sprite.modulate = original_modulate
	)
	
	flash_tween.play()

# Function to handle player death
func die() -> void:
	# Change to death state - safely check and change state
	if main_sm and main_sm.has_method("change_state"):
		var death_state = "death"
		if main_sm.has_method("get_state_name") and main_sm.get_state_name() != death_state:
			main_sm.change_state(main_sm.states.death)
		elif main_sm.active_state and main_sm.active_state.name != death_state:
			main_sm.change_state(main_sm.states.death)
	else:
		# Fallback if state machine isn't available
		animated_sprite.play("Death")
	
	# Emit signal
	SignalBus.player_died.emit(self)
	
	# Reset growth using the growth system
	var growth_system = get_node_or_null("GrowthSystem")
	if growth_system and growth_system.has_method("_on_player_died"):
		growth_system._on_player_died()

func _unhandled_input(event):
	if !main_sm:
		return
		
	if event.is_action_pressed("jump"):
		# If on floor or in coyote time, jump immediately
		if is_on_floor() or coyote_timer > 0:
			if !is_in_state("attack") and !is_in_state("hurt"):
				execute_jump()
		else:
			# Not on floor - buffer the jump for a short time
			jump_buffer_timer = jump_buffer_time
			wants_to_jump = true
	
	elif event.is_action_pressed("attack") and can_attack:
		# Debug message to confirm attack input was received
		print("KNIGHT: Attack button pressed, dispatching attack")
		main_sm.dispatch("attack")
		
	elif event.is_action_pressed("mix_chemicals"):
		# Try to mix chemicals if we have the chemical mixer
		var chemical_mixer = get_node_or_null("ChemicalMixer")
		if chemical_mixer and chemical_mixer.has_method("mix_chemicals"):
			var success = chemical_mixer.mix_chemicals()
			if success:
				print("KNIGHT: Mixed chemicals successfully")
			else:
				print("KNIGHT: Failed to mix chemicals")

# State machine setup
func initialize_state_machine():
	# Create the state machine
	main_sm = LimboHSM.new()
	add_child(main_sm)
	
	# Create states with direct method chaining
	var idle_state = LimboState.new().named("idle").call_on_enter(idle_start).call_on_update(idle_update)
	var walk_state = LimboState.new().named("walk").call_on_enter(walk_start).call_on_update(walk_update)
	var jump_state = LimboState.new().named("jump").call_on_enter(jump_start).call_on_update(jump_update)
	var fall_state = LimboState.new().named("fall").call_on_enter(fall_start).call_on_update(fall_update)
	var attack_state = LimboState.new().named("attack").call_on_enter(attack_start).call_on_update(attack_update).call_on_exit(attack_end)
	var hurt_state = LimboState.new().named("hurt").call_on_enter(hurt_start).call_on_update(hurt_update)
	
	# Add states to the state machine
	main_sm.add_child(idle_state)
	main_sm.add_child(walk_state)
	main_sm.add_child(jump_state)
	main_sm.add_child(fall_state)
	main_sm.add_child(attack_state)
	main_sm.add_child(hurt_state)
	
	# Initialize the state machine
	main_sm.initialize(self)
	main_sm.initial_state = idle_state
	
	# Define transitions
	# From idle state
	main_sm.add_transition(idle_state, walk_state, "walk")
	main_sm.add_transition(idle_state, jump_state, "jump")
	main_sm.add_transition(idle_state, fall_state, "fall")
	
	# From walk state
	main_sm.add_transition(walk_state, idle_state, "idle")
	main_sm.add_transition(walk_state, jump_state, "jump")
	main_sm.add_transition(walk_state, fall_state, "fall")
	
	# From jump state
	main_sm.add_transition(jump_state, fall_state, "fall")
	main_sm.add_transition(jump_state, idle_state, "land_idle")
	main_sm.add_transition(jump_state, walk_state, "land_walk")
	
	# From fall state
	main_sm.add_transition(fall_state, idle_state, "land_idle")
	main_sm.add_transition(fall_state, walk_state, "land_walk")
	
	# From any state to attack state
	main_sm.add_transition(main_sm.ANYSTATE, attack_state, "attack")
	
	# From attack state back to others
	main_sm.add_transition(attack_state, idle_state, "idle")
	main_sm.add_transition(attack_state, walk_state, "walk")
	main_sm.add_transition(attack_state, jump_state, "jump")
	main_sm.add_transition(attack_state, fall_state, "fall")
	
	# Add transitions to/from hurt state
	main_sm.add_transition(main_sm.ANYSTATE, hurt_state, "hurt")
	main_sm.add_transition(hurt_state, idle_state, "recovery")
	main_sm.add_transition(hurt_state, walk_state, "recovery_walk")
	main_sm.add_transition(hurt_state, jump_state, "recovery_jump")
	main_sm.add_transition(hurt_state, fall_state, "recovery_fall")
	
	# Start the state machine
	main_sm.set_active(true)

# State handlers - separate functions for each state

# Idle state handlers
func idle_update(_delta: float):
	if abs(velocity.x) > 10.0:
		main_sm.dispatch("walk")
	elif !is_on_floor():
		if velocity.y < 0:
			main_sm.dispatch("jump")
		else:
			main_sm.dispatch("fall")

# Walk state handlers
func walk_update(_delta: float):
	if abs(velocity.x) < 10.0:
		main_sm.dispatch("idle")
	elif !is_on_floor():
		if velocity.y < 0:
			main_sm.dispatch("jump")
		else:
			main_sm.dispatch("fall")

# Jump state handlers
func jump_update(_delta: float):
	if is_on_floor():
		if abs(velocity.x) > 10.0:
			main_sm.dispatch("land_walk")
		else:
			main_sm.dispatch("land_idle")
	elif velocity.y >= 0:
		main_sm.dispatch("fall")

# Fall state handlers
func fall_update(_delta: float):
	if is_on_floor():
		if abs(velocity.x) > 10.0:
			main_sm.dispatch("land_walk")
		else:
			main_sm.dispatch("land_idle")

# Attack state handlers
func attack_update(_delta: float):
	if !animated_sprite.is_playing() or animated_sprite.animation != "Attack":
		if is_on_floor():
			if abs(velocity.x) > 10.0:
				main_sm.dispatch("walk")
			else:
				main_sm.dispatch("idle")
		else:
			if velocity.y < 0:
				main_sm.dispatch("jump")
			else:
				main_sm.dispatch("fall")

# Called when attack animation ends
func attack_end():
	print("KNIGHT: Exiting attack state")
	in_attack_state = false
	current_attack_frame = 0
	
	# Ensure hitbox is deactivated when exiting attack state
	var hitbox = get_node_or_null("HitBox")
	if hitbox:
		var collision_shape = hitbox.get_node_or_null("CollisionShape2D")
		if collision_shape:
			collision_shape.disabled = true
		
		if hitbox.active:
			print("KNIGHT: Deactivating hitbox in attack_end")
			hitbox.deactivate()

# Utility functions
func is_on_ground() -> bool:
	return is_on_floor()

func is_moving() -> bool:
	return abs(velocity.x) > 10.0

func is_jumping() -> bool:
	return velocity.y < 0 and not is_on_floor()

func is_falling() -> bool:
	return velocity.y > 0 and not is_on_floor()

func is_attacking() -> bool:
	return is_in_state("attack")

# Helper method to get the current state name safely
func get_current_state_name() -> String:
	if main_sm == null:
		return ""
		
	if main_sm.has_method("get_state_name"):
		return main_sm.get_state_name()
	
	if main_sm.has_signal("state_changed") and main_sm.active_state:
		return main_sm.active_state.name
		
	# Fallback
	return ""

# Function to check if knight is in a specific state
func is_in_state(state_name: String) -> bool:
	return get_current_state_name() == state_name 

# Update debug label with current information
func update_debug_label():
	if debug_label == null:
		return
		
	var state_name = get_current_state_name()
	var health_percent = int((current_health / max_health) * 100)
	var pos_x = int(global_position.x)
	var pos_y = int(global_position.y)
	
	var coyote_active = "Yes" if coyote_timer > 0 else "No"
	var jump_buffer_active = "Yes" if jump_buffer_timer > 0 else "No"
	
	# Find the closest enemy to display its animation
	var enemy_animation = "None"
	var enemy_health = "N/A"
	var enemy_state = "N/A"
	var enemy_invincible = "No"
	var enemies = get_tree().get_nodes_in_group("Enemy")
	var closest_enemy = null
	var closest_dist = 1000000.0
	
	for enemy in enemies:
		var dist = global_position.distance_to(enemy.global_position)
		if dist < closest_dist:
			closest_dist = dist
			closest_enemy = enemy
	
	if closest_enemy != null:
		var sprite = closest_enemy.get_node_or_null("AnimatedSprite2D")
		if sprite:
			enemy_animation = sprite.animation
			
		# Try to get health information
		var direct_movement = closest_enemy.get_node_or_null("DirectMovementTest")
		if direct_movement:
			enemy_health = str(direct_movement.current_health) + "/" + str(direct_movement.max_health)
			enemy_state = "Attacking" if direct_movement.is_attacking else "Normal"
			enemy_invincible = "Yes" if direct_movement.is_invincible else "No"
	
	debug_label.text = "Health: " + str(current_health) + "/" + str(max_health) + " (" + str(health_percent) + "%)" + \
					  "\nState: " + state_name + \
					  "\nPosition: X=" + str(pos_x) + ", Y=" + str(pos_y) + \
					  "\nVelocity: " + str(velocity.length()) + " px/s" + \
					  "\nCoyote Time: " + coyote_active + " (" + str(coyote_timer).pad_decimals(2) + ")" + \
					  "\nJump Buffer: " + jump_buffer_active + " (" + str(jump_buffer_timer).pad_decimals(2) + ")" + \
					  "\nEnemy Animation: " + enemy_animation + \
					  "\nEnemy Health: " + enemy_health + \
					  "\nEnemy State: " + enemy_state + \
					  "\nEnemy Invincible: " + enemy_invincible

# Add a hurt start function
func hurt_start():
	animated_sprite.play("Hurt")
	
	# Ensure visibility during hurt animation
	animated_sprite.visible = true

# Add a hurt update function
func hurt_update(_delta: float):
	# Only transition out of hurt state when the animation completes or if we're no longer hurt
	if (!animated_sprite.is_playing() or animated_sprite.animation != "Hurt") and not is_hurt:
		# Transition to the appropriate state based on current conditions
		if is_on_floor():
			if abs(velocity.x) > 10.0:
				main_sm.dispatch("recovery_walk")
			else:
				main_sm.dispatch("recovery")
		else:
			if velocity.y < 0:
				main_sm.dispatch("recovery_jump")
			else:
				main_sm.dispatch("recovery_fall")

# Handle animation completion
func _on_animation_finished():
	# Handle attack animation completion
	if in_attack_state and animated_sprite.animation == "Attack":
		print("KNIGHT: Attack animation completed")
		attack_finish()
		return
	
	# If we're in the hurt state and the animation finished, potentially recover
	if is_in_state("hurt") and animated_sprite.animation == "Hurt":
		# Only recover if the flash effect is done
		if not is_flashing:
			is_hurt = false

# Update coyote time and jump buffer mechanics
func update_jump_mechanics(delta):
	# Check floor status for coyote time
	var is_on_floor_now = is_on_floor()
	
	# Start coyote timer when leaving the ground
	if was_on_floor and !is_on_floor_now:
		coyote_timer = coyote_time
	
	# Decrease coyote timer when in air
	if !is_on_floor_now and coyote_timer > 0:
		coyote_timer -= delta
	
	# Reset coyote timer when on floor
	if is_on_floor_now:
		coyote_timer = 0.0
	
	# Decrease jump buffer timer
	if jump_buffer_timer > 0:
		jump_buffer_timer -= delta
		
		# Try to jump if we've landed or in coyote time
		if (is_on_floor_now or coyote_timer > 0) and !is_in_state("attack") and !is_in_state("hurt"):
			execute_jump()
			jump_buffer_timer = 0.0
	
	# Remember floor status for next frame
	was_on_floor = is_on_floor_now

# Execute the actual jump
func execute_jump():
	velocity.y = jump_velocity
	if main_sm:
		main_sm.dispatch("jump")
	else:
		jump_start()

func attack_finish():
	print("KNIGHT: Attack animation finished, transitioning state")
	
	# Get the main state machine if we need to transition
	if main_sm:
		if is_on_floor():
			print("KNIGHT: Transitioning to idle state after attack")
			main_sm.dispatch("idle")
		else:
			print("KNIGHT: Transitioning to fall state after attack")
			main_sm.dispatch("fall")
	
	in_attack_state = false
	current_attack_frame = 0
	
	# Explicitly deactivate hitbox when attack animation ends
	var hitbox = get_node_or_null("HitBox")
	if hitbox:
		if hitbox.active:
			print("KNIGHT: Explicitly deactivating hitbox in attack_finish")
			hitbox.deactivate()
		else:
			print("KNIGHT: Hitbox already inactive in attack_finish")
			
		# Clear attack-specific metadata
		if hitbox.has_meta("player_attack"):
			hitbox.remove_meta("player_attack")
			
	# Start cooldown timer
	attack_timer = 0.0
	
	print("KNIGHT: Attack sequence completed")
