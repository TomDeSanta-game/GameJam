extends Button

# Called when the node enters the scene tree for the first time.
func _ready():
	# Create styles programmatically - simpler approach
	_setup_button_styles()
	
	# Connect the pressed signal
	pressed.connect(_on_pressed)
	
	# Connect mouse events
	mouse_entered.connect(_on_mouse_entered)
	mouse_exited.connect(_on_mouse_exited)

func _setup_button_styles():
	# Create normal style
	var normal_style = StyleBoxFlat.new()
	normal_style.bg_color = Color(0.1, 0.2, 0.4, 0.8)
	normal_style.border_width_left = 2
	normal_style.border_width_top = 2
	normal_style.border_width_right = 2
	normal_style.border_width_bottom = 2
	normal_style.border_color = Color(0.2, 0.3, 0.5, 1)
	normal_style.corner_radius_top_left = 5
	normal_style.corner_radius_top_right = 5
	normal_style.corner_radius_bottom_right = 5
	normal_style.corner_radius_bottom_left = 5
	normal_style.shadow_color = Color(0.1, 0.3, 0.6, 0.3)
	normal_style.shadow_size = 3
	normal_style.shadow_offset = Vector2(2, 2)
	
	# Create hover style
	var hover_style = StyleBoxFlat.new()
	hover_style.bg_color = Color(0.2, 0.4, 0.7, 0.9)
	hover_style.border_width_left = 2
	hover_style.border_width_top = 2
	hover_style.border_width_right = 2
	hover_style.border_width_bottom = 2
	hover_style.border_color = Color(0.3, 0.5, 0.8, 1) 
	hover_style.corner_radius_top_left = 5
	hover_style.corner_radius_top_right = 5
	hover_style.corner_radius_bottom_right = 5
	hover_style.corner_radius_bottom_left = 5
	hover_style.shadow_color = Color(0.2, 0.4, 0.8, 0.4)
	hover_style.shadow_size = 4
	hover_style.shadow_offset = Vector2(1, 1)
	
	# Apply the styles
	add_theme_stylebox_override("normal", normal_style)
	add_theme_stylebox_override("hover", hover_style)
	add_theme_stylebox_override("focus", hover_style)
	
	# Update text color
	add_theme_color_override("font_color", Color(0.4, 0.7, 1.0, 1.0))
	add_theme_color_override("font_hover_color", Color(0.6, 0.8, 1.0, 1.0))
	add_theme_color_override("font_focus_color", Color(0.6, 0.8, 1.0, 1.0))
	add_theme_constant_override("outline_size", 1)
	add_theme_color_override("outline_color", Color(0.0, 0.2, 0.5, 0.5))

# Handle button press
func _on_pressed():
	var launcher_path = "res://Levels/VampireSurvivorsLauncher.tscn"
	
	print("DEBUG: Attempting to load vampire mode scene: ", launcher_path)
	
	# Check if file exists before trying to load it
	if ResourceLoader.exists(launcher_path):
		print("DEBUG: Scene file exists, loading...")
		# Use change_scene_to_packed instead for better error handling
		var packed_scene = load(launcher_path)
		if packed_scene:
			print("DEBUG: Scene loaded successfully, changing to scene...")
			SceneManager.change_scene(packed_scene)
		else:
			print("ERROR: Failed to load scene: ", launcher_path)
	else:
		# Scene doesn't exist, show error
		print("ERROR: Scene not found: ", launcher_path)
		# Fall back to default level if available
		var fallback_path = "res://Levels/level.tscn"
		print("DEBUG: Trying fallback scene: ", fallback_path)
		if ResourceLoader.exists(fallback_path):
			SceneManager.change_scene(fallback_path)

# Optional hover effects
func _on_mouse_entered():
	# Scale up slightly
	var tween = create_tween()
	tween.tween_property(self, "scale", Vector2(1.05, 1.05), 0.1)
	
	# Add a subtle glow effect
	var glow_tween = create_tween()
	glow_tween.tween_property(self, "modulate", Color(1.1, 1.2, 1.3, 1.0), 0.2)

func _on_mouse_exited():
	# Return to normal scale and color
	var tween = create_tween()
	tween.tween_property(self, "scale", Vector2(1.0, 1.0), 0.1)
	
	var glow_tween = create_tween()
	glow_tween.tween_property(self, "modulate", Color(1.0, 1.0, 1.0, 1.0), 0.2) 