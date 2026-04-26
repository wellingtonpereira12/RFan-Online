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
		
	current_state = State.PATROL
	_load_visual_model(key)
	print("[Mob] Spawnado: ", name, " (", mob_key, ")")

func _load_visual_model(key: String) -> void:
	var model_path = "res://assets/models/mobs/" + key + "/" + key + ".glb"
	if ResourceLoader.exists(model_path):
		var model_scene = load(model_path)
		if model_scene:
			# Remove o visual antigo (Capsula)
			var old_mesh = get_node_or_null("MeshInstance3D")
			if old_mesh:
				old_mesh.visible = false
			
			# Instancia o modelo real
			var model_instance = model_scene.instantiate()
			add_child(model_instance)
			
			# Ajuste de escala e rotacao baseado no banco de dados
			var s = mob_data.get("escala", 1.0)
			model_instance.scale = Vector3(s, s, s)
			model_instance.rotation_degrees.y = 0
			model_instance.position.y = 0
			
			# Ajustar a capsula de colisao para mobs pequenos
			var col = get_node_or_null("CollisionShape3D")
			if col:
				if s < 0.5:
					col.scale = Vector3(0.5, 0.5, 0.5)
					col.position.y = 0.5
				else:
					col.scale = Vector3(1.0, 1.0, 1.0)
					col.position.y = 1.0
			
			# Sistema de Animacao
			var anim_player = _find_animation_player(model_instance)
			if anim_player:
				_setup_animations(anim_player)

func _find_animation_player(node: Node) -> AnimationPlayer:
	if node is AnimationPlayer:
		return node
	for child in node.get_children():
		var found = _find_animation_player(child)
		if found:
			return found
	return null

func _find_mesh(node: Node) -> MeshInstance3D:
	if node is MeshInstance3D:
		return node
	for child in node.get_children():
		var found = _find_mesh(child)
		if found:
			return found
	return null

var _anim_player: AnimationPlayer = null
func _setup_animations(player: AnimationPlayer) -> void:
	_anim_player = player
	print("[Mob Debug] Animacoes encontradas no modelo ", name, ": ", _anim_player.get_animation_list())
	_play_anim("idle")

func _play_anim(anim_name: String) -> void:
	if not _anim_player:
		print("[Mob Debug] ERRO: AnimationPlayer nao encontrado para ", name)
		return
	
	var actual_anim = ""
	var list = _anim_player.get_animation_list()
	
	if anim_name == "idle":
		for a in list:
			if "IDLE" in a.to_upper():
				actual_anim = a
				break
		if actual_anim == "":
			actual_anim = "WARIDLE_01_00"
	elif anim_name == "walk":
		for a in list:
			var ua = a.to_upper()
			if "YOUNGFLEM" in ua and "PEACEWALK" in ua:
				actual_anim = a
				break
		
		if actual_anim == "":
			for a in list:
				if "PEACEWALK" in a.to_upper():
					actual_anim = a
					break
		
		if actual_anim == "":
			for a in list:
				var ua = a.to_upper()
				if "WALK" in ua or "RUN" in ua:
					actual_anim = a
					break
		if actual_anim == "":
			actual_anim = "WARWALK_01_00"
	elif anim_name == "attack":
		for a in list:
			if "ATTACK" in a.to_upper():
				actual_anim = a
				break
		if actual_anim == "":
			actual_anim = "WARFORCEATTACK_01_00"
	elif anim_name == "die":
		for a in list:
			var upper_a = a.to_upper()
			if "DIE" in upper_a or "DEATH" in upper_a:
				actual_anim = a
				break
		
		if actual_anim == "":
			if "WARDIE_01_00" in list:
				actual_anim = "WARDIE_01_00"
			elif "Die" in list:
				actual_anim = "Die"
	
	if actual_anim == "" and list.size() > 0:
		actual_anim = list[0]
		
	if actual_anim != "" and _anim_player.has_animation(actual_anim):
		var anim = _anim_player.get_animation(actual_anim)
		if anim_name == "idle" or anim_name == "walk":
			anim.loop_mode = Animation.LOOP_LINEAR
		else:
			anim.loop_mode = Animation.LOOP_NONE
			
		print("[Mob Debug] Reproduzindo: ", actual_anim, " (Estado: ", anim_name, ")")
		_anim_player.play(actual_anim)
	else:
		print("[Mob Debug] AVISO: Nenhuma animacao correspondente para '", anim_name, "' encontrada. Lista: ", list)

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
	
	if vitals.hp < vitals.max_hp * flee_health_threshold and current_state != State.FLEE:
		_change_state(State.FLEE)
	elif current_target == null and (current_state == State.CHASE or current_state == State.ATTACK):
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
	
	print("[Mob Debug] MORREU! Lista de animacoes disponiveis: ", _anim_player.get_animation_list() if _anim_player else "SEM PLAYER")
	
	var model = get_child(get_child_count() - 1)
	if model:
		var mesh = _find_mesh(model)
		if mesh:
			var mat = StandardMaterial3D.new()
			mat.albedo_color = Color(1, 0, 0)
			mat.emission_enabled = true
			mat.emission = Color(1, 0, 0)
			mesh.set_surface_override_material(0, mat)
	
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
