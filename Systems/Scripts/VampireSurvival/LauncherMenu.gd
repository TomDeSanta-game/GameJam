extends Control

# Vampire Survivors Mode Launcher Menu

# Animation properties
var button_default_scale = Vector2(1.0, 1.0)
var button_hover_scale = Vector2(1.15, 1.15) # 15% larger on hover
var title_hover_scale = Vector2(1.05, 1.05) # 5% larger for title elements
var animation_speed = 0.15 # Animation duration in seconds
var gate_rotation_speed = 0.1 # Rotation speed for gate effects

# Load the click sound at the top of the script
var click_sound = preload("res://assets/Sounds/UI/Click/ui.mp3")
var hover_sound = preload("res://assets/Sounds/UI/Click/ui.mp3") # Using same sound for hover, can be changed later

# Called when the node enters the scene tree for the first time.
func _ready():
	# Setup pivot points for proper scaling
	if has_node("StartButton"):
		$StartButton.pivot_offset = $StartButton.size / 2
		$StartButton.mouse_entered.connect(_on_button_mouse_entered.bind($StartButton))
		$StartButton.mouse_exited.connect(_on_button_mouse_exited.bind($StartButton))
		$StartButton.pressed.connect(_on_start_button_pressed)
		# Disable focus to prevent white outline
		$StartButton.focus_mode = Control.FOCUS_NONE
	
	if has_node("QuitButton"):
		$QuitButton.pivot_offset = $QuitButton.size / 2
		$QuitButton.mouse_entered.connect(_on_button_mouse_entered.bind($QuitButton))
		$QuitButton.mouse_exited.connect(_on_button_mouse_exited.bind($QuitButton))
		$QuitButton.pressed.connect(_on_quit_button_pressed)
		# Disable focus to prevent white outline
		$QuitButton.focus_mode = Control.FOCUS_NONE
	
	# Make titles interactive too
	if has_node("TitleLabel"):
		$TitleLabel.mouse_filter = MOUSE_FILTER_PASS
		$TitleLabel.pivot_offset = $TitleLabel.size / 2
		$TitleLabel.mouse_entered.connect(_on_title_mouse_entered.bind($TitleLabel))
		$TitleLabel.mouse_exited.connect(_on_title_mouse_exited.bind($TitleLabel))
	
	if has_node("SubTitleLabel"):
		$SubTitleLabel.mouse_filter = MOUSE_FILTER_PASS
		$SubTitleLabel.pivot_offset = $SubTitleLabel.size / 2
		$SubTitleLabel.mouse_entered.connect(_on_title_mouse_entered.bind($SubTitleLabel))
		$SubTitleLabel.mouse_exited.connect(_on_title_mouse_exited.bind($SubTitleLabel))
	
	if has_node("TaglineLabel"):
		$TaglineLabel.mouse_filter = MOUSE_FILTER_PASS
		$TaglineLabel.pivot_offset = $TaglineLabel.size / 2
		$TaglineLabel.mouse_entered.connect(_on_title_mouse_entered.bind($TaglineLabel))
		$TaglineLabel.mouse_exited.connect(_on_title_mouse_exited.bind($TaglineLabel))
	
	# If we have background particles, start them
	if has_node("BackgroundParticles"):
		$BackgroundParticles.emitting = true

# Animate the gate effects
func _process(delta):
	if has_node("GateEffects/BlueCircle"):
		$GateEffects/BlueCircle.rotation += gate_rotation_speed * delta
	
	if has_node("GateEffects/BlueCircle2"):
		$GateEffects/BlueCircle2.rotation -= gate_rotation_speed * delta * 0.7

# Button hover animation
func _on_button_mouse_entered(button):
	# Scale button up when hovered
	var tween = create_tween()
	tween.tween_property(button, "scale", button_hover_scale, animation_speed).set_ease(Tween.EASE_OUT)
	
	# For buttons, we can use the built-in font_color and font_hover_color
	# Get the hover color that was set in the theme
	var hover_color = button.get_theme_color("font_hover_color")
	
	# Apply the hover color as the current font color
	var color_tween = create_tween()
	color_tween.tween_property(button, "modulate", Color(1.1, 1.1, 1.1, 1.0), animation_speed * 0.8)
	
	# Play hover sound if available (at lower volume than click)
	if Engine.has_singleton("SoundManager") and hover_sound:
		var sound_manager = Engine.get_singleton("SoundManager")
		# Play the hover sound with a lower volume
		sound_manager.play_ui_sound_with_pitch(hover_sound, 1.5)

# Button exit animation
func _on_button_mouse_exited(button):
	# Scale button back to normal when not hovered
	var tween = create_tween()
	tween.tween_property(button, "scale", button_default_scale, animation_speed).set_ease(Tween.EASE_OUT)
	
	# Reset button modulate
	var color_tween = create_tween()
	color_tween.tween_property(button, "modulate", Color(1.0, 1.0, 1.0, 1.0), animation_speed * 0.8)

# Title hover animation (smaller effect)
func _on_title_mouse_entered(label):
	# Scale title/subtitle slightly when hovered
	var tween = create_tween()
	tween.tween_property(label, "scale", title_hover_scale, animation_speed).set_ease(Tween.EASE_OUT)
	
	# Just use modulate to enhance brightness for labels
	var color_tween = create_tween()
	color_tween.tween_property(label, "modulate", Color(1.15, 1.15, 1.15, 1.0), animation_speed)

# Title exit animation
func _on_title_mouse_exited(label):
	# Scale title/subtitle back to normal
	var tween = create_tween()
	tween.tween_property(label, "scale", button_default_scale, animation_speed).set_ease(Tween.EASE_OUT)
	
	# Reset label modulate
	var color_tween = create_tween()
	color_tween.tween_property(label, "modulate", Color(1.0, 1.0, 1.0, 1.0), animation_speed)

# Button press animation and scene change
func _on_start_button_pressed():
	# Play click sound if available
	if Engine.has_singleton("SoundManager") and click_sound:
		var sound_manager = Engine.get_singleton("SoundManager")
		sound_manager.play_ui_sound(click_sound)
	
	# Animate button press
	var button = $StartButton
	var tween = create_tween()
	tween.tween_property(button, "scale", Vector2(0.9, 0.9), 0.1)
	tween.tween_property(button, "scale", button_default_scale, 0.1)
	
	# Use direct file path
	var game_scene_path = "res://Levels/HunterMode.tscn"
	
	# Check if file exists before trying to load it
	if ResourceLoader.exists(game_scene_path):
		# Wait briefly for animation to complete
		await tween.finished
		
		# Use SceneManager with "radial" pattern effect for a dynamic wipe
		var options = {
			"pattern": "squares",
			"color": Color(0.1, 0.0, 0.0, 1.0),
			"speed": 1.5,
			"wait_time": 0.3
		}
		SceneManager.change_scene(game_scene_path, options)
	else:
		# Scene doesn't exist, show error
		print("ERROR: Game scene not found: ", game_scene_path)

# Return to main menu or quit
func _on_quit_button_pressed():
	# Play click sound if available
	if Engine.has_singleton("SoundManager") and click_sound:
		var sound_manager = Engine.get_singleton("SoundManager")
		sound_manager.play_ui_sound(click_sound)
	
	# Animate button press
	var button = $QuitButton
	var tween = create_tween()
	tween.tween_property(button, "scale", Vector2(0.9, 0.9), 0.1)
	tween.tween_property(button, "scale", button_default_scale, 0.1)
	
	# If we came from a scene, return to it, otherwise quit
	var main_scene_path = "res://Levels/level.tscn"
	
	if ResourceLoader.exists(main_scene_path):
		# Wait briefly for animation to complete
		await tween.finished
		
		# Use "squares" pattern effect for a grid-based transition
		var options = {
			"pattern": "scribbles",
			"color": Color(0.1, 0.0, 0.0, 1.0),
			"speed": 1.5,
			"wait_time": 0.3
		}
		SceneManager.change_scene(main_scene_path, options)
	else:
		print("ERROR: Main scene not found: ", main_scene_path)
		get_tree().quit() 