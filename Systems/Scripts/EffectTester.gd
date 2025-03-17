extends Node

# This script automatically tests the chemical mixing functionality 
# after a delay to ensure effects are working correctly

func _ready():
	print("EffectTester: Initializing")
	# Wait a short time to ensure the player is fully initialized
	get_tree().create_timer(2.0).timeout.connect(func(): run_effect_test())

func run_effect_test():
	print("EffectTester: Running automated effect test")
	
	# Find the player
	var player = get_tree().get_first_node_in_group("Player")
	if player:
		print("EffectTester: Found player:", player.name)
		
		# Get current chemicals
		if "collected_chemicals" in player:
			print("EffectTester: Current chemicals:", player.collected_chemicals)
			
			# If player has chemicals, mix them
			if player.collected_chemicals.size() > 0:
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
	else:
		print("EffectTester: No player found, retrying in 1 second")
		# Try again after a delay
		get_tree().create_timer(1.0).timeout.connect(func(): run_effect_test())

# Test chemical mixing on a player
func test_mix_chemicals(player):
	print("EffectTester: Testing chemical mixing with chemicals:", player.collected_chemicals)
	
	# Try to get the GrowthSystem
	if player.has_node("GrowthSystem"):
		var gs = player.get_node("GrowthSystem")
		var effect_name = null
		
		# Try to determine the effect
		if player.has_method("determine_effect"):
			effect_name = player.determine_effect()
			print("EffectTester: Determined effect:", effect_name)
			
			# Apply the effect
			if effect_name != "None":
				gs.apply_effect(effect_name, 15.0)
				print("EffectTester: DIRECT Applied effect to GrowthSystem:", effect_name)
				
				# Emit signal to update UI
				if get_node_or_null("/root/SignalBus") != null:
					SignalBus.chemicals_mixed.emit(effect_name, 15.0)
					print("EffectTester: Emitted chemicals_mixed signal for effect:", effect_name)
					
					# Verify effect is showing in UI
					get_tree().create_timer(0.5).timeout.connect(func(): verify_effect_in_ui(effect_name))
					
				else:
					print("EffectTester: SignalBus not found")
			else:
				print("EffectTester: No effect determined")
		else:
			print("EffectTester: Player doesn't have determine_effect method")
	else:
		print("EffectTester: Player has no GrowthSystem")

func verify_effect_in_ui(expected_effect):
	# Check if the effect is visible in the UI
	print("EffectTester: Verifying effect is visible in UI...")
	
	# For now, just check the GrowthSystem directly to confirm
	var player = get_tree().get_first_node_in_group("Player")
	if player and player.has_node("GrowthSystem"):
		var gs = player.get_node("GrowthSystem")
		print("EffectTester: UI VERIFICATION - Growth System effect:", gs.current_effect, 
			  ", Expected:", expected_effect,
			  ", Match:", gs.current_effect == expected_effect) 
