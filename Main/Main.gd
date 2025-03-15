extends Node

# Preload the growth system and chemical mixer
const PlayerGrowthSystemClass = preload("res://Entities/Scripts/Player/GrowthSystem.gd")
const PlayerChemicalMixerClass = preload("res://Entities/Scripts/Player/ChemicalMixer.gd")

# UI references
var growth_ui: Node

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
	
	# Setup UI for growth system
	setup_growth_ui()
	
	print("Systems setup complete")

func setup_growth_ui():
	# Create a GrowthUI if it doesn't exist
	if not has_node("GrowthUI"):
		var GrowthUI = load("res://Entities/Scripts/UI/GrowthUI.gd")
		if GrowthUI:
			growth_ui = GrowthUI.new()
			growth_ui.name = "GrowthUI"
			add_child(growth_ui)
			print("Added GrowthUI to the scene")
		else:
			print("ERROR: Could not load GrowthUI script")
	else:
		growth_ui = get_node("GrowthUI")
		print("Found existing GrowthUI") 