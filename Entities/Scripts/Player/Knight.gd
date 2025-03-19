extends CharacterBody2D
# Removed class_name Knight to avoid conflict with global script class

# Movement parameters
@export var movement_speed: float = 280.0     # Maintain high speed for fast movement
@export var acceleration: float = 3000.0      # Dramatically increased for near-instant acceleration
@export var friction: float = 3000.0          # Dramatically increased for near-instant deceleration
@export var jump_velocity: float = -400.0
@export var air_control: float = 0.6          # Increased for more responsive air control
@export var gravity_multiplier: float = 1.5   # Added for faster falling

# Movement interpolation parameters
var velocity_dampening: float = 0.01          # Almost no dampening for instant response
var previous_direction: float = 0.0
var target_velocity: Vector2 = Vector2.ZERO

# IMPROVED: Movement feel tuning parameters
@export_group("Movement Feel")
@export var ground_acceleration_multiplier: float = 1.2   # Increased for faster ground movement
@export var direction_change_penalty: float = 0.9         # Higher value = faster direction changes
@export var landing_impact_reduction: float = 0.95        # Less landing impact for more responsive control
@export var max_fall_speed: float = 600.0                # Cap the falling speed

# Jump mechanics
@export_group("Jump Mechanics")
@export var coyote_time: float = 0.15           # Increased for better jump feel
@export var jump_buffer_time: float = 0.15      # Increased for more forgiving jump timing
@export var jump_cut_height: float = 0.5        # How much to cut jump when button released
var coyote_timer: float = 0.0
var jump_buffer_timer: float = 0.0
var was_on_floor: bool = false
var wants_to_jump: bool = false
var is_jump_cut: bool = false                   # Track if player cut jump height

# Dark Souls stamina system
var max_stamina: float = 100.0
var current_stamina: float = 100.0
var stamina_regen_rate: float = 10.0            # Slower regen rate
var stamina_regen_delay: float = 1.0
var stamina_regen_timer: float = 0.0
var is_stamina_regenerating: bool = true
var is_stamina_depleted: bool = false

# Dark Souls dodge roll
var is_dodge_rolling: bool = false
var dodge_roll_speed: float = 400.0
var dodge_roll_duration: float = 0.4
var dodge_roll_cooldown: float = 0.5
var dodge_roll_timer: float = 0.0
var dodge_roll_cooldown_timer: float = 0.0
var dodge_roll_stamina_cost: float = 25.0
var dodge_roll_i_frames: float = 0.25           # Invincibility frames during roll
var dodge_roll_direction: float = 1.0

# Attack parameters
@export var attack_cooldown: float = 0.8        # Slower attack rate for more deliberate combat
@export var attack_damage: float = 40.0
var can_attack: bool = true
var attack_timer: float = 0.0
var hitbox_active_frame_start: int = 2          # Start hitbox earlier in animation
var hitbox_active_frame_end: int = 5            # End hitbox earlier to match animation
var current_attack_frame: int = 0
var in_attack_state: bool = false
var light_attack_stamina_cost: float = 15.0
var heavy_attack_stamina_cost: float = 35.0
var is_heavy_attack: bool = false

# Health parameters
@export var max_health: float = 100.0
var current_health: float = 100.0
@export var knockback_resistance: float = 0.7
@export var damage_reduction: float = 0.6
@export var invincible_time: float = 1.0
@export var damage_flash_duration: float = 0.3
var is_invincible: bool = false
var invincible_timer: float = 0.0
var is_hurt: bool = false

# Estus Flask healing (Dark Souls)
var max_estus_charges: int = 5
var current_estus_charges: int = 5
var estus_heal_amount: float = 40.0
var is_drinking_estus: bool = false
var estus_drink_duration: float = 1.2
var estus_drink_timer: float = 0.0

# Souls system (experience)
var souls_count: int = 0
var souls_dropped_on_death: int = 0
var souls_drop_position: Vector2 = Vector2.ZERO
var dropped_souls_scene = null                  # Reference to the dropped souls scene

# Health bar animation
var displayed_health: float = 100.0
var health_lerp_speed: float = 3.0

# Respawn system
var respawn_point: Vector2 = Vector2.ZERO
var is_dead: bool = false
var death_timer: float = 0.0
var death_duration: float = 3.0

# State machine
var main_sm

# Get the gravity from the project settings
var gravity = ProjectSettings.get_setting("physics/2d/default_gravity")

@onready var animated_sprite = $AnimatedSprite2D
@onready var health_bar = $CanvasLayer/HealthBar
@onready var stamina_bar = $CanvasLayer/StaminaBar

# Fix missing variable declarations
var anim_player
var sprite

# Flash effect variables
var flash_tween
var is_flashing: bool = false
var original_modulate: Color
var flash_color: Color = Color(2.0, 2.0, 2.0, 1.0)
var flash_iterations: int = 2

# Animation states
enum AnimState { IDLE, RUN, JUMP, FALL, ATTACK, HURT, DODGE, HEAL, DEAD }
var current_anim_state = AnimState.IDLE

# Debug settings
var debug_enabled: bool = true

# Growth and chemical mechanics
@export var max_chemicals: int = 5
var collected_chemicals = []
var growth_system = null

# At the top of the file, add a tracking variable
var e_key_was_pressed = false
var current_frame = 0

# Animation variables
var animation_blend_speed: float = 0.15       # Added for smoother animation transitions
var animation_locked: bool = false            # Prevent certain animations from being interrupted

# Add a max time for hurt state to prevent getting stuck
var hurt_max_duration: float = 0.2  # Significantly reduced from 0.5 to make hurt state shorter
var hurt_timer: float = 0.0

func _ready():
	print("KNIGHT: Starting initialization...")
	
	# Add self to "Player" group for easier lookup
	if not is_in_group("Player"):
		add_to_group("Player")
	
	# IMPROVED: Collision setup in one place with clear purpose
	setup_collision_layers()
	
	# Print controls for debugging
	print("KNIGHT: Controls - A/D or Arrow Keys for movement, Space/W for jump, E for attack, Q/Shift for dodge, H for heal")
	
	# Set up input actions if they don't exist
	if not InputMap.has_action("attack"):
		InputMap.add_action("attack")
		var event = InputEventKey.new()
		event.keycode = KEY_E
		InputMap.action_add_event("attack", event)
		print("KNIGHT: Created attack input action bound to E key")
	
	# Make health and stamina bars smaller
	# Health bar scaling
	if health_bar:
		# Scale the health bar to 70% of its original size
		health_bar.scale = Vector2(0.7, 0.7)
		
		# Adjust position to keep it aligned after scaling
		var current_position = health_bar.position
		health_bar.position = Vector2(current_position.x * 0.7, current_position.y)
		
		print("KNIGHT: Health bar size adjusted")
	
	# Stamina bar scaling
	if stamina_bar:
		# Scale the stamina bar to 70% of its original size
		stamina_bar.scale = Vector2(0.7, 0.7)
		
		# Adjust position to keep it aligned after scaling
		var current_position = stamina_bar.position
		stamina_bar.position = Vector2(current_position.x * 0.7, current_position.y)
		
		print("KNIGHT: Stamina bar size adjusted")
	
	# Initialize jump mechanics
	was_on_floor = is_on_floor()
	coyote_timer = 0.0
	jump_buffer_timer = 0.0
	
	# Store original modulate color for the sprite
	if animated_sprite:
		original_modulate = animated_sprite.modulate
		# Connect to animation signals
		if not animated_sprite.animation_finished.is_connected(_on_animation_finished):
			animated_sprite.animation_finished.connect(_on_animation_finished)
	
	print("KNIGHT: Basic initialization complete")
	
	# Call setup other systems
	setup_other_systems()

# NEW: Centralized collision setup for clarity and maintenance
func setup_collision_layers():
	# Set player collision properties
	collision_layer = 2    # Player layer
	collision_mask = 1     # World layer - physics objects player collides with
	
	# Set proper collision layers for hitbox in one place
	var knight_hitbox = get_node_or_null("HitBox")
	if knight_hitbox:
		knight_hitbox.collision_layer = 16  # Layer 16 for player hitboxes
		knight_hitbox.collision_mask = 8    # Mask 8 to detect enemy hurtboxes
		
		# Ensure hitbox is set up properly
		knight_hitbox.is_player_hitbox = true
		knight_hitbox.debug = true
		
		# Connect hitbox signals
		if not knight_hitbox.is_connected("area_entered", _on_hitbox_area_entered):
			knight_hitbox.area_entered.connect(_on_hitbox_area_entered)
		
		# Ensure collision shape is disabled until attack
		var collision_shape = knight_hitbox.get_node_or_null("CollisionShape2D")
		if collision_shape:
			collision_shape.disabled = true
			
		print("KNIGHT: Hitbox collision set up successfully")
	
	# Set proper collision layers for hurtbox
	var knight_hurtbox = get_node_or_null("HurtBox")
	if knight_hurtbox:
		# Make sure the property exists before setting it
		if "is_player_hurtbox" in knight_hurtbox:
			knight_hurtbox.is_player_hurtbox = true
		
		knight_hurtbox.collision_layer = 8   # Layer 8 for player hurtboxes
		knight_hurtbox.collision_mask = 16   # Mask 16 to detect enemy hitboxes
		
		# Connect hurtbox signals
		if not knight_hurtbox.is_connected("area_entered", _on_hurtbox_area_entered):
			knight_hurtbox.area_entered.connect(_on_hurtbox_area_entered)
		
		print("KNIGHT: Hurtbox collision set up successfully")
	
	print("KNIGHT: Collision setup complete")

# Function to set up other systems
func setup_other_systems():
	# Set up GrowthSystem
	if not get_node_or_null("GrowthSystem"):
		var growth_system_class = ClassDB.class_exists("GrowthSystem")
		if not growth_system_class:
			# Try to load the class script
			var growth_system_script = load("res://Systems/Scripts/GrowthSystem/GrowthSystem.gd")
			if growth_system_script:
				growth_system = Node.new()
				growth_system.set_script(growth_system_script)
				growth_system.name = "GrowthSystem"
				call_deferred("add_child", growth_system)
				print("KNIGHT: Created GrowthSystem from script")
			else:
				print("KNIGHT: GrowthSystem script not found - skipping")
		else:
			growth_system = GrowthSystem.new()
			call_deferred("add_child", growth_system)
			print("KNIGHT: Created new GrowthSystem")
	else:
		print("KNIGHT: GrowthSystem already exists")
	
	# Initialize the state machine
	initialize_state_machine()
	
	# Properly initialize animation player and sprite references
	anim_player = get_node_or_null("AnimationPlayer")
	sprite = get_node_or_null("Sprite2D")
	
	# Connect to animation signals with clean new connection
	if animated_sprite:
		# Clear any existing connections to prevent duplicates
		if animated_sprite.animation_finished.is_connected(_on_animation_finished):
			animated_sprite.animation_finished.disconnect(_on_animation_finished)
	
	# Connect to animation signals with clean new connection
	animated_sprite.animation_finished.connect(_on_animation_finished)
	
	print("KNIGHT: Connected animation_finished signal")
	print("KNIGHT: Animation frames available:", animated_sprite.sprite_frames.get_animation_names())
	
	# Store original modulate color for the sprite
	original_modulate = animated_sprite.modulate
	
	print("KNIGHT: Other systems initialized")

# Move these functions before _physics_process to fix the parse errors
func handle_dodge_roll(delta):
	# Continue the dodge roll
	if dodge_roll_timer > 0:
		dodge_roll_timer -= delta
		
		# Apply dodge roll velocity
		velocity.x = dodge_roll_direction * dodge_roll_speed
		
		# End dodge roll when timer expires
		if dodge_roll_timer <= 0:
			is_dodge_rolling = false
			# Start cooldown
			dodge_roll_cooldown_timer = dodge_roll_cooldown
	
	# Apply gravity but no other input during roll
	if not is_on_floor():
		velocity.y += gravity * delta

func handle_estus_drinking(delta):
	# Continue the estus drinking animation
	if estus_drink_timer > 0:
		estus_drink_timer -= delta
		
		# Apply very slow movement during drinking
		velocity.x = move_toward(velocity.x, 0, friction * 2 * delta)
		
		# End estus drinking when timer expires
		if estus_drink_timer <= 0:
			is_drinking_estus = false
			
			# Apply the healing
			heal(estus_heal_amount)

func _physics_process(delta):
	# Don't process when dead
	if is_dead:
		handle_death(delta)
		return
	
	# Update all timers
	update_timers(delta)
	
	# ==========================================
	# SIMPLIFIED STATE MANAGEMENT & INPUT HANDLING
	# ==========================================
	
	# Basic input gathering - use is_action_pressed for smoother input
	var left_pressed = Input.is_action_pressed("ui_left") or Input.is_key_pressed(KEY_A)
	var right_pressed = Input.is_action_pressed("ui_right") or Input.is_key_pressed(KEY_D)
	var jump_just_pressed = Input.is_action_just_pressed("ui_up") or Input.is_key_pressed(KEY_SPACE) or Input.is_key_pressed(KEY_W)
	var jump_released = Input.is_action_just_released("ui_up") or Input.is_action_just_released("ui_accept") or Input.is_action_just_released("jump")
	var attack_just_pressed = Input.is_action_just_pressed("ui_select") or Input.is_key_pressed(KEY_E)
	var dodge_just_pressed = Input.is_action_just_pressed("ui_cancel") or Input.is_key_pressed(KEY_Q) or Input.is_key_pressed(KEY_SHIFT)
	var heal_just_pressed = Input.is_action_just_pressed("ui_home") or Input.is_key_pressed(KEY_H)
	
	# Get input direction (-1 for left, 1 for right, 0 for none)
	var input_direction = 0
	if left_pressed:
		input_direction -= 1
	if right_pressed:
		input_direction += 1
	
	# ==========================================
	# HANDLE MOVEMENT & ACTIONS BASED ON STATE PRIORITY
	# ==========================================
	
	# STATE 1: Dead - already handled above
	
	# STATE 2: Hurt - No movement or actions
	if is_hurt:
		velocity.x = move_toward(velocity.x, 0, friction * delta)
		
		# Safety timer to prevent getting stuck in hurt state
		hurt_timer -= delta
		if hurt_timer <= 0:
			is_hurt = false
			animation_locked = false
			if debug_enabled:
				print("KNIGHT: Hurt state cleared by safety timer")
	
	# STATE 3: Dodge Rolling - Locked movement with slight control
	elif is_dodge_rolling:
		# IMPROVED: Better handling of dodge roll physics
		handle_dodge_roll_improved(delta, input_direction)
	
	# STATE 4: Drinking Estus - Very limited movement
	elif is_drinking_estus:
		velocity.x = move_toward(velocity.x, input_direction * movement_speed * 0.3, friction * delta * 0.5)
		
		# End estus drinking when timer expires
		if estus_drink_timer <= 0:
			is_drinking_estus = false
			heal(estus_heal_amount)
	
	# STATE 5: Attacking - Limited movement
	elif in_attack_state:
		# IMPROVED: Better attack movement control
		handle_attack_movement(delta, input_direction)
	
	# STATE 6: Normal Movement - Full control
	else:
		# IMPROVED: Better jump handling with cut jump and variable height
		handle_improved_jump(jump_just_pressed, jump_released)
		
		# IMPROVED: Better movement with context-aware acceleration
		handle_improved_movement(delta, input_direction)
		
		# ACTION INPUTS - improved responsiveness with just_pressed
		# Now explicitly check if on floor before allowing attacks
		if is_on_floor():
			# ATTACK - E key - Only allowed when on the floor
			if attack_just_pressed and can_attack:
				execute_attack()
			
			# DODGE - Q or Shift
			elif dodge_just_pressed and can_attack and dodge_roll_cooldown_timer <= 0 and current_stamina >= dodge_roll_stamina_cost:
				attempt_dodge_roll()
			
			# HEAL - H key
			elif heal_just_pressed and can_attack and current_estus_charges > 0:
				attempt_drink_estus()
	
	# ==========================================
	# PHYSICS & GRAVITY - Enhanced fall speed
	# ==========================================
	
	# IMPROVED: Better gravity handling with jump cut and max fall speed
	apply_improved_gravity(delta, jump_released)
	
	# Apply movement
	move_and_slide()
	
	# IMPROVED: Better landing impact
	handle_landing_impact()
	
	# Track floor state for coyote time
	if was_on_floor and not is_on_floor():
		coyote_timer = coyote_time
	else:
		coyote_timer = max(0, coyote_timer - delta)
	was_on_floor = is_on_floor()
	
	# ==========================================
	# ANIMATION UPDATE - Enhanced with blending
	# ==========================================
	update_enhanced_animation()

# IMPROVED: Better dodge roll with physics and control
func handle_dodge_roll_improved(delta, input_direction):
	# Continue the dodge roll
	if dodge_roll_timer > 0:
		dodge_roll_timer -= delta
		
		# Allow minor directional influence during roll
		if input_direction != 0:
			dodge_roll_direction = lerp(dodge_roll_direction, float(input_direction), 0.08)
		
		# Apply stronger initial impulse that gradually decreases
		var roll_speed_factor = remap(dodge_roll_timer, 0, dodge_roll_duration, 0.6, 1.0)
		velocity.x = dodge_roll_direction * dodge_roll_speed * roll_speed_factor
		
		# End dodge roll when timer expires
		if dodge_roll_timer <= 0:
			is_dodge_rolling = false
			# Start cooldown
			dodge_roll_cooldown_timer = dodge_roll_cooldown
	
	# Apply gravity but no other input during roll
	if not is_on_floor():
		velocity.y += gravity * delta

# IMPROVED: Better attack movement handling
func handle_attack_movement(delta, input_direction):
	# Allow minimal movement during attack (20% of normal speed)
	var attack_move_speed = movement_speed * 0.2
	
	# More movement control at beginning of attack, less at end
	if current_attack_frame < 2:
		attack_move_speed = movement_speed * 0.4
	elif current_attack_frame > 4:
		attack_move_speed = movement_speed * 0.1
	
	# Apply controlled movement during attack
	velocity.x = move_toward(velocity.x, input_direction * attack_move_speed, friction * delta * 0.5)
	
	# Handle hitbox during attack with improved timing
	current_attack_frame += 1
	var knight_hitbox = get_node_or_null("HitBox")
	if knight_hitbox:
		var should_monitor = current_attack_frame >= hitbox_active_frame_start and current_attack_frame <= hitbox_active_frame_end
		knight_hitbox.monitoring = should_monitor
		knight_hitbox.monitorable = should_monitor
		
		# Make sure the collision shape is enabled while the hitbox is active
		var collision_shape = knight_hitbox.get_node_or_null("CollisionShape2D")
		if collision_shape:
			collision_shape.disabled = !should_monitor

# IMPROVED: Better jump handling with cut jump and variable height
func handle_improved_jump(jump_just_pressed, jump_released):
	# JUMP with buffer and coyote time
	if jump_just_pressed:
		if is_on_floor():
			velocity.y = jump_velocity
			is_jump_cut = false
			if debug_enabled:
				print("KNIGHT: Jumping")
		elif coyote_timer > 0:
			velocity.y = jump_velocity
			is_jump_cut = false
			coyote_timer = 0
			if debug_enabled:
				print("KNIGHT: Coyote jump")
		else:
			# Buffer jump for a short time
			jump_buffer_timer = jump_buffer_time
	
	# Apply buffered jump if we just landed
	if is_on_floor() and jump_buffer_timer > 0:
		velocity.y = jump_velocity
		jump_buffer_timer = 0
		is_jump_cut = false
		if debug_enabled:
			print("KNIGHT: Buffered jump executed")
	
	# Allow variable jump height by cutting the jump when button is released
	if jump_released and velocity.y < 0 and not is_jump_cut:
		velocity.y *= jump_cut_height
		is_jump_cut = true
		if debug_enabled:
			print("KNIGHT: Jump cut")

# IMPROVED: Better movement with context-aware acceleration
func handle_improved_movement(delta, input_direction):
	if input_direction != 0:
		# Determine if we're changing direction
		var direction_change = sign(velocity.x) != 0 and sign(velocity.x) != input_direction
		
		# Calculate actual acceleration
		var current_accel = acceleration
		
		# Apply ground acceleration boost
		if is_on_floor():
			current_accel *= ground_acceleration_multiplier
		else:
			current_accel *= air_control
		
		# Apply direction change penalty - but keep it minimal for fast turning
		if direction_change:
			current_accel *= direction_change_penalty
			# No extra velocity reduction when changing direction - we want instant response
		
		# Accelerate towards target direction - much faster
		velocity.x = move_toward(velocity.x, input_direction * movement_speed, current_accel * delta)
		
		# Update sprite direction immediately
		if input_direction != 0:
			animated_sprite.flip_h = (input_direction < 0)
		
		# Update hitbox position based on facing direction
		var knight_hitbox = get_node_or_null("HitBox")
		if knight_hitbox:
			knight_hitbox.position.x = 45 if not animated_sprite.flip_h else -45
		
		# Handle stamina for running - reduced consumption
		if is_on_floor() and abs(velocity.x) > movement_speed * 0.5 and stamina_bar:
			if current_stamina > 0:
				# Directly use a small amount of stamina
				current_stamina = max(0, current_stamina - 3.5 * delta)
				if stamina_bar:
					stamina_bar.value = current_stamina
			else:
				velocity.x *= 0.7  # More abrupt slowdown when out of stamina
	else:
		# Apply friction to stop quickly when no input
		var stopping_speed = friction * (1.0 if is_on_floor() else 0.5)
		
		# No gradual stopping - we want to stop quickly at all speeds
		velocity.x = move_toward(velocity.x, 0, stopping_speed * delta)

# IMPROVED: Better gravity handling with jump cut and max fall speed
func apply_improved_gravity(delta, jump_released):
	if not is_on_floor():
		# Fall faster than jump for better feel
		var current_gravity = gravity
		
		if velocity.y > 0:  # If falling
			current_gravity *= gravity_multiplier
		elif velocity.y < 0 and is_jump_cut:  # If jump was cut
			current_gravity *= 1.8  # Even faster fall after cutting jump
		
		velocity.y += current_gravity * delta
		
		# Cap fall speed for better control
		velocity.y = min(velocity.y, max_fall_speed)

# IMPROVED: Handle landing impact for better feel
func handle_landing_impact():
	if is_on_floor() and not was_on_floor:
		# Reduce horizontal velocity slightly when landing for better feel
		velocity.x *= landing_impact_reduction
		
		# Play landing effect if falling fast enough
		if velocity.y > 200:
			# TODO: Add landing particles/sound here
			pass

# IMPROVED: Better animation system with more states and smoother transitions
func update_enhanced_animation():
	var new_anim_state = AnimState.IDLE
	var animation_to_play = ""
	
	# Determine animation state based on priority
	if is_dead:
		new_anim_state = AnimState.DEAD
		animation_to_play = "Death"
		animation_locked = true
	elif is_hurt:
		new_anim_state = AnimState.HURT
		animation_to_play = "Hurt" 
		animation_locked = true
		
		# Add early exit for hurt animation to prevent getting stuck
		if animated_sprite and animated_sprite.animation == "Hurt" and animated_sprite.frame >= 1:
			# Allow hurt animation to be exited earlier
			if abs(velocity.x) > movement_speed * 0.5 or jump_buffer_timer > 0:
				is_hurt = false
				animation_locked = false
				if debug_enabled:
					print("KNIGHT: Hurt state cleared early due to movement")
	elif in_attack_state:
		new_anim_state = AnimState.ATTACK
		animation_to_play = "Attack"
		animation_locked = true
	elif is_dodge_rolling:
		new_anim_state = AnimState.DODGE
		animation_to_play = "Run"  # Use Run for dodge roll with higher speed
	elif is_drinking_estus:
		new_anim_state = AnimState.HEAL
		animation_to_play = "Idle"  # Use Idle for estus for now
	elif not is_on_floor():
		if velocity.y < 0:
			new_anim_state = AnimState.JUMP
			animation_to_play = "Jump"
		else:
			new_anim_state = AnimState.FALL
			animation_to_play = "Fall"
	elif abs(velocity.x) > 10:
		new_anim_state = AnimState.RUN
		animation_to_play = "Run"
	else:
		new_anim_state = AnimState.IDLE
		animation_to_play = "Idle"
	
	# Only change animation if state changed or animation ended,
	# but respect animation_locked for special animations
	if animated_sprite and (
		(new_anim_state != current_anim_state and not animation_locked) or
		not animated_sprite.is_playing()
	):
		# Special case: don't interrupt animations that should complete
		if animation_locked and ((
			current_anim_state == AnimState.ATTACK and in_attack_state) or 
			(current_anim_state == AnimState.DEAD and is_dead)):
			return
			
		# Allow hurt animation to be interrupted more easily
		if animation_locked and current_anim_state == AnimState.HURT and is_hurt:
			# Check if we've shown enough frames of the hurt animation to transition
			if animated_sprite and animated_sprite.frame >= 1:
				animation_locked = false
				is_hurt = false
		
		# Unlock animation if the locked animation finished playing
		if animation_locked and not animated_sprite.is_playing():
			animation_locked = false
		
		# Update current animation state
		current_anim_state = new_anim_state
		
		# Adjust animation speed based on movement speed for run animation
		if animation_to_play == "Run":
			# Scale animation speed based on movement - faster run = faster animation
			animated_sprite.speed_scale = clamp(abs(velocity.x) / movement_speed, 0.7, 1.3)
		elif animation_to_play == "Hurt":
			# Make hurt animation play faster
			animated_sprite.speed_scale = 1.5
		else:
			animated_sprite.speed_scale = 1.0
			
		# Play the new animation
		animated_sprite.play(animation_to_play)
		
		if debug_enabled and animation_to_play != animated_sprite.animation:
			print("KNIGHT: Playing animation: ", animation_to_play)

func _on_animation_finished():
	if debug_enabled:
		print("KNIGHT: Animation finished: ", animated_sprite.animation)
	
	# Reset animation_locked state when animation completes
	animation_locked = false
	
	# Handle attack animation completion
	if animated_sprite.animation == "Attack":
		if debug_enabled:
			print("KNIGHT: Attack animation finished - disabling hitbox")
			
		in_attack_state = false
		
		# Get and disable hitbox
		var knight_hitbox = get_node_or_null("HitBox")
		if knight_hitbox:
			knight_hitbox.monitoring = false
			knight_hitbox.monitorable = false
			
			# Also directly disable the collision shape
			var collision_shape = knight_hitbox.get_node_or_null("CollisionShape2D")
			if collision_shape:
				collision_shape.disabled = true
				if debug_enabled:
					print("KNIGHT: Collision shape disabled")
		
		if debug_enabled:
			print("KNIGHT: Disabled hitbox after attack")
		
	# If hurt animation finished, reset hurt state AND modulate color
	if animated_sprite.animation == "Hurt":
		is_hurt = false
		hurt_timer = 0.0
		animated_sprite.modulate = original_modulate
		if debug_enabled:
			print("KNIGHT: Hurt state cleared by animation finished")
		
	# If death animation finished, ensure we stay on the last frame
	if animated_sprite.animation == "Death" and is_dead:
		animated_sprite.stop()
		animated_sprite.frame = animated_sprite.sprite_frames.get_frame_count("Death") - 1

func handle_action_input():
	# Don't process actions during dodge roll or when drinking estus
	if is_dodge_rolling or is_drinking_estus or is_dead:
		return
	
	# Dodge (Q or Shift)
	if (Input.is_action_just_pressed("ui_cancel") or Input.is_action_just_pressed("ui_text_completion_replace")) and not is_dodge_rolling and dodge_roll_cooldown_timer <= 0:
		if debug_enabled:
			print("KNIGHT: Dodge key just pressed, attempting dodge roll")
		attempt_dodge_roll()
		return
	
	# Heal (H key)
	if Input.is_action_just_pressed("ui_home") and not is_drinking_estus and not in_attack_state:
		if debug_enabled:
			print("KNIGHT: Heal key just pressed, attempting to drink estus")
		attempt_drink_estus()
		return

func attempt_light_attack():
	if debug_enabled:
		print("KNIGHT: Attempting light attack, can_attack=", can_attack, " in_attack_state=", in_attack_state)
	
	# Check if we can attack 
	if not can_attack or in_attack_state:
		if debug_enabled:
			print("KNIGHT: Attack blocked by state - can_attack=", can_attack, " in_attack_state=", in_attack_state)
		return
		
	# Check if we have enough stamina
	if current_stamina < light_attack_stamina_cost:
		if debug_enabled:
			print("KNIGHT: Not enough stamina for attack: ", current_stamina, "/", light_attack_stamina_cost)
		return
	
	# Use stamina
	current_stamina -= light_attack_stamina_cost
	if stamina_bar:
		stamina_bar.value = current_stamina
		
	# Start attack directly
	start_attack(false)
	
	if debug_enabled:
		print("KNIGHT: Light attack successfully started")

func attempt_heavy_attack():
	# Check if we can attack and have enough stamina
	if can_attack and current_stamina >= heavy_attack_stamina_cost:
		# Use stamina
		current_stamina -= heavy_attack_stamina_cost
		if stamina_bar:
			stamina_bar.use_stamina("heavy_attack")
		
		# Start heavy attack
		start_attack(true)

func start_attack(is_heavy):
	if debug_enabled:
		print("KNIGHT: Starting attack animation")
	
	# Set attack state
	in_attack_state = true
	can_attack = false
	attack_timer = attack_cooldown * (1.5 if is_heavy else 1.0)
	is_heavy_attack = is_heavy
	current_attack_frame = 0
	
	# Force play attack animation
	if animated_sprite:
		animated_sprite.stop()
		animated_sprite.play("Attack")
		if debug_enabled:
			print("KNIGHT: Playing Attack animation")
	
	# Set up hitbox
	var knight_hitbox = get_node_or_null("HitBox")
	if knight_hitbox:
		# Set up proper collision layers for attack
		knight_hitbox.collision_layer = 16  # Layer for player hitboxes
		knight_hitbox.collision_mask = 8    # Mask to detect enemy hurtboxes
		
		# Make sure hitbox connections are set up
		if not knight_hitbox.area_entered.is_connected(_on_hitbox_area_entered):
			knight_hitbox.area_entered.connect(_on_hitbox_area_entered)
			if debug_enabled:
				print("KNIGHT: Connected hitbox signal")
		
		# Enable hitbox immediately for better responsiveness
		knight_hitbox.monitoring = true     
		knight_hitbox.monitorable = true
		
		# Update hitbox position based on character direction
		knight_hitbox.position.x = 45 if not animated_sprite.flip_h else -45
		
		if debug_enabled:
			print("KNIGHT: Set up hitbox for attack, position=", knight_hitbox.position, " monitoring=", knight_hitbox.monitoring)
	else:
		if debug_enabled:
			print("KNIGHT: ERROR - No hitbox found! Attack won't hit enemies.")

func attempt_dodge_roll():
	# Can only dodge if not already dodging, not on cooldown, and have enough stamina
	if not is_dodge_rolling and dodge_roll_cooldown_timer <= 0 and current_stamina >= dodge_roll_stamina_cost:
		# Use stamina
		current_stamina -= dodge_roll_stamina_cost
		if stamina_bar:
			stamina_bar.use_stamina("dodge_roll")
		
		# Start dodge roll
		is_dodge_rolling = true
		dodge_roll_timer = dodge_roll_duration
		
		# Direction based on sprite direction
		dodge_roll_direction = -1 if animated_sprite.flip_h else 1
		
		# Start invincibility frames
		start_invincibility(dodge_roll_i_frames)
		
		# Set stamina regeneration delay
		stamina_regen_delay = 1.5

func attempt_drink_estus():
	# Can only drink estus if not already drinking, not in another animation, and have charges
	if not is_drinking_estus and not in_attack_state and not is_dodge_rolling and current_estus_charges > 0:
		# Start estus drinking
		is_drinking_estus = true
		estus_drink_timer = estus_drink_duration
		
		# Use a charge
		current_estus_charges -= 1

func update_health(new_health: float):
	current_health = new_health
	if health_bar:
		health_bar.take_damage(max_health - new_health)  # Convert to damage amount

func heal(amount):
	# Apply healing
	current_health = min(current_health + amount, max_health)
	
	# Update UI
	if health_bar:
		health_bar.heal(amount)

func heal_fully():
	# Used by bonfire system
	current_health = max_health
	
	# Update UI
	if health_bar:
		health_bar.heal(max_health)  # Heal to full

func refill_estus():
	# Used by bonfire system
	current_estus_charges = max_estus_charges

func handle_death(delta):
	# Death timer countdown
	if death_timer > 0:
		death_timer -= delta
		
		# Respawn when timer expires
		if death_timer <= 0:
			respawn()

func die():
	# Enter death state
	is_dead = true
	
	# Drop souls
	drop_souls()
	
	# Play death animation
	animated_sprite.play("Death")
	
	# Start death timer
	death_timer = death_duration

func respawn():
	# Reset state
	is_dead = false
	current_health = max_health
	current_stamina = max_stamina
	
	# Teleport to respawn point
	global_position = respawn_point
	
	# Reset velocity
	velocity = Vector2.ZERO
	
	# Refill estus
	current_estus_charges = max_estus_charges
	
	# Update UI
	if health_bar:
		health_bar.heal(max_health)  # Use heal instead of update_health
	if stamina_bar:
		stamina_bar.update_stamina_bar()

func drop_souls():
	# Store dropped souls amount and position
	souls_dropped_on_death = souls_count
	souls_drop_position = global_position
	
	# Reset souls count
	souls_count = 0
	
	# Update UI

func collect_souls(amount):
	# Add souls to count
	souls_count += amount
	
	# Update UI

# Method to collect chemical items
func collect_chemical(chemical_type, growth_amount=5.0):
	# Add to collected chemicals array
	if collected_chemicals.size() < max_chemicals:
		collected_chemicals.append(chemical_type)
		
		# Print confirmation
		print("Knight: Collected chemical type: ", chemical_type)
		
		# Emit signal via SignalBus if available
		var signal_bus = get_node_or_null("/root/SignalBus")
		if signal_bus and signal_bus.has_signal("chemical_collected"):
			signal_bus.emit_signal("chemical_collected", chemical_type, collected_chemicals.size() - 1)
		
		# Apply growth effect if growth system exists
		if growth_system and growth_system.has_method("apply_growth"):
			growth_system.apply_growth(growth_amount)
			print("Knight: Applied growth: ", growth_amount)
		
		# Play collection effect
		show_chemical_collection_effect(chemical_type)
		
		# Return true to indicate successful collection
		return true
	else:
		print("Knight: Chemical inventory full!")
		return false

# Method to display visual feedback when collecting chemicals
func show_chemical_collection_effect(chemical_type):
	# Visual feedback for chemical collection
	if animated_sprite:
		# Create a quick flash effect
		var original_color = animated_sprite.modulate
		
		# Set color based on chemical type
		var color_map = {
			0: Color(1.5, 0.5, 0.5),  # RED
			1: Color(0.5, 1.5, 0.5),  # GREEN
			2: Color(0.5, 0.5, 1.5),  # BLUE
			3: Color(1.5, 1.5, 0.5),  # YELLOW
			4: Color(1.5, 0.5, 1.5)   # PURPLE
		}
		
		# Apply color flash
		var flash_color = color_map.get(chemical_type, Color(1, 1, 1))
		animated_sprite.modulate = flash_color
		
		# Reset color after brief delay
		await get_tree().create_timer(0.2).timeout
		animated_sprite.modulate = original_color

# Method to add a chemical directly (used by AutoGrowth system)
func add_chemical(chemical_type_name):
	# Convert string type to int
	var type_map = {
		"RED": 0,
		"GREEN": 1,
		"BLUE": 2,
		"YELLOW": 3,
		"PURPLE": 4
	}
	
	var type_int = type_map.get(chemical_type_name, 0)
	collect_chemical(type_int)

func _on_stamina_depleted():
	# Prevent further stamina-consuming actions
	is_stamina_depleted = true
	
	# Force player to stop sprinting
	is_stamina_regenerating = false
	
	# Visual feedback (optional)
	animated_sprite.modulate = Color(0.7, 0.7, 0.9)  # Bluish tint when out of stamina

func _on_stamina_restored():
	# Allow stamina-consuming actions again
	is_stamina_depleted = false
	
	# Reset visual feedback
	animated_sprite.modulate = Color(1, 1, 1)  # Normal color

func start_invincibility(duration):
	is_invincible = true
	invincible_timer = duration

# Function to initialize state machine
func initialize_state_machine():
	# Simplified state machine setup for Dark Souls version
	main_sm = Node.new()
	main_sm.name = "StateMachine"
	add_child(main_sm)

# Add the missing setup_key_checker function
func setup_key_checker():
	# This function was referenced but not implemented
	# Implementation would typically check for keys or create a key checker node
	print("KNIGHT: KeyChecker setup was called but is not implemented")
	
	# Example implementation (commented out):
	# var key_checker = Node.new()
	# key_checker.name = "KeyChecker"
	# add_child(key_checker)
	# print("KNIGHT: Created KeyChecker node")

func _process(delta):
	# Reset color if not in special states
	if not is_invincible and not is_hurt and not is_stamina_depleted and animated_sprite:
		animated_sprite.modulate = original_modulate
	
	# Update timers
	update_timers(delta)
	
	# Handle stamina regeneration
	if not in_attack_state and not is_dodge_rolling and not is_drinking_estus and is_stamina_regenerating:
		regenerate_stamina(delta)
	
	# Handle debug actions
	if Input.is_key_pressed(KEY_I):  # Print debug info
		print("Knight Position:", global_position)
		print("Knight Velocity:", velocity)
		print("On Floor:", is_on_floor())
		print("States: dodge_rolling=", is_dodge_rolling, " in_attack=", in_attack_state, " drinking_estus=", is_drinking_estus)
		print("Can attack:", can_attack, " Stamina:", current_stamina)
		print("Hitbox:", get_node_or_null("HitBox"), " Monitoring:", get_node_or_null("HitBox").monitoring if get_node_or_null("HitBox") else "N/A")
		print("Collision shape:", get_node_or_null("HitBox").get_node_or_null("CollisionShape2D") if get_node_or_null("HitBox") else "N/A")
	
	# Development testing - Press T to force attack (for debugging)
	if Input.is_key_pressed(KEY_T) and is_on_floor():
		print("KNIGHT: T KEY PRESSED - FORCE TESTING ATTACK!")
		execute_attack_test()

# Test function that can be called from console for debugging
func execute_attack_test():
	print("KNIGHT: *** FORCED ATTACK TEST ***")
	
	# Emergency reset of states
	in_attack_state = false
	is_dodge_rolling = false 
	is_drinking_estus = false
	can_attack = true
	
	# Call the execute attack function
	execute_attack()
	
	# Make sure the hitbox is working
	var knight_hitbox = get_node_or_null("HitBox")
	if knight_hitbox:
		# Force the hitbox on
		knight_hitbox.monitoring = true
		knight_hitbox.monitorable = true
		
		# Make sure the collision shape is enabled
		var collision_shape = knight_hitbox.get_node_or_null("CollisionShape2D")
		if collision_shape:
			collision_shape.disabled = false
			print("KNIGHT: Collision shape forcibly enabled for testing")
		
		print("KNIGHT: Hitbox forcibly enabled at ", knight_hitbox.position)

# Add a new function for stamina regeneration
func regenerate_stamina(delta):
	if is_stamina_regenerating:
		if stamina_regen_timer <= 0:
			current_stamina = min(current_stamina + stamina_regen_rate * delta, max_stamina)
			if stamina_bar:
				# Update both the internal value and the UI
				stamina_bar.current_stamina = current_stamina
				stamina_bar.value = current_stamina
		else:
			stamina_regen_timer -= delta

# Add these new functions for hit detection
func _on_hitbox_area_entered(area):
	if debug_enabled:
		print("KNIGHT: Hitbox hit area: ", area, " area parent: ", area.get_parent())
	
	# IMPROVED: More reliable hit detection with multiple checks
	var hit_enemy = false
	var enemy = null
	var damage_multiplier = 1.0
	
	# Check several conditions for hitting an enemy in priority order
	
	# 1. First check if the area has a method for taking damage (most reliable)
	if area.has_method("take_damage"):
		hit_enemy = true
		enemy = area
		if debug_enabled:
			print("KNIGHT: Direct hit on area with take_damage method")
	
	# 2. Check if the area is an enemy hurtbox by group
	elif area.is_in_group("EnemyHurtbox"):
		hit_enemy = true
		enemy = area.get_parent()
		if debug_enabled:
			print("KNIGHT: Hit on area in EnemyHurtbox group")
	
	# 3. Check if the area's parent is an enemy by group
	elif area.get_parent() and area.get_parent().is_in_group("Enemy"):
		hit_enemy = true
		enemy = area.get_parent()
		if debug_enabled:
			print("KNIGHT: Hit on child of Enemy group")
	
	# 4. Last resort - check collision layers
	elif area.collision_layer & 8:  # Layer 8 for enemy hurtboxes
		hit_enemy = true
		enemy = area.get_parent()
		if debug_enabled:
			print("KNIGHT: Hit detected via collision layer")
	
	# If we confirmed a hit with any method
	if hit_enemy and enemy:
		# Calculate damage based on attack type
		var damage = attack_damage
		if is_heavy_attack:
			damage *= 2.0  # Double damage for heavy attacks
			damage_multiplier = 2.0
		
		# Apply critical hit chance (25% chance for +50% damage)
		if randf() < 0.25:
			damage *= 1.5
			damage_multiplier *= 1.5
			# Show critical hit effect
			if debug_enabled:
				print("KNIGHT: CRITICAL HIT!")
		
		# Check which method to use for damage application
		if enemy.has_method("take_damage"):
			enemy.take_damage(damage)
			if debug_enabled:
				print("KNIGHT: Dealt ", damage, " damage to enemy: ", enemy.name)
		elif enemy.has_method("damage"):
			enemy.damage(damage)
			if debug_enabled:
				print("KNIGHT: Dealt ", damage, " damage via damage() method")
		else:
			if debug_enabled:
				print("KNIGHT: Enemy found but has no damage-taking method")
	else:
		if debug_enabled:
			print("KNIGHT: Hit detection failed or object doesn't have take_damage method")

func _on_hurtbox_area_entered(area: Area2D):
	# Skip damage if invincible or in dodge roll
	if is_invincible or is_dodge_rolling:
		if debug_enabled:
			print("KNIGHT: Damage avoided due to invincibility or dodge")
		return
		
	# IMPROVED: Better damage source detection
	var damage = 10.0  # Default damage if not specified
	var source = null
	
	# Try multiple methods to get damage amount
	if area.has_method("get_damage"):
		damage = area.get_damage()
		source = area
	elif area.get_parent() and area.get_parent().has_method("get_damage"):
		damage = area.get_parent().get_damage()
		source = area.get_parent()
	elif area.has_meta("damage"):
		damage = area.get_meta("damage")
		source = area
	
	# Apply damage reduction
	damage *= (1.0 - damage_reduction)
	
	# Update health
	current_health = max(0, current_health - damage)
	if health_bar:
		health_bar.take_damage(damage)
	
	# Visual feedback with improved effects and safety timer
	is_hurt = true
	hurt_timer = hurt_max_duration  # Set safety timer
	animated_sprite.play("Hurt")
	animation_locked = true
	
	# Flash effect
	animated_sprite.modulate = Color(2.0, 0.3, 0.3)
	
	# Start invincibility frames
	start_invincibility(invincible_time)
	
	# Apply knockback with improved physics
	var knockback_direction
	if source:
		knockback_direction = (global_position - source.global_position).normalized()
	else:
		# Fallback if source not found - knockback away from damage direction
		knockback_direction = Vector2(1 if animated_sprite.flip_h else -1, -0.5).normalized()
	
	# Scale knockback with damage amount for better feel
	var knockback_force = damage * (1.0 - knockback_resistance) * 10
	velocity = knockback_direction * knockback_force
	
	if debug_enabled:
		print("KNIGHT: Took ", damage, " damage, health: ", current_health, " knockback: ", knockback_force)
	
	# Check for death
	if current_health <= 0:
		die()
	else:
		# For non-fatal damage, set a timer to quickly exit the hurt state
		get_tree().create_timer(0.15).timeout.connect(func(): 
			if is_hurt:
				is_hurt = false
				animation_locked = false
				if debug_enabled:
					print("KNIGHT: Hurt state cleared by timeout")
		)

func _input(event):
	# Extra check for E key press
	if event is InputEventKey:
		if event.pressed and not event.is_echo():
			# Check for E key (attack)
			if event.keycode == KEY_E:
				# ONLY allow attack when on floor and not in any other state
				if is_on_floor() and not in_attack_state and not is_hurt and not is_dodge_rolling and not is_drinking_estus and can_attack:
					execute_attack()
			
			# Check for T key (test attack) - debug only
			if event.keycode == KEY_T and debug_enabled:
				# Only for debugging, still require being on floor
				if is_on_floor():
					execute_attack_test()

# Also fix unhandled input to prevent attacking while jumping
func _unhandled_input(event):
	# Try to catch input if not handled elsewhere
	if event is InputEventKey:
		if event.pressed and not event.is_echo():
			if event.keycode == KEY_E:
				# ONLY allow attack when on floor and not in any other state
				if is_on_floor() and not in_attack_state and not is_hurt and not is_dodge_rolling and not is_drinking_estus and can_attack:
					execute_attack()

func _notification(what):
	# Check for input detection issues
	if what == NOTIFICATION_APPLICATION_FOCUS_IN:
		print("KNIGHT: Window focus gained - input should work now")
	elif what == NOTIFICATION_APPLICATION_FOCUS_OUT:
		print("KNIGHT: Window focus lost - input might not work")

# IMPROVED: Fixed attack execution function 
func execute_attack():
	if debug_enabled:
		print("KNIGHT: Executing attack!")
	
	# First make sure we have a hitbox
	var knight_hitbox = get_node_or_null("HitBox")
	if not knight_hitbox:
		print("KNIGHT ERROR: No hitbox found!")
		return
	
	# Get the collision shape
	var collision_shape = knight_hitbox.get_node_or_null("CollisionShape2D")
	if not collision_shape:
		print("KNIGHT ERROR: No collision shape in hitbox!")
		return
	
	# Check stamina first
	if current_stamina < light_attack_stamina_cost:
		if debug_enabled:
			print("KNIGHT: Not enough stamina for attack")
		return
	
	# Set attack state
	in_attack_state = true
	can_attack = false
	attack_timer = attack_cooldown
	current_attack_frame = 0
	is_heavy_attack = false  # Default to light attack
	
	# Use stamina
	current_stamina -= light_attack_stamina_cost
	if stamina_bar:
		stamina_bar.value = current_stamina
	
	# Ensure the hitbox has correct collision layers
	knight_hitbox.collision_layer = 16  # Layer for player hitboxes
	knight_hitbox.collision_mask = 8    # Mask to detect enemy hurtboxes
	
	# Hitbox will be enabled during animation frames
	knight_hitbox.monitoring = false
	knight_hitbox.monitorable = true
	collision_shape.disabled = true
	
	# Connect the area_entered signal if not already connected
	if not knight_hitbox.area_entered.is_connected(_on_hitbox_area_entered):
		knight_hitbox.area_entered.connect(_on_hitbox_area_entered)
		if debug_enabled:
			print("KNIGHT: Connected hitbox signal")
	
	# Set position based on direction
	knight_hitbox.position.x = 45 if not animated_sprite.flip_h else -45
	
	# Force play attack animation
	if animated_sprite:
		animated_sprite.stop()
		animated_sprite.play("Attack")
		if debug_enabled:
			print("KNIGHT: Playing Attack animation")
		
	# Set animation as locked during attack
	animation_locked = true

func update_timers(delta):
	# Update dodge roll cooldown
	if dodge_roll_cooldown_timer > 0:
		dodge_roll_cooldown_timer -= delta
	
	# Attack cooldown
	if not can_attack:
		attack_timer -= delta
		if attack_timer <= 0:
			can_attack = true
	
	# Handle invincibility frames
	if is_invincible:
		invincible_timer -= delta
		if invincible_timer <= 0:
			is_invincible = false
			
			# Reset modulate when invincibility ends
			animated_sprite.modulate = original_modulate

# Update stamina separately
func update_stamina(new_stamina: float):
	current_stamina = new_stamina
	if stamina_bar:
		stamina_bar.update_stamina_bar()
