extends Node

class_name GrowthSystem

# Constants
const BASE_GROWTH_AMOUNT = 5.0
const GROWTH_PER_LEVEL = 10.0
const MAX_GROWTH_LEVEL = 5
const BASE_SCALE = Vector2(1.0, 1.0)
const SCALE_MULTIPLIER = 1.2  # 20% scale increase per level

# Variables
var current_growth: float = 0.0
var growth_level: int = 0
var player: Node = null

# Effect system
var current_effect: String = ""
var effect_timer: float = 0.0
var original_speed: float = 0.0
var original_jump: float = 0.0
var original_damage: float = 0.0

func _ready():
	player = get_parent()
	
	# Connect to signals
	var signal_bus = get_node_or_null("/root/SignalBus")
	if signal_bus:
		# Connect to player damage signal
		if signal_bus.has_signal("player_damaged"):
			signal_bus.player_damaged.connect(_on_player_damaged)
		
		# Connect to chemicals mixed signal
		if signal_bus.has_signal("chemicals_mixed"):
			signal_bus.chemicals_mixed.connect(_on_chemicals_mixed)

# Signal handler for chemicals_mixed
func _on_chemicals_mixed(effect_name: String, duration: float) -> void:
	# Don't process if nothing to apply
	if effect_name == "" or effect_name == "None":
		return
	
	# Process the effect
	if player:
		# Force clear any current effect to avoid stacking
		if current_effect != "":
			_end_current_effect()
		
		# Apply the new effect
		_apply_effect(effect_name, duration)
	else:
		# No valid player reference
		pass

# Signal handler for player_damaged
func _on_player_damaged(player_node, damage_amount) -> void:
	# Check that this signal is for our player
	if player_node != player:
		return
	
	# Shrink the player when damaged
	shrink(damage_amount * 2)  # Double the damage for growth reduction

# Basic growth function
func grow(amount: float) -> void:
	# Add growth
	current_growth += amount
	
	# Check for level up
	var new_level = int(current_growth / GROWTH_PER_LEVEL)
	if new_level > growth_level:
		# Level up
		growth_level = new_level
		
		# Limit to max level
		if growth_level > MAX_GROWTH_LEVEL:
			growth_level = MAX_GROWTH_LEVEL
		
		# Apply scaling
		var new_scale = BASE_SCALE * pow(SCALE_MULTIPLIER, growth_level)
		player.scale = new_scale
		
		# Emit signal
		var signal_bus = get_node_or_null("/root/SignalBus")
		if signal_bus and signal_bus.has_signal("growth_level_changed"):
			var level_percent = (current_growth - (growth_level * GROWTH_PER_LEVEL)) / GROWTH_PER_LEVEL
			signal_bus.growth_level_changed.emit(player, growth_level, level_percent)
	
	# Always emit grew signal
	var signal_bus = get_node_or_null("/root/SignalBus")
	if signal_bus and signal_bus.has_signal("player_grew"):
		signal_bus.player_grew.emit(player, current_growth)

# Alias for grow method (for backward compatibility)
func grow_by(amount: float) -> void:
	grow(amount)

# Shrink when taking damage
func shrink(amount: float) -> void:
	# Reduce growth
	current_growth -= amount
	if current_growth < 0:
		current_growth = 0
	
	# Update level
	var new_level = int(current_growth / GROWTH_PER_LEVEL)
	if new_level < growth_level:
		# Level down
		growth_level = new_level
		
		# Apply scaling
		var new_scale = BASE_SCALE * pow(SCALE_MULTIPLIER, growth_level)
		player.scale = new_scale
		
		# Emit signal
		var signal_bus = get_node_or_null("/root/SignalBus")
		if signal_bus and signal_bus.has_signal("growth_level_changed"):
			var level_percent = (current_growth - (growth_level * GROWTH_PER_LEVEL)) / GROWTH_PER_LEVEL
			signal_bus.growth_level_changed.emit(player, growth_level, level_percent)
	
	# Always emit shrank signal
	var signal_bus_shrank = get_node_or_null("/root/SignalBus")
	if signal_bus_shrank and signal_bus_shrank.has_signal("player_shrank"):
		signal_bus_shrank.player_shrank.emit(player, current_growth)

# Public method for backward compatibility
func apply_effect(effect_name: String, duration: float) -> void:
	_apply_effect(effect_name, duration)

# Public method for backward compatibility
func end_effect() -> void:
	_end_current_effect()

# Apply an effect (private implementation)
func _apply_effect(effect_name: String, duration: float) -> void:
	# End any existing effect first
	if current_effect != "":
		_end_current_effect()
	
	# Set the new effect
	current_effect = effect_name
	effect_timer = duration
	
	# Start the effect behavior
	_start_effect_behavior()
	
	# Emit the effect applied signal
	var signal_bus = get_node_or_null("/root/SignalBus")
	if signal_bus and signal_bus.has_signal("effect_applied"):
		signal_bus.effect_applied.emit(effect_name, duration)

# Process function to handle effects
func _process(delta: float) -> void:
	# Update effect timer
	if current_effect != "":
		effect_timer -= delta
		if effect_timer <= 0:
			_end_current_effect()
	
	# Process continuous effect behaviors if needed
	match current_effect:
		"Healing":
			_process_healing(delta)

# Start effect behavior
func _start_effect_behavior() -> void:
	# Get effect depending on type
	match current_effect:
		"Speed":
			original_speed = player.movement_speed
			player.movement_speed = original_speed * 1.5
		
		"Jump":
			original_jump = player.jump_velocity
			player.jump_velocity = original_jump * 1.3
		
		"Healing":
			# This is handled in _process
			pass
		
		"Strength":
			original_damage = player.attack_damage
			player.attack_damage = original_damage * 1.8
		
		"Growth Burst":
			# Instant big growth
			grow(30.0)
		
		"Ultimate Power":
			# Combine all positive effects
			original_speed = player.movement_speed
			player.movement_speed = original_speed * 1.75
			
			original_jump = player.jump_velocity
			player.jump_velocity = original_jump * 1.5
			
			original_damage = player.attack_damage
			player.attack_damage = original_damage * 2.5
			
			grow(50.0)
		
		_:
			# Unknown effect
			pass

# Process healing effect
func _process_healing(delta: float) -> void:
	if player and player.has_method("heal"):
		var heal_amount = delta * 10.0  # Heal 10 health per second
		player.heal(heal_amount)
	else:
		# Fallback if player doesn't have a heal method
		if player and "current_health" in player and "max_health" in player:
			player.current_health = min(player.current_health + (delta * 10.0), player.max_health)

# End the current effect
func _end_current_effect() -> void:
	match current_effect:
		"Speed":
			player.movement_speed = original_speed
		
		"Jump":
			player.jump_velocity = original_jump
		
		"Strength":
			player.attack_damage = original_damage
		
		"Ultimate Power":
			player.movement_speed = original_speed
			player.jump_velocity = original_jump
			player.attack_damage = original_damage
		
		_:
			# Some effects don't need cleanup
			pass
	
	# Clear the effect
	current_effect = ""
	effect_timer = 0.0