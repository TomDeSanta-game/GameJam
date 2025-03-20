extends Area2D

## The amount of damage this hitbox deals
@export var damage: float = 10.0

## Knockback force applied on hit
@export var knockback_force: float = 200.0

## Whether this hitbox is currently active
@export var active: bool = false

# Debug flag to help troubleshoot collision issues
@export var debug: bool = false

# Indicates if this is a player hitbox (false = enemy hitbox)
@export var is_player_hitbox: bool = false

func _ready():
	var parent = get_parent()
	
	# Set debug info based on parent (check name instead of class)
	if parent and "knight" in parent.name.to_lower():
		is_player_hitbox = true
		
		# Default collision settings for player hitbox
		if collision_layer == 0:
			collision_layer = 2  # Layer 2 for player hitboxes
		if collision_mask == 0:
			collision_mask = 4   # Mask 4 to detect enemy hurtboxes
		
	else:
		# Default collision settings for enemy hitbox
		if collision_layer == 0:
			collision_layer = 16  # Layer 16 for enemy hitboxes
		if collision_mask == 0:
			collision_mask = 8    # Mask 8 to detect player hurtboxes
		
	deactivate()  # Start deactivated
	
	# Connect signals
	if not area_entered.is_connected(_on_area_entered):
		area_entered.connect(_on_area_entered)
		
	# Store reference to parent entity in metadata
	if parent:
		set_meta("entity", parent)
		if debug:
			print("HITBOX: Entity set to ", parent.name)
	
	if debug:
		print("HITBOX: Ready - collision_layer=", collision_layer, " collision_mask=", collision_mask)
		print("HITBOX: is_player_hitbox=", is_player_hitbox)

func _on_area_entered(area):
	if debug:
		print("HITBOX: Area entered: ", area.name, " - is_active=", active)
		
	if !active:
		if debug:
			print("HITBOX: Not active, ignoring collision")
		return
		
	# Check if area has take_damage method or is a hurtbox
	if area.has_method("take_damage"):
		# Check for self-damage prevention
		var owner_entity = get_meta("entity") if has_meta("entity") else null
		var target_entity = area.get_meta("entity") if area.has_meta("entity") else null
		
		# Prevent damaging self
		if owner_entity and target_entity and owner_entity == target_entity:
			if debug:
				print("HITBOX: Prevented self-damage")
			return
			
		# Extra check to prevent player<->player or enemy<->enemy damage
		if "is_player_hurtbox" in area and is_player_hitbox == area.is_player_hurtbox:
			if debug:
				print("HITBOX: Prevented same-team damage")
			return
			
		# Apply damage and knockback
		var knockback_direction = (area.global_position - global_position).normalized()
		if knockback_direction.length() < 0.1:  # If too close or same position
			knockback_direction = Vector2.RIGHT  # Default direction
		
		# KNOCKBACK FIX: Calculate appropriate knockback force that doesn't scale with player size
		var actual_knockback = knockback_force
		
		# Check if player has grown larger and adjust knockback accordingly
		if is_player_hitbox and has_meta("entity"):
			var player = get_meta("entity")
			if player and player.has_node("GrowthSystem"):
				var growth_system = player.get_node("GrowthSystem")
				if growth_system and "current_growth" in growth_system:
					var growth_level = growth_system.current_growth
					
					# Prevent knockback from scaling with player size by capping it
					if growth_level > 0:
						# Calculate scaling factor but with a cap
						var max_scale = 2.0  # Cap knockback to double regardless of player size
						var scale_factor = min(1.0 + (growth_level * 0.1), max_scale)
						actual_knockback = knockback_force * scale_factor
						
						if debug:
							print("HITBOX: Adjusting knockback for player growth, level=", growth_level, ", scale=", scale_factor)
			
		# Cap knockback to a maximum value to prevent enemies flying off screen
		var max_knockback = 800.0
		if actual_knockback > max_knockback:
			actual_knockback = max_knockback
			if debug:
				print("HITBOX: Capped excessive knockback to ", max_knockback)
		
		# CRITICAL FIX: Check if we need to preserve the direction
		var prevent_flip = has_meta("no_flip") and get_meta("no_flip") == true
		
		if debug:
			print("HITBOX: Applying damage to hurtbox - amount=", damage, ", no_flip=", prevent_flip)
		
		# Check for special damage handling methods
		if prevent_flip:
			if area.has_method("take_damage_with_info"):
				var damage_info = {
					"amount": damage,
					"knockback": knockback_direction * actual_knockback,
					"no_flip": true
				}
				area.take_damage_with_info(damage_info)
				return
			elif area.has_method("take_damage_no_flip"):
				area.take_damage_no_flip(damage, knockback_direction * actual_knockback)
				return
		
		# Default method if no special handling needed or available
		area.take_damage(damage, knockback_direction * actual_knockback)
	else:
		# Fallback - try to apply damage to the parent if it has a take_damage method
		var parent = area.get_parent()
		if parent and parent.has_method("take_damage"):
			# Apply damage and knockback with the same adjustments as above
			var knockback_direction = (parent.global_position - global_position).normalized()
			if knockback_direction.length() < 0.1:  # If too close or same position
				knockback_direction = Vector2.RIGHT  # Default direction
			
			# Same knockback adjustment as above
			var actual_knockback = knockback_force
			
			# Check if player has grown larger
			if is_player_hitbox and has_meta("entity"):
				var player = get_meta("entity")
				if player and player.has_node("GrowthSystem"):
					var growth_system = player.get_node("GrowthSystem")
					if growth_system and "current_growth" in growth_system:
						var growth_level = growth_system.current_growth
						
						# Cap the scaling
						var max_scale = 2.0
						var scale_factor = min(1.0 + (growth_level * 0.1), max_scale)
						actual_knockback = knockback_force * scale_factor
			
			# Cap knockback
			var max_knockback = 800.0
			if actual_knockback > max_knockback:
				actual_knockback = max_knockback
				
			if debug:
				print("HITBOX: Applying damage to parent - amount=", damage)
				
			parent.take_damage(damage, knockback_direction * actual_knockback)
		elif debug:
			print("HITBOX: Could not find valid damage target")

## Activate the hitbox
func activate():
	active = true
	monitoring = true
	var collision_shape = get_node_or_null("CollisionShape2D")
	if collision_shape:
		collision_shape.set_deferred("disabled", false)
	
	# Debug information if debug mode is on
	if debug:
		var parent = get_parent()
		var parent_name = parent.name if parent else "Unknown"
		var parent_type = "Player" if is_player_hitbox else "Enemy"
		print("HITBOX: Activated ", parent_type, " hitbox on ", parent_name)

## Deactivate the hitbox
func deactivate():
	active = false
	monitoring = false
	var collision_shape = get_node_or_null("CollisionShape2D")
	if collision_shape:
		collision_shape.set_deferred("disabled", true)
	
	# Debug information if debug mode is on
	if debug:
		var context = "Player" if is_player_hitbox else "Enemy"
		print("HITBOX: Deactivated ", context, " hitbox")

# Make the hitbox more visible when debugging is enabled
func _process(_delta):
	if debug and Engine.get_process_frames() % 30 == 0:
		var collision = get_node_or_null("CollisionShape2D")
		if collision and !collision.disabled and active:
			print("HITBOX: Active - waiting for collisions")

func _physics_process(_delta):
	# Optional debug to verify hitbox state periodically
	if debug and Engine.get_physics_frames() % 60 == 0 and active:
		pass 
