extends CharacterBody3D
class_name Enemy

@onready var vitals: VitalsComponent = $VitalsComponent

# --- Configurações da IA ---
var move_speed: float = 4.0
var aggro_range: float = 12.0
var leash_range: float = 18.0
var attack_range: float = 2.5
var attack_damage: int = 10
var attack_cooldown: float = 1.5

# Variáveis Internas
var gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity")
var current_target: Node3D = null
var current_cooldown: float = 0.0

enum State { IDLE, CHASE, ATTACK }
var current_state: State = State.IDLE

func _ready() -> void:
	if vitals:
		vitals.died.connect(_on_died)
		vitals.hp_changed.connect(_on_took_damage)
		
	# Remover Bodyblock: Inimigos e Jogadores se atravessam
	call_deferred("_ignore_players")

func _ignore_players() -> void:
	for p in get_tree().get_nodes_in_group("players"):
		add_collision_exception_with(p)

func _physics_process(delta: float) -> void:
	# Aplicar Gravidade
	if not is_on_floor():
		velocity.y -= gravity * delta

	# Processar tempo de recarga do ataque
	if current_cooldown > 0.0:
		current_cooldown -= delta

	# Pega o jogador ativo no mapa
	current_target = _get_player_target()
	
	# Máquina de Estados da IA
	match current_state:
		State.IDLE:
			_process_idle()
		State.CHASE:
			_process_chase(delta)
		State.ATTACK:
			_process_attack()

	move_and_slide()

# --- Estados da IA ---

func _process_idle() -> void:
	velocity.x = move_toward(velocity.x, 0, move_speed)
	velocity.z = move_toward(velocity.z, 0, move_speed)
	
	if current_target:
		var dist = global_position.distance_to(current_target.global_position)
		if dist <= aggro_range:
			print(">>> INIMIGO [", name, "] avistou o Jogador! Iniciando Perseguição!")
			current_state = State.CHASE

func _process_chase(delta: float) -> void:
	if not current_target:
		current_state = State.IDLE
		return
		
	var dist = global_position.distance_to(current_target.global_position)
	
	# Desistir se for muito longe
	if dist > leash_range:
		print(">>> INIMIGO [", name, "] perdeu o interesse no alvo.")
		current_state = State.IDLE
		return
		
	# Atacar se chegou perto
	if dist <= attack_range:
		current_state = State.ATTACK
		return
		
	# Perseguir fisicamente
	var dir = global_position.direction_to(current_target.global_position)
	dir.y = 0
	dir = dir.normalized()
	
	velocity.x = dir.x * move_speed
	velocity.z = dir.z * move_speed
	
	# Virar o corpo pro jogador
	var target_angle = atan2(velocity.x, velocity.z)
	rotation.y = lerp_angle(rotation.y, target_angle, 10.0 * delta)

func _process_attack() -> void:
	velocity.x = 0
	velocity.z = 0
	
	if not current_target:
		current_state = State.IDLE
		return
		
	var dist = global_position.distance_to(current_target.global_position)
	
	if dist > attack_range:
		# Fugiu, voltar a perseguir
		current_state = State.CHASE
		return
		
	# Golpear
	if current_cooldown <= 0.0:
		print("=== INIMIGO ataca Jogador causando ", attack_damage, " DANO! ===")
		if current_target.has_node("VitalsComponent"):
			current_target.get_node("VitalsComponent").take_damage(attack_damage)
			
		current_cooldown = attack_cooldown

# --- Ajudantes ---

func _get_player_target() -> Node3D:
	var players = get_tree().get_nodes_in_group("players")
	if players.size() > 0:
		return players[0] as Node3D
	return null

func _on_took_damage(current_hp: int, max_hp: int) -> void:
	# Se apanhar de longe, agro instantâneo (vincular mecânica se tiver ataque a distancia)
	if current_state == State.IDLE and current_hp < max_hp:
		current_state = State.CHASE

func _on_died() -> void:
	print(">>> O INIMIGO [", name, "] FOI MORTO fisicamente e removido do jogo!")
	queue_free()
