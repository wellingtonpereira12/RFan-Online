extends CharacterBody3D
class_name Player

@export var class_stats: BaseClassStats

# Componentes
@onready var health_component: HealthComponent = $HealthComponent

# Nós da Câmera
@onready var camera_pivot: Node3D = $CameraPivot
@onready var spring_arm: SpringArm3D = $CameraPivot/SpringArm3D
@onready var camera: Camera3D = $CameraPivot/SpringArm3D/Camera3D

# Referência Target (Sistema Tab-Target)
var current_target: Node3D = null

# Configurações de Câmera
const MOUSE_SENSITIVITY = 0.003
var min_zoom: float = 1.5
var max_zoom: float = 10.0
var zoom_step: float = 0.5

# Variáveis do Player Temporárias
var move_speed: float = 5.0
var jump_velocity: float = 4.5
var gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity")

func _ready() -> void:
	# Mouse visível por padrão para clicar nos inimigos
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	if class_stats:
		move_speed = class_stats.base_movement_speed
		if health_component:
			health_component.max_health = class_stats.base_max_health
			health_component.current_health = health_component.max_health

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
		# Girar o próprio Personagem (Player) no eixo Y (Esquerda/Direita)
		rotate_y(-event.relative.x * MOUSE_SENSITIVITY)
		# Girar apenas o SpringArm no eixo X (Cima/Baixo)
		spring_arm.rotate_x(-event.relative.y * MOUSE_SENSITIVITY)
		spring_arm.rotation.x = clamp(spring_arm.rotation.x, -PI/2.5, PI/4)
		
	if event.is_action_pressed("target_next"): # Equivalente a Tab
		find_next_target()
		
	if event.is_action_pressed("attack"): # Equivalente a Left Click ou 1
		perform_attack()

func _physics_process(delta: float) -> void:
	# Add the gravity.
	if not is_on_floor():
		velocity.y -= gravity * delta

	# Pular
	if Input.is_action_just_pressed("jump") and is_on_floor():
		velocity.y = jump_velocity

	# Obter direção de Input baseada no WASD
	var input_dir := Input.get_vector("move_left", "move_right", "move_forward", "move_backward")
	# Pega a direção da câmera baseada no corpo (já que o corpo gira com o mouse)
	var direction := (transform.basis * Vector3(input_dir.x, 0, input_dir.y)).normalized()
	
	if direction:
		velocity.x = direction.x * move_speed
		velocity.z = direction.z * move_speed
	else:
		velocity.x = move_toward(velocity.x, 0, move_speed)
		velocity.z = move_toward(velocity.z, 0, move_speed)

	move_and_slide()

# --- Sistema Tab Target Simples ---
func find_next_target() -> void:
	var enemies = get_tree().get_nodes_in_group("enemies")
	if enemies.size() == 0:
		print("Nenhum inimigo encontrado.")
		return
		
	# Lógica simples pra agora: pega o inimigo mais próximo
	var closest_enemy = null
	var closest_dist = 9999.0
	for enemy in enemies:
		var dist = global_position.distance_to(enemy.global_position)
		if dist < closest_dist:
			closest_dist = dist
			closest_enemy = enemy
			
	current_target = closest_enemy
	print("Alvo selecionado: ", current_target.name if current_target else "Nenhum")

# --- Sistema de Ataque Básico (Melee) ---
func perform_attack() -> void:
	if not class_stats:
		print("Player não tem classe definida!")
		return
		
	if not current_target:
		print("Selecione um alvo primeiro (Tab)")
		return
		
	var dist = global_position.distance_to(current_target.global_position)
	var attack_range = 2.5 # Range de Melee
	
	if dist <= attack_range:
		print("Player ataca " + current_target.name + " causando " + str(class_stats.base_physical_attack) + " de dano físico!")
		# Aqui chamamos o HealthComponent do alvo no futuro:
		if current_target.has_node("HealthComponent"):
			current_target.get_node("HealthComponent").take_damage(class_stats.base_physical_attack)
	else:
		print("Alvo está muito longe! (" + str(snapped(dist, 0.1)) + "m)")
