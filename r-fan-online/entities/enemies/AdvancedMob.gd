extends CharacterBody3D
class_name AdvancedMob

# --- ENUM DE ESTADOS DA IA ---
enum State { IDLE, PATROL, CHASE, ATTACK, FLEE, RETURN }
var current_state: State = State.IDLE

# --- DADOS DO MOBDATABASE ---
var mob_key: String = ""
var mob_data: Dictionary = {}

# --- COMPONENTES ---
@onready var nav_agent: NavigationAgent3D = null # Se tiver NavMesh
@onready var name_tag: Label3D = $NameTag
var vitals: VitalsComponent = null

# --- CONFIGURACOES DE IA ---
var origin_position: Vector3 = Vector3.ZERO
var current_target: Node3D = null

var sight_radius: float = 15.0
var attack_range: float = 2.5
var patrol_radius: float = 10.0
var flee_health_threshold: float = 0.2 # Foge se HP < 20%

var move_speed: float = 3.0
var attack_damage: int = 10
var attack_cooldown: float = 1.5
var current_cooldown: float = 0.0

var patrol_timer: float = 0.0
var movement_timer: float = 0.0

signal died

func _ready() -> void:
	add_to_group("enemies")
	origin_position = global_position
	
	# Verifica se ha NavigationAgent, se nao tiver, criamos um basico
	nav_agent = get_node_or_null("NavigationAgent3D")
	if not nav_agent:
		nav_agent = NavigationAgent3D.new()
		add_child(nav_agent)
		
	# Instancia Componente de Vida se nao existir
	vitals = get_node_or_null("VitalsComponent")
	if not vitals:
		vitals = VitalsComponent.new()
		vitals.name = "VitalsComponent"
		add_child(vitals)
		
	vitals.died.connect(_on_death)
	vitals.damaged.connect(_on_damaged)

# Inicializado pelo Spawner
func setup_from_db(key: String) -> void:
	mob_key = key
	mob_data = MobDatabase.get_mob(key)
	
	if mob_data.is_empty():
		queue_free()
		return
		
	# Define a origem baseada na posicao atual (onde ele spawnou no mapa)
	origin_position = global_position
	
	name = mob_data["nome"]
	if name_tag:
		name_tag.text = mob_data["nome"]
		
		# Muda a cor baseada no tipo
		if mob_data["tipo"] == "boss":
			name_tag.modulate = Color(1.0, 0.2, 1.0) # Roxo/Rosa para Boss
		elif mob_data["tipo"] == "elite":
			name_tag.modulate = Color(1.0, 0.6, 0.0) # Laranja para Elite
		else:
			name_tag.modulate = Color(1.0, 1.0, 1.0) # Branco normal
			
	move_speed = mob_data["velocidade"]
	attack_damage = mob_data["ataque"]
	
	if vitals:
		vitals.max_hp = mob_data["hp"]
		vitals.hp = vitals.max_hp
		
	current_state = State.IDLE
	_load_visual_model(key)
	_change_state(State.PATROL)
	print("[Mob] Spawnado: ", name, " (", mob_key, ")")

func _force_show_all(node: Node) -> void:
	if node is GeometryInstance3D:
		var gi = node as GeometryInstance3D
		gi.visible = true
		gi.layers = 1  # Garante que esta na layer 1 (camera padrao)
		gi.visibility_range_begin = 0.0
		gi.visibility_range_end = 0.0  # 0 = sem limite
		gi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	elif node is VisualInstance3D:
		(node as VisualInstance3D).visible = true
		(node as VisualInstance3D).layers = 1
	for child in node.get_children():
		_force_show_all(child)

var _models: Dictionary = {}
var _anim_players: Dictionary = {}
var _current_model: Node = null

func _load_visual_model(key: String) -> void:
	var default_path: String = mob_data.get("visual_path", "").strip_edges()
	if default_path == "":
		var visual_key: String = mob_data.get("visual_id", key)
		var model_dir: String = "res://assets/models/mobs/" + visual_key + "/"
		var candidate_paths: Array[String] = [
			model_dir + visual_key + ".tscn",
			model_dir + visual_key + ".glb",
		]
		for path in candidate_paths:
			if ResourceLoader.exists(path):
				default_path = path
				break
	
	if default_path == "":
		print("[Mob Debug] AVISO: Nenhum modelo encontrado para '", key, "'. Usando capsula de fallback.")
		return
	
	# Carrega os modelos baseados no estado. Se não houver específico, usa o padrão.
	_load_and_add_model("idle", mob_data.get("visual_path_idle", default_path))
	_load_and_add_model("walk", mob_data.get("visual_path_walk", default_path))
	_load_and_add_model("attack", mob_data.get("visual_path_attack", default_path))
	_load_and_add_model("die", mob_data.get("visual_path_die", default_path))
	
	# Oculta cápsula de fallback
	var old_mesh = get_node_or_null("MeshInstance3D")
	if old_mesh:
		old_mesh.visible = false
	
	call_deferred("_setup_animations_deferred")

func _load_and_add_model(state_key: String, path: String) -> void:
	if path == "": return
	
	# Se já instanciamos este mesmo caminho, apenas reaproveitamos a referência (evita carregar 4x o mesmo GLB)
	var existing_model = null
	for k in _models.keys():
		if _models[k].has_meta("model_path") and _models[k].get_meta("model_path") == path:
			existing_model = _models[k]
			break
			
	if existing_model:
		_models[state_key] = existing_model
		return
		
	var model_res = load(path)
	if not model_res:
		print("[Mob Debug] Falha ao carregar Resource: ", path)
		return
		
	var model_instance: Node = null
	if model_res is PackedScene:
		model_instance = model_res.instantiate()
	else:
		var gltf = GLTFDocument.new()
		var state = GLTFState.new()
		if gltf.append_from_file(path, state) == OK:
			model_instance = gltf.generate_scene(state)
			
	if model_instance:
		add_child(model_instance)
		_force_show_all(model_instance)
		model_instance.visible = false # Oculta por padrão até ser chamado
		model_instance.set_meta("model_path", path)
		
		var s: float = float(mob_data.get("escala", 1.0))
		model_instance.scale = Vector3(s, s, s)
		model_instance.rotation_degrees.x = float(mob_data.get("visual_rotation_x", 0.0))
		model_instance.rotation_degrees.y = float(mob_data.get("visual_rotation_y", 0.0))
		model_instance.rotation_degrees.z = float(mob_data.get("visual_rotation_z", 0.0))
		model_instance.position.y = float(mob_data.get("visual_offset_y", 0.0))
		
		_models[state_key] = model_instance
		print("[Mob Debug] Carregado modelo para estado '", state_key, "': ", path)

func _setup_animations_deferred() -> void:
	for state_key in _models:
		var model = _models[state_key]
		if not _anim_players.has(model):
			var player = _find_animation_player_deep(model)
			if player:
				_anim_players[model] = player
				print("[Mob Debug] AnimPlayer para '", state_key, "': ", player.get_animation_list())
			else:
				print("[Mob Debug] AVISO: Nenhum AnimationPlayer para '", state_key, "'")
				
	_play_anim("idle")

func _find_animation_player_deep(node: Node) -> AnimationPlayer:
	var queue: Array = [node]
	while queue.size() > 0:
		var current = queue.pop_front()
		if current is AnimationPlayer:
			return current
		for child in current.get_children():
			queue.append(child)
	return null

func _list_children_recursive(node: Node) -> Array:
	var result = [node.name + " (" + node.get_class() + ")"]
	for child in node.get_children():
		result.append_array(_list_children_recursive(child))
	return result

func _find_all_meshes(node: Node, list: Array) -> void:
	if node is MeshInstance3D or node is ImporterMeshInstance3D:
		list.append(node)
	for child in node.get_children():
		_find_all_meshes(child, list)

func _find_mesh(node: Node) -> MeshInstance3D:
	if node is MeshInstance3D:
		return node
	for child in node.get_children():
		var found = _find_mesh(child)
		if found:
			return found
	return null

func _play_anim(anim_name: String) -> void:
	var target_model = _models.get(anim_name)
	if not target_model:
		target_model = _models.get("idle") # Fallback
		
	if not target_model: return
	
	# Troca o modelo visível
	if _current_model and _current_model != target_model:
		_current_model.visible = false
	target_model.visible = true
	_current_model = target_model
	
	var player: AnimationPlayer = _anim_players.get(target_model)
	if not player: return
	
	var list = player.get_animation_list()
	if list.size() == 0: return
	
	var actual_anim = ""
	
	var custom_key = "anim_" + anim_name
	if mob_data.has(custom_key) and mob_data[custom_key] != "":
		var target: String = mob_data[custom_key]
		if player.has_animation(target):
			actual_anim = target
		else:
			var target_up = target.to_upper()
			for a in list:
				if a.to_upper() == target_up or a.to_upper().ends_with("/" + target_up):
					actual_anim = a
					break
	
	if actual_anim == "":
		var keywords: Array = []
		match anim_name:
			"idle":   keywords = ["IDLE", "WAIT", "STAND"]
			"walk":   keywords = ["WALK", "RUN", "MOV", "PEACEWALK"]
			"attack": keywords = ["ATTACK", "HIT", "STRIKE"]
			"die":    keywords = ["DIE", "DEATH", "DEAD"]
		
		for kw in keywords:
			for a in list:
				if kw in a.to_upper():
					actual_anim = a
					break
			if actual_anim != "":
				break
	
	if actual_anim == "":
		for a in list:
			if a != "RESET" and not a.ends_with("/RESET"):
				actual_anim = a
				break
		if actual_anim == "":
			actual_anim = list[0]
	
	if actual_anim != "" and player.has_animation(actual_anim):
		var anim = player.get_animation(actual_anim)
		if anim_name == "idle" or anim_name == "walk":
			anim.loop_mode = Animation.LOOP_LINEAR
		else:
			anim.loop_mode = Animation.LOOP_NONE
		player.play(actual_anim)

func _physics_process(delta: float) -> void:
	if mob_data.is_empty() or vitals.hp <= 0:
		return
		
	if current_cooldown > 0:
		current_cooldown -= delta
		
	# Gravidade
	if not is_on_floor():
		velocity.y -= ProjectSettings.get_setting("physics/3d/default_gravity") * delta

	_process_state_machine(delta)
	move_and_slide()

func _process_state_machine(delta: float) -> void:
	velocity.x = 0.0
	velocity.z = 0.0
	
	if current_target == null and (current_state == State.CHASE or current_state == State.ATTACK):
		_change_state(State.RETURN)

	match current_state:
		State.IDLE:
			patrol_timer -= delta
			if patrol_timer <= 0:
				_pick_patrol_point()
				_change_state(State.PATROL)
			_search_for_player()
				
		State.PATROL:
			movement_timer -= delta
			var next_pos = _get_navigation_target(nav_agent.target_position)

			if movement_timer <= 0 or global_position.distance_to(nav_agent.target_position) < 0.5:
				_change_state(State.IDLE)
			else:
				_move_towards(next_pos)
			_search_for_player()
				
		State.CHASE:
			if is_instance_valid(current_target):
				var dist = global_position.distance_to(current_target.global_position)
				if dist <= attack_range:
					_change_state(State.ATTACK)
				elif dist > sight_radius * 1.5:
					current_target = null
					_change_state(State.RETURN)
				else:
					nav_agent.target_position = current_target.global_position
					_move_towards(_get_navigation_target(current_target.global_position))
			else:
				current_target = null
				
		State.ATTACK:
			if is_instance_valid(current_target):
				var dist = global_position.distance_to(current_target.global_position)
				if dist > attack_range:
					_change_state(State.CHASE)
				else:
					_look_at_target(current_target.global_position)
					if current_cooldown <= 0:
						_perform_attack()
			else:
				current_target = null
				
		State.FLEE:
			if current_target and is_instance_valid(current_target):
				var flee_dir = (global_position - current_target.global_position).normalized()
				var flee_pos = global_position + (flee_dir * 10.0)
				nav_agent.target_position = flee_pos
				_move_towards(_get_navigation_target(flee_pos))
			else:
				_change_state(State.RETURN)
				
		State.RETURN:
			nav_agent.target_position = origin_position
			if global_position.distance_to(origin_position) < 1.0 or nav_agent.is_navigation_finished():
				_change_state(State.IDLE)
			else:
				_move_towards(_get_navigation_target(origin_position))
				vitals.hp = move_toward(vitals.hp, vitals.max_hp, vitals.max_hp * 0.1 * delta)

func _change_state(new_state: State) -> void:
	if current_state == new_state:
		return

	current_state = new_state
	
	match new_state:
		State.IDLE:
			_play_anim("idle")
			patrol_timer = 3.0
		State.PATROL:
			_play_anim("walk")
			movement_timer = 5.0
		State.CHASE, State.RETURN, State.FLEE:
			_play_anim("walk")
		State.ATTACK:
			_play_anim("attack")

func _pick_patrol_point() -> void:
	var rand_x = randf_range(-patrol_radius, patrol_radius)
	var rand_z = randf_range(-patrol_radius, patrol_radius)
	var next_pos = origin_position + Vector3(rand_x, 0, rand_z)
	nav_agent.target_position = next_pos

func _search_for_player() -> void:
	if not mob_data.get("agressivo", true):
		return
		
	var players = get_tree().get_nodes_in_group("players")
	for player in players:
		if global_position.distance_to(player.global_position) <= sight_radius:
			current_target = player
			nav_agent.target_position = player.global_position
			_change_state(State.CHASE)
			return

func _move_towards(target_pos: Vector3) -> void:
	var flat_target = Vector3(target_pos.x, global_position.y, target_pos.z)
	var dir = global_position.direction_to(flat_target)
	dir.y = 0
	dir = dir.normalized()
	
	velocity.x = dir.x * move_speed
	velocity.z = dir.z * move_speed
	
	if dir.length() > 0.1:
		_look_at_target(global_position + dir)

func _get_navigation_target(fallback_target: Vector3) -> Vector3:
	if nav_agent == null:
		return fallback_target

	var next_pos = nav_agent.get_next_path_position()
	if next_pos == Vector3.ZERO:
		return fallback_target

	var flat_next = Vector2(next_pos.x, next_pos.z)
	var flat_self = Vector2(global_position.x, global_position.z)
	if flat_next.distance_to(flat_self) < 0.15:
		return fallback_target

	return next_pos

func _look_at_target(target_pos: Vector3) -> void:
	var flat_pos = Vector3(target_pos.x, global_position.y, target_pos.z)
	if global_position.distance_squared_to(flat_pos) > 0.1:
		look_at(flat_pos, Vector3.UP)

func _perform_attack() -> void:
	var target_vitals = current_target.get_node_or_null("VitalsComponent")
	if not target_vitals:
		return
	
	_play_anim("attack")
	
	var player_def = 0
	if current_target.is_in_group("players"):
		player_def = StatusManager.get_total_status()["defesa"]
	
	var final_dmg = int(max(1, attack_damage - player_def))
	
	if current_target.is_in_group("players"):
		NetworkManager.send_data({
			"type": "entity_damage",
			"victim_uid": current_target.name,
			"victim_type": "player",
			"damage": final_dmg
		})
	
	print("[Mob ", name, "] Atacou ", current_target.name, " | Atk:", attack_damage, " - Def:", player_def, " = Dano:", final_dmg)
	
	target_vitals.take_damage(final_dmg, -1, self)
	current_cooldown = attack_cooldown

func _on_damaged(attacker: Node3D) -> void:
	if not is_instance_valid(attacker):
		return

	current_target = attacker
	nav_agent.target_position = attacker.global_position
	_change_state(State.CHASE)
	print("[Mob ", name, "] Revidando ataque de ", attacker.name)

func get_stats() -> Dictionary:
	return mob_data

func _on_death() -> void:
	if has_meta("is_dying"):
		return
	set_meta("is_dying", true)
	
	current_target = null
	set_physics_process(false)
	
	print("[Mob Debug] MORREU!")
	
	$CollisionShape3D.disabled = true
	
	_play_anim("die")
	
	var uid = get_meta("mob_uid", -1)
	if uid != -1:
		NetworkManager.send_data({
			"type": "mob_die",
			"uid": uid
		})
	
	var xp_reward = mob_data.get("exp", 0)
	ExperienceManager.add_exp(xp_reward)
	
	_roll_drops()
	died.emit()
	
	await get_tree().create_timer(5.0).timeout
	queue_free()

func _roll_drops() -> void:
	var drops = mob_data.get("drop_list", [])
	for drop in drops:
		var chance = float(drop["chance"])
		if chance > 1.0:
			chance = chance / 100.0
			
		if randf() <= chance:
			_spawn_drop(drop["item"], 1)

func _spawn_drop(item_id: String, amount: int) -> void:
	var item_data = ItemDatabase.get_item(item_id)
	if item_data.is_empty():
		printerr("[Mob Drop] Item nao encontrado no ItemDatabase: ", item_id)
		return
	
	var offset = Vector3(randf_range(-0.5, 0.5), 2.0, randf_range(-0.5, 0.5))
	var drop_pos = global_position + offset
	
	NetworkManager.send_data({
		"type": "item_drop",
		"item_id": item_id,
		"pos": {"x": drop_pos.x, "y": drop_pos.y, "z": drop_pos.z},
		"amount": amount
	})
	
	print("[Loot] Solicitando drop global de: ", item_data.get("nome", item_id))
