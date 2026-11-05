class_name Skins
extends RefCounted
## Cosmetic skins (palette swaps) sold in the SHOP for Rift Coins earned by playing. Progression is saved locally.

const CATALOG := {
	&"volt": [
		{"name": "Default", "price": 0},
		{"name": "Solar Flare", "price": 150, "primary": Color("ff7a2b"), "accent": Color("fff36b"), "secondary": Color("3a1d12")},
		{"name": "Ghost Circuit", "price": 300, "primary": Color("e8f2ff"), "accent": Color("6ff6ff"), "secondary": Color("1b2a4a")},
	],
	&"brute": [
		{"name": "Default", "price": 0},
		{"name": "Glacier Forge", "price": 150, "primary": Color("5fd0ff"), "accent": Color("e8fbff"), "secondary": Color("1c2c44")},
		{"name": "Toxic Boiler", "price": 300, "primary": Color("9cff3a"), "accent": Color("f6ff6b"), "secondary": Color("2a3320")},
	],
	&"nyx": [
		{"name": "Default", "price": 0},
		{"name": "Rose Signal", "price": 150, "primary": Color("ff5ab8"), "accent": Color("ffd23f"), "secondary": Color("2b1028")},
		{"name": "Deep Abyss", "price": 300, "primary": Color("2f6bff"), "accent": Color("ff6bd5"), "secondary": Color("0b1030")},
	],
}


## Returns HeroData with the skin palette applied (a copy - the shared resource is never modified).
static func apply(base: HeroData, hero: StringName, skin: int) -> HeroData:
	var list: Array = CATALOG.get(hero, [])
	if skin <= 0 or skin >= list.size():
		return base
	var s: Dictionary = list[skin]
	var d: HeroData = base.duplicate()
	d.primary_color = s.primary
	d.accent_color = s.accent
	d.secondary_color = s.secondary
	return d


static func owned(hero: StringName, skin: int) -> bool:
	return skin == 0 or Settings.owned_skins.has("%s:%d" % [hero, skin])


static func buy(hero: StringName, skin: int) -> bool:
	var price: int = CATALOG[hero][skin].price
	if owned(hero, skin) or Settings.coins < price:
		return false
	Settings.coins -= price
	Settings.owned_skins.append("%s:%d" % [hero, skin])
	Settings.save()
	return true


## Reward after each match (called by the results screen once).
static func reward(won: bool, draw: bool, delivered: int, kills: int) -> int:
	var c := (40 if won else (25 if draw else 15)) + delivered * 3 + kills * 2
	Settings.coins += c
	Settings.matches_played += 1
	if won:
		Settings.wins += 1
	Settings.save()
	return c
