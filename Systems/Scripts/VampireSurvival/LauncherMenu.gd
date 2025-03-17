extends Control

# Vampire Survivors Mode Launcher Menu

# Called when the node enters the scene tree for the first time.
func _ready():
	# Connect button signals using simplified syntax
	if has_node("StartButton"):
		$StartButton.pressed.connect(_on_start_button_pressed)
	if has_node("QuitButton"):
		$QuitButton.pressed.connect(_on_quit_button_pressed)
	
	# If we have background particles, start them
	if has_node("BackgroundParticles"):
		$BackgroundParticles.emitting = true

# Start the game mode
func _on_start_button_pressed():
	# Use direct file path
	var game_scene_path = "res://Levels/HunterMode.tscn"
	
	# Check if file exists before trying to load it
	if ResourceLoader.exists(game_scene_path):
		# Use change_scene_to_packed instead for better error handling
		var packed_scene = load(game_scene_path)
		if packed_scene:
			get_tree().change_scene_to_packed(packed_scene)
		else:
			print("ERROR: Failed to load scene: ", game_scene_path)
	else:
		# Scene doesn't exist, show error
		print("ERROR: Game scene not found: ", game_scene_path)

# Return to main menu or quit
func _on_quit_button_pressed():
	# If we came from a scene, return to it, otherwise quit
	var main_scene_path = "res://Levels/level.tscn"
	
	if ResourceLoader.exists(main_scene_path):
		var packed_scene = load(main_scene_path)
		if packed_scene:
			get_tree().change_scene_to_packed(packed_scene)
		else:
			print("ERROR: Failed to load main scene: ", main_scene_path)
			get_tree().quit()
	else:
		print("ERROR: Main scene not found: ", main_scene_path)
		get_tree().quit() 