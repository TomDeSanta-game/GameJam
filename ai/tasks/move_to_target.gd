@tool
extends BTAction
## Moves the agent toward a target stored in the blackboard.
## Returns RUNNING while moving and SUCCESS when within arrival range.

## Blackboard variable that stores the target Node2D
@export var target_var: StringName = &"target"

## Distance at which to stop approaching the target
@export var arrival_distance: float = 50.0

## Maximum distance to track the target (0 = unlimited)
@export var max_tracking_distance: float = 0.0

## Speed multiplier for movement
@export var speed_multiplier: float = 1.0

## Default speed if agent doesn't have max_speed property
@export var default_speed: float = 100.0

## Blackboard variable for speed (if specified, overrides speed_multiplier)
@export var speed_var: StringName

## Enable debug prints
@export var debug: bool = true

func _generate_name() -> String:
	var name_str = "MoveToTarget  target: %s" % LimboUtility.decorate_var(target_var)
	if not speed_var.is_empty():
		name_str += "  speed: %s" % LimboUtility.decorate_var(speed_var)
	else:
		name_str += "  speed: %.1f" % speed_multiplier
	return name_str

func _tick(_delta: float) -> Status:
	# Get target from blackboard
	var target = blackboard.get_var(target_var)
	
	# Check if target is valid
	if target == null or not is_instance_valid(target) or not target is Node2D:
		if debug: print("MoveToTarget: Target is null or invalid")
		return FAILURE
	
	# Calculate distance to target
	var target_position = target.global_position
	var distance = agent.global_position.distance_to(target_position)
	
	if debug: print("MoveToTarget: Distance to target: ", distance)
	
	# Check if target is too far (if max tracking distance is set)
	if max_tracking_distance > 0 and distance > max_tracking_distance:
		if debug: print("MoveToTarget: Target too far away: ", distance, " > ", max_tracking_distance)
		return FAILURE
	
	# Check if we've reached the target
	if distance <= arrival_distance:
		if debug: print("MoveToTarget: Reached target (distance: ", distance, ")")
		return SUCCESS
	
	# Get movement speed
	var speed = default_speed
	
	# Try to get max_speed from agent if available
	if "max_speed" in agent:
		speed = agent.max_speed
		if debug: print("MoveToTarget: Using agent's max_speed: ", speed)
	else:
		if debug: print("MoveToTarget: Using default speed: ", speed)
	
	# Apply speed modifier or get from blackboard
	if not speed_var.is_empty():
		speed = blackboard.get_var(speed_var, speed)
		if debug: print("MoveToTarget: Using speed from blackboard: ", speed)
	else:
		speed = speed * speed_multiplier
		if debug: print("MoveToTarget: Applied speed multiplier: ", speed)
	
	# Calculate direction to target
	var direction = agent.global_position.direction_to(target_position)
	if debug: print("MoveToTarget: Direction to target: ", direction)
	
	# Use the agent's move function from enemy_base.gd
	if agent.has_method("move"):
		if debug: print("MoveToTarget: Calling move with direction: ", direction, " and speed: ", speed)
		agent.move(direction, speed)
	else:
		if debug: print("MoveToTarget: Agent doesn't have move method!")
	
	return RUNNING 