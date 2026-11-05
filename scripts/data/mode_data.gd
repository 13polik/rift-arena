class_name ModeData
extends Resource
## RIFT CORE rules. The core pulses energy shards; carry them home and channel them into your Uplink.

@export var display_name := "RIFT CORE"
@export var duration := 210.0
@export var countdown := 3.0
@export var win_score := 14
@export var pulse_interval := 7.0
@export var first_pulse_at := 3.0
@export var shards_per_pulse := 2
@export var surge_after := 120.0
@export var surge_shards_per_pulse := 3
@export var max_shards_on_field := 14
@export var shard_scatter_min := 1.8
@export var shard_scatter_max := 4.2
@export var shard_lifetime := 25.0
@export var pickup_radius := 1.0
@export var max_carry := 8
@export var deposit_interval := 0.3
@export var reveal_carry := 4            ## carrying this many makes you glow (bushes can't hide you)
@export var respawn_time := 4.0
@export var spawn_protection := 1.5
@export var max_players_per_team := 3
@export var bush_reveal_distance := 2.8
@export var reveal_after_attack := 1.1
@export var reveal_after_damage := 0.8
