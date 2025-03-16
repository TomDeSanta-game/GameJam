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
	darken_background()
	
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

# Function to darken the background by adjusting modulate.a for each sprite
func darken_background():
	var parallax_bg = $ParallaxBackground
	if parallax_bg:
		# Apply darkness to each layer
		for layer_idx in range(1, 8):  # ParallaxLayer1 through ParallaxLayer7
			var layer_path = "ParallaxLayer" if layer_idx == 1 else "ParallaxLayer" + str(layer_idx)
			var layer = parallax_bg.get_node_or_null(layer_path)
			
			if layer:
				var sprite = layer.get_node_or_null("Sprite2D")
				if sprite:
					# Adjust the modulate to make it darker
					var modulate_color = sprite.modulate
					modulate_color.a = background_darkness
					sprite.modulate = modulate_color

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
	
	# Add to the scene
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

# Timer callback for spawning chemicals
func _on_spawn_timer_timeout():
	if spawn_chemicals:
		spawn_random_chemical() 