extends Node

# Growth system signals
signal player_grew(player, growth_amount)
signal player_shrank(player, shrink_amount)
signal growth_level_changed(player, new_level, level_percent)
signal growth_reset()

# Chemical system signals
signal chemical_collected(chemical_type, slot_index)
signal chemicals_mixed(effect_name, duration)

# Player signals
signal player_damaged(player, damage_amount)
signal player_healed(player, heal_amount)
signal player_died()

# Enemy signals
signal enemy_damaged(enemy, damage_amount)
signal enemy_died(enemy)
signal enemy_killed(position, enemy_type)

func _ready():
	print("SignalBus initialized") 