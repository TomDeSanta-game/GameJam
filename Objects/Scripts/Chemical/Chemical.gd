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
var light: PointLight2D
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
	
	# Set up collision layers - layer 32 for chemicals, mask 2 for player
	collision_layer = 32  # Chemical layer
	collision_mask = 2    # Detect player
	
	# Connect the area entered signal
	area_entered.connect(_on_area_entered)
	body_entered.connect(_on_body_entered)
	
	# Create a simple polygon shape for the chemical
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
	
	# Create shader material
	var shader_material = ShaderMaterial.new()
	var shader_code = """
	shader_type canvas_item;
	
	uniform vec4 glow_color : source_color = vec4(1.0, 1.0, 1.0, 1.0);
	uniform float glow_strength : hint_range(0.0, 2.0) = 1.0;
	uniform float pulse_speed : hint_range(0.0, 5.0) = 2.0;
	
	void fragment() {
		vec4 current_color = texture(TEXTURE, UV);
		float pulse = (sin(TIME * pulse_speed) * 0.5 + 0.5) * glow_strength;
		vec4 glow = glow_color * pulse;
		COLOR = mix(current_color, glow, 0.5);
		COLOR.a = current_color.a;
	}
	"""
	
	shader_material.shader = Shader.new()
	shader_material.shader.code = shader_code
	
	# Set color based on chemical type
	var base_color: Color
	match chemical_type:
		ChemicalType.RED:
			base_color = Color(1, 0.2, 0.2, 0.8)
		ChemicalType.GREEN:
			base_color = Color(0.2, 1, 0.2, 0.8)
		ChemicalType.BLUE:
			base_color = Color(0.2, 0.2, 1, 0.8)
		ChemicalType.YELLOW:
			base_color = Color(1, 1, 0.2, 0.8)
		ChemicalType.PURPLE:
			base_color = Color(1, 0.2, 1, 0.8)
	
	polygon.color = base_color
	shader_material.set_shader_parameter("glow_color", base_color)
	shader_material.set_shader_parameter("glow_strength", 1.5)
	shader_material.set_shader_parameter("pulse_speed", 2.0)
	polygon.material = shader_material
	
	sprite.add_child(polygon)
	add_child(sprite)
	
	# Setup light with programmatically created gradient texture
	light = PointLight2D.new()
	
	# Create a radial gradient texture for the light
	var gradient = Gradient.new()
	gradient.add_point(0.0, base_color)
	gradient.add_point(1.0, Color(0, 0, 0, 0))
	
	var gradient_texture = GradientTexture2D.new()
	gradient_texture.gradient = gradient
	gradient_texture.width = 128
	gradient_texture.height = 128
	gradient_texture.fill = GradientTexture2D.FILL_RADIAL
	gradient_texture.fill_from = Vector2(0.5, 0.5)
	gradient_texture.fill_to = Vector2(1, 0.5)
	
	light.texture = gradient_texture
	light.energy = 1.2
	light.texture_scale = 0.8
	add_child(light)
	
	# Add inner glow polygon
	var inner_glow = Polygon2D.new()
	inner_glow.polygon = points
	inner_glow.color = base_color
	inner_glow.color.a = 0.3
	inner_glow.scale = Vector2(1.2, 1.2)
	sprite.add_child(inner_glow)
	
	# Setup audio player for collection sound
	audio_player = AudioStreamPlayer2D.new()
	add_child(audio_player)
	
	# Store initial position for floating effect
	initial_position = position
	time_offset = randf() * PI * 2
	
	if debug:
		print("Chemical initialized with type: ", chemical_type)
		print("Collision layer: ", collision_layer, " mask: ", collision_mask)

func _on_body_entered(body):
	if body.is_in_group("Player"):
		if debug:
			print("Player body entered chemical")
		collect(body)

func _on_area_entered(area):
	var parent = area.get_parent()
	if parent and parent.is_in_group("Player"):
		if debug:
			print("Player area entered chemical")
		collect(parent)

func collect(collector):
	if collector.has_method("collect_chemical"):
		if collector.collect_chemical(chemical_type):
			# Play collection sound if available
			if collection_sound and audio_player:
				audio_player.stream = collection_sound
				audio_player.play()
			
			# Queue for deletion
			queue_free()

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

# Set the chemical type and update visuals
func set_type(type: int):
	chemical_type = type
	
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
