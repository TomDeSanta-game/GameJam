@tool
extends BTAction
## Selects a random position within the specified range and stores it on the blackboard.
## Returns SUCCESS when a position is found.

## Minimum distance from the agent to the random position
@export var min_distance: float = 100.0

## Maximum distance from the agent to the random position
@export var max_distance: float = 300.0

## Blackboard variable to store the selected position
@export var position_var: StringName = &"move_position"

## Number of attempts to find a valid position
@export var max_attempts: int = 10

func _generate_name() -> String:
	return "RandomMovePosition  range: [%s, %s]  ➜%s" % [
		min_distance, max_distance,
		LimboUtility.decorate_var(position_var)]

func _tick(_delta: float) -> Status:
	var pos: Vector2
	var attempts = 0
	var valid_position = false
	
	# Try to find a valid position within the specified number of attempts
	while attempts < max_attempts and not valid_position:
		attempts += 1
		
		# Generate a random angle and distance
		var angle = randf() * TAU  # 2π radians = full circle
		var distance = randf_range(min_distance, max_distance)
		
		# Calculate the position
		pos = agent.global_position + Vector2(cos(angle), sin(angle)) * distance
		
		# Check if the position is valid (can be overridden in subclasses)
		valid_position = _is_valid_position(pos)
	
	if valid_position:
		# Store the position in the blackboard
		blackboard.set_var(position_var, pos)
		return SUCCESS
	else:
		return FAILURE

## Override this method to implement custom position validation
func _is_valid_position(_pos: Vector2) -> bool:
	# By default, consider all positions valid
	# Inherit this class to add custom validation (e.g., navigation check)
	return true 