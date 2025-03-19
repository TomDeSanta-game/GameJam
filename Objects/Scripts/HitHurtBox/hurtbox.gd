extends Area2D

## The entity that owns this hurtbox
var entity

# For debugging collision issues
@export var debug: bool = false

# Indicates if this is a player hurtbox (false = enemy hurtbox)
@export var is_player_hurtbox: bool = false

func _ready():
	var parent = get_parent()
	
	# Set debug info based on parent
	if parent.is_in_group("Player"):  # Check if parent is in Player group instead of using class name
		is_player_hurtbox = true
		
		# Default collision settings for player hurtbox
		if collision_layer == 0:
			collision_layer = 8  # Layer 8 for player hurtboxes
		if collision_mask == 0:
			collision_mask = 16  # Mask 16 to detect enemy hitboxes
		
	else:
		# Default collision settings for enemy hurtbox
		if collision_layer == 0:
			collision_layer = 4  # Layer 4 for enemy hurtboxes
		if collision_mask == 0:
			collision_mask = 2  # Mask 2 to detect player hitboxes
		
	# Set the entity for damage processing
	entity = find_damage_entity()
	
	# Register in metadata to avoid self-damage
	if entity:
		set_meta("entity", entity)
		if debug:
			print("HURTBOX: Entity set to ", entity.name if entity.has_method("get_path") else "Unknown")
	else:
		if debug:
			print("HURTBOX: WARNING - No entity found for damage processing")
	
	# Connect area entered signal
	area_entered.connect(_on_area_entered)
	
	# Only print if debug mode is enabled
	if debug:
		print("HURTBOX: Ready - collision_layer=", collision_layer, " collision_mask=", collision_mask)
		print("HURTBOX: is_player_hurtbox=", is_player_hurtbox)

# Find the entity responsible for damage handling
func find_damage_entity():
	var parent = get_parent()
	
	# First, check if parent is valid and has a take_damage method
	if parent and parent.has_method("take_damage"):
		return parent
	
	# Check for DirectMovementTest component
	if parent and parent.has_node("DirectMovementTest"):
		var direct_movement = parent.get_node("DirectMovementTest")
		if direct_movement and direct_movement.has_method("take_damage"):
			return direct_movement
		
	# If parent doesn't have take_damage, check NightBorneEnemy script
	if parent and parent.get_script() and parent.get_script().get_path().contains("night_borne.gd"):
		return parent
		
	# Last resort - try to find any ancestor with take_damage
	var current = parent
	for _i in range(3):  # Limit search depth to prevent infinite loops
		if current and current.get_parent() and current.get_parent().has_method("take_damage"):
			return current.get_parent()
		if current:
			current = current.get_parent()
	
	return null

# Handle damage through the hurtbox
func take_damage(damage_amount: float, knockback_direction: Vector2 = Vector2.ZERO):
	if debug:
		print("HURTBOX: take_damage called with damage=", damage_amount)
	
	# First try the cached entity
	if entity and entity.has_method("take_damage"):
		if debug:
			print("HURTBOX: Applying damage to cached entity: ", entity.name if entity.has_method("get_path") else "Unknown")
		
		# CRITICAL FIX: Check if we should prevent sprite flipping
		var should_preserve_direction = false
		
		# Find the area that called this method
		var areas = get_overlapping_areas()
		for area in areas:
			if area.has_meta("no_flip") and area.get_meta("no_flip"):
				should_preserve_direction = true
				if debug:
					print("HURTBOX: Detected no_flip flag in hitbox, will preserve direction")
				break
		
		# Apply damage with the appropriate method
		if should_preserve_direction:
			if entity.has_method("take_damage_no_flip"):
				entity.take_damage_no_flip(damage_amount, knockback_direction)
				return
			elif entity.has_method("take_damage_with_info"):
				var damage_info = {
					"amount": damage_amount,
					"knockback": knockback_direction,
					"no_flip": true
				}
				entity.take_damage_with_info(damage_info)
				return
		
		# Default method if no special handling or flag not found
		entity.take_damage(damage_amount, knockback_direction)
		return
		
	# Try finding the entity again
	entity = find_damage_entity()
	if entity and entity.has_method("take_damage"):
		if debug:
			print("HURTBOX: Applying damage to newly-found entity")
		entity.take_damage(damage_amount, knockback_direction)
		return
	
	# Last resort - try direct connections
	var parent = get_parent()
	if parent:
		var direct_movement = parent.get_node_or_null("DirectMovementTest")
		if direct_movement and direct_movement.has_method("take_damage"):
			if debug:
				print("HURTBOX: Applying damage via DirectMovementTest component")
				
			direct_movement.take_damage(damage_amount, knockback_direction)
		elif parent.has_method("take_damage"):
			if debug:
				print("HURTBOX: Applying damage directly to parent")
				
			parent.take_damage(damage_amount, knockback_direction)

# Handle area entered - provide better debugging
func _on_area_entered(area):
	if debug:
		print("HURTBOX: Area entered: ", area.name, " - is_player_hurtbox=", is_player_hurtbox)
		
		# Check if it's a hitbox with opposite player/enemy status
		if area.has_method("activate") and "is_player_hitbox" in area:
			var is_player_hitbox = area.is_player_hitbox
			print("HURTBOX: Entered by ", "player" if is_player_hitbox else "enemy", " hitbox")
			
			# Check if the hitbox is active
			if "active" in area:
				print("HURTBOX: Hitbox active=", area.active)
			
			# Check and print no_flip status if available
			if area.has_meta("no_flip"):
				print("HURTBOX: Hitbox has no_flip=", area.get_meta("no_flip"))

# Monitor hurtbox state during _physics_process for debugging
func _physics_process(_delta):
	# Check if our collision is disabled when it shouldn't be
	var collision = get_node_or_null("CollisionShape2D")
	if collision and collision.disabled and debug and Engine.get_physics_frames() % 60 == 0:
		print("HURTBOX WARNING: CollisionShape2D is disabled!")
