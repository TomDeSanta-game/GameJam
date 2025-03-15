extends Node

# This script should be attached to the root level of your game scene
# It ensures the player is properly registered for AI targeting

@export var player_path: NodePath
@export var debug: bool = true

func _ready():
	# Find the player
	var player = get_node_or_null(player_path)
	
	if not player:
		# Try to find the player by class name or other means
		var potential_players = get_tree().get_nodes_in_group("Player")
		
		if not potential_players.is_empty():
			player = potential_players[0]
		else:
			# If still not found, try a more aggressive search
			var all_nodes = get_tree().get_nodes_in_group("*")
			for node in all_nodes:
				if "Player" in node.name:
					player = node
					break
	
	if player:
		# Ensure player is in the Player group
		if not player.is_in_group("Player"):
			player.add_to_group("Player")
		
		# Register player with TargetManager
		TargetManager.store_target(player, "Player") 