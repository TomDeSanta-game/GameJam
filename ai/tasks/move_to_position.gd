@tool
extends BTAction
## Moves the agent to a position stored in the blackboard.
## Returns RUNNING while moving and SUCCESS when in range of target position.

## Blackboard variable that stores the target position (Vector2)
@export var position_var: StringName = &"move_position"

## How close the agent needs to be to consider it has reached the position
@export var arrival_tolerance: float = 20.0

## Speed multiplier for movement
@export var speed_multiplier: float = 1.0

## Default speed if agent doesn't have max_speed property
@export var default_speed: float = 100.0

## Blackboard variable for speed (if specified, overrides speed_multiplier)
@export var speed_var: StringName

func _generate_name() -> String:
	var name_str = "MoveToPosition  pos: %s" % LimboUtility.decorate_var(position_var)
	if not speed_var.is_empty():
		name_str += "  speed: %s" % LimboUtility.decorate_var(speed_var)
	else:
		name_str += "  speed: %.1f" % speed_multiplier
	return name_str

func _tick(_delta: float) -> Status:
	# Get target position from blackboard
	var target_pos: Vector2 = blackboard.get_var(position_var, Vector2.ZERO)
	
	# Check if we've reached the target
	var distance = agent.global_position.distance_to(target_pos)
	if distance <= arrival_tolerance:
		return SUCCESS
	
	# Get movement speed
	var speed = default_speed
	
	# Try to get max_speed from agent if available
	if "max_speed" in agent:
		speed = agent.max_speed
	
	# Apply speed modifier or get from blackboard
	if not speed_var.is_empty():
		speed = blackboard.get_var(speed_var, speed)
	else:
		speed = speed * speed_multiplier
	
	# Calculate direction to target
	var direction = agent.global_position.direction_to(target_pos)
	
	# Use the agent's move function from enemy_base.gd
	if agent.has_method("move"):
		agent.move(direction, speed)
	
	return RUNNING 