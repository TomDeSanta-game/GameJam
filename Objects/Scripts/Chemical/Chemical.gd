extends Area2D

class_name ChemicalItem

# Define chemical types directly
enum ChemicalType {
	RED = 0,
	GREEN = 1,
	BLUE = 2,
	YELLOW = 3,
	PURPLE = 4
}

# Chemical properties
@export var chemical_type: int = ChemicalType.RED
@export var float_height: float = 10.0
@export var float_speed: float = 2.0
@export var rotation_speed: float = 1.0
@export var collection_sound: AudioStream
@export var debug: bool = false  # Debug flag to control print statements

# Visual components
var sprite: Sprite2D
var particles: GPUParticles2D
var light: Node2D
var audio_player: AudioStreamPlayer2D
var initial_position: Vector2
var time_offset: float = 0.0

# Called when the node enters the scene tree for the first time
func _ready():
	# Set up collision shape for area
	var collision_shape = CollisionShape2D.new()
	var shape = CircleShape2D.new()
	shape.radius = 20.0
	collision_shape.shape = shape
	add_child(collision_shape)
	
	# Create a simple shape sprite instead of loading textures
	sprite = Sprite2D.new()
	
	# Create a simple polygon shape for the chemical
	var polygon = Polygon2D.new()
	var points = PackedVector2Array([
		Vector2(-10, -15),
		Vector2(10, -15),
		Vector2(15, 0),
		Vector2(10, 15),
		Vector2(-10, 15),
		Vector2(-15, 0)
	])
	polygon.polygon = points
	sprite.add_child(polygon)
	add_child(sprite)
	
	# Setup simple light using a polygon
	light = Node2D.new()
	light.z_index = -1
	var light_polygon = Polygon2D.new()
	var light_points = PackedVector2Array([
		Vector2(-20, -25),
		Vector2(20, -25),
		Vector2(25, 0),
		Vector2(20, 25),
		Vector2(-20, 25),
		Vector2(-25, 0)
	])
	light_polygon.polygon = light_points
	light_polygon.color = Color(1, 1, 1, 0.2)
	light.add_child(light_polygon)
	add_child(light)
	
	# Setup audio player
	audio_player = AudioStreamPlayer2D.new()
	add_child(audio_player)
	
	# Save initial position for floating effect
	initial_position = position
	
	# Random time offset for floating animation
	time_offset = randf() * TAU
	
	# Set color based on chemical type
	set_chemical_color()
	
	# Connect signal - ensure we're connected even if not done in editor
	if not body_entered.is_connected(_on_body_entered):
		body_entered.connect(_on_body_entered)
	
	# Print debug info
	if debug:
		print("Chemical initialized: ", ChemicalType.keys()[chemical_type])
		print("Chemical collision_layer: ", collision_layer)
		print("Chemical collision_mask: ", collision_mask)
	else:
		# Always print this crucial debug info
		print("Chemical initialized at ", position, " type: ", ChemicalType.keys()[chemical_type])

# Set the color of the chemical based on its type
func set_chemical_color():
	var color_map = {
		ChemicalType.RED: Color(1.0, 0.2, 0.2),
		ChemicalType.GREEN: Color(0.2, 1.0, 0.2),
		ChemicalType.BLUE: Color(0.2, 0.2, 1.0),
		ChemicalType.YELLOW: Color(1.0, 1.0, 0.2),
		ChemicalType.PURPLE: Color(0.8, 0.2, 0.8)
	}
	
	var color = color_map.get(chemical_type, Color(1, 1, 1))
	
	# Apply color to sprite and light
	var polygon = sprite.get_child(0)
	if polygon and polygon is Polygon2D:
		polygon.color = color
	
	var light_polygon = light.get_child(0)
	if light_polygon and light_polygon is Polygon2D:
		light_polygon.color = color.lightened(0.5)
		light_polygon.color.a = 0.3

# Process function for animation
func _process(delta: float):
	# Floating animation
	var floating_offset = sin(Time.get_ticks_msec() * 0.001 * float_speed + time_offset) * float_height
	position.y = initial_position.y + floating_offset
	
	# Rotation animation
	sprite.rotation += rotation_speed * delta

# Called when this node is ready to handle physics
func _physics_process(_delta):
	# Debug collision - check if there are overlapping bodies
	# Only check if monitoring is enabled to avoid errors
	if monitoring and debug:
		var overlapping_bodies = get_overlapping_bodies()
		if overlapping_bodies.size() > 0:
			pass # Debug code removed

# Handle player collection
func _on_body_entered(body):
	# Check for Player in multiple ways for robustness
	if body.is_in_group("Player") or body is Knight or "Knight" in body.name:
		# Emit signal if SignalBus is available
		if get_node_or_null("/root/SignalBus") != null:
			var signal_bus = get_node("/root/SignalBus")
			signal_bus.chemical_collected.emit(chemical_type, global_position)
		else:
			# Direct call as fallback if player has collect_chemical method
			if body.has_method("collect_chemical"):
				body.collect_chemical(chemical_type, 5.0)  # Default 5.0 growth
		
		# Play collection sound and effect
		if audio_player and collection_sound:
			audio_player.stream = collection_sound
			audio_player.play()
		
		# Make sprite fade out
		var tween = get_tree().create_tween()
		tween.tween_property(sprite, "modulate:a", 0.0, 0.5)
		
		# Disable collision using set_deferred to avoid errors during signal callback
		set_deferred("monitoring", false)
		set_deferred("monitorable", false)
		
		# Free after sound finishes
		await get_tree().create_timer(0.5).timeout
		queue_free()

# Set the chemical type and update visuals
func set_type(type: int):
	chemical_type = type
	set_chemical_color()
	
# Static method to create a chemical at a specific position
static func spawn_chemical(pos: Vector2, type: int = -1) -> ChemicalItem:
	# Create a new Chemical instance directly
	var chemical = ChemicalItem.new()
	
	# Set random type if not specified
	if type < 0 or type >= ChemicalType.size():
		type = randi() % ChemicalType.size()
	
	chemical.position = pos
	chemical.chemical_type = type
	
	return chemical 
