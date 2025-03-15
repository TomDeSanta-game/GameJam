@tool
extends BTAction
## Finds a target and stores it in the blackboard.
## Can use group-based or TargetManager-based approaches.

## Target group to search for
@export var target_group: String = "Player"

## Use TargetManager instead of direct group lookup
@export var use_target_manager: bool = true

## Target key in TargetManager (used if use_target_manager is true)
@export var target_key: String = "Player"

## Blackboard variable to store the found target
@export var output_var: StringName = &"target"

## Maximum search distance (0 = unlimited)
@export var max_distance: float = 0.0

## Enable debug prints
@export var debug: bool = true

func _generate_name() -> String:
	var method = "TargetManager(%s)" % target_key if use_target_manager else "Group(%s)" % target_group
	var dist_text = "" if max_distance <= 0 else "  max_dist: %.1f" % max_distance
	return "FindTarget  method: %s%s  ➜%s" % [method, dist_text, LimboUtility.decorate_var(output_var)]

func _tick(_delta: float) -> Status:
	var target = null
	
	# Find target using the specified method
	if use_target_manager:
		# Use TargetManager singleton
		if TargetManager.has_target(target_key):
			target = TargetManager.get_target(target_key)
		else:
			# Fallback to group if target not found in TargetManager
			var nodes = TargetManager.get_targets_in_group(target_group)
			if not nodes.is_empty():
				target = nodes[0]
	else:
		# Use group-based approach
		var nodes = agent.get_tree().get_nodes_in_group(target_group)
		
		if not nodes.is_empty():
			if max_distance > 0:
				# Find the closest target within range
				var closest_dist = INF
				for node in nodes:
					if node is Node2D:
						var dist = agent.global_position.distance_to(node.global_position)
						if dist < closest_dist and dist <= max_distance:
							closest_dist = dist
							target = node
			else:
				# Take the first target
				target = nodes[0]
	
	# Check if we found a valid target
	if target != null and is_instance_valid(target):
		# Store target in blackboard
		blackboard.set_var(output_var, target)
		
		# If we're using TargetManager, ensure the target is stored there too
		if use_target_manager and not TargetManager.has_target(target_key):
			TargetManager.store_target(target, target_key)
		
		return SUCCESS
	else:
		return FAILURE 
