@tool
extends BTAction
## Performs an attack against the target.
## Returns SUCCESS if the attack was performed, FAILURE if it couldn't attack.

## Blackboard variable that stores the target
@export var target_var: StringName = &"target"

## Attack range
@export var attack_range: float = 60.0

func _generate_name() -> String:
	return "PerformAttack  target: %s  range: %.1f" % [
		LimboUtility.decorate_var(target_var),
		attack_range]

func _tick(_delta: float) -> Status:
	# Get target from blackboard
	var target = blackboard.get_var(target_var)
	
	# Check if target is valid
	if target == null or not is_instance_valid(target) or not target is Node2D:
		return FAILURE
	
	# Check if target is in range
	var distance = agent.global_position.distance_to(target.global_position)
	if distance > attack_range:
		return FAILURE
	
	# Set the agent's target
	if agent.has_method("set_target"):
		agent.set_target(target)
	
	# Attempt to attack
	if agent.has_method("attack"):
		if agent.attack():
			return SUCCESS
	
	# Attack failed or not possible right now
	return FAILURE 