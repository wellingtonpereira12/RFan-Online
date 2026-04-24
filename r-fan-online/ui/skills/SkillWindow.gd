extends Panel

@onready var skill_list = $VBox/Scroll/SkillList
@onready var melee_btn = $VBox/Tabs/MeleeBtn
@onready var range_btn = $VBox/Tabs/RangeBtn

const SKILL_SLOT_SCENE_PATH = "res://ui/skills/SkillSlot.tscn"

# Variáveis para Movimentação
var is_dragging = false
var drag_offset = Vector2.ZERO

func _ready() -> void:
	visible = false
	melee_btn.pressed.connect(_on_melee_tab_pressed)
	range_btn.pressed.connect(_on_range_tab_pressed)
	
	# Conecta sinal para mover a janela
	gui_input.connect(_on_gui_input)
	
	# Carrega aba inicial
	_on_melee_tab_pressed()

func toggle():
	visible = !visible
	if visible:
		_on_melee_tab_pressed() # Atualiza lista ao abrir

func _on_melee_tab_pressed():
	_update_list("melee")

func _on_range_tab_pressed():
	_update_list("range")

func _update_list(category: String):
	_clear_list()
	var skill_data_list = SkillDatabase.get_all_skills_by_category(category)
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
			# Garante que a janela fique por cima ao clicar
			move_to_front()
		else:
			is_dragging = false
	elif event is InputEventMouseMotion and is_dragging:
		global_position = get_global_mouse_position() - drag_offset
