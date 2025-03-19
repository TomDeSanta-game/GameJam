extends CharacterBody2D
class_name Knight

# UI elements
@onready var ui_canvas = $CanvasLayer
@onready var health_bar = $CanvasLayer/HealthBar
@onready var stamina_bar = $CanvasLayer/StaminaBar

# Movement parameters
@export var movement_speed: float = 300.0       # Increased from 200.0 for more responsive movement
@export var acceleration: float = 3000.0        # Increased from 1500.0 for quicker acceleration
@export var friction: float = 2000.0            # Increased for better stopping
@export var jump_velocity: float = -400.0       # Increased jump power
@export var direction_change_speed: float = 5.0 # Increased for more responsive turning
@export var air_control: float = 0.7            # Increased from 0.5 for better air control

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
var stamina_regen_rate: float = 15.0            # Slower regen rate
var stamina_regen_delay: float = 1.0
var stamina_regen_timer: float = 0.0
var stamina_ui: Node = null
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
var hitbox_active_frame_start: int = 8
var hitbox_active_frame_end: int = 9
var current_attack_frame: int = 0
var in_attack_state: bool = false
var light_attack_stamina_cost: float = 15.0
var heavy_attack_stamina_cost: float = 35.0
var is_heavy_attack: bool = false

# Health parameters
@export var max_health: float = 100.0
@export var current_health: float = 100.0
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
var souls_ui: Node = null

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

func _ready():
	print("KNIGHT: Starting initialization...")
	
	# Add self to "Player" group for easier lookup
	if not is_in_group("Player"):
		add_to_group("Player")
	
	# Debug collision settings
	print("KNIGHT: Initial collision_layer=", collision_layer, " collision_mask=", collision_mask)
	
	# Ensure basic collision is set up - layer 2 is player, layer 32 and 64 are chemicals
	collision_layer = 2  # Player layer
	collision_mask = 1 | 32 | 64  # Collide with world (1) and chemicals (32 & 64)
	
	print("KNIGHT: Updated collision_layer=", collision_layer, " collision_mask=", collision_mask)
	
	# Set initial respawn point to current position
	respawn_point = global_position
	
	# Check if canvas already exists before creating a new one
	ui_canvas = get_node_or_null("CanvasLayer")
	
	# Set up other systems
	call_deferred("setup_other_systems")
	
	# Initialize jump mechanics
	was_on_floor = is_on_floor()
	coyote_timer = 0.0
	jump_buffer_timer = 0.0
	
	# Initialize collected chemicals array
	collected_chemicals = []
	
	# Store original modulate color for the sprite
	if animated_sprite:
		original_modulate = animated_sprite.modulate
	
	print("KNIGHT: Basic initialization complete")

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
	
	# Comment out the key checker setup if not needed
	# call_deferred("setup_key_checker")
	
	# Setup hitbox with proper collision layers and debugging
	var knight_hitbox = get_node_or_null("HitBox")
	if knight_hitbox:
		knight_hitbox.is_player_hitbox = true
		knight_hitbox.debug = true
		
		# Set collision layers/masks for proper detection
		knight_hitbox.collision_layer = 2
		knight_hitbox.collision_mask = 4
	
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
		
		# Apply Dark Souls shader to the character
		apply_dark_souls_shader()
	
	print("KNIGHT: Other systems initialized")

func apply_dark_souls_shader():
	# Set character to normal color - disable any shader or tint
	if animated_sprite:
		# Reset any material
		animated_sprite.material = null
		
		# Ensure normal color (white)
		animated_sprite.modulate = Color(1, 1, 1, 1)  # Normal white color with no tint
		
		# Store this as the original modulate
		original_modulate = animated_sprite.modulate
		
		print("KNIGHT: Applied normal coloration without shader tint")

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
	
	# Check for jump keys at the beginning of the frame
	var jump_key_pressed = Input.is_key_pressed(KEY_SPACE) or Input.is_key_pressed(KEY_W) or Input.is_action_pressed("ui_up")
	
	# If jump key is pressed, cancel attack state
	if jump_key_pressed and in_attack_state:
		in_attack_state = false
	
	# Apply gravity consistently
	if not is_on_floor():
		velocity.y += gravity * delta
	else:
		# Reset vertical velocity when on floor to prevent accumulation
		velocity.y = 0
		
	# Handle movement logic to read left-right input
	var input_direction = 0.0
	if InputMap.has_action("move_left") and InputMap.has_action("move_right"):
		input_direction = Input.get_axis("move_left", "move_right")
	else:
		# Fallback to arrow keys if custom actions aren't defined
		input_direction = Input.get_axis("ui_left", "ui_right")
	
	# Directly use input direction for more responsive feel
	previous_direction = lerp(previous_direction, input_direction, direction_change_speed * delta)
	
	# Handle dodge roll - takes precedence over regular movement
	if is_dodge_rolling:
		handle_dodge_roll(delta)
	# Handle estus flask animation
	elif is_drinking_estus:
		handle_estus_drinking(delta)
	# Handle regular movement
	else:
		# Clear any residual horizontal movement first if input direction is zero
		if is_zero_approx(input_direction) and is_zero_approx(velocity.x) == false:
			velocity.x = move_toward(velocity.x, 0, friction * delta)
		
		# Apply movement based on input if there's direction input
		if not is_zero_approx(input_direction):
			# Calculate target speed based on input
			var target_speed = input_direction * movement_speed
			
			# Set acceleration based on whether on floor or in air
			var current_acceleration = acceleration
			if not is_on_floor():
				current_acceleration *= air_control
			
			# Apply movement with proper acceleration
			velocity.x = move_toward(velocity.x, target_speed, current_acceleration * delta)
	
	# Handle jump logic
	process_jump(delta)
	
	# Update timers
	update_timers(delta)
	
	# Process movement
	move_and_slide()
	
	# Update UI and animations after physics update
	update_stamina(delta)
	update_animation_state()
	
	# Only handle action inputs when on floor and NOT pressing jump keys
	if is_on_floor() and not jump_key_pressed:
		handle_action_input()
	
	# Flip sprite based on direction
	if input_direction != 0 and not is_dodge_rolling and not in_attack_state:
		animated_sprite.flip_h = input_direction < 0

# Break out jump logic into a separate function for clarity
func process_jump(delta):
	# Handle coyote time (grace period for jumping after leaving a platform)
	if was_on_floor and not is_on_floor():
		coyote_timer = coyote_time
	else:
		if coyote_timer > 0:
			coyote_timer -= delta
	
	# Handle jump request
	if wants_to_jump:
		jump_buffer_timer = jump_buffer_time
		wants_to_jump = false
	
	# Execute jump if possible
	if jump_buffer_timer > 0:
		jump_buffer_timer -= delta
		if is_on_floor() or coyote_timer > 0:
			velocity.y = jump_velocity
			jump_buffer_timer = 0
			coyote_timer = 0
			# Play jump sound effect if available
			# if jump_sound:
			#    jump_sound.play()
	
	# Track if we were on floor
	was_on_floor = is_on_floor()

# Update all the various timers
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
func update_stamina(delta):
	# Regenerate stamina
	if is_stamina_regenerating and not is_dodge_rolling and not is_drinking_estus and not in_attack_state:
		current_stamina = min(current_stamina + stamina_regen_rate * delta, max_stamina)
		
		# Update UI
		if stamina_ui and "current_stamina" in stamina_ui:
			stamina_ui.current_stamina = current_stamina

func update_animation_state():
	var new_anim_state = current_anim_state
	
	# Determine animation state based on current conditions
	if is_dead:
		new_anim_state = AnimState.DEAD
	elif is_hurt:
		new_anim_state = AnimState.HURT
	elif is_drinking_estus:
		new_anim_state = AnimState.HEAL
	elif is_dodge_rolling:
		new_anim_state = AnimState.DODGE
	elif in_attack_state:
		new_anim_state = AnimState.ATTACK
	elif not is_on_floor():
		if velocity.y < 0:
			new_anim_state = AnimState.JUMP
		else:
			new_anim_state = AnimState.FALL
	else:
		if abs(velocity.x) > 10:
			new_anim_state = AnimState.RUN
		else:
			new_anim_state = AnimState.IDLE
	
	# Update animation if state changed
	if new_anim_state != current_anim_state:
		current_anim_state = new_anim_state
		play_animation_for_state(current_anim_state)

func play_animation_for_state(anim_state):
	match anim_state:
		AnimState.IDLE:
			animated_sprite.play("Idle")
		AnimState.RUN:
			animated_sprite.play("Run")
		AnimState.JUMP:
			animated_sprite.play("Jump")
		AnimState.FALL:
			animated_sprite.play("Fall")
		AnimState.ATTACK:
			if is_heavy_attack:
				# Use the same Attack animation for now, could be replaced with a heavy attack animation
				animated_sprite.play("Attack")
			else:
				animated_sprite.play("Attack")
		AnimState.HURT:
			animated_sprite.play("Hurt")
		AnimState.DODGE:
			# Use Fall animation for dodge roll for now, could be replaced with a roll animation
			animated_sprite.play("Fall")
		AnimState.HEAL:
			# Use Idle animation for estus for now, could be replaced with a drinking animation
			animated_sprite.play("Idle")
		AnimState.DEAD:
			animated_sprite.play("Death")

func handle_action_input():
	# Don't process actions during dodge roll or when drinking estus
	if is_dodge_rolling or is_drinking_estus or is_dead:
		return
		
	# Check if jump keys are pressed - these should NEVER trigger attacks
	var jump_key_pressed = Input.is_key_pressed(KEY_SPACE) or Input.is_key_pressed(KEY_W) or Input.is_action_pressed("ui_up")
	
	# Don't allow attacks if not on floor or if jump keys are pressed
	var can_attack_now = is_on_floor() and not in_attack_state and not jump_key_pressed
	
	# Track if an action button was just pressed this frame
	var action_pressed = false
	
	# Jump input - process FIRST and prioritize over other actions
	var jump_requested = false
	if not in_attack_state:
		if InputMap.has_action("jump") and Input.is_action_just_pressed("jump") and not Input.is_action_pressed("ui_down"):
			jump_requested = true
		elif Input.is_action_just_pressed("ui_up"):
			jump_requested = true
		elif Input.is_key_pressed(KEY_SPACE) or Input.is_key_pressed(KEY_W):
			jump_requested = true
	
	if jump_requested:
		wants_to_jump = true
		# Ensure no attacks happen during jump
		action_pressed = true
		return  # Exit early to prevent any other actions this frame
	
	# Attack input - fallback to ui_accept if attack action isn't defined
	# ONLY trigger attack if on floor AND not using jump keys
	if can_attack_now and ((InputMap.has_action("attack") and Input.is_action_just_pressed("attack")) or 
	   (Input.is_action_just_pressed("ui_accept") and not Input.is_action_just_pressed("ui_up") and not Input.is_key_pressed(KEY_SPACE))):
		attempt_light_attack()
		action_pressed = true
	
	# Heavy attack input - fallback to ui_select + ui_down if not defined
	var heavy_attack_triggered = false
	if can_attack_now:
		if InputMap.has_action("heavy_attack") and Input.is_action_just_pressed("heavy_attack"):
			heavy_attack_triggered = true
		elif InputMap.has_action("attack") and Input.is_action_just_pressed("attack") and Input.is_action_pressed("ui_down"):
			heavy_attack_triggered = true
		elif Input.is_action_just_pressed("ui_select") and Input.is_action_pressed("ui_down"):
			heavy_attack_triggered = true
	
	if heavy_attack_triggered:
		attempt_heavy_attack()
		action_pressed = true
	
	# Dodge roll input - fallback to ui_cancel if dodge isn't defined
	var dodge_triggered = false
	if InputMap.has_action("dodge") and Input.is_action_just_pressed("dodge"):
		dodge_triggered = true
	elif InputMap.has_action("jump") and Input.is_action_just_pressed("jump") and Input.is_action_pressed("ui_down"):
		dodge_triggered = true
	elif Input.is_action_just_pressed("ui_cancel"):
		dodge_triggered = true
	
	if dodge_triggered and is_on_floor():  # Only dodge when on floor
		attempt_dodge_roll()
		action_pressed = true
	
	# Estus flask input - fallback to E key if heal isn't defined
	# Use is_action_just_pressed for E key to avoid holding key
	if can_attack_now and ((InputMap.has_action("heal") and Input.is_action_just_pressed("heal")) or 
	   Input.is_key_pressed(KEY_E) and Input.get_action_strength("ui_accept") < 0.5):  
		attempt_drink_estus()

func attempt_light_attack():
	# Check if we can attack and have enough stamina
	if can_attack and current_stamina >= light_attack_stamina_cost:
		# Use stamina
		current_stamina -= light_attack_stamina_cost
		
		# Update UI
		if stamina_ui and "current_stamina" in stamina_ui:
			stamina_ui.current_stamina = current_stamina
		
		# Start attack
		start_attack(false)

func attempt_heavy_attack():
	# Check if we can attack and have enough stamina
	if can_attack and current_stamina >= heavy_attack_stamina_cost:
		# Use stamina
		current_stamina -= heavy_attack_stamina_cost
		
		# Update UI
		if stamina_ui and "current_stamina" in stamina_ui:
			stamina_ui.current_stamina = current_stamina
		
		# Start heavy attack
		start_attack(true)

func start_attack(is_heavy):
	in_attack_state = true
	can_attack = false
	attack_timer = attack_cooldown
	is_heavy_attack = is_heavy
	
	# Slightly longer cooldown for heavy attacks
	if is_heavy:
		attack_timer = attack_cooldown * 1.5
	
	# Reset frame counter
	current_attack_frame = 0
	
	# Set stamina regeneration delay
	stamina_regen_delay = 1.0

func attempt_dodge_roll():
	# Can only dodge if not already dodging, not on cooldown, and have enough stamina
	if not is_dodge_rolling and dodge_roll_cooldown_timer <= 0 and current_stamina >= dodge_roll_stamina_cost:
		# Use stamina
		current_stamina -= dodge_roll_stamina_cost
		
		# Update UI
		if stamina_ui and "current_stamina" in stamina_ui:
			stamina_ui.current_stamina = current_stamina
		
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

func heal(amount):
	# Apply healing
	current_health = min(current_health + amount, max_health)
	
	# Update UI
	if health_bar:
		health_bar.value = current_health

func heal_fully():
	# Used by bonfire system
	current_health = max_health
	
	# Update UI
	if health_bar:
		health_bar.value = current_health

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
		health_bar.value = current_health

func drop_souls():
	# Store dropped souls amount and position
	souls_dropped_on_death = souls_count
	souls_drop_position = global_position
	
	# Reset souls count
	souls_count = 0
	
	# Update UI
	if souls_ui and souls_ui.has_method("update_souls_display"):
		souls_ui.souls_count = 0
		souls_ui.update_souls_display()
	
	# Spawn dropped souls visual (would be implemented in a real game)
	# TODO: Implement dropped souls visual

func collect_souls(amount):
	# Add souls to count
	souls_count += amount
	
	# Update UI
	if souls_ui and souls_ui.has_method("add_souls"):
		souls_ui.add_souls(amount)

# Method to collect chemical items
func collect_chemical(chemical_type, growth_amount=5.0):
	# Add to collected chemicals array
	if collected_chemicals.size() < max_chemicals:
		collected_chemicals.append(chemical_type)
		
		# Print confirmation
		print("Knight: Collected chemical type: ", chemical_type)
		
		# Emit signal via SignalBus if available
		var signal_bus = get_node_or_null("/root/SignalBus")
		if signal_bus:
			signal_bus.chemical_collected.emit(chemical_type, collected_chemicals.size() - 1)
		
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

# Handle animation completion
func _on_animation_finished():
	# Handle attack animation completion
	if animated_sprite.animation == "Attack":
		in_attack_state = false
		
	# If hurt animation finished, reset hurt state
	if animated_sprite.animation == "Hurt":
		is_hurt = false

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
	# Manual movement testing with key presses
	var test_move_left = Input.is_key_pressed(KEY_A) 
	var test_move_right = Input.is_key_pressed(KEY_D)
	var test_jump = Input.is_key_pressed(KEY_W) or Input.is_key_pressed(KEY_SPACE)
	
	# If space or W is pressed, ALWAYS prioritize jumping over attacking
	if Input.is_key_pressed(KEY_SPACE) or Input.is_key_pressed(KEY_W):
		# Explicitly cancel any attack state and prevent new attacks
		if in_attack_state:
			in_attack_state = false
		can_attack = false
		attack_timer = 0.1  # Short delay to prevent attack right after jump
		
		# If on floor, trigger the jump
		if is_on_floor() and not is_dodge_rolling and not is_drinking_estus and not is_dead:
			velocity.y = jump_velocity
			animated_sprite.play("Jump")
			# Set jump request flag for the physics process
			wants_to_jump = true
	
	# Don't allow test movement during attack animations when on floor
	# (allow movement if in air to prevent getting stuck)
	if in_attack_state and is_on_floor() and not test_jump:
		return
	
	# Force direction to make movement more immediate and responsive for testing
	if test_move_left and not is_dodge_rolling and not is_drinking_estus and not is_dead:
		# Force move left for testing - immediate response
		velocity.x = -movement_speed
		animated_sprite.flip_h = true
		if is_on_floor() and not test_jump:  # Don't change animation if jumping
			animated_sprite.play("Run")
		
	elif test_move_right and not is_dodge_rolling and not is_drinking_estus and not is_dead:
		# Force move right for testing - immediate response
		velocity.x = movement_speed
		animated_sprite.flip_h = false
		if is_on_floor() and not test_jump:  # Don't change animation if jumping
			animated_sprite.play("Run") 
	
	# Additional debugging controls
	if Input.is_key_pressed(KEY_I):  # Print debug info
		print("Knight Position:", global_position)
		print("Knight Velocity:", velocity)
		print("On Floor:", is_on_floor())
		print("Collision Layer:", collision_layer, " Mask:", collision_mask)
		print("States: dodge_rolling=", is_dodge_rolling, 
			  " drinking_estus=", is_drinking_estus, 
			  " in_attack=", in_attack_state)
