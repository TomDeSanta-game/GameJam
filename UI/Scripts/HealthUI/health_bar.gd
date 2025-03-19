extends ProgressBar

@onready var style = StyleBoxFlat.new()
@onready var bg_style = StyleBoxFlat.new()
@onready var panel_style = StyleBoxFlat.new()

signal health_depleted
signal health_restored

# Health properties
@export var max_health: float = 100.0
@export var current_health: float = 100.0

# Animation properties
var displayed_health: float = 100.0
var damage_tween: Tween
var heal_tween: Tween
var pulse_tween: Tween

func _ready():
	setup_health_bar()
	start_idle_animation()
	# Set minimum size
	custom_minimum_size = Vector2(200, 15)  # Wider and taller bar

func setup_health_bar():
	# Set up the fill style (red) - slightly rounded only on top
	style.bg_color = Color(0.9, 0.0, 0.0)  # Bright red color
	style.corner_radius_top_left = 4
	style.corner_radius_top_right = 4
	style.corner_radius_bottom_left = 0
	style.corner_radius_bottom_right = 0
	add_theme_stylebox_override("fill", style)
	
	# Set up the background style (darker red with gradient) - slightly rounded only on top
	bg_style.bg_color = Color(0.25, 0.0, 0.0)  # Darker red color
	bg_style.corner_radius_top_left = 4
	bg_style.corner_radius_top_right = 4
	bg_style.corner_radius_bottom_left = 0
	bg_style.corner_radius_bottom_right = 0
	add_theme_stylebox_override("background", bg_style)
	
	# Set up the panel background (sleek black outline with glow) - slightly rounded only on top
	panel_style.bg_color = Color(0, 0, 0, 0.4)  # More transparent black
	panel_style.corner_radius_top_left = 4
	panel_style.corner_radius_top_right = 4
	panel_style.corner_radius_bottom_left = 0
	panel_style.corner_radius_bottom_right = 0
	panel_style.border_width_left = 1
	panel_style.border_width_top = 1
	panel_style.border_width_right = 1
	panel_style.border_width_bottom = 0  # No bottom border to connect with stamina bar
	panel_style.border_color = Color(0.3, 0.0, 0.0, 0.8)
	panel_style.shadow_color = Color(0.9, 0.0, 0.0, 0.3)
	panel_style.shadow_size = 2
	$Background.add_theme_stylebox_override("panel", panel_style)

func start_idle_animation():
	if pulse_tween:
		pulse_tween.kill()
	
	pulse_tween = create_tween()
	pulse_tween.set_loops()
	pulse_tween.tween_property(self, "modulate", Color(1.1, 1.0, 1.0, 1.0), 1.0)
	pulse_tween.tween_property(self, "modulate", Color(1.0, 1.0, 1.0, 1.0), 1.0)

func _process(delta):
	# Smooth out the displayed health bar
	if abs(displayed_health - current_health) > 0.1:
		displayed_health = lerp(displayed_health, current_health, 15.0 * delta)
		update_health_bar()

func update_health_bar():
	value = displayed_health
	
	# Change color based on health percentage
	var health_percent = current_health / max_health
	var base_color = Color(0.9, 0.0, 0.0)  # Base red color
	
	if health_percent < 0.3:
		# Intense pulsing when health is low
		var flash = abs(sin(Time.get_ticks_msec() * 0.008))
		style.bg_color = base_color.lerp(Color(1, 0.2, 0.2, 0.8), flash)
		panel_style.border_color = Color(0.8, 0.0, 0.0, 0.8).lerp(Color(1, 0.2, 0.2, 0.8), flash)
		panel_style.shadow_color = Color(0.9, 0.0, 0.0, 0.4).lerp(Color(1, 0.2, 0.2, 0.4), flash)
	else:
		style.bg_color = base_color
		panel_style.border_color = Color(0.3, 0.0, 0.0, 0.8)
		panel_style.shadow_color = Color(0.9, 0.0, 0.0, 0.3)
	
	add_theme_stylebox_override("fill", style)
	$Background.add_theme_stylebox_override("panel", panel_style)

func take_damage(amount: float):
	if damage_tween:
		damage_tween.kill()
	
	current_health = max(0.0, current_health - amount)
	
	# Enhanced damage effect with only color flash
	damage_tween = create_tween()
	damage_tween.tween_property(self, "modulate", Color(2.0, 1.0, 1.0, 1.0), 0.1)
	damage_tween.tween_property(self, "modulate", Color(1.0, 1.0, 1.0, 1.0), 0.1)
	
	update_health_bar()
	
	if current_health <= 0:
		emit_signal("health_depleted")

func heal(amount: float):
	if heal_tween:
		heal_tween.kill()
	
	current_health = min(max_health, current_health + amount)
	
	# Enhanced heal effect with sparkle
	heal_tween = create_tween()
	heal_tween.tween_property(self, "modulate", Color(1.2, 1.4, 1.2, 1.0), 0.2)
	heal_tween.tween_property(self, "modulate", Color(1.0, 1.0, 1.0, 1.0), 0.3)
	
	update_health_bar()
	
	if current_health >= max_health:
		emit_signal("health_restored")

func set_max_health(value: float):
	max_health = value
	current_health = min(current_health, max_health)
	update_health_bar()

func get_health_percent() -> float:
	return current_health / max_health 