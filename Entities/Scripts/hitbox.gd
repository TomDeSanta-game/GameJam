extends Area2D

## The amount of damage this hitbox deals
@export var damage: float = 10.0

## Knockback force applied on hit
@export var knockback_force: float = 200.0

## Whether this hitbox is currently active
@export var active: bool = false

# Debug flag to help troubleshoot collision issues
@export var debug: bool = true

# Indicates if this is a player hitbox (false = enemy hitbox)
@export var is_player_hitbox: bool = false

func _ready():
	# Start with hitbox disabled
	monitoring = active
	monitorable = active
	
	# Determine if this is a player hitbox based on parent
	var parent = get_parent()
	if parent is Knight:
		is_player_hitbox = true
		if debug:
			print("Detected player hitbox for: ", parent.name)
	
	# Set collision layers/masks for proper detection
	if is_player_hitbox:
		# Player hitbox should only collide with enemy hurtboxes (layer 4)
		collision_layer = 2  # Layer 2 for player hitboxes
		collision_mask = 4   # Mask 4 to detect enemy hurtboxes
		if debug:
			print("Player hitbox configured with layer 2, mask 4")
	else:
		# Enemy hitbox should only collide with player hurtbox (layer 8) 
		collision_layer = 16  # Layer 16 for enemy hitboxes
		collision_mask = 8    # Mask 8 to detect player hurtbox
		if debug:
			print("Enemy hitbox configured with layer 16, mask 8")
	
	# Connect signals
	if not area_entered.is_connected(_on_area_entered):
		area_entered.connect(_on_area_entered)

func _on_area_entered(area: Area2D):
	if not active:
		if debug:
			print("Hitbox not active, ignoring collision")
		return
	
	if debug:
		print("Hitbox detected collision with: ", area.name, " from owner: ", get_parent().name)
		print("Hitbox collision details - is_player_hitbox: ", is_player_hitbox, 
			  " collision_layer: ", collision_layer, 
			  " collision_mask: ", collision_mask)
		
		# Print area details
		print("Area collision details - is_player_hurtbox: ", 
			  area.get("is_player_hurtbox") if area.has_method("get") else "unknown",
			  " collision_layer: ", area.collision_layer, 
			  " collision_mask: ", area.collision_mask)
	
	# Get the owner entity from metadata if it exists
	var owner_entity = get_meta("owner_entity", null) if has_meta("owner_entity") else null
	var parent_hurtbox = get_meta("parent_hurtbox", null) if has_meta("parent_hurtbox") else null
	
	# Check for self-damage prevention
	var is_self_damage = false
	
	# Method 1: Direct reference check
	if parent_hurtbox == area:
		is_self_damage = true
		
	# Method 2: Entity ownership check
	if owner_entity != null and area.has_meta("entity") and area.get_meta("entity") == owner_entity:
		is_self_damage = true
	
	# Method 3: Check via entity property
	if owner_entity != null and "entity" in area and area.entity == owner_entity:
		is_self_damage = true
	
	# Prevent damaging your own hurtbox
	if is_self_damage:
		if debug:
			print("Prevented self-damage, hitbox owner: ", owner_entity)
		return
		
	if area.has_method("take_damage"):
		if debug:
			print("Applying damage: ", damage, " to: ", area.name, " (is_player_hitbox: ", is_player_hitbox, ")")
		# Deal damage to the entity
		area.take_damage(damage, global_position.direction_to(area.global_position) * knockback_force)

## Activate the hitbox
func activate():
	# Get parent information for debugging
	var parent_name = "Unknown"
	var parent_type = "Unknown"
	if get_parent():
		parent_name = get_parent().name
		parent_type = get_parent().get_class()
		
	var context = "player" if is_player_hitbox else "enemy"
	print(context.to_upper() + " HITBOX: Activating with damage: " + str(damage) + " for parent: " + parent_name + " (" + parent_type + ")")
	
	active = true
	monitoring = true
	monitorable = true
	
	# Log collision layers for debugging
	print(context.to_upper() + " HITBOX: Collision layer: " + str(collision_layer) + ", mask: " + str(collision_mask))
	
## Deactivate the hitbox
func deactivate():
	var context = "player" if is_player_hitbox else "enemy"
	print(context.to_upper() + " HITBOX: Deactivating")
	
	active = false
	monitoring = false
	monitorable = false
	
	# IMPORTANT: Clear ownership metadata when deactivating
	# This ensures the hitbox doesn't remember its previous owner
	if has_meta("owner_entity"):
		remove_meta("owner_entity")
	if has_meta("parent_hurtbox"):
		remove_meta("parent_hurtbox")
	
	print(context.to_upper() + " HITBOX: Metadata cleared")

func _physics_process(_delta):
	# Optional debug to verify hitbox state periodically
	if debug and Engine.get_physics_frames() % 60 == 0 and active:
		print("Hitbox still active with damage: ", damage) 