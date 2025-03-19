extends Control
class_name SoulsCounter

# Soul counter properties
var souls_count: int = 0
var displayed_souls: int = 0
var lerp_speed: float = 5.0
var shake_amount: float = 1.0
var fade_time: float = 1.0

# UI elements
var souls_label: Label
var souls_icon: TextureRect
var tween: Tween

# Animation properties
var original_position: Vector2
var is_animating: bool = false

# Shader
var souls_material: ShaderMaterial

func _ready():
    # Create UI elements
    souls_label = Label.new()
    souls_icon = TextureRect.new()
    
    # Setup container
    var container = HBoxContainer.new()
    container.add_child(souls_icon)
    container.add_child(souls_label)
    add_child(container)
    
    # Position and style the souls counter
    setup_ui_elements()
    
    # Store original position for animation
    await get_tree().process_frame
    original_position = container.position
    
    # Initialize souls counter
    update_souls_display()

func setup_ui_elements():
    # Container setup
    var container = get_node_or_null("HBoxContainer")
    if !container:
        return
    
    container.size = Vector2(200, 50)
    container.position = Vector2(20, 50)  # Position below health bar
    
    # Icon setup
    if souls_icon:
        # Use an existing texture from the project as a placeholder
        # We'll use gems_db16.png which we found in the assets directory
        souls_icon.texture = preload("res://assets/gems_db16.png")
        souls_icon.expand = true
        souls_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT
        souls_icon.custom_minimum_size = Vector2(32, 32)
        
        # Apply ember glow shader
        souls_material = ShaderMaterial.new()
        souls_material.shader = preload("res://assets/Shaders/ember_glow.gdshader")
        souls_material.set_shader_parameter("base_color", Color(0.8, 0.4, 0.0, 1.0))
        souls_material.set_shader_parameter("glow_color", Color(1.0, 0.7, 0.2, 1.0))
        souls_material.set_shader_parameter("intensity", 1.0)
        souls_material.set_shader_parameter("speed", 1.0)
        souls_icon.material = souls_material
    
    # Label setup
    if souls_label:
        souls_label.text = "0"
        souls_label.add_theme_font_size_override("font_size", 18)
        souls_label.add_theme_color_override("font_color", Color(0.9, 0.8, 0.6))
        souls_label.add_theme_font_override("font", preload("res://assets/Fonts/static/JetBrainsMono-Bold.ttf"))

func add_souls(amount: int):
    souls_count += amount
    animate_souls_gain()
    update_souls_display()

func lose_souls():
    # Dark Souls style - lose all souls on death
    var souls_to_lose = souls_count
    souls_count = 0
    update_souls_display()
    return souls_to_lose

func update_souls_display():
    if souls_label:
        souls_label.text = str(displayed_souls)

func _process(delta):
    # Smooth interpolation for souls counter
    if displayed_souls != souls_count:
        displayed_souls = int(lerp(float(displayed_souls), float(souls_count), delta * lerp_speed))
        if abs(displayed_souls - souls_count) < 5:
            displayed_souls = souls_count
        update_souls_display()

func animate_souls_gain():
    # Don't start a new animation if one is already running
    if is_animating:
        return
    
    is_animating = true
    
    var container = get_node_or_null("HBoxContainer")
    if !container:
        is_animating = false
        return
    
    # Cancel any existing tweens
    if tween and tween.is_running():
        tween.kill()
    
    # Create new tween
    tween = create_tween()
    tween.set_parallel(true)
    
    # Scale up
    tween.tween_property(container, "scale", Vector2(1.2, 1.2), 0.1)
    
    # Shake effect
    for i in range(5):
        var random_offset = Vector2(
            randf_range(-shake_amount, shake_amount),
            randf_range(-shake_amount, shake_amount)
        )
        tween.tween_property(container, "position", original_position + random_offset, 0.05)
    
    # Return to original state
    tween.tween_property(container, "scale", Vector2(1.0, 1.0), 0.2)
    tween.tween_property(container, "position", original_position, 0.1)
    
    # Emit ember particles (not implemented in this basic version)
    
    # Reset animation flag when done
    tween.finished.connect(func(): is_animating = false)
    
    # Increase ember glow temporarily
    if souls_material:
        souls_material.set_shader_parameter("intensity", 1.5)
        
        var glow_tween = create_tween()
        glow_tween.tween_method(
            func(val): souls_material.set_shader_parameter("intensity", val),
            1.5, 1.0, 0.5
        ) 