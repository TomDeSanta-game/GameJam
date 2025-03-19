extends Node

# This script automatically tests the chemical mixing functionality 
# after a delay to ensure effects are working correctly

# Configuration
@export var initial_delay: float = 3.0      # Increased from 2.0 to 3.0 seconds
@export var retry_delay: float = 1.0        # Time to wait between retries
@export var max_retries: int = 5            # Maximum number of retries before giving up
var retry_count: int = 0                    # Current retry count

func _ready():
	print("EffectTester: Initializing with", initial_delay, "second delay")
	# Wait a longer time to ensure the player is fully initialized
	get_tree().create_timer(initial_delay).timeout.connect(func(): run_effect_test())

func run_effect_test():
	print("EffectTester: Running automated effect test (attempt", retry_count + 1, "of", max_retries + 1, ")")
	
	# Find the player - first by player group, then try other methods if that fails
	var player = get_tree().get_first_node_in_group("Player")
	
	# If no player found, try alternative methods
	if not player:
		print("EffectTester: No player found in 'Player' group, trying other methods")
		# Try lowercase 'player' group
		player = get_tree().get_first_node_in_group("player") 
		
		# If still no player found, retry after delay or give up
		if not player:
			if retry_count < max_retries:
				retry_count += 1
				print("EffectTester: No player found, retrying in", retry_delay, "seconds (attempt", retry_count + 1, "of", max_retries + 1, ")")
				get_tree().create_timer(retry_delay).timeout.connect(func(): run_effect_test())
			else:
				print("EffectTester: Maximum retries reached. No player found after", max_retries + 1, "attempts. Giving up.")
			return
	
	print("EffectTester: Found player:", player.name)
	
	# Check if the player has the needed properties and methods
	if player and "collected_chemicals" in player:
		var chemicals = player.collected_chemicals
		print("EffectTester: Current chemicals:", chemicals)
		
		# If player has chemicals, mix them
		if chemicals and chemicals.size() > 0:
			test_mix_chemicals(player)
		else:
			print("EffectTester: Player has no chemicals, adding test chemicals")
			# Add some test chemicals
			if player.has_method("collect_chemical"):
				player.collect_chemical(0, 5.0)  # RED
				player.collect_chemical(1, 5.0)  # GREEN
				
				# Try to mix after a short delay
				get_tree().create_timer(0.5).timeout.connect(func(): test_mix_chemicals(player))
			else:
				print("EffectTester: Player doesn't have collect_chemical method")
	else:
		print("EffectTester: Player doesn't have collected_chemicals property")
		if retry_count < max_retries:
			retry_count += 1
			print("EffectTester: Will retry in", retry_delay, "seconds (attempt", retry_count + 1, "of", max_retries + 1, ")")
			get_tree().create_timer(retry_delay).timeout.connect(func(): run_effect_test())
		else:
			print("EffectTester: Maximum retries reached. Player properties not available after", max_retries + 1, "attempts. Giving up.")

# Test chemical mixing on a player
func test_mix_chemicals(player):
	# Ensure player exists
	if not player:
		print("EffectTester: Invalid player object in test_mix_chemicals")
		return
		
	# Safely access collected_chemicals
	if not "collected_chemicals" in player:
		print("EffectTester: Player missing collected_chemicals property in test_mix_chemicals")
		return
		
	print("EffectTester: Testing chemical mixing with chemicals:", player.collected_chemicals)
	
	# Try to get the GrowthSystem
	if player.has_node("GrowthSystem"):
		var gs = player.get_node("GrowthSystem")
		if not gs:
			print("EffectTester: GrowthSystem node found but is null")
			return
			
		var effect_name = null
		
		# Try to determine the effect
		if player.has_method("determine_effect"):
			# Safely call determine_effect with error handling
			effect_name = player.determine_effect()
			print("EffectTester: Determined effect:", effect_name)
			
			# Apply the effect
			if effect_name != null and effect_name != "None":
				# Make sure gs has apply_effect method
				if gs.has_method("apply_effect"):
					gs.apply_effect(effect_name, 15.0)
					print("EffectTester: DIRECT Applied effect to GrowthSystem:", effect_name)
					
					# Emit signal to update UI - safely check for SignalBus
					var signal_bus = get_node_or_null("/root/SignalBus")
					if signal_bus != null:
						# Make sure SignalBus has the signal
						if signal_bus.has_signal("chemicals_mixed"):
							SignalBus.chemicals_mixed.emit(effect_name, 15.0)
							print("EffectTester: Emitted chemicals_mixed signal for effect:", effect_name)
							
							# Verify effect is showing in UI
							get_tree().create_timer(0.5).timeout.connect(func(): verify_effect_in_ui(effect_name))
						else:
							print("EffectTester: SignalBus doesn't have 'chemicals_mixed' signal")
					else:
						print("EffectTester: SignalBus not found")
				else:
					print("EffectTester: GrowthSystem doesn't have apply_effect method")
			else:
				print("EffectTester: No effect determined or effect is 'None'")
		else:
			print("EffectTester: Player doesn't have determine_effect method")
	else:
		print("EffectTester: Player has no GrowthSystem node")

func verify_effect_in_ui(expected_effect):
	# Check if the effect is visible in the UI
	print("EffectTester: Verifying effect is visible in UI...")
	
	# Validate expected_effect
	if expected_effect == null or expected_effect.is_empty():
		print("EffectTester: Cannot verify null or empty effect")
		return
	
	# For now, just check the GrowthSystem directly to confirm
	var player = get_tree().get_first_node_in_group("Player")
	if not player:
		print("EffectTester: No player found during UI verification")
		return
		
	if player.has_node("GrowthSystem"):
		var gs = player.get_node("GrowthSystem")
		if not gs:
			print("EffectTester: GrowthSystem node found but is null during verification")
			return
			
		if "current_effect" in gs:
			print("EffectTester: UI VERIFICATION - Growth System effect:", gs.current_effect, 
				", Expected:", expected_effect,
				", Match:", gs.current_effect == expected_effect)
		else:
			print("EffectTester: GrowthSystem doesn't have current_effect property")
	else:
		print("EffectTester: Player has no GrowthSystem during verification")
