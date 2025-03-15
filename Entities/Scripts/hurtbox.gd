extends Area2D

## The entity that owns this hurtbox
var entity

func _ready():
	# Get parent entity
	entity = get_parent()
	
	# Set collision layers/masks for proper detection
	collision_layer = 4  # Layer 4 for hurtboxes
	collision_mask = 2   # Mask 2 to be hit by hitboxes
	
	# Check if entity has take_damage method
	if not entity.has_method("take_damage"):
		push_warning("Entity with Hurtbox doesn't implement take_damage method: " + entity.name)

## Take damage when hit by a hitbox
func take_damage(damage_amount: float, knockback_force: Vector2 = Vector2.ZERO):
	if entity.has_method("take_damage"):
		entity.take_damage(damage_amount, knockback_force) 
