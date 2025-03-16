extends CharacterBody2D

class_name EnemyController

# Enemy properties
@export var health: int = 40  # Decreased from 100 to match our other changes
@export var damage: int = 20  # Increased from 10 to make enemies more dangerous
@export var drop_chemical_chance: float = 0.7  # 70% chance to drop

# References
var sprite: AnimatedSprite2D
var is_dead: bool = false
var is_attacking: bool = false  # Track attack state
var cannot_cancel_attack: bool = true  # Prevent interruption of attack animations

# Called when the node enters the scene tree
func _ready():
	# Find the animated sprite
	sprite = $AnimatedSprite2D
	if not sprite:
		push_error("Enemy is missing AnimatedSprite2D node")
	
	# Add to enemies group
	add_to_group("enemies")

# Take damage from player
func take_damage(amount: int):
	if is_dead:
		return
		
	health -= amount
	
	# Check if dead
	if health <= 0:
		die()
	else:
		# Only play hurt animation if not in attack animation
		if sprite:
			if is_attacking and cannot_cancel_attack:
				# Apply damage shader if available, but don't interrupt attack
				apply_damage_flash()
			elif sprite.has_animation("hurt"):
				sprite.play("hurt")

# Apply a damage flash effect
func apply_damage_flash():
	# This is a simple implementation - in a real project, you'd use a shader
	if sprite:
		var original_modulate = sprite.modulate
		sprite.modulate = Color(1.5, 0.3, 0.3, 1.0)  # Red flash
		
		# Return to normal after a short time
		var tween = get_tree().create_tween()
		tween.tween_property(sprite, "modulate", original_modulate, 0.15)

# Die and emit signals
func die():
	if is_dead:
		return
		
	is_dead = true
	
	# Play death animation if available
	if sprite and sprite.has_animation("death"):
		sprite.play("death")
	
	# Disable collision
	$CollisionShape2D.set_deferred("disabled", true)
	
	# Emit signal if SignalBus is available
	if Engine.has_singleton("SignalBus"):
		var signal_bus = Engine.get_singleton("SignalBus")
		signal_bus.enemy_died.emit(self)
		signal_bus.enemy_killed.emit(global_position, "NightBorne")
	
	# Chance to drop a chemical
	if randf() <= drop_chemical_chance:
		drop_chemical()
	
	# Queue free after animation
	await get_tree().create_timer(1.0).timeout
	queue_free()

# Drop a chemical when dying
func drop_chemical():
	# Get the level
	var level = get_tree().current_scene
	
	# Check if the level has a spawn_random_chemical method
	if level and level.has_method("spawn_random_chemical"):
		# Use the level to spawn a chemical at our position
		var ChemicalScript = load("res://Objects/Scripts/Chemical/Chemical.gd")
		var chemical = ChemicalScript.spawn_chemical(global_position)
		level.add_child(chemical)
		print("Enemy dropped a chemical") 