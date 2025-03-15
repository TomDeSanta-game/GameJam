extends CharacterBody2D

class_name EnemyController

# Enemy properties
@export var health: int = 100
@export var damage: int = 10
@export var drop_chemical_chance: float = 0.7  # 70% chance to drop

# References
var sprite: AnimatedSprite2D
var is_dead: bool = false

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
		# Play hurt animation if available
		if sprite and sprite.has_animation("hurt"):
			sprite.play("hurt")

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
	
	# Emit signals for growth system
	SignalBus.enemy_died.emit(self)
	SignalBus.enemy_killed.emit(global_position, "NightBorne")
	
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
		var ChemicalItem = load("res://Entities/Scripts/Items/Chemical.gd")
		var chemical = ChemicalItem.spawn_chemical(global_position)
		level.add_child(chemical)
		print("Enemy dropped a chemical")
	
	# Alternatively, just emit a signal for something else to handle
	SignalBus.chemical_collected.emit(randi() % 5, global_position) 