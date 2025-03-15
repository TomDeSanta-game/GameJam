extends Area2D

## The entity that owns this hurtbox
var entity

# For debugging collision issues
@export var debug: bool = true

# Indicates if this is a player hurtbox (false = enemy hurtbox)
@export var is_player_hurtbox: bool = false

func _ready():
	# Get parent entity
	entity = get_parent()
	
	# Determine if this is a player hurtbox based on parent
	if entity is Knight:
		is_player_hurtbox = true
		if debug:
			print("Detected player hurtbox for: ", entity.name)
	
	# Set collision layers/masks for proper detection
	if is_player_hurtbox:
		# Player hurtbox should only be hit by enemy hitboxes (layer 16)
		collision_layer = 8   # Layer 8 for player hurtboxes
		collision_mask = 16   # Mask 16 to be hit by enemy hitboxes
		if debug:
			print("Player hurtbox configured with layer 8, mask 16")
	else:
		# Enemy hurtbox should only be hit by player hitboxes (layer 2)
		collision_layer = 4   # Layer 4 for enemy hurtboxes
		collision_mask = 2    # Mask 2 to be hit by player hitboxes
		if debug:
			print("Enemy hurtbox configured with layer 4, mask 2")
	
	# Store a reference to the entity in metadata for more reliable detection
	set_meta("entity", entity)
	
	# CRITICAL: Also check for DirectMovementTest component for NightBorne enemies
	if not is_player_hurtbox and entity.get_node_or_null("DirectMovementTest"):
		# This is a NightBorne enemy - we need to use its DirectMovementTest component
		entity = entity.get_node("DirectMovementTest")
		if debug:
			print("HurtBox using DirectMovementTest component for damage handling")
	
	# Check if entity has take_damage method
	if not entity.has_method("take_damage"):
		push_warning("Entity with Hurtbox doesn't implement take_damage method: " + entity.name)
	
	if debug:
		print("HurtBox initialized for entity: ", entity.name if entity else "null", 
			  " (is_player_hurtbox: ", is_player_hurtbox, ")")

## Take damage when hit by a hitbox
func take_damage(damage_amount: float, knockback_force: Vector2 = Vector2.ZERO):
	if debug:
		print("HurtBox received damage: ", damage_amount, 
			  " (is_player_hurtbox: ", is_player_hurtbox, ")")
		
	if entity and entity.has_method("take_damage"):
		if debug:
			print("Forwarding damage to entity: ", entity.name, 
				  " (is_player_hurtbox: ", is_player_hurtbox, ")")
		entity.take_damage(damage_amount, knockback_force)
	else:
		if debug:
			print("ERROR: Entity missing or doesn't have take_damage method")
			# Try one more approach - check if parent has DirectMovementTest
			var parent = get_parent()
			if parent and parent.get_node_or_null("DirectMovementTest"):
				var direct_movement = parent.get_node("DirectMovementTest")
				if direct_movement and direct_movement.has_method("take_damage"):
					print("Fallback: Forwarding damage to DirectMovementTest component")
					direct_movement.take_damage(damage_amount, knockback_force)

# Monitor hurtbox state during _physics_process for debugging
func _physics_process(_delta):
	# Check collision shape state periodically
	if debug and Engine.get_physics_frames() % 60 == 0:
		var collision = get_node_or_null("CollisionShape2D")
		if collision:
			if collision.disabled:
				print("WARNING: HurtBox collision is disabled for entity: ", entity.name if entity else "null") 
