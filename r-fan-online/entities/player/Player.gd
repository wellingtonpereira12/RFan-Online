extends CharacterBody3D
class_name Player

@export var class_stats: BaseClassStats

# Componentes
@onready var vitals_component: VitalsComponent = $VitalsComponent
@onready var combat_component: CombatComponent = $CombatComponent

# HUD e Inventário
var hud_scene = preload("res://ui/hud/HUD.tscn")
var hud_instance: HUD
var inventory_manager: InventoryManager

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
var auto_attack_mode_enabled: bool = true
var run_mode_enabled: bool = true
var is_pursuing_and_attacking: bool = false
var basic_attack_cooldown_timer: float = 0.0
var basic_attack_interval: float = 1.0 # 1 hit por segundo
var base_attack_range: float = 2.5
var last_manual_attack_msec: int = -99999 # Tempo absoluto do último ataque manual

# --- Sistema de Click-to-Move ---
var nav_agent: NavigationAgent3D
var click_target_position: Vector3 = Vector3.ZERO
var is_moving_to_click: bool = false
var click_marker: Node3D = null
var pickup_target: Node3D = null

# --- Sistema de Status de Batalha ---
var is_in_combat: bool = false
var combat_mode_timer: float = 0.0
const COMBAT_MODE_DURATION: float = 10.0

var is_dead: bool = false
var death_ui: CanvasLayer = null

func _ready() -> void:
	# Registro global para Inimigos acharem o Jogador e Agro
	add_to_group("players")
	
	# Mouse visível por padrão para clicar nos inimigos
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	
	# Inicializar HUD
	hud_instance = hud_scene.instantiate()
	add_child(hud_instance)
	
	# Inicializar Inventory Manager e UI automaticamente
	inventory_manager = InventoryManager.new()
	inventory_manager.name = "InventoryManager"
	inventory_manager.add_to_group("inventory_manager")
	add_child(inventory_manager)
	
	# Configurar Navegação
	_setup_navigation()
	_create_click_marker()
	
	# Configurar Cursor de Espada
	_setup_custom_cursor()
	
	# Inicializar Console Admin (GM)
	var admin_scene = preload("res://ui/admin/AdminConsole.tscn")
	var admin_ui = admin_scene.instantiate()
	add_child(admin_ui)

	# Inicializar EquipmentManager
	var equipment_manager = EquipmentManager.new()
	equipment_manager.name = "EquipmentManager"
	equipment_manager.add_to_group("equipment_manager")
	equipment_manager.setup(inventory_manager)
	add_child(equipment_manager)

	# Inicializar EquipmentUI
	var equip_ui_scene = preload("res://ui/equipment/EquipmentUI.tscn")
	var equip_ui = equip_ui_scene.instantiate()
	hud_instance.add_child(equip_ui)
	equip_ui.setup(equipment_manager)
	
	# Inicializar Velocidade
	update_movement_speed()
	update_attack_speed()
	
	# Inicializar MacroUI
	var macro_scene = preload("res://ui/macro/MacroUI.tscn")
	var macro_ui = macro_scene.instantiate()
	hud_instance.add_child(macro_ui)
	
	# Inicializar Auto Potion System
	var pot_system = AutoPotionSystem.new()
	pot_system.name = "AutoPotionSystem"
	add_child(pot_system)

	# Adicionar equipamentos de teste ao inventário
	inventory_manager.add_item("espada_ferro", 1)
	inventory_manager.add_item("capacete_couro", 1)
	inventory_manager.add_item("armadura_couro", 1)
	inventory_manager.add_item("anel_forca", 2)
	inventory_manager.add_item("anel_defesa", 1)
	inventory_manager.add_item("brinco_agilidade", 1)
	
	var inv_scene = preload("res://ui/inventory/InventoryUI.tscn")
	var inv_ui = inv_scene.instantiate()
	hud_instance.add_child(inv_ui)
	inv_ui.setup(inventory_manager)
	
	# Inicializar Chat UI
	var chat_scene = preload("res://ui/chat/ChatUI.tscn")
	var chat_ui = chat_scene.instantiate()
	hud_instance.add_child(chat_ui)
	
	# --- PERSISTÊNCIA DE PERSONAGEM ---
	var acc = AccountManager.get_logged_in_account()
	var character_found = false
	for char_data in acc.get("characters", []):
		if char_data["name"] == GameManager.player_name:
			character_found = true
			# Carrega o inventário salvo se houver
			if char_data.get("inventory", []).size() > 0:
				inventory_manager.load_inventory_data(char_data["inventory"])
				print("[DB] Inventário carregado para ", GameManager.player_name)
			else:
				# Personagem novo ou sem itens salvos, dá itens iniciais
				_give_initial_items()
			
			# Carrega Level e XP
			var p_level = char_data.get("level", 1)
			var p_exp = char_data.get("exp", 0)
			ExperienceManager.setup_player(p_level, p_exp)
			# Inicializa os status base baseados na classe e level carregados
			StatusManager.initialize_for_player()
			break
	
	if not character_found:
		_give_initial_items()
		# Mesmo sem personagem salvo, inicializa o StatusManager com os dados padrão do GameManager
		StatusManager.initialize_for_player()

	# Conectar sinais de XP ao HUD
	ExperienceManager.exp_changed.connect(hud_instance.update_exp)
	ExperienceManager.level_up.connect(func(nl): 
		ChatManager.receive_message({
			"sender": "SISTEMA",
			"text": "LEVEL UP! Você agora é nível " + str(nl),
			"race": GameManager.player_race,
			"channel": ChatManager.Channel.LOCAL
		})
	)
	
	# Forçar atualização inicial da UI
	hud_instance.update_exp(ExperienceManager.current_exp, ExperienceManager.max_exp)


	# Timer para Salvar Automaticamente a cada 30 segundos
	var save_timer = Timer.new()
	save_timer.wait_time = 30.0
	save_timer.autostart = true
	save_timer.timeout.connect(_save_player_to_db)
	add_child(save_timer)

	# --- ALQUIMIA GLOBAL (Injeção de Seleção do Singleton) ---
	var p_name = GameManager.player_name
	var p_race = GameManager.player_race
	
	if p_name != "" and p_race != "":
		var p_class = GameManager.player_class
		var class_str = (" [" + p_class + "]") if p_class != "" else ""
		name_tag.text = "[ " + p_race + class_str + " ]\n" + p_name
		
		# Inicia o carregamento do modelo 3D (Skin)
		_load_visual_model(p_class)

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

	_setup_skill_system()

	# Conectar modos da UI ao Player
	hud_instance.run_toggled.connect(_on_hud_run_toggled)
	hud_instance.auto_attack_mode_toggled.connect(_on_hud_auto_mode_toggled)
	
	_create_death_ui()

func _setup_skill_system() -> void:
	if not combat_component or not hud_instance or not hud_instance.skill_bar:
		return

	if not hud_instance.skill_bar.action_triggered.is_connected(_on_skill_bar_action_triggered):
		hud_instance.skill_bar.action_triggered.connect(_on_skill_bar_action_triggered)

	_bind_default_melee_skills()

func _bind_default_melee_skills() -> void:
	var melee_skills = SkillDatabase.get_all_skills_by_category("melee")
	melee_skills.sort_custom(func(a: Dictionary, b: Dictionary): return int(a.get("id", 0)) < int(b.get("id", 0)))

	var max_slots = mini(melee_skills.size(), 4)
	for i in range(max_slots):
		hud_instance.skill_bar.set_slot_action(i + 1, melee_skills[i])

func _on_skill_bar_action_triggered(idx: int) -> void:
	var action_data = hud_instance.skill_bar.slots[idx - 1].action_data
	combat_component.process_action(idx, action_data, hud_instance.skill_bar)

func _setup_navigation():
	nav_agent = NavigationAgent3D.new()
	nav_agent.path_desired_distance = 0.5
	nav_agent.target_desired_distance = 0.5
	add_child(nav_agent)

func _create_click_marker():
	# Criar uma setinha vermelha simples
	click_marker = Node3D.new()
	var mesh_inst = MeshInstance3D.new()
	var cone = CylinderMesh.new()
	cone.top_radius = 0.0
	cone.bottom_radius = 0.15 # Antes era 0.3
	cone.height = 0.4        # Antes era 0.8
	mesh_inst.mesh = cone
	
	var mat = StandardMaterial3D.new()
	mat.albedo_color = Color(1, 0, 0, 1) # Vermelho vivo
	mat.emission_enabled = true
	mat.emission = Color(1, 0, 0, 1)
	mesh_inst.material_override = mat
	
	click_marker.add_child(mesh_inst)
	# Rotaciona para apontar para baixo
	mesh_inst.rotation_degrees.x = 180
	mesh_inst.position.y = 0.2 # Baixado para colar no chão (antes era 1.0)
	
	get_tree().root.add_child.call_deferred(click_marker)
	click_marker.visible = false

func _stop_click_to_move():
	is_moving_to_click = false
	pickup_target = null
	if click_marker:
		click_marker.visible = false
	
func _collect_item(item_node: Node3D, uid: int):
	if uid == -1: return
	
	# Feedback visual imediato
	item_node.visible = false
	
	# Solicita ao servidor
	NetworkManager.send_data({
		"type": "item_pickup",
		"uid": uid
	})
	pickup_target = null
	print("[Player] Coletando item em alcance: ", uid)
	if click_marker: click_marker.visible = false

func _setup_custom_cursor():
	var cursor_path = "res://assets/icons/sword_cursor.png"
	if FileAccess.file_exists(cursor_path):
		var img = Image.load_from_file(ProjectSettings.globalize_path(cursor_path))
		var tex = ImageTexture.create_from_image(img)
		Input.set_custom_mouse_cursor(tex, Input.CURSOR_ARROW, Vector2(0, 0))

func _process_auto_attack_movement():
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

func _update_mouse_cursor():
	var space_state = get_world_3d().direct_space_state
	var mouse_pos = get_viewport().get_mouse_position()
	var ray_origin = camera.project_ray_origin(mouse_pos)
	var ray_end = ray_origin + camera.project_ray_normal(mouse_pos) * 1000.0
	var query = PhysicsRayQueryParameters3D.create(ray_origin, ray_end)
	var result = space_state.intersect_ray(query)
	
	if result and result.has("collider") and result.collider.is_in_group("enemies"):
		Input.set_default_cursor_shape(Input.CURSOR_CROSS)
	else:
		Input.set_default_cursor_shape(Input.CURSOR_ARROW)

func _update_combat_mode(delta: float) -> void:
	if combat_mode_timer > 0:
		combat_mode_timer -= delta
		if hud_instance: 
			hud_instance.update_combat_status(true, combat_mode_timer)
		is_in_combat = true
	else:
		if is_in_combat:
			is_in_combat = false
			if hud_instance: 
				hud_instance.update_combat_status(false, 0.0)

func set_in_combat() -> void:
	combat_mode_timer = COMBAT_MODE_DURATION
	_stop_click_to_move() # Cancela movimento por clique ao entrar em combate

func _on_hud_auto_mode_toggled(is_auto: bool) -> void:
	auto_attack_mode_enabled = is_auto

func _on_hud_run_toggled(is_run_mode: bool) -> void:
	run_mode_enabled = is_run_mode
	if is_run_mode and vitals_component and vitals_component.fp <= 0:
		run_mode_enabled = false
		hud_instance.force_walk_mode()

func _create_death_ui() -> void:
	death_ui = CanvasLayer.new()
	death_ui.layer = 100 # Ficar por cima de tudo
	
	var bg = ColorRect.new()
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	
	# --- EFEITO GRAYSCALE (Preto e Branco) ---
	var shader = Shader.new()
	shader.code = """
	shader_type canvas_item;
	uniform sampler2D screen_tex : hint_screen_texture, repeat_disable, filter_nearest;
	void fragment() {
		vec4 c = texture(screen_tex, SCREEN_UV);
		float gray = dot(c.rgb, vec3(0.299, 0.587, 0.114));
		// Deixa a tela cinza e escurece um pouquinho pra dar clima de morte
		COLOR = vec4(vec3(gray) * 0.6, 1.0);
	}
	"""
	var mat = ShaderMaterial.new()
	mat.shader = shader
	bg.material = mat
	
	death_ui.add_child(bg)
	
	var vbox = VBoxContainer.new()
	vbox.set_anchors_preset(Control.PRESET_FULL_RECT)
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	bg.add_child(vbox)
	
	var label = Label.new()
	label.text = "VOCÊ MORREU"
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 42) # Fonte menor
	label.add_theme_color_override("font_color", Color(0.8, 0.1, 0.1))
	vbox.add_child(label)
	
	# Dá um espacinho entre o texto e o botão
	var spacer = Control.new()
	spacer.custom_minimum_size = Vector2(0, 20)
	vbox.add_child(spacer)
	
	var btn = Button.new()
	btn.text = "RENASCER"
	btn.add_theme_font_size_override("font_size", 24)
	btn.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	btn.custom_minimum_size = Vector2(200, 50)
	btn.pressed.connect(_on_respawn_btn_pressed)
	vbox.add_child(btn)
	
	add_child(death_ui)
	death_ui.visible = false

# --- Sistema de Morte e Renascimento ---
func _on_player_died() -> void:
	print("=> [SISTEMA]: Jogador MORREU! Tela de morte ativada.")
	is_dead = true
	_play_anim("die")
	
	# Interrompe qualquer perseguição
	is_pursuing_and_attacking = false
	current_target = null
	hud_instance.unbind_target()
	_stop_click_to_move()
	
	death_ui.visible = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

func _on_respawn_btn_pressed() -> void:
	death_ui.visible = false
	is_dead = false
	
	# Restaurar Status Full
	vitals_component.hp = vitals_component.max_hp
	vitals_component.sp = vitals_component.max_sp
	vitals_component.fp = vitals_component.max_fp
	
	vitals_component.hp_changed.emit(vitals_component.hp, vitals_component.max_hp)
	vitals_component.sp_changed.emit(vitals_component.sp, vitals_component.max_sp)
	vitals_component.fp_changed.emit(vitals_component.fp, vitals_component.max_fp)
	
	# Teletransportar pro centro da plataforma
	global_position = Vector3(0, 1.5, 0)
	
	_play_anim("idle")
	print("=> [SISTEMA]: Respawn concluído com sucesso!")

# --- Sistema de Inventário (Drop de Itens) ---
func drop_item_on_ground(item_data: Dictionary, amount: int) -> void:
	# Calcula posição de drop (mais alto para evitar clipping)
	var offset = Vector3(randf_range(-1.0, 1.0), 2.0, randf_range(-1.0, 1.0))
	var drop_pos = global_position + offset
	
	# ENVIAR PARA O SERVIDOR
	NetworkManager.send_data({
		"type": "item_drop",
		"item_id": item_data["id"],
		"pos": {"x": drop_pos.x, "y": drop_pos.y, "z": drop_pos.z},
		"amount": amount
	})
	
	print("[Loot] Solicitando drop manual de: ", item_data.get("nome", "item"))

func _unhandled_input(event: InputEvent) -> void:
	if is_dead: return
	
	# Cancelar Target, Ataque e Fechar Janelas com ESC
	if event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
		var esc_handled = false
		
		# 1. Fechar Inventário se estiver aberto
		var inv_ui = get_tree().get_first_node_in_group("inventory_ui")
		if inv_ui and inv_ui.visible:
			inv_ui.visible = false
			esc_handled = true
		
		# 2. Fechar Equipamentos se estiver aberto
		var eq_ui = get_tree().get_first_node_in_group("equipment_ui")
		if eq_ui and eq_ui.visible:
			eq_ui.visible = false
			esc_handled = true
			
		# 3. Fechar Macro se estiver aberto
		var m_ui = get_tree().get_first_node_in_group("macro_ui")
		if m_ui and m_ui.visible:
			m_ui.visible = false
			esc_handled = true
			
		# 2. Desmarcar Target e parar ataque
		if current_target != null or is_pursuing_and_attacking:
			current_target = null
			hud_instance.unbind_target()
			is_pursuing_and_attacking = false
			esc_handled = true
			
		# 4. Parar Movimento por clique
		if is_moving_to_click:
			_stop_click_to_move()
			esc_handled = true
		
		if esc_handled:
			get_viewport().set_input_as_handled()
			return

	# Lógica Clássica de MMO: Segurar o Botão DIREITO do mouse para "Guiar" a Câmera e o Corpo
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_RIGHT:
		if event.pressed:
			# SEGURANÇA TOTAL: Se o mouse estiver sobre qualquer janela aberta, NÃO captura o mouse.
			# Isso resolve o problema do mouse ir para o centro da tela ao usar itens.
			var mouse_pos = get_viewport().get_mouse_position()
			
			# Checa Inventário
			var inv_ui = get_tree().get_first_node_in_group("inventory_ui")
			if inv_ui and inv_ui.visible:
				var bg = inv_ui.get_node_or_null("Background")
				if bg and bg.get_global_rect().has_point(mouse_pos):
					return
					
			# Checa Equipamentos
			var eq_ui = get_tree().get_first_node_in_group("equipment_ui")
			if eq_ui and eq_ui.visible:
				var bg = eq_ui.get_node_or_null("Background")
				if bg and bg.get_global_rect().has_point(mouse_pos):
					return
			
			# Checa SkillBar (Barra de atalhos)
			var skill_bar_node = hud_instance.get_node_or_null("SkillBar")
			if skill_bar_node and skill_bar_node.get_global_rect().has_point(mouse_pos):
				return

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
		var hit_pos = result.position
		
		# Busca recursiva pelo pai que seja um Inimigo
		var enemy_node = hit_obj
		while enemy_node and not enemy_node.is_in_group("enemies") and enemy_node != get_tree().root:
			enemy_node = enemy_node.get_parent()
		
		# Se não achou um inimigo na árvore, volta para o objeto original para checar itens/chão
		if not enemy_node or not enemy_node.is_in_group("enemies"):
			enemy_node = hit_obj
		
		# 0. Clique no Chão (Click-to-Move)
		if not enemy_node.is_in_group("enemies") and not hit_obj.has_meta("is_dropped_item"):
			is_moving_to_click = true
			click_target_position = hit_pos
			print("[Click-to-Move] Indo para: ", hit_pos)
			
			if click_marker:
				click_marker.global_position = hit_pos
				click_marker.visible = true
			
			is_pursuing_and_attacking = false # Cancela ataque se mover pro chão
			return
		# 1. Clique em Item
		if hit_obj.has_meta("is_dropped_item") or hit_obj.has_meta("item_uid"):
			var item_uid = int(hit_obj.get_meta("item_uid", -1))
			if item_uid != -1:
				var dist = global_position.distance_to(hit_obj.global_position)
				if dist <= 2.5:
					_collect_item(hit_obj, item_uid)
				else:
					pickup_target = hit_obj
					is_moving_to_click = true
					click_target_position = hit_obj.global_position
					print("[Player] Indo buscar item...")
			return

		# 2. Verifica se clicou em um Inimigo
		if enemy_node.is_in_group("enemies"):
			var previous_target = current_target
			_stop_click_to_move() # Para qualquer movimento de clique anterior
			
			# Se o clique for em um alvo DIFERENTE: apenas SELECIONA
			if enemy_node != previous_target:
				current_target = enemy_node
				hud_instance.bind_target(enemy_node)
				is_pursuing_and_attacking = false 
				print("[Combate] Alvo selecionado: ", enemy_node.name)
				return
			
			# Se o clique for no MESMO alvo (segundo clique): ATACA
			is_pursuing_and_attacking = true
			print("[Combate] Iniciando perseguição e ataque automático!")
			return
			
	# Se clicou fora ou não é inimigo, desmarca
	current_target = null
	hud_instance.unbind_target()
	is_pursuing_and_attacking = false

func _process(delta: float) -> void:
	_update_mouse_cursor()
	_update_combat_mode(delta)

func _physics_process(delta: float) -> void:
	# Add the gravity.
	if not is_on_floor():
		velocity.y -= gravity * delta

	if is_dead:
		move_and_slide()
		return

	# Handle Jump (Tecla X) ou Attack (Espaço)
	var focus_owner = get_viewport().gui_get_focus_owner()
	if not (focus_owner is LineEdit):
		# ESC -> CANCELA CLICK-TO-MOVE
		if Input.is_key_pressed(KEY_ESCAPE):
			_stop_click_to_move()

		# ESPAÇO -> ATACAR
		if Input.is_action_just_pressed("ui_accept"):
			if is_instance_valid(current_target):
				is_pursuing_and_attacking = true
				print("[Combate] Atacando via ESPAÇO.")
		
		# TECLA X -> PULAR
		if Input.is_key_pressed(KEY_X) and is_on_floor():
			velocity.y = jump_velocity

	# Obter direção de Input baseada no Teclado mas com referência absoluta da CÂMERA
	var input_dir := Vector2.ZERO
	focus_owner = get_viewport().gui_get_focus_owner()
	
	if not (focus_owner is LineEdit):
		input_dir = Input.get_vector("move_left", "move_right", "move_forward", "move_backward")
	var cam_dir = camera_pivot.global_basis * Vector3(input_dir.x, 0, input_dir.y)
	cam_dir.y = 0
	var direction := cam_dir.normalized()

	# Apenas Gravidade é local agora
	var vertical_vel = velocity.y
	velocity = Vector3.ZERO
	velocity.y = vertical_vel

	# Condições de Interrupção de teclado
	if input_dir.length() > 0:
		is_pursuing_and_attacking = false
		if is_moving_to_click:
			_stop_click_to_move()

	# --- LÓGICA DE COLETA AUTOMÁTICA ---
	if pickup_target and is_instance_valid(pickup_target):
		if global_position.distance_to(pickup_target.global_position) <= 2.5:
			var item_uid = int(pickup_target.get_meta("item_uid", -1))
			_collect_item(pickup_target, item_uid)
			_stop_click_to_move() # Para de andar ao chegar
	elif pickup_target:
		pickup_target = null

	# --- Lógica de Consumo de FP Dinâmico ---
	var target_dist = 0.0
	if current_target:
		target_dist = global_position.distance_to(current_target.global_position)
		
	# Só considera movimento se houver input, se estiver perseguindo ALÉM do alcance, ou se houver um clique no chão
	var is_moving = direction.length() > 0.0 or (is_pursuing_and_attacking and target_dist > base_attack_range) or is_moving_to_click
	
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
	
	# Processar movimentação de Click-to-Move
	if is_moving_to_click:
		var dist_to_target = global_position.distance_to(click_target_position)
		
		if dist_to_target > 0.5:
			var dir = global_position.direction_to(click_target_position)
			dir.y = 0
			dir = dir.normalized()
			
			velocity.x = dir.x * move_speed
			velocity.z = dir.z * move_speed
		else:
			velocity.x = 0
			velocity.z = 0
			_stop_click_to_move()

	# Processar movimentação de Auto Attack Autônoma
	if is_pursuing_and_attacking:
		# ... (lógica de perseguição)
		_process_auto_attack_movement()
	elif is_moving_to_click:
		# Lógica de Click-to-Move (Já processada acima, não faz nada aqui)
		pass
	else:
		# Processamento WASD Comum - SÓ SE NÃO ESTIVER CLICANDO PARA MOVER
		if direction:
			velocity.x = direction.x * move_speed
			velocity.z = direction.z * move_speed
		else:
			velocity.x = move_toward(velocity.x, 0, move_speed)
			velocity.z = move_toward(velocity.z, 0, move_speed)

	# --- Lógica de Animação de Movimento ---
	if not is_on_floor():
		_play_anim("jump")
	elif Vector2(velocity.x, velocity.z).length() > 0.1:
		if vitals_component and vitals_component.is_running:
			_play_anim("run")
		else:
			_play_anim("walk")
	else:
		if basic_attack_cooldown_timer <= 0: # Não cancela animação de ataque se estiver parado batendo
			_play_anim("idle")

	# Atualiza Rotação VISUAL (Malha 3D) baseada puramente na direção que o boneco anda
	if Vector2(velocity.x, velocity.z).length() > 0.1:
		var target_angle = atan2(velocity.x, velocity.z)
		# Gira o Capsule padrão
		$MeshInstance3D.global_rotation.y = lerp_angle($MeshInstance3D.global_rotation.y, target_angle, 15.0 * delta)
		# Gira o root de todos os modelos GLB
		if is_instance_valid(_visuals_root):
			_visuals_root.global_rotation.y = lerp_angle(_visuals_root.global_rotation.y, target_angle, 15.0 * delta)

	# Tempo de Cooldown correndo fora da condicional pra garantir recuperação universal
	if basic_attack_cooldown_timer > 0.0:
		basic_attack_cooldown_timer -= delta

	# Atualiza a barrinha de cooldown do botão de ataque na SkillBar
	hud_instance.skill_bar.update_attack_cooldown(basic_attack_cooldown_timer, basic_attack_interval)

	move_and_slide()
	
	# --- ENVIO DE MOVIMENTO PARA O SERVIDOR (NODE.JS) ---
	# Enviamos se houver input manual, clique no chão OU perseguição de mob
	if current_target: target_dist = global_position.distance_to(current_target.global_position)
	
	var is_pursuing = is_pursuing_and_attacking and target_dist > base_attack_range
	
	if input_dir.length() > 0 or is_moving_to_click or is_pursuing:
		var network_dir = direction
		if is_moving_to_click:
			network_dir = global_position.direction_to(click_target_position)
		elif is_pursuing:
			network_dir = global_position.direction_to(current_target.global_position)
		
		var is_running = vitals_component.is_running if vitals_component else false
		NetworkManager.send_move(network_dir, delta, is_running)
	
	NetworkManager.send_speed_sync()

# --- Sistema de Ataque Básico (Melee) ---
func perform_attack() -> void:
	if GameManager.is_safe_zone:
		print("[SafeZone] Ataques bloqueados nesta área.")
		return
		
	set_in_combat()
	
	if not current_target:
		print("Selecione um alvo primeiro (Tab)")
		return
		
	_play_anim("attack")
	
	var dist = global_position.distance_to(current_target.global_position)
	if dist <= base_attack_range:
		# Pega o ataque total do sistema de status centralizado
		var total_atk = StatusManager.get_total_status()["ataque"]
		
		print("Player AUTO ATAQUE em " + current_target.name + " com " + str(total_atk) + " de dano.")
		
		# Procura o componente de vida do alvo (pode ser Vitals ou Health)
		var target_vitals = current_target.get_node_or_null("VitalsComponent")
		if not target_vitals: target_vitals = current_target.get_node_or_null("HealthComponent")
		
		if target_vitals:
			# Calcula redução de defesa do alvo (se houver)
			var target_def = 10 # Padrão
			if current_target.has_method("get_stats"):
				target_def = current_target.get_stats().get("defesa", 10)
			
			var final_dmg = int(max(1, total_atk - target_def))
			
			# Sincronização Multiplayer: Notifica o servidor sobre o dano
			var victim_uid = current_target.get_meta("mob_uid", -1)
			if victim_uid != -1:
				NetworkManager.send_data({
					"type": "entity_damage",
					"victim_uid": victim_uid,
					"victim_type": "mob",
					"damage": final_dmg
				})
			
			target_vitals.take_damage(final_dmg, -1, self)
	else:
		print("Alvo está muito longe! (" + str(snapped(dist, 0.1)) + "m)")

func _give_initial_items():
	inventory_manager.add_item("espada_ferro", 1)
	inventory_manager.add_item("pote_hp_p", 20)
	inventory_manager.add_item("pote_sp_p", 10)
	_save_player_to_db()

func _save_player_to_db():
	var exp_data = ExperienceManager.get_data_to_save()
	var data_to_save = {
		"inventory": inventory_manager.get_inventory_data(),
		"level": exp_data["level"],
		"exp": exp_data["exp"]
	}
	AccountManager.update_character_data(GameManager.player_name, data_to_save)
	print("[DB] Progresso de ", GameManager.player_name, " salvo automaticamente.")

func update_movement_speed():
	var speed_val = MovementSpeedManager.get_speed()
	var bonus_pct = MovementSpeedManager.get_bonus_percent(speed_val)
	var multiplier = 1.0 + (bonus_pct / 100.0)
	
	# Velocidades base (RF costuma ser 5 e 12)
	walk_speed = 5.0 * multiplier
	run_speed = 12.0 * multiplier
	
	print("[Player] Velocidade atualizada: Walk=", walk_speed, " Run=", run_speed, " (", bonus_pct, "%)")

func update_attack_speed():
	var speed_val = AttackSpeedManager.get_attack_speed()
	var bonus_pct = AttackSpeedManager.get_bonus_percent(speed_val)
	var multiplier = 1.0 + (bonus_pct / 100.0)
	
	# Intervalo base é 1.0 segundo. Mais velocidade = Menos tempo de espera.
	basic_attack_interval = 1.0 / multiplier
	
	print("[Player] Vel. Ataque atualizada: Intervalo=", basic_attack_interval, "s (", bonus_pct, "%)")

# ==========================================
# ====== SISTEMA DE SKIN 3D (MODELOS) ======
# ==========================================
var _models: Dictionary = {}
var _anim_players: Dictionary = {}
var _current_model: Node = null
var _current_anim_state: String = ""
var _visuals_root: Node3D = null

func _load_visual_model(p_class_id: String) -> void:
	if not _visuals_root:
		_visuals_root = Node3D.new()
		add_child(_visuals_root)
		
	var raw_class = p_class_id.to_lower()
	var archetype = StatusManager.CLASS_MAPPING.get(raw_class, "melee")
	var class_data = StatusManager.all_class_configs.get(archetype, {})
	
	# Tenta pegar base configs
	var base_data = class_data.get("base", {}) if not class_data.is_empty() else {}
	
	# Pega os caminhos (Fallback para vazio se não existir)
	var path_idle = base_data.get("visual_path", "")
	var path_walk = base_data.get("visual_path_walk", path_idle)
	var path_run = base_data.get("visual_path_run", path_walk)
	var path_attack = base_data.get("visual_path_attack", path_idle)
	var path_die = base_data.get("visual_path_die", path_idle)
	var path_jump = base_data.get("visual_path_jump", path_idle)
	
	if path_idle == "":
		print("[Player Skin] Nenhuma skin definida em class_configs.json para a classe: ", archetype)
		return
		
	print("[Player Skin] Carregando skins para a classe: ", archetype)
	
	var s: float = float(base_data.get("escala", 1.0))
	var oy: float = float(base_data.get("visual_offset_y", 0.0))
	var ry: float = float(base_data.get("visual_rotation_y", 0.0))
	
	_load_and_add_model("idle", path_idle, s, oy, ry)
	_load_and_add_model("walk", path_walk, s, oy, ry)
	_load_and_add_model("run", path_run, s, oy, ry)
	_load_and_add_model("attack", path_attack, s, oy, ry)
	_load_and_add_model("die", path_die, s, oy, ry)
	_load_and_add_model("jump", path_jump, s, oy, ry)
	
	# Oculta cápsula de fallback
	if visual_mesh:
		visual_mesh.visible = false
	
	call_deferred("_setup_animations_deferred")

func _load_and_add_model(state_key: String, path: String, s: float, oy: float, ry: float) -> void:
	if path == "": return
	
	# Reutilizar
	var existing_model = null
	for k in _models.keys():
		if _models[k].has_meta("model_path") and _models[k].get_meta("model_path") == path:
			existing_model = _models[k]
			break
			
	if existing_model:
		_models[state_key] = existing_model
		return
		
	var model_res = load(path)
	if not model_res: return
		
	var model_instance: Node = null
	if model_res is PackedScene:
		model_instance = model_res.instantiate()
	else:
		var gltf = GLTFDocument.new()
		var state = GLTFState.new()
		if gltf.append_from_file(path, state) == OK:
			model_instance = gltf.generate_scene(state)
			
	if model_instance:
		_visuals_root.add_child(model_instance)
		_force_show_all(model_instance)
		model_instance.visible = false
		model_instance.set_meta("model_path", path)
		
		model_instance.scale = Vector3(s, s, s)
		model_instance.rotation_degrees.y = ry
		model_instance.position.y = oy
		
		_models[state_key] = model_instance

func _setup_animations_deferred() -> void:
	for state_key in _models:
		var model = _models[state_key]
		if not _anim_players.has(model):
			var queue: Array = [model]
			var player = null
			while queue.size() > 0:
				var current = queue.pop_front()
				if current is AnimationPlayer:
					player = current
					break
				for child in current.get_children():
					queue.append(child)
			if player:
				_anim_players[model] = player
				
	_play_anim("idle")

func _force_show_all(node: Node) -> void:
	if node is GeometryInstance3D:
		var gi = node as GeometryInstance3D
		gi.visible = true
		gi.layers = 1
		gi.visibility_range_begin = 0.0
		gi.visibility_range_end = 0.0
		gi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	elif node is VisualInstance3D:
		(node as VisualInstance3D).visible = true
		(node as VisualInstance3D).layers = 1
	for child in node.get_children():
		_force_show_all(child)

func _play_anim(anim_name: String) -> void:
	# Trava a animação de pulo para que ela toque até o final, mesmo se encostar no chão
	if _current_anim_state == "jump" and anim_name != "jump" and anim_name != "die":
		var current_player: AnimationPlayer = _anim_players.get(_current_model)
		if current_player and current_player.is_playing():
			return

	# Evita resetar a mesma animação
	if _current_anim_state == anim_name and anim_name != "attack":
		return
		
	var target_model = _models.get(anim_name)
	if not target_model:
		target_model = _models.get("idle")
	if not target_model: return
	
	if _current_model and _current_model != target_model:
		_current_model.visible = false
	target_model.visible = true
	_current_model = target_model
	_current_anim_state = anim_name
	
	var player: AnimationPlayer = _anim_players.get(target_model)
	if not player: return
	
	var list = player.get_animation_list()
	if list.size() == 0: return
	
	var actual_anim = ""
	
	var keywords: Array = []
	match anim_name:
		"idle":   keywords = ["IDLE", "WAIT", "STAND"]
		"walk":   keywords = ["WALK", "MOV", "PEACEWALK"]
		"run":    keywords = ["RUN", "SPRINT", "DASH"]
		"attack": keywords = ["ATTACK", "HIT", "STRIKE", "PUNCH", "COMBO"]
		"die":    keywords = ["DIE", "DEATH", "DEAD"]
		"jump":   keywords = ["JUMP", "FALL", "AIR"]
	
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
		if anim_name == "idle" or anim_name == "walk" or anim_name == "run":
			anim.loop_mode = Animation.LOOP_LINEAR
		else:
			anim.loop_mode = Animation.LOOP_NONE
		
		# Reinicia a animação sempre que for disparada uma nova (principalmente pulo e ataque)
		if anim_name == "attack" or anim_name == "jump" or anim_name == "die":
			player.stop()
			
		player.play(actual_anim)
