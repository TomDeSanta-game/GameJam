extends Node

# Preload the growth system and chemical mixer
const PlayerGrowthSystemClass = preload("res://Systems/Scripts/GrowthSystem/GrowthSystem.gd")
const PlayerChemicalMixerClass = preload("res://Entities/Scripts/Player/ChemicalMixer.gd")

func _ready():
	# Wait until all nodes are ready
	call_deferred("setup_systems")

func setup_systems():
	# Find the player
	var player = get_node_or_null("Knight")
	if not player:
		print("ERROR: Player (Knight) not found in the Main scene!")
		return
	
	print("Player found: ", player.name)
	
	# Ensure player is in the 'player' group
	if not player.is_in_group("player"):
		player.add_to_group("player")
	
	# Check if systems are already attached
	if not player.has_node("GrowthSystem"):
		print("Adding GrowthSystem to player")
		var growth_system = PlayerGrowthSystemClass.new()
		growth_system.name = "GrowthSystem"
		player.add_child(growth_system)
	
	if not player.has_node("ChemicalMixer"):
		print("Adding ChemicalMixer to player")
		var chemical_mixer = PlayerChemicalMixerClass.new()
		chemical_mixer.name = "ChemicalMixer"
		player.add_child(chemical_mixer)
	
	print("Systems setup complete") 