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

# Get targets by group
func get_targets_in_group(group_name: String) -> Array[Node]:
    return get_tree().get_nodes_in_group(group_name)

# Get first target in a group
func get_first_in_group(group_name: String) -> Node:
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