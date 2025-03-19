extends CharacterBody2D
# Removed class_name Knight to avoid conflict with global script class

# Movement parameters
@export var movement_speed: float = 250.0     # Reduced from 300 for better control
@export var acceleration: float = 2000.0      # Reduced for smoother acceleration
@export var friction: float = 1500.0          # Reduced for smoother deceleration
@export var jump_velocity: float = -400.0
@export var air_control: float = 0.5          # Reduced for more realistic air control
@export var gravity_multiplier: float = 1.5   # Added for faster falling

# Movement interpolation parameters
var velocity_dampening: float = 0.05            # Decreased for less sluggish movement
var previous_direction: float = 0.0
var target_velocity: Vector2 = Vector2.ZERO

# Jump mechanics
@export var coyote_time: float = 0.15           # Increased for better jump feel
@export var jump_buffer_time: float = 0.15      # Increased for more forgiving jump timing
var coyote_timer: float = 0.0
var jump_buffer_timer: float = 0.0
var was_on_floor: bool = false
var wants_to_jump: bool = false

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

func _ready():
	print("KNIGHT: Starting initialization...")
	
	# Add self to "Player" group for easier lookup
	if not is_in_group("Player"):
		add_to_group("Player")
	
	# Debug collision settings
	print("KNIGHT: Initial collision_layer=", collision_layer, " collision_mask=", collision_mask)
	
	# Ensure basic collision is set up - layer 2 is player, layer 32 and 64 are chemicals
	collision_layer = 2  # Player layer
	collision_mask = 1   # World layer - only world collision for now to simplify
	
	print("KNIGHT: Updated collision_layer=", collision_layer, " collision_mask=", collision_mask)
	
	# Print controls for debugging
	print("KNIGHT: Controls - A/D or Arrow Keys for movement, Space/W for jump, E for attack, Q/Shift for dodge, H for heal")
	
	# Set up input actions if they don't exist
	if not InputMap.has_action("attack"):
		InputMap.add_action("attack")
		var event = InputEventKey.new()
		event.keycode = KEY_E
		InputMap.action_add_event("attack", event)
		print("KNIGHT: Created attack input action bound to E key")
	
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
	
	# Setup hitbox with proper collision layers and debugging
	var knight_hitbox = get_node_or_null("HitBox")
	if knight_hitbox:
		knight_hitbox.is_player_hitbox = true
		knight_hitbox.debug = true
		
		# Set collision layers/masks for proper detection
		knight_hitbox.collision_layer = 16  # Layer 16 for player hitboxes
		knight_hitbox.collision_mask = 8    # Mask 8 to detect enemy hurtboxes
		
		# Connect hitbox signals
		if not knight_hitbox.is_connected("area_entered", _on_hitbox_area_entered):
			knight_hitbox.area_entered.connect(_on_hitbox_area_entered)
		
		print("KNIGHT: Hitbox setup complete")
	
	# Setup hurtbox with proper collision layers
	var knight_hurtbox = get_node_or_null("HurtBox")
	if knight_hurtbox:
		# Make sure the property exists before setting it
		if "is_player_hurtbox" in knight_hurtbox:
			knight_hurtbox.is_player_hurtbox = true
		
		if "debug" in knight_hurtbox:
			knight_hurtbox.debug = true  # Always enable debug for hurtbox
		
		# Set collision layers/masks for proper detection
		knight_hurtbox.collision_layer = 8   # Layer 8 for player hurtboxes
		knight_hurtbox.collision_mask = 16   # Mask 16 to detect enemy hitboxes
		
		# Connect hurtbox signals
		if not knight_hurtbox.is_connected("area_entered", _on_hurtbox_area_entered):
			knight_hurtbox.area_entered.connect(_on_hurtbox_area_entered)
		
		print("KNIGHT: Hurtbox setup complete")
	
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
	
	# STATE 3: Dodge Rolling - Locked movement with slight control
	elif is_dodge_rolling:
		# Allow minor directional control during dodge (10% of input)
		if input_direction != 0:
			dodge_roll_direction = lerp(dodge_roll_direction, float(input_direction), 0.05)
		
		velocity.x = dodge_roll_direction * dodge_roll_speed
		
		# End dodge roll when timer expires
		if dodge_roll_timer <= 0:
			is_dodge_rolling = false
			dodge_roll_cooldown_timer = dodge_roll_cooldown
	
	# STATE 4: Drinking Estus - Very limited movement
	elif is_drinking_estus:
		velocity.x = move_toward(velocity.x, input_direction * movement_speed * 0.3, friction * delta * 0.5)
		
		# End estus drinking when timer expires
		if estus_drink_timer <= 0:
			is_drinking_estus = false
			heal(estus_heal_amount)
	
	# STATE 5: Attacking - Limited movement
	elif in_attack_state:
		# Allow minimal movement during attack (20% of normal speed)
		velocity.x = move_toward(velocity.x, input_direction * movement_speed * 0.2, friction * delta * 0.5)
		
		# Handle hitbox during attack
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

	# STATE 6: Normal Movement - Full control
	else:
		# JUMP - improved jump feel with buffering
		if jump_just_pressed:
			if is_on_floor():
				velocity.y = jump_velocity
				if debug_enabled:
					print("KNIGHT: Jumping")
			else:
				# Buffer jump for a short time (coyote time)
				jump_buffer_timer = jump_buffer_time
		
		# Apply buffered jump if we just landed
		if is_on_floor() and jump_buffer_timer > 0:
			velocity.y = jump_velocity
			jump_buffer_timer = 0
			if debug_enabled:
				print("KNIGHT: Buffered jump executed")
		
		# HORIZONTAL MOVEMENT with variable acceleration
		if input_direction != 0:
			# Adjust acceleration based on whether we're changing direction
			var direction_change = sign(velocity.x) != 0 and sign(velocity.x) != input_direction
			var current_accel = acceleration * (0.6 if direction_change else 1.0)
			
			# More control on ground, less in air
			if not is_on_floor():
				current_accel *= air_control
			
			# Accelerate towards target direction
			velocity.x = move_toward(velocity.x, input_direction * movement_speed, current_accel * delta)
			
			# Update sprite direction with slight delay for more natural feel
			if abs(velocity.x) > movement_speed * 0.1:
				animated_sprite.flip_h = velocity.x < 0
			
			# Update hitbox position based on facing direction
			var knight_hitbox = get_node_or_null("HitBox")
			if knight_hitbox:
				knight_hitbox.position.x = 45 if not animated_sprite.flip_h else -45
			
			# Handle stamina for running - reduced consumption
			if is_on_floor() and abs(velocity.x) > movement_speed * 0.5 and stamina_bar:
				if current_stamina > 0:
					# Directly use a small amount of stamina
					current_stamina = max(0, current_stamina - 5.0 * delta)
					if stamina_bar:
						stamina_bar.value = current_stamina
				else:
					velocity.x *= 0.7  # Slow down when out of stamina
		else:
			# Apply friction to slow down when no input - smoother on ground
			var stopping_speed = friction * (1.0 if is_on_floor() else 0.4)
			velocity.x = move_toward(velocity.x, 0, stopping_speed * delta)
		
		# ACTION INPUTS - improved responsiveness with just_pressed
		if is_on_floor():
			# ATTACK - E key
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
	
	# Apply gravity with multiplier for better jump feel
	if not is_on_floor():
		# Fall faster than jump for better feel
		var current_gravity = gravity
		if velocity.y > 0:  # If falling
			current_gravity *= gravity_multiplier
		
		velocity.y += current_gravity * delta
	
	# Apply movement
	move_and_slide()
	
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

# Enhanced animation handling with smoother transitions
func update_enhanced_animation():
	var animation_to_play = ""
	
	# Determine animation based on state priority and movement
	if is_dead:
		animation_to_play = "Death"
	elif is_hurt:
		animation_to_play = "Hurt"
	elif in_attack_state:
		animation_to_play = "Attack"
	elif is_dodge_rolling:
		animation_to_play = "Run"  # Use Run for dodge roll with higher speed
	elif is_drinking_estus:
		animation_to_play = "Idle"  # Use Idle for estus
	elif not is_on_floor():
		if velocity.y < 0:
			animation_to_play = "Jump"
		else:
			animation_to_play = "Fall"
	elif abs(velocity.x) > 10:
		animation_to_play = "Run"
	else:
		animation_to_play = "Idle"
	
	# Only change animation if different from current or animation ended
	if animated_sprite and (
		animation_to_play != animated_sprite.animation or 
		not animated_sprite.is_playing() or
		(animated_sprite.animation == "Run" and abs(velocity.x) < 10) or
		(animated_sprite.animation == "Idle" and abs(velocity.x) > 10)
	):
		# Special case: don't interrupt animations that should complete
		if ((animated_sprite.animation == "Attack" and animated_sprite.is_playing() and in_attack_state) or 
			(animated_sprite.animation == "Hurt" and animated_sprite.is_playing() and is_hurt) or
			(animated_sprite.animation == "Death" and is_dead)):
			return
		
		# Adjust animation speed based on movement speed for run animation
		if animation_to_play == "Run":
			animated_sprite.speed_scale = clamp(abs(velocity.x) / movement_speed, 0.7, 1.3)
		else:
			animated_sprite.speed_scale = 1.0
			
		# Play the new animation
		animated_sprite.play(animation_to_play)
		
		if debug_enabled and animation_to_play != animated_sprite.animation:
			print("KNIGHT: Playing animation: ", animation_to_play)

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

func _on_animation_finished():
	if debug_enabled:
		print("KNIGHT: Animation finished: ", animated_sprite.animation)
	
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
		
	# If hurt animation finished, reset hurt state
	if animated_sprite.animation == "Hurt":
		is_hurt = false
		
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
	
	# Check several possible conditions for hitting an enemy
	var hit_enemy = false
	var enemy = null
	
	# Check if the area is an enemy hurtbox directly
	if area.is_in_group("EnemyHurtbox"):
		hit_enemy = true
		enemy = area.get_parent()
	
	# Check if the area's parent is an enemy
	elif area.get_parent() and area.get_parent().is_in_group("Enemy"):
		hit_enemy = true
		enemy = area.get_parent()
	
	# Check if the area has a collision_layer that matches enemy hurtbox (8)
	elif area.collision_layer & 8:
		hit_enemy = true
		enemy = area.get_parent()
	
	# If we confirmed a hit
	if hit_enemy and enemy and enemy.has_method("take_damage"):
		var damage = attack_damage
		if is_heavy_attack:
			damage *= 2.0  # Double damage for heavy attacks
		
		enemy.take_damage(damage)
		if debug_enabled:
			print("KNIGHT: Dealt ", damage, " damage to enemy: ", enemy.name)
	else:
		if debug_enabled:
			print("KNIGHT: Hit detection failed or object doesn't have take_damage method")

func _on_hurtbox_area_entered(area: Area2D):
	if not is_invincible and not is_dodge_rolling:
		var damage = 10.0  # Default damage if not specified
		if area.has_method("get_damage"):
			damage = area.get_damage()
		
		# Apply damage reduction
		damage *= (1.0 - damage_reduction)
		
		# Update health
		current_health = max(0, current_health - damage)
		if health_bar:
			health_bar.take_damage(damage)  # Use take_damage instead of update_health
		
		# Visual feedback
		is_hurt = true
		animated_sprite.play("Hurt")
		
		# Start invincibility frames
		start_invincibility(invincible_time)
		
		# Apply knockback
		var knockback_direction = (global_position - area.global_position).normalized()
		velocity = knockback_direction * (damage * (1.0 - knockback_resistance))
		
		print("KNIGHT: Took ", damage, " damage, health: ", current_health)
		
		# Check for death
		if current_health <= 0:
			die()

func _input(event):
	# Extra check for E key press
	if event is InputEventKey:
		if event.pressed and not event.is_echo():
			print("KNIGHT: Key pressed: ", event.keycode)
			
			# Check for E key (attack)
			if event.keycode == KEY_E:
				print("KNIGHT: E key pressed directly!")
				if is_on_floor() and not in_attack_state and can_attack:
					print("KNIGHT: Executing attack from _input!")
					execute_attack()
			
			# Check for T key (test attack)
			if event.keycode == KEY_T:
				print("KNIGHT: T key pressed for test attack!")
				execute_attack_test()

func _unhandled_input(event):
	# Try to catch input if not handled elsewhere
	if event is InputEventKey:
		if event.pressed and not event.is_echo():
			if event.keycode == KEY_E:
				print("KNIGHT: E key pressed in _unhandled_input!")
				if is_on_floor() and not in_attack_state and can_attack:
					print("KNIGHT: Executing attack from _unhandled_input!")
					execute_attack()

func _notification(what):
	# Check for input detection issues
	if what == NOTIFICATION_APPLICATION_FOCUS_IN:
		print("KNIGHT: Window focus gained - input should work now")
	elif what == NOTIFICATION_APPLICATION_FOCUS_OUT:
		print("KNIGHT: Window focus lost - input might not work")

# Direct attack execution function
func execute_attack():
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
	
	# Set attack state
	in_attack_state = true
	can_attack = false
	attack_timer = attack_cooldown
	current_attack_frame = 0
	is_heavy_attack = false  # Default to light attack
	
	# Use stamina (if we have enough)
	if current_stamina >= light_attack_stamina_cost:
		current_stamina -= light_attack_stamina_cost
		if stamina_bar:
			stamina_bar.value = current_stamina
	
	# Ensure the hitbox is set up
	knight_hitbox.collision_layer = 16  # Layer for player hitboxes
	knight_hitbox.collision_mask = 8    # Mask to detect enemy hurtboxes
	
	# Will be enabled during the appropriate animation frames
	knight_hitbox.monitoring = false
	knight_hitbox.monitorable = true
	collision_shape.disabled = true
	
	# Connect the area_entered signal if not already connected
	if not knight_hitbox.area_entered.is_connected(_on_hitbox_area_entered):
		knight_hitbox.area_entered.connect(_on_hitbox_area_entered)
		print("KNIGHT: Connected hitbox signal")
	
	# Set position based on direction
	knight_hitbox.position.x = 45 if not animated_sprite.flip_h else -45
	
	# Force play attack animation
	if animated_sprite:
		animated_sprite.stop()
		animated_sprite.play("Attack")
		print("KNIGHT: Playing Attack animation")
		
	print("KNIGHT: Attack setup complete!")
