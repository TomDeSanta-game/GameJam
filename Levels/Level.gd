extends Node2D

# Preload the Chemical class
const ChemicalItemClass = preload("res://Objects/Scripts/Chemical/Chemical.gd")

# Chemical spawning variables
@export var spawn_chemicals: bool = true
@export var chemical_count: int = 5
@export var spawn_interval: float = 10.0

# Background darkness settings
@export var background_darkness: float = 0.4

# References
var player: Node2D
var spawn_timer: Timer

func _ready():
	# Make the background darker
	# darken_background()
	
	# Wait for player to be added to the scene
	call_deferred("setup_level")
	
	# Create timer for chemical spawning
	if spawn_chemicals:
		spawn_timer = Timer.new()
		spawn_timer.wait_time = spawn_interval
		spawn_timer.one_shot = false
		spawn_timer.autostart = true
		spawn_timer.timeout.connect(_on_spawn_timer_timeout)
		add_child(spawn_timer)
	
	# Fix positions of any NightBorne enemies already in the scene
	call_deferred("fix_nightborne_positions")

# Fix positions of any NightBorne enemies to make sure they're on valid ground
func fix_nightborne_positions():
	await get_tree().process_frame
	# All NightBorne enemies will fix their own positions on _ready,
	# but this is a safeguard for manually placed enemies in the scene
	var nightbornes = get_tree().get_nodes_in_group("Enemy")
	for enemy in nightbornes:
		if enemy.name.contains("NightBorne"):
			# Let the NightBorne self-correct its position
			# Its fix_spawn_position function will handle placement
			print("Level: Found initial NightBorne at ", enemy.global_position)

# Function to darken the background by adjusting modulate.a for each sprite
# func darken_background():
# 	var parallax_bg = $ParallaxBackground
# 	if parallax_bg:
# 		# Apply darkness to each layer
# 		for layer_idx in range(1, 8):  # ParallaxLayer1 through ParallaxLayer7
# 			var layer_path = "ParallaxLayer" if layer_idx == 1 else "ParallaxLayer" + str(layer_idx)
# 			var layer = parallax_bg.get_node_or_null(layer_path)
			
# 			if layer:
# 				var sprite = layer.get_node_or_null("Sprite2D")
# 				if sprite:
# 					# Adjust the modulate to make it darker
# 					var modulate_color = sprite.modulate
# 					modulate_color.a = background_darkness
# 					sprite.modulate = modulate_color

func setup_level():
	# Wait a frame to make sure player is fully loaded
	await get_tree().process_frame
	
	# Find the player
	player = get_tree().get_first_node_in_group("player")
	if not player:
		push_warning("Player not found in the scene.")
		return
	
	# Initial chemical spawning
	if spawn_chemicals:
		for i in range(chemical_count):
			spawn_random_chemical()

# Spawn a random chemical in the level
func spawn_random_chemical():
	if not player:
		return
	
	# Get a random position in the level, not too far from player
	var pos = get_random_spawn_position()
	
	# Use the static method to create a chemical
	var chemical = ChemicalItemClass.spawn_chemical(pos)
	
	# Add a timeout to ensure chemicals don't stay forever 
	# This helps prevent "floating" chemicals that can't be collected
	var timer = Timer.new()
	timer.wait_time = 20.0  # Auto-remove after 20 seconds
	timer.one_shot = true
	timer.timeout.connect(func(): 
		if is_instance_valid(chemical):
			# Make the chemical fade out gracefully
			var tween = get_tree().create_tween()
			tween.tween_property(chemical, "modulate:a", 0.0, 0.5)
			await tween.finished
			chemical.queue_free()
			timer.queue_free()
	)
	add_child(timer)
	timer.start()
	
	# Add the chemical to the scene
	add_child(chemical)

# Get a random position for chemical spawning
func get_random_spawn_position() -> Vector2:
	# If player is available, spawn within a certain range
	if player:
		var spawn_range = 300.0
		var x = player.position.x + randf_range(-spawn_range, spawn_range)
		var y = player.position.y + randf_range(-spawn_range, spawn_range)
		
		# Make sure it's above the ground - this is just an approximation
		# You would need actual ground detection for a more robust solution
		y = min(y, player.position.y - 50)
		
		return Vector2(x, y)
	else:
		# If no player, use a default area
		return Vector2(
			randf_range(100, 700),
			randf_range(100, 300)
		)

# Get a valid ground position for enemy spawning
func get_valid_ground_position(x_position: float = -1) -> Vector2:
	# If no specific x position is provided, generate one
	if x_position < 0:
		x_position = randf_range(100, 700)
	
	# Check for ground at this position
	var space_state = get_world_2d().direct_space_state
	
	# Try to find the main floor
	var ray_start = Vector2(x_position, 100)  # Start from high up
	var ray_end = Vector2(x_position, 400)    # Go down past expected floor level
	
	var query = PhysicsRayQueryParameters2D.create(ray_start, ray_end)
	query.collision_mask = 1  # Only check against world/terrain
	
	var result = space_state.intersect_ray(query)
	if result:
		# Found ground, position the enemy slightly above it
		return Vector2(x_position, result.position.y - 20)
	else:
		# If no ground found, use the default floor height
		return Vector2(x_position, 272.9)  # Common floor position

# Timer callback for spawning chemicals
func _on_spawn_timer_timeout():
	if spawn_chemicals:
		spawn_random_chemical() 

func _on_doom_box_body_entered(body: Node2D) -> void:
	if body == player:
		SceneManager.reload_scene()