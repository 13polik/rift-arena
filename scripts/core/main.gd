extends Node
## Root of scenes/main.tscn. Hosts the UI layer and the running Match.
## Command line (after `--`):  practice=<hero>  -> jump straight into a 3v3 bot match (dev / testing)
##                             server         -> headless dedicated LAN server (ENet)
##                             server ws      -> headless dedicated INTERNET server (WebSocket, port from $PORT)

func _ready() -> void:
	GameManager.register_main(self)
	var args := OS.get_cmdline_user_args()
	for a in args:
		if a.begins_with("practice="):
			GameManager.start_practice(StringName(a.get_slice("=", 1)))
			return
		if a == "server":
			Net.start_dedicated(Net.DEFAULT_PORT, "ws" if "ws" in args else "enet")
			return
	GameManager.go_home()
