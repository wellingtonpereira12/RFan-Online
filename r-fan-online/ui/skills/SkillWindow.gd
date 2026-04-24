extends Panel

@onready var skill_list = $VBox/Scroll/SkillList
@onready var melee_btn = $VBox/Tabs/MeleeBtn
@onready var range_btn = $VBox/Tabs/RangeBtn
@onready var force_btn = $VBox/Tabs/ForceBtn
@onready var elemental_tabs = $VBox/ElementalTabs

# Botões Elementais
@onready var elem_special_btn = $VBox/ElementalTabs/ElemSpecialBtn
@onready var elem_fire_btn = $VBox/ElementalTabs/ElemFireBtn
@onready var elem_water_btn = $VBox/ElementalTabs/ElemWaterBtn
@onready var elem_earth_btn = $VBox/ElementalTabs/ElemEarthBtn
@onready var elem_wind_btn = $VBox/ElementalTabs/ElemWindBtn

const SKILL_SLOT_SCENE_PATH = "res://ui/skills/SkillSlot.tscn"

# Variáveis para Movimentação
var is_dragging = false
var drag_offset = Vector2.ZERO

func _ready() -> void:
	visible = false
	melee_btn.pressed.connect(_on_melee_tab_pressed)
	range_btn.pressed.connect(_on_range_tab_pressed)
	force_btn.pressed.connect(_on_force_tab_pressed)
	
	# Conecta Elementais
	elem_special_btn.pressed.connect(func(): _update_force_list_by_race_type())
	elem_fire_btn.pressed.connect(func(): _update_list_by_type("force", "fire"))
	elem_water_btn.pressed.connect(func(): _update_list_by_type("force", "water"))
	elem_earth_btn.pressed.connect(func(): _update_list_by_type("force", "earth"))
	elem_wind_btn.pressed.connect(func(): _update_list_by_type("force", "wind"))
	
	# Conecta sinal para mover a janela
	gui_input.connect(_on_gui_input)
	
	# Ajusta UI por raça
	_setup_race_ui()
	
	# Carrega aba inicial
	_on_melee_tab_pressed()

func _setup_race_ui():
	var race = GameManager.player_race
	if race == "Accretia":
		force_btn.disabled = true
		force_btn.tooltip_text = "Essa raça não possui habilidades Force"
	elif race == "Bellato":
		elem_special_btn.text = "Holy"
	elif race == "Cora":
		elem_special_btn.text = "Dark"

func toggle():
	visible = !visible
	if visible:
		# Sempre que abrir, se for Accretia garante que não está na aba force
		if GameManager.player_race == "Accretia" and elemental_tabs.visible:
			_on_melee_tab_pressed()
		else:
			_update_current_tab()

func _update_current_tab():
	if elemental_tabs.visible:
		_on_force_tab_pressed()
	elif range_btn.button_pressed: # No Godot 4 Button doesn't have button_pressed unless toggle_mode
		pass # Por simplicidade vamos apenas resetar pra melee se houver dúvida
	else:
		_on_melee_tab_pressed()

func _on_melee_tab_pressed():
	elemental_tabs.visible = false
	_update_list("melee")

func _on_range_tab_pressed():
	elemental_tabs.visible = false
	_update_list("range")

func _on_force_tab_pressed():
	if GameManager.player_race == "Accretia":
		_on_melee_tab_pressed()
		return
	elemental_tabs.visible = true
	_update_force_list_by_race_type()

func _update_force_list_by_race_type():
	var race = GameManager.player_race
	var type = "holy" if race == "Bellato" else "dark"
	_update_list_by_type("force", type)

func _update_list(category: String):
	_clear_list()
	var skill_data_list = SkillDatabase.get_all_skills_by_category(category)
	_fill_list(skill_data_list)

func _update_list_by_type(category: String, type: String):
	_clear_list()
	var skill_data_list = SkillDatabase.get_skills_by_category_and_type(category, type)
	_fill_list(skill_data_list)

func _fill_list(skill_data_list: Array):
	var slot_scene = load(SKILL_SLOT_SCENE_PATH)
	for skill_data in skill_data_list:
		var slot = slot_scene.instantiate()
		skill_list.add_child(slot)
		slot.setup(skill_data)
		slot.skill_right_clicked.connect(_on_skill_right_clicked)

func _on_skill_right_clicked(skill_data: Dictionary):
	var players = get_tree().get_nodes_in_group("players")
	if players.size() > 0:
		var player = players[0]
		if player.has_node("CombatComponent"):
			player.get_node("CombatComponent").use_skill_directly(skill_data)

func _clear_list():
	for child in skill_list.get_children():
		child.queue_free()

func _input(event: InputEvent) -> void:
	if visible and event is InputEventKey and event.pressed:
		if event.keycode == KEY_ESCAPE:
			visible = false
			get_viewport().set_input_as_handled()

func _on_gui_input(event: InputEvent):
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			is_dragging = true
			drag_offset = get_global_mouse_position() - global_position
			move_to_front()
		else:
			is_dragging = false
	elif event is InputEventMouseMotion and is_dragging:
		global_position = get_global_mouse_position() - drag_offset
