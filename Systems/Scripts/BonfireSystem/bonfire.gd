extends Area2D
class_name Bonfire

signal bonfire_rested_at(bonfire_id)

@export var bonfire_id: String = "bonfire_1"
@export var bonfire_name: String = "Abandoned Bonfire"
@export var is_lit: bool = false
@export var respawn_enemies: bool = true
@export var interact_distance: float = 50.0
@export var interaction_time: float = 0.5  # Hold time needed to activate

# Visual components
var flame_animation: AnimatedSprite2D
var particle_emitter: GPUParticles2D
var light_source: PointLight2D
var prompt_label: Label

# Interaction state
var player_in_range: bool = false
var interaction_progress: float = 0.0
var is_player_interacting: bool = false
var player_ref: Node2D = null

# Ember shader
var ember_material: ShaderMaterial

func _ready():
    # Configure area detection
    collision_layer = 0  # No collision
    collision_mask = 1   # Detect player
    
    # Create the visual components
    setup_visuals()
    
    # Connect signals
    body_entered.connect(_on_body_entered)
    body_exited.connect(_on_body_exit)
    
    # Initialize bonfire state
    update_bonfire_state()
    
    # Add to Bonfire group for easy reference
    add_to_group("Bonfires")

func setup_visuals():
    # Create animated sprite for flame
    flame_animation = AnimatedSprite2D.new()
    add_child(flame_animation)
    
    # Create collision shape
    var collision = CollisionShape2D.new()
    var shape = CircleShape2D.new()
    shape.radius = interact_distance
    collision.shape = shape
    add_child(collision)
    
    # Create particle emitter for ember effect
    particle_emitter = GPUParticles2D.new()
    add_child(particle_emitter)
    
    # Create light source
    light_source = PointLight2D.new()
    # Will need to create a light texture or find one in the project
    # light_source.texture = preload("res://assets/light_texture.png")
    light_source.color = Color(1.0, 0.7, 0.2, 0.8)
    light_source.energy = 0.8
    add_child(light_source)
    
    # Create interaction prompt
    prompt_label = Label.new()
    prompt_label.text = "Hold E to rest"
    prompt_label.position = Vector2(0, -80)
    prompt_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    prompt_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
    prompt_label.visible = false
    add_child(prompt_label)
    
    # Apply ember shader to flame animation
    ember_material = ShaderMaterial.new()
    ember_material.shader = preload("res://assets/Shaders/ember_glow.gdshader")
    ember_material.set_shader_parameter("base_color", Color(0.8, 0.4, 0.0, 1.0))
    ember_material.set_shader_parameter("glow_color", Color(1.0, 0.7, 0.2, 1.0))
    flame_animation.material = ember_material

func update_bonfire_state():
    if is_lit:
        # Enable flame animation
        flame_animation.play("lit")
        # Enable particle emitter
        particle_emitter.emitting = true
        # Enable light with full brightness
        light_source.energy = 0.8
    else:
        # Disable flame animation
        flame_animation.play("unlit")
        # Disable particle emitter
        particle_emitter.emitting = false
        # Disable light
        light_source.energy = 0.0

func _on_body_entered(body):
    if body.is_in_group("Player"):
        player_in_range = true
        player_ref = body
        prompt_label.visible = true

func _on_body_exit(body):
    if body.is_in_group("Player"):
        player_in_range = false
        player_ref = null
        prompt_label.visible = false
        # Reset interaction
        is_player_interacting = false
        interaction_progress = 0.0

func _process(delta):
    if player_in_range and player_ref:
        # Check for interaction input
        if Input.is_action_pressed("interact"):
            if not is_player_interacting:
                is_player_interacting = true
                interaction_progress = 0.0
                
            # Progress the interaction timer
            interaction_progress += delta
            
            # Update visual feedback
            prompt_label.text = "Resting... " + str(int((interaction_progress / interaction_time) * 100)) + "%"
            
            # Check if interaction is complete
            if interaction_progress >= interaction_time:
                rest_at_bonfire()
        else:
            # Reset interaction when button released
            if is_player_interacting:
                is_player_interacting = false
                interaction_progress = 0.0
                prompt_label.text = "Hold E to rest"

func rest_at_bonfire():
    # Light the bonfire if it's not already lit
    if not is_lit:
        is_lit = true
        update_bonfire_state()
        
        # Play lighting animation/effects
        play_lighting_effect()
    
    # Heal the player
    if player_ref and player_ref.has_method("heal_fully"):
        player_ref.heal_fully()
    
    # Refill estus flask if implemented
    if player_ref and player_ref.has_method("refill_estus"):
        player_ref.refill_estus()
    
    # Respawn enemies if configured
    if respawn_enemies:
        var game_manager = get_node_or_null("/root/GameManager")
        if game_manager and game_manager.has_method("respawn_all_enemies"):
            game_manager.respawn_all_enemies()
    
    # Save game state if implemented
    var save_system = get_node_or_null("/root/SaveSystem")
    if save_system and save_system.has_method("save_game"):
        save_system.save_game()
    
    # Set as respawn point
    if player_ref and "respawn_point" in player_ref:
        player_ref.respawn_point = global_position
    
    # Emit signal for other systems
    emit_signal("bonfire_rested_at", bonfire_id)
    
    # Reset interaction state
    is_player_interacting = false
    interaction_progress = 0.0
    prompt_label.text = "E to rest"
    
    # Show "Bonfire lit" UI notification
    show_bonfire_lit_notification()

func play_lighting_effect():
    # Create a tween for lighting effect
    var tween = create_tween()
    tween.set_parallel(true)
    
    # Start particle emission
    particle_emitter.emitting = true
    
    # Gradually increase light intensity
    tween.tween_property(light_source, "energy", 0.8, 1.0)
    
    # Scale up the flame
    tween.tween_property(flame_animation, "scale", Vector2(1.2, 1.2), 0.3)
    tween.tween_property(flame_animation, "scale", Vector2(1.0, 1.0), 0.7)
    
    # Increase ember glow shader intensity
    tween.tween_method(
        func(val): ember_material.set_shader_parameter("intensity", val),
        0.0, 1.5, 0.5
    )
    tween.tween_method(
        func(val): ember_material.set_shader_parameter("intensity", val),
        1.5, 1.0, 0.5
    )

func show_bonfire_lit_notification():
    # This would be implemented to show a Dark Souls-style "BONFIRE LIT" message
    # For now we'll just print to console
    print("BONFIRE LIT: " + bonfire_name) 