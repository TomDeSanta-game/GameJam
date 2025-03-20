extends Area2D
class_name ChemicalCollectible

# Chemical properties
@export var chemical_type: String = "red"  # red, blue, green, yellow, purple
@export var collect_sound: AudioStream
@export var growth_amount: float = 5.0  # Amount to grow the player

# Visual elements
@onready var sprite = $Sprite2D
@onready var animation_player = $AnimationPlayer
@onready var particles = $CPUParticles2D

# Collision detection
@onready var collision_shape = $CollisionShape2D

# Collection state
var collected: bool = false

func _ready():
	# Set color based on chemical type
	match chemical_type:
		"red":
			sprite.modulate = Color(1, 0.2, 0.2)
			if particles:
				particles.color = Color(1, 0.2, 0.2)
		"blue":
			sprite.modulate = Color(0.2, 0.4, 1)
			if particles:
				particles.color = Color(0.2, 0.4, 1)
		"green":
			sprite.modulate = Color(0.2, 0.8, 0.2)
			if particles:
				particles.color = Color(0.2, 0.8, 0.2)
		"yellow":
			sprite.modulate = Color(1, 0.9, 0.2)
			if particles:
				particles.color = Color(1, 0.9, 0.2)
		"purple":
			sprite.modulate = Color(0.8, 0.2, 0.8)
			if particles:
				particles.color = Color(0.8, 0.2, 0.8)
	
	# Connect to signals
	body_entered.connect(_on_body_entered)
	
	# Start idle animation if available
	if animation_player and animation_player.has_animation("idle"):
		animation_player.play("idle")

func _on_body_entered(body):
	if collected:
		return
		
	# Check if the colliding body is the player
	if body.is_in_group("Player"):
		collected = true
		
		# Ensure the collision shape is disabled immediately to prevent multiple collisions
		collision_shape.set_deferred("disabled", true)
		
		# Try different methods to collect the chemical
		var success = false
		
		if body.has_method("collect_chemical"):
			success = body.collect_chemical(chemical_type, growth_amount)
		else:
			# Fallback method - try to find a GrowthSystem on the player
			var growth_system = body.get_node_or_null("GrowthSystem")
			if growth_system and growth_system.has_method("add_growth"):
				growth_system.add_growth(growth_amount)
				success = true
		
		# Handle success or failure
		if success:
			# Play collection animation if available
			if animation_player and animation_player.has_animation("collect"):
				animation_player.play("collect")
				
				# Use a Timer instead of await to prevent getting stuck
				var timer = Timer.new()
				timer.wait_time = animation_player.get_animation("collect").length
				timer.one_shot = true
				add_child(timer)
				timer.start()
				timer.timeout.connect(func(): queue_free())
			else:
				# If no animation, just disappear
				visible = false
				
				# Play collection particle effect if available
				if particles:
					particles.emitting = true
					
					# Use a Timer for particles too
					var timer = Timer.new()
					timer.wait_time = 1.0
					timer.one_shot = true
					add_child(timer)
					timer.start()
					timer.timeout.connect(func(): queue_free())
				else:
					queue_free()
			
			# Play sound if assigned
			if collect_sound:
				var audio_player = AudioStreamPlayer.new()
				get_tree().root.add_child(audio_player)
				audio_player.stream = collect_sound
				audio_player.volume_db = -10
				audio_player.play()
				
				# Auto-remove after playing
				audio_player.finished.connect(func(): audio_player.queue_free())
		else:
			# If collection failed, just remove the chemical
			queue_free() 