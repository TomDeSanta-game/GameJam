extends Node

class_name PlayerGrowthSystem

# Growth System Parameters
@export var base_scale: float = 1.0           # Starting scale of the player
@export var max_scale: float = 2.5            # Maximum scale the player can grow to
@export var min_scale: float = 0.5            # Minimum scale the player can shrink to
@export var kill_growth_amount: float = 0.025 # Reduced from 0.05 to 0.025 (more kills needed for growth)
@export var chem_growth_amount: float = 0.1   # How much to grow when collecting a chemical
@export var damage_shrink_amount: float = 0.1 # How much to shrink when taking damage
@export var growth_speed: float = 5.0         # How fast the scale animation happens
@export var debug: bool = false               # Set to false to disable debug logs

# Variables to track growth
var current_scale: float = 1.0                # Current scale value
var target_scale: float = 1.0                 # Target scale to animate towards
var initial_player_scale: Vector2             # Store the player's initial scale
var accumulated_growth: float = 0.0           # Track total growth for damage calculations
var collected_chems: int = 0                  # Track number of chemicals collected
var enemies_killed: int = 0                   # Track number of enemies killed
var current_level: int = 1                    # Current growth level

# References
var player: CharacterBody2D                   # Reference to the player
var is_animating_scale: bool = false          # Flag to check if currently animating scale

# Signal for UI updates
signal growth_updated(scale_percent: float, chems: int, enemies: int)

func _ready() -> void:
	# Find the player (parent node)
	player = get_parent()
	if not player is CharacterBody2D:
		push_error("GrowthSystem must be attached to a CharacterBody2D node")
		set_process(false)
		return
	
	# Store initial scale
	initial_player_scale = player.scale
	current_scale = base_scale
	target_scale = base_scale
	
	# Connect to relevant signals
	_connect_signals()

func _process(delta: float) -> void:
	# Animate current scale towards target scale
	if current_scale != target_scale:
		is_animating_scale = true
		current_scale = lerp(current_scale, target_scale, delta * growth_speed)
		
		# If we're close enough to the target, snap to it
		if abs(current_scale - target_scale) < 0.01:
			current_scale = target_scale
			is_animating_scale = false
		
		# Apply the scale to the player
		player.scale = initial_player_scale * current_scale
		
		# Emit signal for UI updates
		var growth_percent: float = (current_scale - base_scale) / (max_scale - base_scale) * 100
		growth_updated.emit(growth_percent, collected_chems, enemies_killed)
		
		# Update growth level when scale changes
		_update_growth_level()

func _connect_signals() -> void:
	# Connect to relevant signal buses
	var signal_bus = get_node_or_null("/root/SignalBus")
	if signal_bus:
		if signal_bus.has_signal("enemy_died"):
			signal_bus.enemy_died.connect(_on_enemy_died)
		
		if signal_bus.has_signal("chemical_collected"):
			signal_bus.chemical_collected.connect(_on_chemical_collected)
		
		if signal_bus.has_signal("player_damaged"):
			signal_bus.player_damaged.connect(_on_player_damaged)
		
		if signal_bus.has_signal("player_died"):
			signal_bus.player_died.connect(_on_player_died)
	
	# If player has a Knight script, connect directly to its signals
	if player.has_signal("damaged"):
		player.damaged.connect(_on_player_damaged)
	
	if player.has_signal("died"):
		player.died.connect(_on_player_died)

# Called when an enemy is killed
func _on_enemy_died(_enemy: Node) -> void:
	# Implement diminishing returns for growth from enemy kills
	var diminished_growth: float = kill_growth_amount / (1.0 + (enemies_killed * 0.1))
	
	# Increase the growth with diminished returns
	grow_by(diminished_growth)
	enemies_killed += 1
	
	# Update growth level after enemy kill
	_update_growth_level()

# Called when a chemical is collected
func _on_chemical_collected(_chemical_type: int, _chemical_position: Vector2) -> void:
	# Increase the growth
	grow_by(chem_growth_amount)
	collected_chems += 1

# Called when the player takes damage
func _on_player_damaged(_player_node: Node, _damage_amount: float) -> void:
	# Decrease the growth, but not below the accumulated growth
	shrink_by(damage_shrink_amount)

# Called when the player dies
func _on_player_died() -> void:
	# Reset growth
	reset_growth()

# Grow by the specified amount, up to max_scale
func grow_by(amount: float) -> void:
	accumulated_growth += amount
	target_scale = clamp(target_scale + amount, min_scale, max_scale)

# Shrink by the specified amount, but not below min_scale
# Also don't shrink more than we've grown through enemies/chemicals
func shrink_by(amount: float) -> void:
	# Calculate minimum allowed scale based on accumulated growth
	var min_allowed_scale: float = max(min_scale, base_scale - accumulated_growth * 0.5)
	target_scale = clamp(target_scale - amount, min_allowed_scale, max_scale)

# Reset growth to base value
func reset_growth() -> void:
	target_scale = base_scale
	accumulated_growth = 0.0
	
	# Immediately reset scale without animation
	current_scale = base_scale
	player.scale = initial_player_scale * current_scale

# Get current growth percentage (0-100)
func get_growth_percent() -> float:
	return (current_scale - base_scale) / (max_scale - base_scale) * 100

# Apply gameplay effects based on current growth
func apply_growth_effects() -> void:
	# Modify player stats based on current growth
	# These could be overwritten by child classes specific to your game
	
	# Example: Increase damage with size
	if player.has_method("set_damage_multiplier"):
		var damage_multiplier: float = 1.0 + (current_scale - base_scale)
		player.set_damage_multiplier(damage_multiplier)
	
	# Example: Increase jump height with size
	if "jump_velocity" in player:
		var jump_boost: float = 1.0 + (current_scale - base_scale) * 0.5
		player.jump_velocity = player.jump_velocity * jump_boost
	
	# Example: Decrease movement speed as you get bigger
	if "movement_speed" in player:
		var speed_penalty: float = 1.0 - (current_scale - base_scale) * 0.2
		player.movement_speed = player.movement_speed * max(0.6, speed_penalty)

# Add a level system based on growth thresholds
func _update_growth_level() -> void:
	# Calculate what level the player should be based on current scale
	# Each level requires progressively more growth
	var new_level: int = 1
	var growth_percentage: float = (current_scale - base_scale) / (max_scale - base_scale)
	
	if growth_percentage <= 0.0:
		new_level = 1
	elif growth_percentage <= 0.2:
		new_level = 2
	elif growth_percentage <= 0.4:
		new_level = 3
	elif growth_percentage <= 0.6:
		new_level = 4
	elif growth_percentage <= 0.8:
		new_level = 5
	else:
		new_level = 6
	
	# If level changed, update it and emit signal
	if new_level != current_level:
		current_level = new_level
		var signal_bus = get_node_or_null("/root/SignalBus")
		if signal_bus and signal_bus.has_signal("growth_level_changed"):
			signal_bus.growth_level_changed.emit(current_level, Vector2(current_scale, current_scale)) 