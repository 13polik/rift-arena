class_name Health
extends RefCounted
## HP rules: damage, healing, out-of-combat regeneration. Pure functions over Hero state.

static func apply_damage(target: Hero, amount: float, now: float) -> float:
	if not target.alive or target.is_protected(now):
		return 0.0
	var dealt := minf(target.hp, roundf(amount))
	target.hp -= dealt
	target.last_damaged_at = now
	return dealt


static func apply_heal(target: Hero, amount: float) -> float:
	if not target.alive:
		return 0.0
	var healed := minf(target.data.max_hp - target.hp, amount)
	target.hp += healed
	return healed


## Regenerates after `regen_delay` seconds without taking damage.
static func regen(h: Hero, dt: float, now: float) -> void:
	if h.alive and h.hp < h.data.max_hp and now - h.last_damaged_at >= h.data.regen_delay:
		h.hp = minf(h.data.max_hp, h.hp + h.data.max_hp * h.data.regen_percent_per_sec * dt)
