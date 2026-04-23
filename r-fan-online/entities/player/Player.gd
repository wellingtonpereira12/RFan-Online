extends CharacterBody3D
class_name Player

@export var class_stats: BaseClassStats

# Componentes
@onready var vitals_component: VitalsComponent = $VitalsComponent
@onready var combat_component: CombatComponent = $CombatComponent

# HUD
var hud_scene = preload("res://ui/hud/HUD.tscn")
var hud_instance: HUD

# Nós da Câmera
@onready var camera_pivot: Node3D = $CameraPivot
@onready var spring_arm: SpringArm3D = $CameraPivot/SpringArm3D
@onready var camera: Camera3D = $CameraPivot/SpringArm3D/Camera3D

# Visível
@onready var visual_mesh: MeshInstance3D = $MeshInstance3D
@onready var name_tag: Label3D = $MeshInstance3D/NameTag

# Referência Target (Sistema Tab-Target)
var current_target: Node3D = null

# Configurações de Câmera
const MOUSE_SENSITIVITY = 0.003
var min_zoom: float = 1.5
var max_zoom: float = 10.0
var zoom_step: float = 0.5

# Variáveis do Player Temporárias
var walk_speed: float = 5.0
var run_speed: float = 12.0
var move_speed: float = 5.0
var jump_velocity: float = 4.5
var gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity")

# --- Variáveis do Sistema de Combate / Auto-Attack ---
var auto_attack_mode_enabled: bool = false
var run_mode_enabled: bool = false
var is_pursuing_and_attacking: bool = false
var basic_attack_cooldown_timer: float = 0.0
var basic_attack_interval: float = 1.0 # 1 hit por segundo fixo na mão
var base_attack_range: float = 2.5

func _ready() -> void:
	# Registro global para Inimigos acharem o Jogador e Agro
	add_to_group("players")
	
	# Mouse visível por padrão para clicar nos inimigos
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	
	# Inicializar HUD
	hud_instance = hud_scene.instantiate()
	add_child(hud_instance)

	# --- ALQUIMIA GLOBAL (Injeção de Seleção do Singleton) ---
	var p_name = GameManager.player_name
	var p_race = GameManager.player_race
	
	if p_name != "" and p_race != "":
		# Atualiza Título
		name_tag.text = "[ " + p_race + " ]\n" + p_name
		
		# Cria cor orgânica baseada na Facção (Corita = Roxo, Bellato = Azul, Accretia = Vermelho)
		var custom_mat = StandardMaterial3D.new()
		match p_race:
			"Cora": custom_mat.albedo_color = Color(0.8, 0.0, 0.8) # Roxo Intenso
			"Bellato": custom_mat.albedo_color = Color(0.0, 0.5, 1.0) # Azul Heroico
			"Accretia": custom_mat.albedo_color = Color(1.0, 0.2, 0.0) # Vermelho Máquina
			
		visual_mesh.set_surface_override_material(0, custom_mat)

	# Se a classe não for definida visualmente no Godot, criamos o Guerreiro (Warrior) via código por padrão
	if not class_stats:
		class_stats = BaseClassStats.new()
		class_stats.character_class_name = "Warrior"
		class_stats.base_max_health = 150
		class_stats.base_max_sp = 50
		class_stats.base_max_fp = 100
		class_stats.base_physical_attack = 20

	if class_stats:
		walk_speed = class_stats.base_movement_speed
		move_speed = walk_speed
		if vitals_component:
			vitals_component.max_hp = class_stats.base_max_health
			vitals_component.max_sp = class_stats.base_max_sp
			vitals_component.max_fp = class_stats.base_max_fp
			vitals_component.hp = vitals_component.max_hp
			vitals_component.sp = vitals_component.max_sp
			vitals_component.fp = vitals_component.max_fp
			
			# Conectar Sinais ao HUD
			vitals_component.hp_changed.connect(hud_instance.update_hp)
			vitals_component.sp_changed.connect(hud_instance.update_sp)
			vitals_component.fp_changed.connect(hud_instance.update_fp)
			
			# Atualizar HUD com valores iniciais
			hud_instance.update_hp(vitals_component.hp, vitals_component.max_hp)
			hud_instance.update_sp(vitals_component.sp, vitals_component.max_sp)
			hud_instance.update_fp(vitals_component.fp, vitals_component.max_fp)
			
			# Lógica de Morte / Respawn
			vitals_component.died.connect(_on_player_died)

	# Inicializar a primeira Magia em Código pra teste ("Wild Smash") e Injetar Item na SkillBar
	if combat_component and hud_instance.skill_bar:
		var wild_smash = SkillResource.new()
		wild_smash.skill_name = "Golpe Selvagem"
		wild_smash.sp_cost = 20
		wild_smash.cooldown = 3.0
		wild_smash.damage_multiplier = 2.5
		wild_smash.skill_range = 3.5
		hud_instance.skill_bar.set_slot_action(1, wild_smash)
		
		var fake_potion = SkillResource.new()
		fake_potion.skill_name = "Pote de HP"
		fake_potion.cooldown = 10.0
		hud_instance.skill_bar.set_slot_action(2, fake_potion)
		
		# Amarra a barra gráfica ao motor de dano do CombatComponent!
		hud_instance.skill_bar.action_triggered.connect(func(idx): 
			var act_data = hud_instance.skill_bar.slots[idx - 1].action_data
			combat_component.process_action(idx, act_data, hud_instance.skill_bar)
		)

	# Conectar modos da UI ao Player
	hud_instance.run_toggled.connect(_on_hud_run_toggled)
	hud_instance.auto_attack_mode_toggled.connect(_on_hud_auto_mode_toggled)

func _on_hud_auto_mode_toggled(is_auto: bool) -> void:
	auto_attack_mode_enabled = is_auto

func _on_hud_run_toggled(is_run_mode: bool) -> void:
	run_mode_enabled = is_run_mode
	if is_run_mode and vitals_component and vitals_component.fp <= 0:
		run_mode_enabled = false
		hud_instance.force_walk_mode()

# --- Sistema de Morte e Renascimento ---
func _on_player_died() -> void:
	print("=> [SISTEMA]: Jogador MORREU! Iniciando Respawn...")
	
	# Restaurar Status Full
	vitals_component.hp = vitals_component.max_hp
	vitals_component.sp = vitals_component.max_sp
	vitals_component.fp = vitals_component.max_fp
	
	vitals_component.hp_changed.emit(vitals_component.hp, vitals_component.max_hp)
	vitals_component.sp_changed.emit(vitals_component.sp, vitals_component.max_sp)
	vitals_component.fp_changed.emit(vitals_component.fp, vitals_component.max_fp)
	
	# Interrompe qualquer perseguição
	is_pursuing_and_attacking = false
	current_target = null
	hud_instance.unbind_target()
	
	# Teletransportar pro centro da plataforma
	global_position = Vector3(0, 1.5, 0)
	
	print("=> [SISTEMA]: Respawn concluído com sucesso!")

func _unhandled_input(event: InputEvent) -> void:
	# Lógica Clássica de MMO: Segurar o Botão DIREITO do mouse para "Guiar" a Câmera e o Corpo
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_RIGHT:
		if event.pressed:
			Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
		else:
			Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

	# Lógica de Zoom da Câmera (Scroll do Mouse)
	if event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP:
			spring_arm.spring_length = clamp(spring_arm.spring_length - zoom_step, min_zoom, max_zoom)
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			spring_arm.spring_length = clamp(spring_arm.spring_length + zoom_step, min_zoom, max_zoom)

	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		# Gira apenas a Câmera independentemente (evita spin de 360 do mundo)
		camera_pivot.rotate_y(-event.relative.x * MOUSE_SENSITIVITY)
		# Girar apenas o SpringArm no eixo X (Cima/Baixo)
		spring_arm.rotate_x(-event.relative.y * MOUSE_SENSITIVITY)
		spring_arm.rotation.x = clamp(spring_arm.rotation.x, -PI/2.5, PI/4)
		
	# Clique Esquerdo Analisado Detalhadamente (Target / Atacar / Auto Attack DoubleClick)
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		handle_mouse_click(event.double_click)

func handle_mouse_click(is_double_click: bool) -> void:
	var space_state = get_world_3d().direct_space_state
	var mouse_pos = get_viewport().get_mouse_position()
	var ray_origin = camera.project_ray_origin(mouse_pos)
	var ray_end = ray_origin + camera.project_ray_normal(mouse_pos) * 1000.0
	
	var query = PhysicsRayQueryParameters3D.create(ray_origin, ray_end)
	var result = space_state.intersect_ray(query)
	
	if result and result.has("collider"):
		var hit_obj = result.collider
		if hit_obj.is_in_group("enemies"):
			# Define Alvo novo ou mantém
			current_target = hit_obj
			hud_instance.bind_target(hit_obj)
			
			# Analisar Comportamento de clique baseado no Modo
			if auto_attack_mode_enabled:
				# MODO AUTO: 1 clique já persegue para bater infinitamente
				is_pursuing_and_attacking = true
				basic_attack_cooldown_timer = 0.0
			elif is_double_click:
				# MODO MANUAL: 2 cliques para perseguir e dar exatamente UM hit
				is_pursuing_and_attacking = true
				basic_attack_cooldown_timer = 0.0
			# Se for Modo Manual e Clique Único, apenas Seleciona o Target (já feito acima)
				
			return
			
	# Se clicou fora ou não é inimigo, desmarca
	current_target = null
	hud_instance.unbind_target()
	is_pursuing_and_attacking = false

func _physics_process(delta: float) -> void:
	# Add the gravity.
	if not is_on_floor():
		velocity.y -= gravity * delta

	# Pular
	if Input.is_action_just_pressed("jump") and is_on_floor():
		velocity.y = jump_velocity

	# Obter direção de Input baseada no Teclado mas com referência absoluta da CÂMERA
	var input_dir := Input.get_vector("move_left", "move_right", "move_forward", "move_backward")
	var cam_dir = camera_pivot.global_basis * Vector3(input_dir.x, 0, input_dir.y)
	cam_dir.y = 0
	var direction := cam_dir.normalized()
	
	# Condições de Interrupção de teclado
	if input_dir.length() > 0:
		is_pursuing_and_attacking = false # O usuário tocou no WASD, cancelar perseguição automátiCa!

	# --- Lógica de Consumo de FP Dinâmico ---
	var is_moving = direction.length() > 0.0 or is_pursuing_and_attacking
	if run_mode_enabled and is_moving and vitals_component and vitals_component.fp > 0:
		move_speed = run_speed
		vitals_component.is_running = true
	else:
		move_speed = walk_speed
		vitals_component.is_running = false
		
		# Se tentou correr sem FP, desativa
		if run_mode_enabled and is_moving and vitals_component and vitals_component.fp == 0:
			run_mode_enabled = false
			hud_instance.force_walk_mode()
	
	# Processar movimentação de Auto Attack Autônoma
	if is_pursuing_and_attacking:
		if is_instance_valid(current_target):
			var dist = global_position.distance_to(current_target.global_position)
			if dist > base_attack_range:
				# Precisa andar até ele
				var dir_to_mob = global_position.direction_to(current_target.global_position)
				dir_to_mob.y = 0
				dir_to_mob = dir_to_mob.normalized()
				
				velocity.x = dir_to_mob.x * move_speed
				velocity.z = dir_to_mob.z * move_speed
			else:
				# Chegou! Parar de andar e processar ataque.
				velocity.x = 0
				velocity.z = 0
				if basic_attack_cooldown_timer <= 0.0:
					perform_attack()
					basic_attack_cooldown_timer = basic_attack_interval
					
					# REGRA DE OURO: Modo Manual só bate UMA vez e o comboencerra!
					if not auto_attack_mode_enabled:
						is_pursuing_and_attacking = false
		else:
			# Alvo morreu fisicamente (foi limpo do jogo)
			current_target = null
			is_pursuing_and_attacking = false
			hud_instance.unbind_target()
	else:
		# Processamento WASD Comum
		if direction:
			velocity.x = direction.x * move_speed
			velocity.z = direction.z * move_speed
		else:
			velocity.x = move_toward(velocity.x, 0, move_speed)
			velocity.z = move_toward(velocity.z, 0, move_speed)

	# Atualiza Rotação VISUAL (Malha 3D) baseada puramente na direção que o boneco anda
	if Vector2(velocity.x, velocity.z).length() > 0.1:
		var target_angle = atan2(velocity.x, velocity.z)
		$MeshInstance3D.global_rotation.y = lerp_angle($MeshInstance3D.global_rotation.y, target_angle, 15.0 * delta)

	# Tempo de Cooldown correndo fora da condicional pra garantir recuperação universal
	if basic_attack_cooldown_timer > 0.0:
		basic_attack_cooldown_timer -= delta

	move_and_slide()

# --- Sistema de Ataque Básico (Melee) ---
func perform_attack() -> void:
	if not class_stats:
		print("Player não tem classe definida!")
		return
		
	if not current_target:
		print("Selecione um alvo primeiro (Tab)")
		return
		
	var dist = global_position.distance_to(current_target.global_position)
	if dist <= base_attack_range:
		print("Player AUTO ATAQUE em " + current_target.name + " com " + str(class_stats.base_physical_attack) + " de dano.")
		if current_target.has_node("VitalsComponent"):
			current_target.get_node("VitalsComponent").take_damage(class_stats.base_physical_attack)
	else:
		print("Alvo está muito longe! (" + str(snapped(dist, 0.1)) + "m)")
