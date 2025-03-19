extends ProgressBar

@onready var style = StyleBoxFlat.new()
@onready var bg_style = StyleBoxFlat.new()
@onready var panel_style = StyleBoxFlat.new()

signal stamina_depleted
signal stamina_restored

# Stamina properties
@export var max_stamina: float = 100.0
@export var current_stamina: float = 100.0
@export var stamina_regen_rate: float = 25.0  # Per second
@export var stamina_regen_delay: float = 1.0  # Delay before regeneration starts
@export var action_costs: Dictionary = {
    "dodge_roll": 25.0,
    "sprint": 10.0,    # Reduced cost per second for running
    "heavy_attack": 30.0,  # Reduced cost
    "light_attack": 10.0,  # Reduced cost
    "block": 10.0,    # Initial cost
    "block_hit": 15.0 # Additional cost when blocking a hit
}

# Animation properties
var displayed_stamina: float = 100.0
var deplete_tween: Tween
var restore_tween: Tween
var pulse_tween: Tween
var is_regenerating: bool = true
var regen_timer: float = 0.0

func _ready():
	setup_stamina_bar()
	start_idle_animation()
	# Set minimum size
	custom_minimum_size = Vector2(200, 15)  # Wider and taller bar

func setup_stamina_bar():
	# Set up the fill style (green) - slightly rounded only on bottom
	style.bg_color = Color(0.2, 0.8, 0.2)  # Bright green color
	style.corner_radius_top_left = 0
	style.corner_radius_top_right = 0
	style.corner_radius_bottom_left = 4
	style.corner_radius_bottom_right = 4
	add_theme_stylebox_override("fill", style)
	
	# Set up the background style (darker green with gradient) - slightly rounded only on bottom
	bg_style.bg_color = Color(0.1, 0.2, 0.1)  # Dark green color
	bg_style.corner_radius_top_left = 0
	bg_style.corner_radius_top_right = 0
	bg_style.corner_radius_bottom_left = 4
	bg_style.corner_radius_bottom_right = 4
	add_theme_stylebox_override("background", bg_style)
	
	# Set up the panel background (sleek black outline with glow) - slightly rounded only on bottom
	panel_style.bg_color = Color(0, 0, 0, 0.4)  # More transparent black
	panel_style.corner_radius_top_left = 0
	panel_style.corner_radius_top_right = 0
	panel_style.corner_radius_bottom_left = 4
	panel_style.corner_radius_bottom_right = 4
	panel_style.border_width_left = 1
	panel_style.border_width_top = 0  # No top border to connect with health bar
	panel_style.border_width_right = 1
	panel_style.border_width_bottom = 1
	panel_style.border_color = Color(0.1, 0.3, 0.1, 0.8)
	panel_style.shadow_color = Color(0.2, 0.8, 0.2, 0.3)
	panel_style.shadow_size = 2
	$Background.add_theme_stylebox_override("panel", panel_style)

func start_idle_animation():
	if pulse_tween:
		pulse_tween.kill()
	
	pulse_tween = create_tween()
	pulse_tween.set_loops()
	pulse_tween.tween_property(self, "modulate", Color(1.0, 1.1, 1.0, 1.0), 1.0)
	pulse_tween.tween_property(self, "modulate", Color(1.0, 1.0, 1.0, 1.0), 1.0)

func _process(delta):
	# Handle stamina regeneration
	if regen_timer > 0:
		regen_timer -= delta
		if regen_timer <= 0:
			is_regenerating = true
	
	if is_regenerating and current_stamina < max_stamina:
		current_stamina = min(current_stamina + (stamina_regen_rate * delta), max_stamina)
		if current_stamina >= max_stamina:
			emit_signal("stamina_restored")
	
	# Smooth out the displayed stamina bar - use a faster lerp for smoother transitions
	if abs(displayed_stamina - current_stamina) > 0.01:
		displayed_stamina = lerp(displayed_stamina, current_stamina, 10.0 * delta)
		update_stamina_bar()

func update_stamina_bar():
	# Use displayed_stamina for smoother visual updates
	value = displayed_stamina
	
	# Change color based on stamina percentage
	var stamina_percent = displayed_stamina / max_stamina
	var base_color = Color(0.2, 0.8, 0.2)  # Base green color
	
	if stamina_percent < 0.3:
		# Intense pulsing when stamina is low
		var flash = abs(sin(Time.get_ticks_msec() * 0.008))
		style.bg_color = base_color.lerp(Color(1.0, 0.5, 0.0, 0.8), flash)  # Flash orange
		panel_style.border_color = Color(0.3, 0.2, 0.0, 0.8).lerp(Color(1.0, 0.5, 0.0, 0.8), flash)
		panel_style.shadow_color = Color(1.0, 0.5, 0.0, 0.3).lerp(Color(1.0, 0.7, 0.0, 0.4), flash)
	else:
		style.bg_color = base_color
		panel_style.border_color = Color(0.1, 0.3, 0.1, 0.8)
		panel_style.shadow_color = Color(0.2, 0.8, 0.2, 0.3)
	
	add_theme_stylebox_override("fill", style)
	$Background.add_theme_stylebox_override("panel", panel_style)

func use_stamina(action: String) -> bool:
	if not action in action_costs:
		push_warning("Attempted to use unknown stamina action: " + action)
		return false
	
	var cost = action_costs[action]
	
	# Special handling for continuous actions like sprinting
	if action == "sprint":
		cost *= get_process_delta_time() * 1.0  # Reduced multiplier for more gradual drain
	
	# Don't allow action if not enough stamina
	if current_stamina < cost:
		emit_signal("stamina_depleted")
		return false
	
	# Kill any existing tween
	if deplete_tween:
		deplete_tween.kill()
	
	# Update actual stamina immediately
	current_stamina = max(0.0, current_stamina - cost)
	
	# Only show visual effect for instant actions, not for sprint
	if action != "sprint":
		deplete_tween = create_tween()
		deplete_tween.tween_property(self, "modulate", Color(1.5, 1.2, 0.5, 1.0), 0.1)
		deplete_tween.tween_property(self, "modulate", Color(1.0, 1.0, 1.0, 1.0), 0.1)
	
	# Always update the bar
	update_stamina_bar()
	
	# Reset regeneration timer for all actions
	if action != "sprint" or current_stamina < max_stamina * 0.2:  # Only delay regen for sprint when low on stamina
		regen_timer = stamina_regen_delay
		is_regenerating = false
	
	return true

func restore_stamina(amount: float):
	if restore_tween:
		restore_tween.kill()
	
	current_stamina = min(max_stamina, current_stamina + amount)
	
	# Enhanced restore effect with sparkle
	restore_tween = create_tween()
	restore_tween.tween_property(self, "modulate", Color(0.8, 1.5, 0.8, 1.0), 0.2)
	restore_tween.tween_property(self, "modulate", Color(1.0, 1.0, 1.0, 1.0), 0.3)
	
	update_stamina_bar()
	
	if current_stamina >= max_stamina:
		emit_signal("stamina_restored")

func set_regenerating(value: bool):
	is_regenerating = value
	if is_regenerating:
		regen_timer = stamina_regen_delay

func is_stamina_full() -> bool:
	return current_stamina >= max_stamina

func get_stamina_percent() -> float:
	return current_stamina / max_stamina 