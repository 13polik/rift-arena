class_name AbilityData
extends Resource
## One attack / ability / super. The `kind` picks the behaviour in AbilityRunner; every number is tunable here.

enum Kind { PROJECTILE, MELEE, BLINK, CHARGE, ZONE, BLAST_PROJECTILE, SHOCKWAVE }

@export var display_name := "ABILITY"
@export var kind: Kind = Kind.PROJECTILE
@export_group("Core")
@export var damage := 100.0
@export var cooldown := 0.5
@export var range := 8.0                ## projectile travel / melee reach / blink distance / charge distance
@export var windup := 0.0               ## delay before the effect lands (telegraph)
@export var knockback := 0.6
@export_group("Projectile")
@export var projectile_speed := 20.0
@export var projectile_radius := 0.2
@export var count := 1                  ## projectiles per volley
@export var spread_deg := 0.0
@export var burst_count := 1            ## volleys per trigger (Volt fires a quick series)
@export var burst_interval := 0.07
@export var homing_turn_rate := 0.0     ## rad/s, 0 = straight
@export var homing_acquire_range := 6.0
@export var blast_radius := 0.0         ## >0: explodes on impact / at max range
@export_group("Melee")
@export var arc_deg := 100.0
@export_group("Charge / Blink")
@export var duration := 0.3
@export_group("Zone")
@export var cast_range := 0.0           ## max distance from the caster where the zone can be placed
@export var zone_effect: StringName = &"slow"   ## slow | heal
@export var zone_radius := 2.5
@export var magnitude := 0.5            ## slow fraction or heal per second
@export var dps := 0.0
@export_group("Shockwave")
@export var slow_factor := 0.5
@export var slow_duration := 1.5
@export_group("Super")
@export var charge_required := 2500.0   ## damage that must be dealt to fill the super meter
@export_group("Presentation")
@export var vfx: StringName = &""
@export var sfx: StringName = &""
@export var anim: StringName = &"attack"
@export var shake := 0.0                ## camera trauma when this lands near the local player
