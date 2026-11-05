extends Node
## Autoload "Net": transport layer over Godot's high-level MultiplayerAPI + ENet (UDP).
## - host(): listen server (the host also plays)            - join(): connect by ROOM CODE or ip[:port]
## - start_dedicated(): headless authoritative server, no local player (run with `-- server`)
## Gameplay never touches the peer directly; Match/Lobby only use RPCs, so swapping ENet for WebSocket/WebRTC
## or a hosted relay later only changes this file.
##
## ROOM CODE = the host's LAN IPv4 + port packed into 8 characters (no lookup server needed on a local network).

signal connected
signal connection_failed(reason: String)
signal disconnected
signal peer_joined(id: int)
signal peer_left(id: int)

const DEFAULT_PORT := 24680
const MAX_CLIENTS := 6
const CODE_ALPHABET := "ABCDEFGHJKLMNPQRSTUVWXYZ23456789"   # 32 symbols, no 0/O/1/I

var dedicated := false
var room_code := ""
var host_address := ""


func _ready() -> void:
	multiplayer.peer_connected.connect(func(id): peer_joined.emit(id))
	multiplayer.peer_disconnected.connect(func(id): peer_left.emit(id))
	multiplayer.connected_to_server.connect(func(): connected.emit())
	multiplayer.connection_failed.connect(func(): _reset(); connection_failed.emit("Could not reach the host"))
	multiplayer.server_disconnected.connect(func(): _reset(); disconnected.emit())


func is_online() -> bool:
	return multiplayer.multiplayer_peer != null and not (multiplayer.multiplayer_peer is OfflineMultiplayerPeer) \
		and multiplayer.multiplayer_peer.get_connection_status() != MultiplayerPeer.CONNECTION_DISCONNECTED


func is_server() -> bool:
	return multiplayer.is_server()


func my_id() -> int:
	return multiplayer.get_unique_id()


func host(port := DEFAULT_PORT) -> Error:
	close()
	var peer := ENetMultiplayerPeer.new()
	var err := peer.create_server(port, MAX_CLIENTS)
	if err != OK:
		return err
	peer.host.compress(ENetConnection.COMPRESS_RANGE_CODER)
	multiplayer.multiplayer_peer = peer
	host_address = lan_ip()
	room_code = encode_code(host_address, port)
	return OK


func join(code_or_address: String) -> Error:
	close()
	var target := decode_code(code_or_address)
	if target.is_empty():
		return ERR_INVALID_PARAMETER
	var peer := ENetMultiplayerPeer.new()
	var err := peer.create_client(target.ip, target.port)
	if err != OK:
		return err
	peer.host.compress(ENetConnection.COMPRESS_RANGE_CODER)
	multiplayer.multiplayer_peer = peer
	host_address = target.ip
	room_code = code_or_address.to_upper() if target.from_code else ""
	return OK


## INTERNET: connect to an online dedicated server over WebSocket (works through HTTPS hosting / proxies).
## url examples: "wss://rift-arena.onrender.com", "ws://127.0.0.1:24681"
func join_online(url: String) -> Error:
	close()
	url = url.strip_edges()
	if not (url.begins_with("ws://") or url.begins_with("wss://")):
		url = "wss://" + url
	var peer := WebSocketMultiplayerPeer.new()
	peer.handshake_timeout = 60.0   # free hosting tiers can take ~a minute to wake up
	var err := peer.create_client(url)
	if err != OK:
		return err
	multiplayer.multiplayer_peer = peer
	host_address = url
	room_code = "ONLINE"
	return OK


## Dedicated server. transport "enet" (LAN, UDP) or "ws" (internet, WebSocket behind a hosting proxy).
## The port comes from $PORT when the hosting platform provides one.
func start_dedicated(port := DEFAULT_PORT, transport := "enet") -> void:
	dedicated = true
	Engine.physics_ticks_per_second = 30   # cheaper simulation on small cloud instances (all logic is dt-based)
	Engine.max_fps = 30
	var env_port := OS.get_environment("PORT")
	if env_port.is_valid_int():
		port = int(env_port)
	var err := OK
	if transport == "ws":
		close()
		var peer := WebSocketMultiplayerPeer.new()
		err = peer.create_server(port, "*")
		if err == OK:
			multiplayer.multiplayer_peer = peer
			host_address = "0.0.0.0"
			room_code = "ONLINE"
	else:
		err = host(port)
	if err != OK:
		push_error("Dedicated server failed to start: %s" % error_string(err))
		get_tree().quit(1)
		return
	print("[RIFT ARENA] dedicated %s server on port %d  ROOM CODE: %s" % [transport, port, room_code])
	Lobby.open_room(false)


func close() -> void:
	if multiplayer.multiplayer_peer and not (multiplayer.multiplayer_peer is OfflineMultiplayerPeer):
		multiplayer.multiplayer_peer.close()
	_reset()


func _reset() -> void:
	multiplayer.multiplayer_peer = OfflineMultiplayerPeer.new()
	room_code = ""


## Best LAN address of this device (prefers private ranges).
func lan_ip() -> String:
	var best := "127.0.0.1"
	for a in IP.get_local_addresses():
		if a.count(".") != 3 or a.begins_with("127.") or a.begins_with("169.254."):
			continue
		if a.begins_with("192.168.") or a.begins_with("10.") or a.begins_with("172."):
			return a
		best = a
	return best


static func encode_code(ip: String, port: int) -> String:
	var parts := ip.split(".")
	if parts.size() != 4:
		return ""
	var v := 0
	for p in parts:
		v = (v << 8) | (int(p) & 255)
	v = (v << 8) | ((port - DEFAULT_PORT) & 255)   # 40 bits = 8 base-32 symbols
	var s := ""
	for i in 8:
		s = CODE_ALPHABET[v & 31] + s
		v >>= 5
	return s


## Accepts an 8-char room code or "ip" / "ip:port". Returns {ip, port, from_code} or {}.
static func decode_code(text: String) -> Dictionary:
	text = text.strip_edges()
	if text.count(".") == 3:
		var port := DEFAULT_PORT
		var ip := text
		if text.contains(":"):
			ip = text.get_slice(":", 0)
			port = int(text.get_slice(":", 1))
		return {"ip": ip, "port": port, "from_code": false}
	var code := text.to_upper().replace(" ", "").replace("-", "")
	if code.length() != 8:
		return {}
	var v := 0
	for c in code:
		var idx := CODE_ALPHABET.find(c)
		if idx < 0:
			return {}
		v = (v << 5) | idx
	var port_off := v & 255
	v >>= 8
	var ip := "%d.%d.%d.%d" % [(v >> 24) & 255, (v >> 16) & 255, (v >> 8) & 255, v & 255]
	return {"ip": ip, "port": DEFAULT_PORT + port_off, "from_code": true}
