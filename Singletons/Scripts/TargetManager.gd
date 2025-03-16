extends Node

# Dictionary to store targets with custom keys
var targets = {}

# Store a target with a specified key
func store_target(source: Node, key: String) -> void:
    targets[key] = source

# Remove a target by key
func remove_target(key: String) -> void:
    if targets.has(key):
        targets.erase(key)

# Get a target by key
func get_target(key: String) -> Node:
    if targets.has(key):
        return targets[key]
    return null

# Get all targets
func get_all_targets() -> Dictionary:
    return targets

# Get targets by group - only call this after the node is ready
func get_targets_in_group(group_name: String) -> Array:
    if not is_inside_tree():
        push_error("TargetManager: get_targets_in_group called before node is ready")
        return []
    return get_tree().get_nodes_in_group(group_name)

# Get first target in a group - only call this after the node is ready
func get_first_in_group(group_name: String) -> Node:
    if not is_inside_tree():
        push_error("TargetManager: get_first_in_group called before node is ready")
        return null
    var nodes = get_tree().get_nodes_in_group(group_name)
    if nodes.size() > 0:
        return nodes[0]
    return null

# Clear all targets
func clear_targets() -> void:
    targets.clear()

# Check if a key exists
func has_target(key: String) -> bool:
    return targets.has(key) 