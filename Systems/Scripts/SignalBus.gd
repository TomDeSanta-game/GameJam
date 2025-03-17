extends Node

# Growth and player signals
@warning_ignore("unused_signal")
signal player_grew(player, growth_amount)
@warning_ignore("unused_signal")
signal player_shrank(player, growth_amount)
@warning_ignore("unused_signal")
signal growth_level_changed(player, new_level, level_percent)
@warning_ignore("unused_signal")
signal growth_reset()
@warning_ignore("unused_signal")
signal player_damaged(player, damage_amount)
@warning_ignore("unused_signal")
signal player_died()

# Chemical signals
@warning_ignore("unused_signal")
signal chemical_collected(chemical_type, slot_index)
@warning_ignore("unused_signal")
signal chemicals_mixed(effect_name, duration)
@warning_ignore("unused_signal")
signal effect_applied(effect_name, duration)

# Enemy signals
@warning_ignore("unused_signal")
signal enemy_died(enemy)
@warning_ignore("unused_signal")
signal enemy_damaged(enemy, damage_amount)

# func _init():
# 	pass

# func _ready():
# 	pass 