class_name FractureYardLayout
extends RefCounted
## Map "Fracture Yard" - a rift-scarred freight yard. Pure data so level design changes never touch code.
## Arena: x in [-19, 19] (Blue base left, Red base right), z in [-12, 12].
## LEFT_* lists describe Blue's half; they are mirrored with point symmetry (x,z) -> (-x,-z) for Red,
## so both teams get exactly the same map. Units = meters.
##
##  Lanes: TOP (z ~ -8.6), MID (z ~ 0, through the Rift Core), BOTTOM (z ~ +8.6).

const HALF_W := 19.0
const HALF_D := 12.0
const CORE := Vector3(0, 0, 0)
const CORE_RADIUS := 1.25
const UPLINK := Vector2(-15.6, 0.0)   # Blue scoring zone (Red is mirrored)
const UPLINK_RADIUS := 2.5
const SPAWNS := [Vector2(-17.6, -2.0), Vector2(-17.6, 0.0), Vector2(-17.6, 2.0)]

## Tall walls: [x, z, width(x), depth(z), height]. Block movement + projectiles.
const LEFT_WALLS := [
	[-13.0, -4.7, 1.0, 3.4, 1.7],   # base cover north
	[-13.0, 4.7, 1.0, 3.4, 1.7],    # base cover south
	[-8.6, -5.3, 5.2, 1.0, 1.5],    # lane divider north
	[-8.6, 5.3, 5.2, 1.0, 1.5],     # lane divider south
	[-5.2, 0.0, 1.0, 3.4, 1.6],     # mid shield
	[-3.6, -9.3, 3.4, 1.0, 1.5],    # top lane chicane
	[-12.0, 9.7, 1.0, 2.6, 1.5],    # bottom lane base wall
	[-2.3, 6.1, 1.0, 2.6, 1.6],     # bottom approach
]

## Cargo crates: [x, z, style(0 orange, 1 teal)]. 1.1 m cubes, block movement + projectiles.
const LEFT_CRATES := [
	[-10.4, -8.7, 0], [-9.3, -8.7, 1], [-10.4, -9.8, 1],
	[-3.7, 3.1, 0], [-3.7, 4.2, 0],
	[-15.6, -7.6, 1], [-16.7, -7.6, 0],
	[-7.0, 9.6, 1],
	[-1.4, -3.7, 0],
	[-10.5, 1.6, 1],
]

## Tall rift-grass: [x, z, width, depth]. Hides heroes from enemies.
const LEFT_BUSHES := [
	[-6.2, -8.6, 3.0, 2.2],
	[-6.9, 2.6, 2.4, 2.4],
	[-15.8, 9.4, 3.2, 2.2],
	[-1.4, -7.1, 2.4, 1.8],
	[-10.6, -1.4, 2.0, 2.2],
]

## Street lamps (decor + light): [x, z]. Along the arena rim.
const LEFT_LAMPS := [[-14.5, -11.6], [-7.5, -11.6], [-0.5, -11.6], [-18.6, 6.5]]

## Barrels / small props (no collision): [x, z, kind]
const LEFT_DECOR := [[-12.2, -6.8, 0], [-12.4, 6.9, 0], [-17.9, -9.8, 1], [-6.0, -6.3, 1], [-4.4, 8.5, 0]]

## Buildings outside the arena: [x, z, width, depth, height, style]
const LEFT_BUILDINGS := [
	[-15.0, -15.2, 7.0, 5.0, 6.0, 0],
	[-7.0, -15.6, 6.5, 6.0, 9.0, 1],
	[0.5, -15.0, 5.5, 4.6, 5.0, 0],
	[-23.5, -6.0, 6.0, 9.0, 7.5, 2],
	[-23.5, 6.0, 6.0, 9.0, 5.0, 1],
]


static func mirror(v: Array) -> Array:
	var m := v.duplicate()
	m[0] = -v[0]
	m[1] = -v[1]
	return m


static func both(list: Array) -> Array:
	var out := []
	for e in list:
		out.append(e)
		out.append(mirror(e))
	return out
