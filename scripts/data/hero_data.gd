class_name HeroData
extends Resource
## Balance + presentation data for one hero. Edit resources/heroes/*.tres to rebalance without touching code.

@export var id: StringName = &"volt"
@export var display_name := "VOLT"
@export var role := "Ranged damage"
@export var weapon := "Energy blaster"
@export_multiline var description := ""
@export_group("Stats")
@export var max_hp := 3200
@export var move_speed := 5.4
@export var radius := 0.5
@export var regen_delay := 3.0
@export var regen_percent_per_sec := 0.12
@export var super_passive_per_sec := 0.01
@export_group("Kit")
@export var attack: AbilityData
@export var ability: AbilityData
@export var super_ability: AbilityData
@export_group("Look")
@export var primary_color := Color("35d4ff")
@export var secondary_color := Color("1d2a5c")
@export var accent_color := Color("fff36b")
@export var skin_color := Color("f2d3b5")
@export var model_scale := 1.0
@export var sfx_footstep: StringName = &"step_light"


func slot(name: StringName) -> AbilityData:
	match name:
		&"attack": return attack
		&"ability": return ability
		&"super": return super_ability
	return null
