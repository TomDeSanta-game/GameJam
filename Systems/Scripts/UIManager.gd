extends Node

# UIManager script - handles setting up UI elements for the game

var debug_mode = true

func _ready():
	print("UIManager initialized")
	
	# You can still add other UI elements here
	# But GrowthUI is now directly part of the Knight scene
	
	# Wait for the player to be ready
	await get_tree().process_frame
	
	# Find the player
	var player = get_tree().get_first_node_in_group("Player")
	if not player:
		if debug_mode:
			print("UIManager: Player not found")
		await get_tree().create_timer(0.5).timeout
		player = get_tree().get_first_node_in_group("Player")
		
	if player:
		setup_player_ui(player)
	else:
		if debug_mode:
			print("UIManager: Could not find player")

func setup_player_ui(player):
	if debug_mode:
		print("UIManager: Setting up player UI")
	
	# Check if player has a canvas layer
	var canvas = player.get_node_or_null("CanvasLayer")
	if not canvas:
		if debug_mode:
			print("UIManager: Player has no canvas layer")
		return
	
	# No need to add GrowthUI here anymore, it's part of the Knight scene
	# You can add other UI elements as needed 