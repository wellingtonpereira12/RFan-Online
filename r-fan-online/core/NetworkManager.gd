extends Node

var socket = WebSocketPeer.new()
var is_connected_to_server = false
var server_url = "ws://localhost:8080"

signal map_changed(new_map_id)
signal players_synced(player_list)

var maps_data = {}
var other_players = {} # id -> node
var other_player_scene = preload("res://entities/player/OtherPlayer.tscn")
var dropped_items = {} # uid -> node
var other_mobs = {} # uid -> node

func _ready():
	_load_maps_data()
	connect_to_server()

func _load_maps_data():
	var path = "res://database/maps.json"
	if FileAccess.file_exists(path):
		var file = FileAccess.open(path, FileAccess.READ)
		maps_data = JSON.parse_string(file.get_as_text())

func connect_to_server():
	print("[Network] Conectando ao servidor: ", server_url)
	socket.connect_to_url(server_url)

func _process(_delta):
	socket.poll()
	var state = socket.get_ready_state()
	
	if state == WebSocketPeer.STATE_OPEN:
		if not is_connected_to_server:
			is_connected_to_server = true
			print("[Network] Conectado!")
			login()
		
		while socket.get_available_packet_count() > 0:
			_on_data_received(socket.get_packet().get_string_from_utf8())
			
	elif state == WebSocketPeer.STATE_CLOSED:
		if is_connected_to_server:
			is_connected_to_server = false
			print("[Network] Conexão perdida.")

func login():
	send_data({
		"type": "login",
		"name": GameManager.player_name
	})

func send_move(input_dir: Vector3, delta: float, is_running: bool = false):
	if is_connected_to_server:
		send_data({
			"type": "move",
			"input_dir": {"x": input_dir.x, "z": input_dir.z},
			"delta": delta,
			"is_running": is_running
		})

func send_speed_sync():
	if is_connected_to_server:
		send_data({
			"type": "request_speed",
			"value": MovementSpeedManager.get_speed()
		})

func send_data(data: Dictionary):
	var json_str = JSON.stringify(data)
	socket.send_text(json_str)

func _on_data_received(json_str: String):
	var data = JSON.parse_string(json_str)
	if not data: return
	
	match data.type:
		"welcome", "pos_update", "map_change":
			var player = get_tree().get_first_node_in_group("players")
			if player:
				player.global_position.x = data.pos.x
				player.global_position.z = data.pos.z
				
				if data.type == "map_change" or data.type == "welcome":
					GameManager.current_map_id = data.map_id
					if maps_data.has(data.map_id):
						GameManager.current_map_name = maps_data[data.map_id]["nome"]
					_clear_all_dropped_items()
					_clear_all_mobs()
					map_changed.emit(data.map_id)
		
		"map_sync":
			_sync_other_players(data.players)
			if data.has("items"):
				_sync_items(data.items)
			if data.has("mobs"):
				_sync_mobs(data.mobs)
		
		"mob_spawn":
			_handle_mob_spawn(data.mob)
		
		"mob_remove":
			_handle_mob_remove(int(data.uid))
		
		"entity_damage":
			_handle_entity_damage(data)
		
		"item_drop":
			_handle_item_drop(data.item)
			
		"item_remove":
			_handle_item_remove(int(data.uid))
		
		"pickup_success":
			_handle_pickup_success(data.item)

func _sync_other_players(player_list: Array):
	var current_ids = []
	for p_data in player_list:
		var id = p_data.id
		if id == GameManager.player_name: continue
		
		current_ids.append(id)
		
		if not other_players.has(id):
			var new_p = other_player_scene.instantiate()
			get_tree().root.add_child(new_p)
			new_p.setup(id, p_data.name)
			other_players[id] = new_p
		
		var pos = Vector3(p_data.pos.x, 0, p_data.pos.z)
		other_players[id].update_position(pos)
	
	var ids_to_remove = []
	for id in other_players.keys():
		if not id in current_ids:
			ids_to_remove.append(id)
	
	for id in ids_to_remove:
		other_players[id].queue_free()
		other_players.erase(id)

func _sync_items(item_list: Array):
	var server_uids = []
	for i_data in item_list:
		var uid = int(i_data.uid)
		server_uids.append(uid)
		if not dropped_items.has(uid):
			_handle_item_drop(i_data)
	
	var to_remove = []
	for uid in dropped_items.keys():
		if not uid in server_uids:
			to_remove.append(uid)
	
	for uid in to_remove:
		_handle_item_remove(uid)

func _handle_item_drop(item_data: Dictionary):
	var uid = int(item_data.uid)
	if dropped_items.has(uid): return
	
	var item_scene = preload("res://entities/items/DroppedItem.tscn")
	var new_item = item_scene.instantiate()
	get_tree().root.add_child(new_item)
	
	var pos = Vector3(item_data.pos.x, item_data.pos.y, item_data.pos.z)
	new_item.global_position = pos
	
	new_item.set_meta("item_uid", item_data.uid)
	new_item.set_meta("item_id", item_data.item_id)
	new_item.set_meta("item_amount", item_data.amount)
	
	if new_item.has_method("setup_from_id"):
		new_item.setup_from_id(item_data.item_id)
		
	dropped_items[uid] = new_item

func _handle_item_remove(uid: int):
	if dropped_items.has(uid):
		dropped_items[uid].queue_free()
		dropped_items.erase(uid)

func _handle_pickup_success(item_data: Dictionary):
	var inv_ui = get_tree().get_first_node_in_group("inventory_ui")
	if inv_ui and inv_ui.inventory_manager:
		inv_ui.inventory_manager.add_item(item_data.item_id, item_data.amount)

func _clear_all_dropped_items():
	for uid in dropped_items.keys():
		if is_instance_valid(dropped_items[uid]):
			dropped_items[uid].queue_free()
	dropped_items.clear()

func _sync_mobs(mob_list: Array):
	var server_uids = []
	for m_data in mob_list:
		var uid = int(m_data.uid)
		server_uids.append(uid)
		if not other_mobs.has(uid):
			_handle_mob_spawn(m_data)
		else:
			# Atualiza posição (opcional se mobs se moverem no servidor)
			var pos = Vector3(m_data.pos.x, m_data.pos.y, m_data.pos.z)
			other_mobs[uid].global_position = pos
	
	var to_remove = []
	for uid in other_mobs.keys():
		if not uid in server_uids:
			to_remove.append(uid)
	
	for uid in to_remove:
		if is_instance_valid(other_mobs[uid]):
			other_mobs[uid].queue_free()
		other_mobs.erase(uid)

func _handle_mob_spawn(mob_data: Dictionary):
	var uid = int(mob_data.uid)
	if other_mobs.has(uid): return
	
	var mob_scene = preload("res://entities/enemies/AdvancedMob.tscn")
	var new_mob = mob_scene.instantiate()
	get_tree().root.add_child(new_mob)
	
	var pos = Vector3(mob_data.pos.x, mob_data.pos.y, mob_data.pos.z)
	new_mob.global_position = pos
	new_mob.set_meta("mob_uid", uid)
	
	# Setup estatísticas do MobDatabase
	if new_mob.has_method("setup_from_db"):
		new_mob.setup_from_db(mob_data.mob_id)
	
	other_mobs[uid] = new_mob
	print("[Network] Novo mob visível: ", mob_data.mob_id, " (UID: ", uid, ")")

func _clear_all_mobs():
	for uid in other_mobs.keys():
		if is_instance_valid(other_mobs[uid]):
			other_mobs[uid].queue_free()
	other_mobs.clear()

func _handle_mob_remove(uid: int):
	if other_mobs.has(uid):
		var mob_node = other_mobs[uid]
		if is_instance_valid(mob_node):
			mob_node.queue_free()
		other_mobs.erase(uid)
		print("[Network] Mob removido do mapa: ", uid)

func _handle_entity_damage(data: Dictionary):
	var victim_uid = data.victim_uid
	var victim_type = data.victim_type
	var damage = int(data.damage)
	var attacker_id = data.attacker_id
	
	var victim_node = null
	
	if victim_type == "mob":
		var uid = int(victim_uid)
		if other_mobs.has(uid):
			victim_node = other_mobs[uid]
	else:
		# Player victim
		if victim_uid == GameManager.player_name:
			# Sou eu! Mas o dano já foi aplicado localmente ou será aplicado pelo server?
			# No Godot, dano sofrido por mobs já é local.
			# Aqui evitamos aplicar de novo se formos nós.
			return
		elif other_players.has(victim_uid):
			victim_node = other_players[victim_uid]
	
	if is_instance_valid(victim_node):
		# Mostra o dano visualmente (se houver componente de vida)
		var vitals = victim_node.get_node_or_null("VitalsComponent")
		if not vitals: vitals = victim_node.get_node_or_null("HealthComponent")
		
		if vitals:
			# Aplica o dano para sincronizar as barrinhas de HP
			vitals.take_damage(damage)
			print("[Network] Dano Sincronizado: ", attacker_id, " causou ", damage, " em ", victim_node.name)
