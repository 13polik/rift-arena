class_name Prof
extends RefCounted
## Tiny manual profiler for dev builds: Prof.begin("x") ... Prof.end("x"); Prof.report() prints avg ms per frame.
static var _t := {}
static var _acc := {}
static var enabled := false

static func begin(k: String) -> void:
	if enabled: _t[k] = Time.get_ticks_usec()

static func end(k: String) -> void:
	if enabled and _t.has(k): _acc[k] = _acc.get(k, 0) + Time.get_ticks_usec() - _t[k]

static func report(frames: int) -> String:
	var out := []
	for k in _acc:
		out.append("%s=%.2fms" % [k, _acc[k] / 1000.0 / maxf(frames, 1)])
	_acc.clear()
	return " ".join(out)
