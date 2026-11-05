extends Node
# Renders every menu screen to user://shots/ui_<name>.png
func _ready() -> void:
	var main: Node = load("res://scenes/main.tscn").instantiate()
	main.set_script(null)
	main.name = "Main"
	get_tree().root.add_child.call_deferred(main)
	await get_tree().process_frame
	GameManager.register_main(main)
	for n in ["home_screen", "play_screen", "characters_screen", "shop_screen", "settings_screen", "results_screen"]:
		var setup := {}
		if n == "results_screen":
			setup = {"my_team": 0, "result": {"winner": 0, "reason": "score", "score": [14, 9], "players": [
				{"id": 1, "name": "You", "team": 0, "hero": "volt", "bot": false, "kills": 6, "deaths": 2, "delivered": 7, "damage": 14200, "healing": 0},
				{"id": -1, "name": "BOT Rook", "team": 0, "hero": "brute", "bot": true, "kills": 3, "deaths": 4, "delivered": 4, "damage": 9100, "healing": 0},
				{"id": -2, "name": "BOT Tess", "team": 0, "hero": "nyx", "bot": true, "kills": 1, "deaths": 2, "delivered": 3, "damage": 6800, "healing": 9300},
				{"id": -3, "name": "BOT Jinx", "team": 1, "hero": "nyx", "bot": true, "kills": 2, "deaths": 5, "delivered": 4, "damage": 7100, "healing": 6100},
				{"id": -4, "name": "BOT Pike", "team": 1, "hero": "volt", "bot": true, "kills": 4, "deaths": 3, "delivered": 2, "damage": 11800, "healing": 0},
				{"id": -5, "name": "BOT Zed", "team": 1, "hero": "brute", "bot": true, "kills": 2, "deaths": 4, "delivered": 3, "damage": 8000, "healing": 0}]}}
		GameManager.show_screen("res://ui/%s.tscn" % n, setup)
		for i in 45:
			await get_tree().process_frame
		get_viewport().get_texture().get_image().save_png("user://shots/ui_%s.png" % n)
	print("UI_SHOTS_OK")
	get_tree().quit()
