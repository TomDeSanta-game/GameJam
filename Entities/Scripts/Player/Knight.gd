extends CharacterBody2D

# Constants and Configuration
const STATS = {
	"MAX_HEALTH": 100.0,
	"MAX_STAMINA": 100.0,
	"STAMINA_REGEN_RATE": 10.0,
	"ATTACK_STAMINA_COST": 15.0,
	"HEAVY_ATTACK_STAMINA_COST": 35.0,
	"DODGE_STAMINA_COST": 25.0,
	"RUN_STAMINA_DRAIN": 5.0,
	"COYOTE_TIME": 0.15,
	"JUMP_BUFFER_TIME": 0.15,
	"MAX_KNOCKBACK_SPEED": 200.0,  # Add maximum knockback speed
}

# Variable version of stats that can be modified
var current_stats = {
	"MAX_HEALTH": 100.0,
	"MAX_STAMINA": 100.0,
}

const ANIMATIONS = {
	"IDLE": "Idle",
	"RUN": "Run",
	"JUMP": "Jump",
	"FALL": "Fall",
	"ATTACK": "Attack",
	"HEAVY_ATTACK": "Heavy_Attack",
	"HURT": "Hurt",
	"DODGE": "Dodge",
	"ESTUS": "Estus",
	"DEATH": "Death"
}

# Movement parameters
@export var movement_speed: float = 300.0
@export var acceleration: float = 1800.0
@export var friction: float = 1600.0
@export var jump_strength: float = -450.0  # Make this negative to jump upward
@export var gravity: float = 980.0
@export var max_fall_speed: float = 980.0
@export var air_control: float = 0.9  # Good air control
@export var max_horizontal_speed: float = 500.0

# ROCK-SOLID jump feel parameters
@export var jump_gravity_scale: float = 0.5  # Standard platformer rising gravity
@export var fall_gravity_scale: float = 1.0  # Normal falling gravity 
@export var apex_gravity_scale: float = 0.4  # Slight float at apex
@export var apex_threshold: float = 80.0  # Tighter apex window for snappier jumps

# PROVEN jump cut parameters
@export var jump_cut_power: float = 0.4  # Standard platformer cut value
@export var min_jump_height_ratio: float = 0.3  # Good minimum height for gameplay
@export var min_jump_time: float = 0.07  # Just enough time to feel right

# Add floor snap vector
var floor_snap_vector: Vector2 = Vector2.DOWN * 32.0

# Jump mechanics
@export var coyote_time: float = 0.15  # Increased from 0.1 to 0.15
@export var jump_buffer_time: float = 0.15  # Increased from 0.1 to 0.15
var coyote_timer: float = 0.0
var jump_buffer_timer: float = 0.0
var can_double_jump: bool = true
var is_jumping: bool = false
var was_jump_pressed: bool = false
var jump_held: bool = false  # Track if jump button is being held
var jump_time: float = 0.0   # Track how long we've been jumping

# Combat state
var current_stamina: float = 100.0
var current_health: float = 100.0
var is_invincible: bool = false
var invincibility_timer: float = 0.0
var is_state_locked: bool = false
var is_heavy_attack: bool = false
var current_attack_frame: int = 0
var can_attack: bool = true
var damage_reduction: float = 0.0  # Add damage reduction variable

# Dodge roll
var is_dodge_rolling: bool = false
var dodge_roll_duration: float = 0.3
var dodge_roll_speed: float = 250.0
var dodge_roll_i_frames: float = 0.3
var dodge_roll_cooldown: float = 0.5
var dodge_roll_timer: float = 0.0
var dodge_roll_cooldown_timer: float = 0.0

# Estus flask
var current_estus_charges: int = 5
var max_estus_charges: int = 5
var estus_heal_amount: float = 50.0
var estus_drink_duration: float = 1.0
var estus_drink_timer: float = 0.0

# Node references
@onready var animated_sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var health_bar = $CanvasLayer/HealthBar
@onready var stamina_bar = $CanvasLayer/StaminaBar
@onready var knight_state_machine: KnightStateMachine

# Colors
var hurt_color: Color = Color(2, 2, 2, 1)  # White flash (values > 1 create bright flash)
var normal_color: Color = Color(1, 1, 1)

# State tracking
var current_state: String = "idle"
var previous_state: String = "idle"
var was_on_floor: bool = false
var wants_to_jump: bool = false
var is_jump_cut: bool = false

# Movement state
var previous_direction: float = 0.0
var target_velocity: Vector2 = Vector2.ZERO

# Debug
var debug_enabled: bool = true

# State flags
var is_hurt: bool = false
var is_stamina_depleted: bool = false
var is_stamina_regenerating: bool = true
var in_attack_state: bool = false
var is_drinking_estus: bool = false
var last_damage_from_nightborne: bool = false

# Add initial position tracking at the top with other variables
@export var initial_position: Vector2 = Vector2.ZERO
@export var death_y_threshold: float = 1000.0  # Adjust this value based on your level

# Camera parameters
@onready var camera: Camera2D = $Camera2D
var camera_fixed_y_position: float = 0.0  # Will be set on ready
var max_vertical_distance: float = 150.0  # Maximum distance you can go above camera
var camera_ceiling_push_force: float = 3000.0  # Force to push player down when hitting ceiling

# Add these variables near the top with other constants/configs
@export var base_attack_damage: float = 1.0  # Base damage the player deals
@export var damage_modifier: float = 1.0      # Modifier for current game mode
var vampire_mode: bool = false                 # Track if vampire mode is active

# Gameplay properties
var is_dead: bool = false  # New flag to track death state
var stamina_regen_rate: float = 20.0

# Character stats and modifiers
var attack_cooldown_timer: float = 0.0
var last_attack_time: int = 0

func _ready() -> void:
	# Initialize current_stats with values from STATS
	current_stats["MAX_HEALTH"] = STATS.MAX_HEALTH
	current_stats["MAX_STAMINA"] = STATS.MAX_STAMINA
	
	# Store initial position
	initial_position = global_position
	
	# Set up floor snap
	floor_snap_vector = Vector2.DOWN * 32.0
	
	# Add self to "Player" group
	if not is_in_group("Player"):
		add_to_group("Player")
	
	# Set up collision layers
	setup_collision_layers()
	
	# Set up input actions
	setup_input_actions()
	
	# Initialize state machine
	setup_state_machine()
	
	# Store original modulate color
	if animated_sprite:
		animated_sprite.modulate = normal_color
	
	# Setup camera - completely fixed in Y direction
	if camera:
		# Store the initial Y position of the camera
		camera_fixed_y_position = global_position.y
		
		# Disable all automatic camera following
		camera.position_smoothing_enabled = false
		camera.drag_horizontal_enabled = false
		camera.drag_vertical_enabled = false
		camera.position = Vector2(0, 0)  # Reset position relative to player
		
		# Important: Enable process callback to manually control camera
		set_process(true)
	
	# Initialize timers
	was_on_floor = is_on_floor()
	coyote_timer = 0.0
	jump_buffer_timer = 0.0
	
	# Add ChemicalCollectSound if it doesn't exist
	if not has_node("ChemicalCollectSound"):
		var sound = AudioStreamPlayer.new()
		sound.name = "ChemicalCollectSound"
		sound.volume_db = -8.0
		# Don't try to load a specific sound file that may not exist
		# Instead, we'll create the audio player now and set the stream when collecting
		add_child(sound)
		# Added ChemicalCollectSound node without stream
	
	# Initialization complete

func _process(delta: float) -> void:
	# Handle stamina regeneration
	if not is_state_locked:
		regenerate_stamina(delta)
	
	# Reset color if not in special states
	if not is_invincible and not is_hurt and not is_stamina_depleted and animated_sprite:
		animated_sprite.modulate = normal_color
	
	# Manual camera control - COMPLETELY FIXED Y, only follows horizontally
	if camera:
		# Force the camera's Y position to stay fixed
		camera.global_position.y = camera_fixed_y_position
		
		# Let X position follow the player directly (no smoothing)
		camera.global_position.x = global_position.x
	
	# Handle debug actions
	if debug_enabled:
		if Input.is_key_pressed(KEY_I):  # Print debug info
			print("Knight Position:", global_position)
			print("Knight Velocity:", velocity)
			print("On Floor:", is_on_floor())
			print("Camera Position:", camera.global_position if camera else "No camera")
			print("States: dodge_rolling=", is_dodge_rolling, " in_attack=", in_attack_state, " drinking_estus=", is_drinking_estus)
			print("Can attack:", can_attack, " Stamina:", current_stamina)
			print("Hitbox:", get_node_or_null("HitBox"), " Monitoring:", get_node_or_null("HitBox").monitoring if get_node_or_null("HitBox") else "N/A")
			print("Collision shape:", get_node_or_null("HitBox").get_node_or_null("CollisionShape2D") if get_node_or_null("HitBox") else "N/A")
		
		# Development testing - Press T to force attack (for debugging)
		if Input.is_key_pressed(KEY_T) and is_on_floor():
			print("KNIGHT: T KEY PRESSED - FORCE TESTING ATTACK!")
			execute_attack_test()
		
		# Let the user press R to reset the camera if needed
		if Input.is_key_pressed(KEY_R) and camera:
			camera_fixed_y_position = global_position.y
			print("KNIGHT: Camera Y position reset to ", camera_fixed_y_position)

func _physics_process(delta: float) -> void:
	# Skip input processing if paused
	if get_tree().paused:
		return
	
	# Skip all processing if dead except for out of bounds check
	if is_dead:
		# Only apply gravity and move_and_slide to ensure the character falls if needed
		if not is_on_floor():
			velocity.y += gravity * delta
			velocity.y = min(velocity.y, max_fall_speed)
		velocity.x = 0  # Stop horizontal movement when dead
		move_and_slide()
		return
	
	# Check for out of bounds before anything else
	if global_position.y > death_y_threshold:
		respawn()
		return
	
	# Track if jump was pressed this frame
	var jump_pressed = Input.is_action_just_pressed("jump")
	var jump_released = Input.is_action_just_released("jump")
	var jump_button_held = Input.is_action_pressed("jump")
	
	# Update jump time when jumping
	if is_jumping:
		jump_time += delta
	else:
		jump_time = 0.0
	
	# Update jump held state - crucial for variable jump height
	if jump_pressed:
		jump_held = true
	if jump_released:
		jump_held = false
	
	# Update coyote time and jump buffer
	if is_on_floor():
		coyote_timer = coyote_time
		can_double_jump = true
	else:
		coyote_timer -= delta
	
	if jump_pressed:
		jump_buffer_timer = jump_buffer_time
		was_jump_pressed = true
	else:
		jump_buffer_timer -= delta
	
	# Soft ceiling constraint - prevent going too far above camera
	var distance_above_camera = camera_fixed_y_position - global_position.y
	
	# Get input direction
	var input_direction = Input.get_axis("move_left", "move_right")
	
	# Handle jumps with improved logic
	if (jump_pressed or jump_buffer_timer > 0) and (is_on_floor() or coyote_timer > 0):
		# Execute jump if on floor or in coyote time, and jump was pressed or buffered
		velocity.y = jump_strength  # Use the original value without negation
		is_jumping = true
		jump_time = 0.0
		jump_buffer_timer = 0.0  # Reset jump buffer
		can_double_jump = true
		
		# Play jump sound
		var jump_sound = get_node_or_null("JumpSound")
		if jump_sound:
			jump_sound.play()
			
		# Play jump animation
		if animated_sprite:
			animated_sprite.play(ANIMATIONS.JUMP)
	elif jump_pressed and can_double_jump and not is_on_floor() and !is_state_locked:
		# Execute double jump if in air and have double jump available
		velocity.y = jump_strength * 0.8  # Slightly weaker double jump
		can_double_jump = false
		
		# Play double jump sound
		var jump_sound = get_node_or_null("JumpSound")
		if jump_sound:
			jump_sound.play()
			
		# Play jump animation
		if animated_sprite:
			animated_sprite.play(ANIMATIONS.JUMP)
	
	# Variable jump height by cutting velocity when button released
	if !jump_button_held and velocity.y < 0 and is_jumping:
		velocity.y *= 0.5  # Cut jump short if button released
		is_jumping = false
	
	# Apply gravity with variable scale based on jump state
	var current_gravity_scale = 1.0
	
	# NEW: Check for enemies very close to the player that might cause them to get stuck
	var enemies_nearby = false
	var enemy_position = null
	var nearby_enemies = get_tree().get_nodes_in_group("Enemy")
	
	for enemy in nearby_enemies:
		var distance = global_position.distance_to(enemy.global_position)
		if distance < 20:  # Enemies within very close proximity
			enemies_nearby = true
			enemy_position = enemy.global_position
			break
	
	# If enemies are very close and we're moving slower than expected, apply a small separation force
	if enemies_nearby and abs(velocity.x) < 50 and abs(input_direction) > 0.5:
		var separation_direction = (global_position - enemy_position).normalized()
		velocity += separation_direction * 100 * delta
	
	if not is_on_floor():
		if abs(velocity.y) < apex_threshold:
			# We're at the apex of the jump - apply reduced gravity for a floaty feel
			current_gravity_scale = apex_gravity_scale
		elif velocity.y < 0:
			# Rising - normal jump gravity
			current_gravity_scale = jump_gravity_scale
		else:
			# Falling - heavier gravity for satisfying landing
			current_gravity_scale = fall_gravity_scale
			is_jumping = false  # Reset jumping when falling
		
		# Apply gravity with current scale
		velocity.y += gravity * current_gravity_scale * delta
		
		# Cap fall speed
		velocity.y = min(velocity.y, max_fall_speed)
	else:
		# Reset jump state when on floor
		is_jumping = false
	
	# Handle movement input using both arrow keys and WASD
	handle_improved_movement(delta, input_direction)
	
	# Update state machine after movement
	if knight_state_machine:
		knight_state_machine.update(delta)
	
	# Clamp horizontal velocity
	velocity.x = clamp(velocity.x, -max_horizontal_speed, max_horizontal_speed)
	
	# Handle sprite flipping based on movement
	if input_direction != 0 and animated_sprite:
		animated_sprite.flip_h = input_direction < 0
	
	move_and_slide()
	
	# NEW: If we're colliding with something and barely moving, give a tiny upward boost
	if get_slide_collision_count() > 0 and abs(velocity.x) < 10 and abs(input_direction) > 0.2:
		velocity.y = -50  # Small upward boost to help unstick
	
	# Update state tracking
	was_jump_pressed = Input.is_action_pressed("jump")
	
	update_timers(delta)
	regenerate_stamina(delta)
	update_hitbox_position()
	
	# Ensure animation state matches physics state if we're not in a special state
	if not is_state_locked and knight_state_machine:
		if not is_on_floor():
			# Use a similar threshold as the Jump state for consistency
			var fall_threshold = 35.0  # Updated to match Jump state (was 25.0)
			if velocity.y < 0 and knight_state_machine.current_state != "jump":
				knight_state_machine.change_state("jump")
			elif velocity.y > fall_threshold and knight_state_machine.current_state != "fall" and knight_state_machine.current_state == "jump":
				# Only change from jump to fall if we're above the threshold
				# Otherwise, let the jump state's own timer and logic handle it
				knight_state_machine.change_state("fall")
		elif input_direction != 0 and knight_state_machine.current_state != "run":
			knight_state_machine.change_state("run")
		elif input_direction == 0 and is_on_floor() and knight_state_machine.current_state != "idle":
			knight_state_machine.change_state("idle")

func setup_state_machine() -> void:
	knight_state_machine = KnightStateMachine.new()
	add_child(knight_state_machine)
	knight_state_machine.init(self)

# State machine class
class KnightStateMachine extends Node:
	var knight: CharacterBody2D
	var current_state: String = "idle"
	var states: Dictionary = {}
	
	func init(knight_node: CharacterBody2D) -> void:
		knight = knight_node
		
		# Initialize states
		states = {
			"idle": StateIdle.new(knight),
			"run": StateRun.new(knight),
			"jump": StateJump.new(knight),
			"fall": StateFall.new(knight),
			"attack": StateAttack.new(knight),
			"hurt": StateHurt.new(knight),
			"dodge": StateDodge.new(knight),
			"estus": StateEstus.new(knight),
			"death": StateDeath.new(knight)
		}
		
		change_state("idle")
	
	func update(delta: float) -> void:
		if current_state in states:
			states[current_state].update(delta)
	
	func change_state(new_state: String) -> void:
		if current_state in states:
			states[current_state].exit()
		
		current_state = new_state
		
		if current_state in states:
			states[current_state].enter()
		
		if knight.debug_enabled:
			print("KNIGHT: State changed to ", current_state)

# Base state class
class State:
	var knight: CharacterBody2D
	
	func _init(knight_node: CharacterBody2D) -> void:
		knight = knight_node
	
	func enter() -> void:
		pass
	
	func update(_delta: float) -> void:
		pass
	
	func exit() -> void:
		pass

# Idle state
class StateIdle extends State:
	func enter() -> void:
		knight.animated_sprite.play(knight.ANIMATIONS.IDLE)
		knight.is_state_locked = false
	
	func update(delta: float) -> void:
		var input_direction = Input.get_axis("move_left", "move_right")
		
		if input_direction != 0:
			knight.knight_state_machine.change_state("run")
		elif not knight.is_on_floor():
			if knight.velocity.y > 0:
				knight.knight_state_machine.change_state("fall")
			else:
				knight.knight_state_machine.change_state("jump")
		
		# Handle attack input
		if Input.is_action_just_pressed("attack") and knight.can_attack:
			knight.knight_state_machine.change_state("attack")
		
		# Handle dodge input
		if Input.is_action_just_pressed("ui_focus_next") or Input.is_key_pressed(KEY_Q):
			if knight.attempt_dodge_roll():
				knight.knight_state_machine.change_state("dodge")
		
		# Handle estus input
		if Input.is_key_pressed(KEY_H) and knight.current_estus_charges > 0:
			knight.knight_state_machine.change_state("estus")
		
		# Handle movement in idle
		knight.handle_improved_movement(delta, input_direction)

# Run state
class StateRun extends State:
	func enter() -> void:
		knight.animated_sprite.play(knight.ANIMATIONS.RUN)
		knight.is_state_locked = false
	
	func update(delta: float) -> void:
		var input_direction = Input.get_axis("move_left", "move_right")
		
		if input_direction == 0:
			knight.knight_state_machine.change_state("idle")
		elif not knight.is_on_floor():
			if knight.velocity.y > 0:
				knight.knight_state_machine.change_state("fall")
			else:
				knight.knight_state_machine.change_state("jump")
		
		# Handle movement
		knight.handle_improved_movement(delta, input_direction)
		
		# Handle attack input
		if Input.is_action_just_pressed("attack") and knight.can_attack:
			knight.knight_state_machine.change_state("attack")
		
		# Handle dodge input
		if Input.is_action_just_pressed("ui_focus_next") or Input.is_key_pressed(KEY_Q):
			if knight.attempt_dodge_roll():
				knight.knight_state_machine.change_state("dodge")
		
		# Apply gravity
		if not knight.is_on_floor():
			knight.velocity.y += knight.gravity * delta

# Jump state
class StateJump extends State:
	var animation_started: bool = false
	var min_jump_time: float = 0.15  # Minimum time to stay in jump state (animation only)
	var time_in_jump: float = 0.0  # Track time spent in jump state
	var fall_threshold: float = 35.0  # Higher threshold for better floatiness
	
	func enter() -> void:
		knight.is_state_locked = false
		# Only play the animation once when entering the state
		if not animation_started:
			# Play the jump animation at slower speed for longer duration
			knight.animated_sprite.play(knight.ANIMATIONS.JUMP)
			knight.animated_sprite.speed_scale = 0.5  # Even slower animation (was 0.6)
			animation_started = true
		time_in_jump = 0.0  # Reset timer when entering jump state
		
		if knight.is_on_floor():
			knight.velocity.y = knight.jump_strength
			knight.is_jumping = true  # Make sure we set this flag
			knight.jump_time = 0.0   # Reset jump time
			print("KNIGHT: Jump state entered, velocity set to: ", knight.velocity.y)
	
	func update(delta: float) -> void:
		var input_direction = Input.get_axis("move_left", "move_right")
		
		# Increment time spent in jump state
		time_in_jump += delta
		
		# NOTE: We aren't handling jump cutting here anymore - it's all in _physics_process
		# This simplifies the logic and ensures consistency
		
		# Handle air movement - allow the player to move while jumping
		knight.handle_improved_movement(delta, input_direction)
		
		# Apply gravity with reduced scale for slower jumps
		knight.velocity.y += knight.gravity * knight.jump_gravity_scale * delta
		
		# Only transition to fall state when actually falling at sufficient speed
		if knight.velocity.y > fall_threshold:
			animation_started = false  # Reset for next jump
			knight.knight_state_machine.change_state("fall")
			return
		
		# Land check - only transition if actually on floor
		if knight.is_on_floor():
			animation_started = false  # Reset for next jump
			knight.is_jumping = false  # Make sure we reset this flag
			if abs(knight.velocity.x) > 10:
				knight.knight_state_machine.change_state("run")
			else:
				knight.knight_state_machine.change_state("idle")
	
	func exit() -> void:
		# Reset animation flag and speed when exiting the state
		animation_started = false
		knight.animated_sprite.speed_scale = 1.0

# Fall state
class StateFall extends State:
	var animation_started: bool = false
	var time_in_fall: float = 0.0
	var min_fall_time: float = 0.12  # Slightly increased time in fall state (was 0.1)
	
	func enter() -> void:
		knight.is_state_locked = false
		# Only play the animation once when entering the state
		if not animation_started:
			knight.animated_sprite.play(knight.ANIMATIONS.FALL)
			knight.animated_sprite.speed_scale = 0.9  # Slightly slower fall animation
			animation_started = true
		time_in_fall = 0.0  # Reset timer
	
	func update(delta: float) -> void:
		var input_direction = Input.get_axis("move_left", "move_right")
		
		# Increment time in fall state
		time_in_fall += delta
		
		# Handle movement
		knight.handle_improved_movement(delta, input_direction)
		
		# Apply gravity with the fall gravity scale
		knight.velocity.y += knight.gravity * knight.fall_gravity_scale * delta
		
		# Cap fall speed
		knight.velocity.y = min(knight.velocity.y, knight.max_fall_speed)
		
		# Only check for landing when we're actually falling and have been in fall state for minimum time
		if knight.is_on_floor() and time_in_fall >= min_fall_time:
			animation_started = false  # Reset for next fall
			if abs(knight.velocity.x) > 10:
				knight.knight_state_machine.change_state("run")
			else:
				knight.knight_state_machine.change_state("idle")
	
	func exit() -> void:
		# Reset animation flag and speed when exiting the state
		animation_started = false
		knight.animated_sprite.speed_scale = 1.0

# Attack state
class StateAttack extends State:
	var attack_timer: float = 0.0
	var max_attack_duration: float = 0.4  # 4 frames at 10 fps = 0.4 seconds
	
	func enter() -> void:
		knight.is_state_locked = true
		knight.animated_sprite.play(knight.ANIMATIONS.ATTACK if not knight.is_heavy_attack else knight.ANIMATIONS.HEAVY_ATTACK)
		
		# Reset the attack timer
		attack_timer = 0.0
		
		# Set animation speed to ensure it plays at correct speed
		knight.animated_sprite.speed_scale = 1.0
		
		knight.current_attack_frame = 0
		
		# Perform the attack with damage scaling
		knight.perform_attack(knight.is_heavy_attack)
		
		# Apply attack cost
		var stamina_cost = knight.STATS.ATTACK_STAMINA_COST
		if knight.is_heavy_attack:
			stamina_cost = knight.STATS.HEAVY_ATTACK_STAMINA_COST
		knight.current_stamina = max(0, knight.current_stamina - stamina_cost)
		
		# Update stamina bar if it exists
		var stamina_bar = knight.get_node_or_null("CanvasLayer/StaminaBar")
		if stamina_bar:
			stamina_bar.value = knight.current_stamina
	
	func update(delta: float) -> void:
		# Update attack timer
		attack_timer += delta
		
		# Force exit from attack state if it's been longer than the animation should take
		if attack_timer >= max_attack_duration:
			print("KNIGHT: Attack state timed out after ", attack_timer, " seconds - force ending")
			knight.in_attack_state = false
			knight.is_state_locked = false
			
			# Forcibly change state based on current conditions
			if knight.is_on_floor():
				if abs(knight.velocity.x) > 10:
					knight.knight_state_machine.change_state("run")
				else:
					knight.knight_state_machine.change_state("idle")
			elif knight.velocity.y > 0:
				knight.knight_state_machine.change_state("fall")
			else:
				knight.knight_state_machine.change_state("jump")
				
			# Also make sure hitbox is disabled
			var knight_hitbox = knight.get_node_or_null("HitBox")
			if knight_hitbox:
				knight_hitbox.set_deferred("monitoring", false)
				knight_hitbox.set_deferred("monitorable", false)
				var collision_shape = knight_hitbox.get_node_or_null("CollisionShape2D")
				if collision_shape:
					collision_shape.set_deferred("disabled", true)
			return
		
		# Handle attack movement
		knight.handle_attack_movement(delta, Input.get_axis("move_left", "move_right"))
		
		# Apply gravity
		if not knight.is_on_floor():
			knight.velocity.y += knight.gravity * delta
	
	func exit() -> void:
		# Ensure we reset the attack state
		knight.in_attack_state = false
		knight.is_state_locked = false
		
		# Ensure hitbox is disabled
		var knight_hitbox = knight.get_node_or_null("HitBox")
		if knight_hitbox:
			knight_hitbox.set_deferred("monitoring", false)
			knight_hitbox.set_deferred("monitorable", false)
			var collision_shape = knight_hitbox.get_node_or_null("CollisionShape2D")
			if collision_shape:
				collision_shape.set_deferred("disabled", true)

# Hurt state
class StateHurt extends State:
	var hurt_timer: float = 0.1  # Reduced hurt state duration
	var current_timer: float = 0.0
	
	func enter() -> void:
		knight.is_state_locked = true
		knight.animated_sprite.play(knight.ANIMATIONS.HURT)
		knight.animated_sprite.modulate = knight.hurt_color
		current_timer = hurt_timer
		
		# ALWAYS completely stop all movement when hit, not just from NightBorne
		knight.velocity = Vector2.ZERO
	
	func update(delta: float) -> void:
		current_timer -= delta
		
		# Apply gravity only, no horizontal movement allowed
		if not knight.is_on_floor():
			knight.velocity.y += knight.gravity * delta
		
		# Force X velocity to zero during the entire hurt state
		knight.velocity.x = 0
		
		# Exit hurt state after timer
		if current_timer <= 0:
			knight.last_damage_from_nightborne = false  # Reset the flag
			knight.knight_state_machine.change_state("idle")

# Dodge state
class StateDodge extends State:
	func enter() -> void:
		knight.is_state_locked = true
		knight.animated_sprite.play(knight.ANIMATIONS.DODGE)
		knight.start_invincibility(knight.dodge_roll_i_frames)
	
	func update(delta: float) -> void:
		knight.handle_dodge_roll_improved(delta, Input.get_axis("move_left", "move_right"))
		
		if not knight.is_dodge_rolling:
			knight.knight_state_machine.change_state("idle")

# Estus state
class StateEstus extends State:
	func enter() -> void:
		knight.is_state_locked = true
		knight.animated_sprite.play(knight.ANIMATIONS.ESTUS)
		knight.current_estus_charges -= 1
		knight.estus_drink_timer = knight.estus_drink_duration
	
	func update(delta: float) -> void:
		knight.estus_drink_timer -= delta
		
		if knight.estus_drink_timer <= 0:
			knight.heal(knight.estus_heal_amount)
			knight.knight_state_machine.change_state("idle")

# Death state
class StateDeath extends State:
	func enter() -> void:
		knight.is_state_locked = true
		knight.is_dead = true  # Set the dead flag
		knight.animated_sprite.play(knight.ANIMATIONS.DEATH)
		
		# Disable hitboxes
		var knight_hitbox = knight.get_node_or_null("HitBox")
		if knight_hitbox:
			knight_hitbox.set_deferred("monitoring", false)
			knight_hitbox.set_deferred("monitorable", false)
		
		var knight_hurtbox = knight.get_node_or_null("HurtBox")
		if knight_hurtbox:
			knight_hurtbox.set_deferred("monitoring", false)
			knight_hurtbox.set_deferred("monitorable", false)
			
		# Emit signal that player died
		var signal_bus = knight.get_node_or_null("/root/SignalBus")
		if signal_bus and signal_bus.has_signal("player_died"):
			signal_bus.emit_signal("player_died")
		
		# Schedule scene reload after a short delay to show death animation
		var death_timer = knight.get_tree().create_timer(1.0)
		death_timer.timeout.connect(func(): 
			# Access SceneManager and reload the scene
			var scene_manager = knight.get_node_or_null("/root/SceneManager")
			if scene_manager and scene_manager.has_method("reload_scene"):
				scene_manager.reload_scene()
			else:
				# Fallback if SceneManager is not available
				knight.get_tree().reload_current_scene()
		)

# Helper functions
func handle_improved_movement(delta: float, input_direction: float) -> void:
	if is_state_locked:
		return
		
	var target_speed = input_direction * movement_speed
	
	# Apply improved air control
	if not is_on_floor():
		# Apply smoother air control with less aggressive braking
		if input_direction != 0:
			# When actively controlling, allow better responsiveness in the air
			var air_accel = acceleration * air_control
			velocity.x = move_toward(velocity.x, target_speed, air_accel * delta)
		else:
			# When not controlling, apply very light air resistance
			var air_friction = friction * 0.2
			velocity.x = move_toward(velocity.x, 0, air_friction * delta)
	else:
		# Ground movement remains unchanged
		if input_direction != 0:
			velocity.x = move_toward(velocity.x, target_speed, acceleration * delta)
		else:
			velocity.x = move_toward(velocity.x, 0, friction * delta)

func handle_dodge_roll_improved(delta: float, _input_direction: float) -> void:
	if is_dodge_rolling:
		velocity.x = dodge_roll_speed * (-1 if animated_sprite.flip_h else 1)
		dodge_roll_timer -= delta
		
		if dodge_roll_timer <= 0:
			is_dodge_rolling = false
			dodge_roll_cooldown_timer = dodge_roll_cooldown

func handle_attack_movement(delta: float, input_direction: float) -> void:
	# Slow down during attacks
	velocity.x = move_toward(velocity.x, 0, friction * delta * 2)
	
	# Allow slight movement during attacks
	if input_direction != 0:
		velocity.x += input_direction * movement_speed * 0.2 * delta

func handle_jump() -> void:
	if Input.is_action_just_pressed("jump"):
		# Print debug info to verify jump is being triggered
		print("KNIGHT: Jump button pressed")
		
		if is_on_floor() or coyote_timer > 0:
			# First jump
			print("KNIGHT: Executing first jump")
			velocity.y = jump_strength  # Apply negative value directly for upward movement
			coyote_timer = 0
			can_double_jump = false
			
			# Play jump animation
			if animated_sprite and not in_attack_state:
				animated_sprite.play(ANIMATIONS.JUMP)
				
			# Play jump sound if available
			var jump_sound = get_node_or_null("JumpSound")
			if jump_sound:
				jump_sound.play()
				
		elif not can_double_jump and not is_state_locked:
			# Second jump (double jump)
			print("KNIGHT: Executing double jump")
			velocity.y = jump_strength * 0.8  # Slightly weaker double jump
			can_double_jump = false
			
			# Play double jump animation if different
			if animated_sprite and not in_attack_state:
				animated_sprite.play(ANIMATIONS.JUMP)
				
			# Play double jump sound if available
			var double_jump_sound = get_node_or_null("DoubleJumpSound")
			var jump_sound = get_node_or_null("JumpSound")  # Define jump_sound in this scope too
			if double_jump_sound:
				double_jump_sound.play()
			elif jump_sound:
				jump_sound.play()

func apply_improved_gravity(delta: float) -> void:
	if not is_on_floor():
		var current_gravity_scale = 1.0
		
		# Determine gravity scale based on vertical state
		if abs(velocity.y) < apex_threshold:
			# At jump apex, apply lower gravity for a floaty feel
			current_gravity_scale = apex_gravity_scale
		elif velocity.y < 0:
			# Rising - use jump gravity
			current_gravity_scale = jump_gravity_scale
		else:
			# Falling - use fall gravity
			current_gravity_scale = fall_gravity_scale
			is_jumping = false
		
		# Apply scaled gravity
		velocity.y += gravity * current_gravity_scale * delta
		velocity.y = min(velocity.y, max_fall_speed)
	else:
		# Reset jump state when on floor
		is_jumping = false

func handle_landing_impact() -> void:
	if is_on_floor() and velocity.y > 500:
		velocity.x *= 0.5
		# Add landing effects here if needed

func update_hitbox_position() -> void:
	var hitbox = get_node_or_null("HitBox")
	if hitbox:
		var base_position = Vector2(20 if not animated_sprite.flip_h else -20, 0)
		hitbox.position = base_position

func regenerate_stamina(delta: float) -> void:
	if not is_state_locked:
		var old_stamina = current_stamina
		current_stamina = min(current_stamina + 20 * delta, current_stats.MAX_STAMINA)
		
		# Only update UI if value has changed
		if stamina_bar and old_stamina != current_stamina:
			stamina_bar.value = current_stamina

func update_timers(delta: float) -> void:
	if invincibility_timer > 0:
		invincibility_timer -= delta
		if invincibility_timer <= 0:
			is_invincible = false
			animated_sprite.modulate = normal_color
	
	if attack_cooldown_timer > 0:
		attack_cooldown_timer -= delta

func setup_collision_layers() -> void:
	var hitbox = get_node_or_null("HitBox")
	var hurtbox = get_node_or_null("HurtBox")
	
	if hitbox:
		hitbox.connect("area_entered", Callable(self, "_on_hitbox_area_entered"))
	
	if hurtbox:
		hurtbox.connect("area_entered", Callable(self, "_on_hurtbox_area_entered"))

func setup_other_systems() -> void:
	animated_sprite.animation_finished.connect(_on_animation_finished)

func attempt_dodge_roll() -> bool:
	if not is_dodge_rolling and dodge_roll_cooldown_timer <= 0 and current_stamina >= STATS.DODGE_STAMINA_COST:
		current_stamina -= STATS.DODGE_STAMINA_COST
		
		# Update stamina bar
		if stamina_bar:
			stamina_bar.value = current_stamina
			
		is_dodge_rolling = true
		dodge_roll_timer = dodge_roll_duration
		return true
	return false

func start_invincibility(duration: float) -> void:
	is_invincible = true
	invincibility_timer = duration
	animated_sprite.modulate = hurt_color  # White flash
	
	# Create a tween for the flash effect
	var tween = create_tween()
	tween.tween_property(animated_sprite, "modulate", normal_color, 0.1)

# Add method for external systems to trigger invulnerability
func set_invulnerable(invulnerable: bool, duration: float = 0.0) -> void:
	print("GODMODE: Player invulnerability set to ", invulnerable, " for ", duration, " seconds")
	
	is_invincible = invulnerable
	if invulnerable and duration > 0:
		invincibility_timer = duration
		
		# Create visual feedback for godmode
		animated_sprite.modulate = Color(1.5, 1.5, 2.0, 0.8)  # Bright blue-ish glow
		
		# Create pulsing effect to show invulnerability
		var tween = create_tween()
		tween.set_loops()  # Make it loop indefinitely
		tween.tween_property(animated_sprite, "modulate", Color(1.0, 1.0, 3.0, 0.9), 0.5)
		tween.tween_property(animated_sprite, "modulate", Color(1.5, 1.5, 2.0, 0.8), 0.5)
		
		# Reset after duration
		await get_tree().create_timer(duration).timeout
		if tween.is_valid():
			tween.kill()  # Stop the tween
		is_invincible = false
		animated_sprite.modulate = normal_color
		print("GODMODE: Player invulnerability expired")
	elif not invulnerable:
		# Immediately turn off invulnerability
		invincibility_timer = 0.0
		animated_sprite.modulate = normal_color

# Add method to set damage reduction
func set_damage_reduction(reduction: float) -> void:
	print("GODMODE: Player damage reduction set to ", reduction * 100, "%")
	damage_reduction = clamp(reduction, 0.0, 1.0)  # Ensure it's between 0 and 1

# Add method to set max health bonus
func set_max_health_bonus(bonus: float) -> void:
	print("GODMODE: Player max health bonus set to +", bonus)
	var old_max = current_stats.MAX_HEALTH
	current_stats.MAX_HEALTH = 100.0 + bonus
	
	# Update UI
	if health_bar:
		health_bar.max_value = current_stats.MAX_HEALTH
		
	# Also heal the player by the difference
	if current_health < current_stats.MAX_HEALTH:
		heal(current_stats.MAX_HEALTH - old_max)

func heal(amount: float) -> void:
	current_health = min(current_health + amount, current_stats.MAX_HEALTH)
	if health_bar:
		health_bar.heal(amount)

# Ensures animation completion by forcibly resetting stuck animations
func _on_animation_finished():
	var current_animation = animated_sprite.animation
	
	# Special handling for attack animation
	if in_attack_state or current_animation == ANIMATIONS.ATTACK:
		print("KNIGHT: Attack animation finished")
		in_attack_state = false
		is_state_locked = false
		
		# Ensure hitbox is disabled
		var knight_hitbox = get_node_or_null("HitBox")
		if knight_hitbox:
			knight_hitbox.set_deferred("monitoring", false)
			knight_hitbox.set_deferred("monitorable", false)
			var collision_shape = knight_hitbox.get_node_or_null("CollisionShape2D")
			if collision_shape:
				collision_shape.set_deferred("disabled", true)
		
		# Return to appropriate movement state
		if is_on_floor():
			if abs(velocity.x) > 10:
				knight_state_machine.change_state("run")
			else:
				knight_state_machine.change_state("idle")
		elif velocity.y > 0:
			knight_state_machine.change_state("fall")
		else:
			knight_state_machine.change_state("jump")
	
	# If we're in a dodge roll, reset state
	elif is_dodge_rolling and current_animation == ANIMATIONS.DODGE_ROLL:
		is_dodge_rolling = false
		is_invincible = false
		is_state_locked = false
		animated_sprite.modulate = normal_color
		
		# Return to appropriate movement state
		if is_on_floor():
			if abs(velocity.x) > 10:
				knight_state_machine.change_state("run")
			else:
				knight_state_machine.change_state("idle")
		elif velocity.y > 0:
			knight_state_machine.change_state("fall")
		else:
			knight_state_machine.change_state("jump")

func _on_hitbox_area_entered(area: Area2D) -> void:
	if area.is_in_group("enemy"):
		var enemy = area.get_parent()
		if enemy.has_method("take_damage"):
			# Check if this is the NightBorne enemy by name
			var is_nightborne = false
			if "name" in enemy and (enemy.name.to_lower().contains("nightborne") or enemy.name.to_lower().contains("night_borne")):
				is_nightborne = true
				print("KNIGHT: Hit NightBorne enemy - applying no knockback")
			
			# Apply normal knockback to regular enemies, but no knockback to NightBorne
			var knockback_vector = Vector2.ZERO if is_nightborne else (enemy.global_position - global_position).normalized()
			
			# Apply damage with current modifier
			var actual_damage = base_attack_damage * damage_modifier
			enemy.take_damage(actual_damage, knockback_vector)

func _on_hurtbox_area_entered(area: Area2D) -> void:
	if area.is_in_group("enemy_attack"):
		var enemy = area.get_parent()
		if enemy:
			# Check if this is the NightBorne enemy by name - more comprehensive check
			var is_nightborne = false
			if enemy:
				# Check the enemy node name at any level in its hierarchy
				var check_node = enemy
				while check_node and not is_nightborne:
					if check_node.name.to_lower().contains("nightborne") or check_node.name.to_lower().contains("night") or check_node.name.to_lower().contains("borne"):
						is_nightborne = true
						print("KNIGHT: Hit by NightBorne enemy - ignoring knockback")
					check_node = check_node.get_parent() if check_node.get_parent() != null else null
			
			# Always take damage without knockback, whether NightBorne or not
			take_damage(10, Vector2.ZERO)  # Just always use zero knockback for now

func take_damage(amount: float, knockback_direction: Vector2) -> void:
	if is_dead or is_invincible:
		return
	
	# Apply damage
	current_health -= amount
	
	# Update health bar UI
	if health_bar:
		# Call take_damage method instead of directly setting value
		health_bar.take_damage(amount)
		print("KNIGHT: Health reduced to ", current_health)
	else:
		print("KNIGHT: Health bar not found!")
	
	# NEVER apply knockback regardless of the direction
	velocity = Vector2.ZERO
	
	start_invincibility(0.5)
	
	if current_health <= 0:
		knight_state_machine.change_state("death")
	else:
		knight_state_machine.change_state("hurt")

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

# Function to initialize state machine
func initialize_state_machine():
	# Simplified state machine setup for Dark Souls version
	knight_state_machine = KnightStateMachine.new()
	add_child(knight_state_machine)
	knight_state_machine.init(self)

# Add the missing setup_key_checker function
func setup_key_checker():
	# This function was referenced but not implemented
	# Implementation would typically check for keys or create a key checker node
	print("KNIGHT: KeyChecker setup was called but not implemented")
	
	# Example implementation (commented out):
	# var key_checker = Node.new()
	# key_checker.name = "KeyChecker"
	# add_child(key_checker)
	# print("KNIGHT: Created KeyChecker node")

# Update existing test function to use deferred calls
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
		# Force the hitbox on with deferred calls
		knight_hitbox.set_deferred("monitoring", true)
		knight_hitbox.set_deferred("monitorable", true)
		
		# Make sure the collision shape is enabled
		var collision_shape = knight_hitbox.get_node_or_null("CollisionShape2D")
		if collision_shape:
			collision_shape.set_deferred("disabled", false)
			print("KNIGHT: Collision shape forcibly enabled for testing")
		
		print("KNIGHT: Hitbox forcibly enabled at ", knight_hitbox.position)

func execute_attack() -> void:
	# Set state variables
	in_attack_state = true
	is_state_locked = true
	last_attack_time = Time.get_ticks_msec()
	
	# Play attack animation
	if animated_sprite:
		animated_sprite.play(ANIMATIONS.ATTACK)
	
	# Get hitbox
	var knight_hitbox = get_node_or_null("HitBox")
	if knight_hitbox:
		# CRITICAL FIX: Enable hitbox with deferred calls to ensure reliable activation
		knight_hitbox.set_deferred("monitoring", true)
		knight_hitbox.set_deferred("monitorable", true)
		
		# Make sure the collision shape is enabled
		var collision_shape = knight_hitbox.get_node_or_null("CollisionShape2D")
		if collision_shape:
			collision_shape.set_deferred("disabled", false)
			
		# Set damage and activate the hitbox
		knight_hitbox.damage = base_attack_damage * damage_modifier
		knight_hitbox.activate()
		
		print("KNIGHT: Hitbox activated with damage: ", knight_hitbox.damage)
	
	# Apply attack cooldown
	can_attack = false
	attack_cooldown_timer = 0.5

# Set up input map for WASD
func setup_input_actions() -> void:
	# Set up move left
	if not InputMap.has_action("move_left"):
		InputMap.add_action("move_left")
		var event_a = InputEventKey.new()
		event_a.keycode = KEY_A
		InputMap.action_add_event("move_left", event_a)
		var event_left = InputEventKey.new()
		event_left.keycode = KEY_LEFT
		InputMap.action_add_event("move_left", event_left)
	
	# Set up move right
	if not InputMap.has_action("move_right"):
		InputMap.add_action("move_right")
		var event_d = InputEventKey.new()
		event_d.keycode = KEY_D
		InputMap.action_add_event("move_right", event_d)
		var event_right = InputEventKey.new()
		event_right.keycode = KEY_RIGHT
		InputMap.action_add_event("move_right", event_right)
	
	# Set up jump
	if not InputMap.has_action("jump"):
		InputMap.add_action("jump")
		var event_w = InputEventKey.new()
		event_w.keycode = KEY_W
		InputMap.action_add_event("jump", event_w)
		var event_space = InputEventKey.new()
		event_space.keycode = KEY_SPACE
		InputMap.action_add_event("jump", event_space)
		var event_up = InputEventKey.new()
		event_up.keycode = KEY_UP
		InputMap.action_add_event("jump", event_up)

# Add function to toggle vampire mode
func toggle_vampire_mode(enabled: bool) -> void:
	vampire_mode = enabled
	
	if vampire_mode:
		# In vampire mode, player deals more damage but takes less
		damage_modifier = 2.0  # Double player damage
		print("KNIGHT: Vampire mode activated - damage increased")
	else:
		# In normal mode, player deals less damage but takes more
		damage_modifier = 0.75  # Reduced player damage
		print("KNIGHT: Normal mode activated - damage decreased")
		
	# You can call this function from elsewhere to toggle modes

# Fix the perform_attack function to properly check if AttackSound exists
func perform_attack(is_heavy: bool = false) -> void:
	# Get hitbox
	var hitbox = $HitBox
	
	if not hitbox:
		print("KNIGHT: No hitbox found for attack!")
		return
		
	# Update hitbox with current damage including modifier
	var attack_damage = base_attack_damage
	if is_heavy:
		attack_damage *= 2.0  # Heavy attacks do double damage
		
	# Apply damage modifier
	attack_damage *= damage_modifier
	
	# Set hitbox damage
	hitbox.damage = attack_damage
	
	# Activate hitbox
	hitbox.activate()
	
	# Play attack sound if node exists
	var attack_sound = get_node_or_null("AttackSound")
	if attack_sound:
		attack_sound.play()

# Add a respawn function to reset the player
func respawn() -> void:
	# Reset position and velocity
	global_position = initial_position
	velocity = Vector2.ZERO
	
	# Reset health
	current_health = current_stats.MAX_HEALTH
	if health_bar:
		health_bar.value = current_health
	
	# Reset stamina
	current_stamina = current_stats.MAX_STAMINA
	if stamina_bar:
		stamina_bar.value = current_stamina
	
	# Reset death state
	is_dead = false
	is_state_locked = false
	
	# Re-enable hitboxes
	var knight_hitbox = get_node_or_null("HitBox")
	if knight_hitbox:
		knight_hitbox.set_deferred("monitoring", true)
		knight_hitbox.set_deferred("monitorable", true)
	
	var knight_hurtbox = get_node_or_null("HurtBox")
	if knight_hurtbox:
		knight_hurtbox.set_deferred("monitoring", true)
		knight_hurtbox.set_deferred("monitorable", true)
	
	# Reset to idle state
	if knight_state_machine:
		knight_state_machine.change_state("idle")
	
	print("KNIGHT: Respawned at initial position")

# Function to handle chemical collection
func collect_chemical(chemical_type: String, growth_amount: float) -> void:
	# Apply growth if we have a growth system
	if has_node("GrowthSystem") and get_node("GrowthSystem").has_method("grow"):
		get_node("GrowthSystem").grow(growth_amount)
	
	# Play sound effect
	if has_node("ChemicalCollectSound"):
		var sound = get_node("ChemicalCollectSound")
		if not sound.stream:
			sound.stream = load("res://Assets/Sounds/chemical_collect.wav")
		sound.play()
	
	# Apply effects based on chemical type
	match chemical_type:
		"red":
			# Healing
			heal(20.0)
		"blue":
			# Stamina restoration
			current_stamina = min(current_stamina + 50.0, current_stats.MAX_STAMINA)
		"green":
			# Speed boost
			movement_speed *= 1.3
			await get_tree().create_timer(5.0).timeout
			movement_speed /= 1.3
		"yellow":
			# Invincibility
			set_invulnerable(3.0)
		"purple":
			# Attack power
			damage_modifier *= 1.5
			await get_tree().create_timer(5.0).timeout
			damage_modifier /= 1.5
