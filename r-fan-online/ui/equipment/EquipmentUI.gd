extends Control
class_name EquipmentUI

var slot_scene = preload("res://ui/equipment/EquipmentSlotUI.tscn")

var equipment_manager: EquipmentManager
var slot_uis: Dictionary = {}

# Configuração visual: slot_name → [label, linha, coluna]
const SLOT_LAYOUT := [
	["head",        "Capacete",   1, 1],
	["body",        "Armadura",   2, 1],
	["weapon",      "Arma",       3, 0],
	["shield",      "Escudo",     3, 2],
	["boots",       "Botas",      4, 1],
	["accessory_1", "Acessório 1",5, 0],
	["accessory_2", "Acessório 2",5, 2],
	["accessory_3", "Acessório 3",6, 0],
	["accessory_4", "Acessório 4",6, 2],
]

func _ready() -> void:
	add_to_group("equipment_ui")
	visible = false

func setup(eq_manager: EquipmentManager) -> void:
	equipment_manager = eq_manager
	equipment_manager.equipment_changed.connect(_on_equipment_changed)
	_build_ui()

func _build_ui() -> void:
	# Painel de fundo
	var bg = Panel.new()
	bg.name = "Background"
	bg.custom_minimum_size = Vector2(220, 580)
	bg.position = Vector2(20, 20) # Posição padrão - pode ser arrastado
	add_child(bg)

	# Título
	var title = Label.new()
	title.text = "⚔ Equipamentos"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 14)
	title.set_anchors_preset(Control.PRESET_TOP_WIDE)
	title.offset_top = 8
	title.offset_bottom = 30
	title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bg.add_child(title)

	# Grid para os slots
	var grid = GridContainer.new()
	grid.columns = 3
	grid.add_theme_constant_override("h_separation", 8)
	grid.add_theme_constant_override("v_separation", 8)
	grid.position = Vector2(10, 36)
	bg.add_child(grid)

	# Preenche com 7 linhas x 3 colunas
	var cells: Array = []
	for r in range(7):
		for c in range(3):
			cells.append({"row": r, "col": c, "node": null})

	# Cria slots reais
	for entry in SLOT_LAYOUT:
		var s_name  = entry[0]
		var s_label = entry[1]
		var s_row   = entry[2]
		var s_col   = entry[3]

		var slot_ui: EquipmentSlotUI = slot_scene.instantiate()
		slot_ui.setup(s_name, s_label, equipment_manager)
		slot_ui.slot_clicked_right.connect(_on_slot_right_clicked)
		slot_uis[s_name] = slot_ui

		# Marca célula como ocupada
		for cell in cells:
			if cell["row"] == s_row and cell["col"] == s_col:
				cell["node"] = slot_ui
				break

	# Adiciona ao grid com espaçadores
	for cell in cells:
		if cell["node"] != null:
			grid.add_child(cell["node"])
		else:
			var spacer = Control.new()
			spacer.custom_minimum_size = Vector2(64, 64)
			grid.add_child(spacer)

	# Dragging do painel
	bg.gui_input.connect(_on_bg_gui_input)
	_drag_offset = Vector2.ZERO

var _dragging_panel: bool = false
var _drag_offset: Vector2 = Vector2.ZERO

func _on_bg_gui_input(event: InputEvent) -> void:
	var bg = get_node_or_null("Background")
	if bg == null: return
	
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_RIGHT:
		get_viewport().set_input_as_handled() # Impede rotação de câmera ao clicar no fundo da janela
		
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		_dragging_panel = event.pressed
		if event.pressed:
			_drag_offset = event.global_position - bg.global_position
			move_to_front()
	elif event is InputEventMouseMotion and _dragging_panel:
		bg.global_position = event.global_position - _drag_offset

func _on_equipment_changed(slot_name: String, item_id: String) -> void:
	if slot_uis.has(slot_name):
		slot_uis[slot_name].set_item(item_id)

func _on_slot_right_clicked(slot_name: String) -> void:
	# Clique direito no slot = desequipa e devolve ao inventário
	equipment_manager.unequip_item(slot_name)

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_E:
			visible = !visible
