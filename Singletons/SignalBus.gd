extends Node

# Player signals
@warning_ignore("unused_signal")
signal player_damaged(player, damage_amount)
@warning_ignore("unused_signal")
signal player_died(player)
@warning_ignore("unused_signal")
signal player_attacked(player)
@warning_ignore("unused_signal")
signal player_healed(player, heal_amount)

# Enemy signals
@warning_ignore("unused_signal")
signal enemy_died(enemy)
@warning_ignore("unused_signal")
signal enemy_damaged(enemy, amount)
@warning_ignore("unused_signal")
signal enemy_spotted_player(enemy, target)
@warning_ignore("unused_signal")
signal enemy_attack_started(enemy)
@warning_ignore("unused_signal")
signal enemy_attack_landed(enemy, target)

# Game state signals
@warning_ignore("unused_signal")
signal game_started()
@warning_ignore("unused_signal")
signal game_paused(is_paused)
@warning_ignore("unused_signal")
signal game_over(win)
@warning_ignore("unused_signal")
signal level_started(level_name)
@warning_ignore("unused_signal")
signal level_completed(level_name)

# Pickup signals
@warning_ignore("unused_signal")
signal item_collected(item_type, amount) 