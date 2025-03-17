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
	if body.is_in_group("Player") and body.has_method("collect_chemical"):
		collected = true
		
		# Call the collection method on the player
		var success = body.collect_chemical(chemical_type, growth_amount)
		
		if success:
			# Play collection animation
			if animation_player and animation_player.has_animation("collect"):
				animation_player.play("collect")
				await animation_player.animation_finished
				queue_free()
			else:
				# If no animation, just disappear
				visible = false
				collision_shape.set_deferred("disabled", true)
				
				# Play collection particle effect if available
				if particles:
					particles.emitting = true
					await get_tree().create_timer(1.0).timeout
				
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