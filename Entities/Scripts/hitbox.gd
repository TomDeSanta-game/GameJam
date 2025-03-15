extends Area2D

## The amount of damage this hitbox deals
@export var damage: float = 10.0

## Knockback force applied on hit
@export var knockback_force: float = 200.0

## Whether this hitbox is currently active
@export var active: bool = false

func _ready():
	# Start with hitbox disabled
	monitoring = active
	monitorable = active
	
	# Set collision layers/masks for proper detection
	collision_layer = 2  # Layer 2 for hitboxes
	collision_mask = 4   # Mask 4 to detect hurtboxes
	
	# Connect signals
	if not area_entered.is_connected(_on_area_entered):
		area_entered.connect(_on_area_entered)

func _on_area_entered(area: Area2D):
	if not active:
		return
	
	# Get the owner entity from metadata if it exists
	var owner_entity = get_meta("owner_entity", null) if has_meta("owner_entity") else null
	var parent_hurtbox = get_meta("parent_hurtbox", null) if has_meta("parent_hurtbox") else null
	
	# Prevent damaging your own hurtbox
	if parent_hurtbox == area or owner_entity == area.entity:
		# This is our own hurtbox - don't damage self
		return
		
	if area.has_method("take_damage"):
		# Deal damage to the entity
		area.take_damage(damage, global_position.direction_to(area.global_position) * knockback_force)

## Activate the hitbox
func activate():
	active = true
	monitoring = true
	monitorable = true
	
## Deactivate the hitbox
func deactivate():
	active = false
	monitoring = false
	monitorable = false

func _physics_process(_delta):
	# No need for the debug prints here
	pass 