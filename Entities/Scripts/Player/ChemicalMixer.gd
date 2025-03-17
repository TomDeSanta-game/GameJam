extends Node

class_name PlayerChemicalMixer

# Preload the Growth System to ensure we're using the correct implementation
const GrowthSystemClass = preload("res://Systems/Scripts/GrowthSystem/GrowthSystem.gd")

# Chemical mixing parameters
@export var max_stored_chemicals: int = 3     # Maximum number of chemicals that can be stored
@export var mix_cooldown: float = 2.0         # Cooldown between mixes in seconds
@export var debug: bool = false               # Disable debug logs

# Chemical mix effects
const MIX_EFFECTS = {
	"RedGreen": "Speed",         # Speed boost
	"RedBlue": "Strength",       # Damage boost
	"RedYellow": "FireResist",   # Fire resistance
	"RedPurple": "Explosion",    # Area damage
	"GreenBlue": "Healing",      # Health regeneration
	"GreenYellow": "Jump",       # Jump boost
	"GreenPurple": "Toxic",      # Toxic cloud
	"BlueYellow": "Electric",    # Electric attacks
	"BluePurple": "Shield",      # Damage shield
	"YellowPurple": "Stealth"    # Temporary invisibility
}

# Effect durations in seconds
const EFFECT_DURATIONS = {
	"Speed": 10.0,
	"Strength": 15.0,
	"FireResist": 20.0,
	"Explosion": 0.5,  # Instant effect but with small delay
	"Healing": 5.0,
	"Jump": 12.0,
	"Toxic": 8.0,
	"Electric": 10.0,
	"Shield": 8.0,
	"Stealth": 5.0
}

# References
var player: Node
var growth_system: Node  # Changed from GrowthSystem to Node to avoid parse error

# State variables
var stored_chemicals = []           # Array of chemical types currently stored
var can_mix: bool = true            # Whether mixing is available
var mix_timer: float = 0.0          # Timer for mix cooldown
var active_effects = {}             # Dictionary of active effects and their timers

# Signals
signal chemical_stored(chemical_type, total_stored)
signal chemicals_mixed(mix_name, effect_name)
signal effect_activated(effect_name, duration)
signal effect_deactivated(effect_name)

func _ready():
	# Find player (parent node)
	player = get_parent()
	
	# Find growth system if it exists
	growth_system = player.get_node_or_null("GrowthSystem")
	
	# Connect to chemical collected signal
	var signal_bus = get_node_or_null("/root/SignalBus")
	if signal_bus and signal_bus.has_signal("chemical_collected"):
		signal_bus.chemical_collected.connect(_on_chemical_collected)

func _process(delta):
	# Handle mix cooldown
	if not can_mix:
		mix_timer -= delta
		if mix_timer <= 0:
			can_mix = true
	
	# Update active effects
	var effects_to_remove = []
	for effect in active_effects.keys():
		active_effects[effect] -= delta
		if active_effects[effect] <= 0:
			effects_to_remove.append(effect)
	
	# Remove expired effects
	for effect in effects_to_remove:
		_deactivate_effect(effect)

# Called when a chemical is collected
# Using _ prefix for param2 to indicate it's intentionally unused
func _on_chemical_collected(chemical_type, _param2) -> void:
	# Skip processing if null - used for clearing slots
	if chemical_type == null:
		return
	
	# Store the chemical if there's room
	if stored_chemicals.size() < max_stored_chemicals:
		stored_chemicals.append(chemical_type)
		emit_signal("chemical_stored", chemical_type, stored_chemicals.size())
		
		# Auto-mix if we have enough chemicals
		if stored_chemicals.size() >= 2:
			var should_auto_mix = randf() < 0.5  # 50% chance to auto-mix
			if should_auto_mix:
				mix_chemicals()
	
# Mix the stored chemicals to create an effect
func mix_chemicals():
	if not can_mix or stored_chemicals.size() < 2:
		return false
	
	# Select two random chemicals to mix
	stored_chemicals.shuffle()
	var chem1 = stored_chemicals.pop_front()
	var chem2 = stored_chemicals.pop_front()
	
	# Sort the chemicals alphabetically to ensure consistent mix keys
	var mix_key
	if chem1 < chem2:
		mix_key = chem1 + chem2
	else:
		mix_key = chem2 + chem1
	
	# Check if this is a valid mix
	if mix_key in MIX_EFFECTS:
		var effect_name = MIX_EFFECTS[mix_key]
		emit_signal("chemicals_mixed", mix_key, effect_name)
		
		# Apply the effect
		_activate_effect(effect_name)
		
		# Start cooldown
		can_mix = false
		mix_timer = mix_cooldown
		
		return true
	else:
		# Invalid mix, return chemicals to storage
		stored_chemicals.append(chem1)
		stored_chemicals.append(chem2)
		
		return false

# Activate the effect of a chemical mix
func _activate_effect(effect_name):
	var duration = EFFECT_DURATIONS[effect_name]
	active_effects[effect_name] = duration
	
	# Apply effect based on type
	match effect_name:
		"Speed":
			# Increase player speed
			if "movement_speed" in player:
				player.movement_speed *= 1.5
		
		"Strength":
			# Increase damage output
			if player.has_method("set_damage_multiplier"):
				player.set_damage_multiplier(2.0)
		
		"FireResist":
			# Add fire resistance
			if "resistances" in player:
				player.resistances["fire"] = 0.8
		
		"Explosion":
			# Create an explosion around the player
			_create_explosion()
		
		"Healing":
			# Heal the player
			if "current_health" in player and "max_health" in player:
				player.current_health = min(player.current_health + 20, player.max_health)
		
		"Jump":
			# Increase jump height
			if "jump_velocity" in player:
				player.jump_velocity *= 1.3
		
		"Toxic":
			# Create toxic cloud that damages enemies
			_create_toxic_cloud()
		
		"Electric":
			# Add electric damage to attacks
			if player.has_method("add_elemental_effect"):
				player.add_elemental_effect("electric", 10)
		
		"Shield":
			# Add damage shield
			if "is_invincible" in player:
				player.is_invincible = true
		
		"Stealth":
			# Make player temporarily invisible
			if player.has_method("set_visibility"):
				player.set_visibility(0.3)  # 30% opacity
	
	# Also boost growth slightly for the "mix chemicals" part of the growth system
	if growth_system:
		growth_system.grow_by(0.02)  # Small growth boost from mixing
	
	emit_signal("effect_activated", effect_name, duration)

# Deactivate an effect when it expires
func _deactivate_effect(effect_name):
	# Remove from active effects
	active_effects.erase(effect_name)
	
	# Undo effect based on type
	match effect_name:
		"Speed":
			# Reset player speed
			if "movement_speed" in player:
				player.movement_speed /= 1.5
		
		"Strength":
			# Reset damage output
			if player.has_method("set_damage_multiplier"):
				player.set_damage_multiplier(1.0)
		
		"FireResist":
			# Remove fire resistance
			if "resistances" in player:
				player.resistances.erase("fire")
		
		"Jump":
			# Reset jump height
			if "jump_velocity" in player:
				player.jump_velocity /= 1.3
		
		"Electric":
			# Remove electric damage from attacks
			if player.has_method("remove_elemental_effect"):
				player.remove_elemental_effect("electric")
		
		"Shield":
			# Remove damage shield
			if "is_invincible" in player:
				player.is_invincible = false
		
		"Stealth":
			# Make player visible again
			if player.has_method("set_visibility"):
				player.set_visibility(1.0)  # Full opacity
	
	emit_signal("effect_deactivated", effect_name)

# Create an explosion around the player
func _create_explosion():
	# Spawn explosion effect
	var explosion_scene = load("res://Effects/ChemicalExplosion.tscn")
	if explosion_scene:
		var explosion = explosion_scene.instantiate()
		player.get_parent().add_child(explosion)
		explosion.global_position = player.global_position
		
		# Try to damage nearby enemies through the explosion node
		if explosion.has_method("set_damage"):
			explosion.set_damage(25.0)
	
	if debug:
		print("Created explosion at player position")

# Create a toxic cloud that follows the player
func _create_toxic_cloud():
	# Spawn toxic cloud effect
	var cloud_scene = load("res://Effects/ToxicCloud.tscn")
	if cloud_scene:
		var cloud = cloud_scene.instantiate()
		player.add_child(cloud)
		cloud.position = Vector2.ZERO  # Center on player
		
		# Try to set the cloud duration
		if "duration" in cloud:
			cloud.duration = EFFECT_DURATIONS["Toxic"]
	
	if debug:
		print("Created toxic cloud following player")

# Get the number of stored chemicals
func get_stored_count() -> int:
	return stored_chemicals.size()

# Get list of active effects
func get_active_effects() -> Array:
	return active_effects.keys()

# Force a specific chemical mix (for testing or special gameplay moments)
func force_mix(chem1: String, chem2: String) -> bool:
	# Add chemicals temporarily
	stored_chemicals.append(chem1)
	stored_chemicals.append(chem2)
	
	# Try to mix
	return mix_chemicals() 