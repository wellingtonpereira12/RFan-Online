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

# --- CONFIGURAÇÕES DE IA ---
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

signal died

func _ready() -> void:
	add_to_group("enemies")
	origin_position = global_position
	
	# Verifica se há NavigationAgent, se não tiver, criamos um básico
	nav_agent = get_node_or_null("NavigationAgent3D")
	if not nav_agent:
		nav_agent = NavigationAgent3D.new()
		add_child(nav_agent)
		
	# Instancia Componente de Vida se não existir
	vitals = get_node_or_null("VitalsComponent")
	if not vitals:
		vitals = VitalsComponent.new()
		vitals.name = "VitalsComponent"
		add_child(vitals)
		
	vitals.died.connect(_on_death)

# Inicializado pelo Spawner
func setup_from_db(key: String) -> void:
	mob_key = key
	mob_data = MobDatabase.get_mob(key)
	
	if mob_data.is_empty():
		queue_free()
		return
		
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
	print("[Mob] Spawnado: ", name, " (", mob_key, ")")

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
	# Transições Universais (Prioridade Máxima)
	if vitals.hp < vitals.max_hp * flee_health_threshold and current_state != State.FLEE:
		_change_state(State.FLEE)
	elif current_target == null and (current_state == State.CHASE or current_state == State.ATTACK):
		_change_state(State.RETURN)

	# Máquina de Estados
	match current_state:
		State.IDLE:
			patrol_timer -= delta
			if patrol_timer <= 0:
				_pick_patrol_point()
				_change_state(State.PATROL)
			_search_for_player()
				
		State.PATROL:
			if nav_agent.is_navigation_finished():
				patrol_timer = randf_range(2.0, 5.0)
				_change_state(State.IDLE)
			else:
				_move_towards(nav_agent.get_next_path_position())
			_search_for_player()
				
		State.CHASE:
			if is_instance_valid(current_target):
				var dist = global_position.distance_to(current_target.global_position)
				if dist <= attack_range:
					_change_state(State.ATTACK)
				elif dist > sight_radius * 1.5: # Perdeu de vista
					current_target = null
					_change_state(State.RETURN)
				else:
					nav_agent.target_position = current_target.global_position
					_move_towards(nav_agent.get_next_path_position())
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
			# Foge na direção contrária à origem ou ao alvo
			if current_target and is_instance_valid(current_target):
				var flee_dir = (global_position - current_target.global_position).normalized()
				var flee_pos = global_position + (flee_dir * 10.0)
				nav_agent.target_position = flee_pos
				_move_towards(nav_agent.get_next_path_position())
			else:
				_change_state(State.RETURN)
				
		State.RETURN:
			nav_agent.target_position = origin_position
			if global_position.distance_to(origin_position) < 1.0 or nav_agent.is_navigation_finished():
				_change_state(State.IDLE)
			else:
				_move_towards(nav_agent.get_next_path_position())
				# Opcional: Curar enquanto volta (Reset)
				vitals.hp = move_toward(vitals.hp, vitals.max_hp, vitals.max_hp * 0.1 * delta)

func _change_state(new_state: State) -> void:
	current_state = new_state

func _pick_patrol_point() -> void:
	var rand_x = randf_range(-patrol_radius, patrol_radius)
	var rand_z = randf_range(-patrol_radius, patrol_radius)
	var next_pos = origin_position + Vector3(rand_x, 0, rand_z)
	nav_agent.target_position = next_pos

func _search_for_player() -> void:
	var players = get_tree().get_nodes_in_group("players")
	for player in players:
		if global_position.distance_to(player.global_position) <= sight_radius:
			current_target = player
			_change_state(State.CHASE)
			return

func _move_towards(target_pos: Vector3) -> void:
	var dir = global_position.direction_to(target_pos)
	dir.y = 0
	dir = dir.normalized()
	velocity.x = dir.x * move_speed
	velocity.z = dir.z * move_speed
	
	if dir.length() > 0.1:
		_look_at_target(global_position + dir)

func _look_at_target(target_pos: Vector3) -> void:
	var flat_pos = Vector3(target_pos.x, global_position.y, target_pos.z)
	if global_position.distance_squared_to(flat_pos) > 0.1:
		look_at(flat_pos, Vector3.UP)

func _perform_attack() -> void:
	# Busca o componente de vida do player (ou alvo)
	var target_vitals = current_target.get_node_or_null("VitalsComponent")
	if not target_vitals: return
	
	# --- CÁLCULO DE DEFESA DO PLAYER ---
	var player_def = 0
	# Se o alvo for o player, pegamos a defesa real do StatusManager
	if current_target.is_in_group("players"):
		player_def = StatusManager.get_total_status()["defesa"]
	
	# Dano Final = Ataque do Mob - Defesa do Player
	var final_dmg = int(max(1, attack_damage - player_def))
	
	print("[Mob ", name, "] Atacou ", current_target.name, " | Atk:", attack_damage, " - Def:", player_def, " = Dano:", final_dmg)
	
	target_vitals.take_damage(final_dmg)
	current_cooldown = attack_cooldown

func get_stats() -> Dictionary:
	return mob_data

func _on_death() -> void:
	print("[Mob ", name, "] Morreu!")
	
	# Dá XP ao jogador
	var xp_reward = mob_data.get("exp", 0)
	ExperienceManager.add_exp(xp_reward)
	
	_roll_drops()
	died.emit()
	queue_free()

func _roll_drops() -> void:
	var drops = mob_data.get("drop_list", [])
	for drop in drops:
		# Rola a chance (normalizada: 0.0-1.0, ou 0-100 viram 0.0-1.0 automaticamente)
		var chance = float(drop["chance"])
		if chance > 1.0:
			chance = chance / 100.0
			
		if randf() <= chance:
			_spawn_drop(drop["item"], 1)

func _spawn_drop(item_id: String, amount: int) -> void:
	var item_data = ItemDatabase.get_item(item_id)
	if item_data.is_empty():
		printerr("[Mob Drop] Item não encontrado no ItemDatabase: ", item_id)
		return
	
	# Cria o nó físico igual ao drop do inventário
	var item_node = RigidBody3D.new()
	
	var mesh_inst = MeshInstance3D.new()
	var box_mesh = BoxMesh.new()
	box_mesh.size = Vector3(0.3, 0.3, 0.3)
	mesh_inst.mesh = box_mesh
	
	var mat = StandardMaterial3D.new()
	mat.albedo_color = Color(1.0, 0.84, 0.0) # Amarelo Ouro = Loot
	box_mesh.surface_set_material(0, mat)
	
	var coll = CollisionShape3D.new()
	var box_shape = BoxShape3D.new()
	box_shape.size = Vector3(0.3, 0.3, 0.3)
	coll.shape = box_shape
	
	item_node.add_child(mesh_inst)
	item_node.add_child(coll)
	
	# Metadados idênticos ao sistema de drop do Player
	item_node.set_meta("is_dropped_item", true)
	item_node.set_meta("item_data", item_data)
	item_node.set_meta("item_amount", amount)
	
	# Adiciona à cena e posiciona em cima do mob
	get_tree().current_scene.add_child(item_node)
	var offset = Vector3(randf_range(-0.5, 0.5), 1.0, randf_range(-0.5, 0.5))
	item_node.global_position = global_position + offset
	item_node.apply_central_impulse(Vector3(0, 4.0, 0))
	
	print("[Loot] ", name, " dropou: ", item_data.get("nome", item_id), " x", amount)
