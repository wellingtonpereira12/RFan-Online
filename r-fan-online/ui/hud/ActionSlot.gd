extends Panel

@onready var icon_title: Label = $IconTitle
@onready var keybind_label: Label = $KeybindLabel
@onready var cooldown_overlay: ColorRect = $CooldownOverlay
@onready var cooldown_label: Label = $CooldownLabel
@onready var color_rect: ColorRect = $IconRect
@onready var amount_label: Label = $AmountLabel

var slot_index: int = 1
var action_data: Variant = null # Flexível (SkillResource ou Dictionary de Item)
var is_on_cooldown: bool = false
var max_cooldown: float = 0.0
var current_cooldown: float = 0.0

signal slot_dragged(from_index: int, to_index: int)
signal action_requested(index: int)
signal inventory_item_dropped(data: Variant, target_index: int)

func setup(index: int, key_text: String) -> void:
	slot_index = index
	keybind_label.text = key_text
	cooldown_overlay.anchor_top = 1.0
	clear_slot()

func set_action(data: Variant) -> void:
	action_data = data
	if data != null and typeof(data) != TYPE_NIL and (typeof(data) == TYPE_OBJECT or typeof(data) == TYPE_DICTIONARY):
		if typeof(data) == TYPE_DICTIONARY:
			icon_title.text = data.get("nome", "Item/Ação")
		else:
			if data.get("skill_name") != null:
				icon_title.text = data.get("skill_name")
			elif data.get("name") != null:
				icon_title.text = data.get("name")
			else:
				icon_title.text = "Item/Ação"
		
		color_rect.color = Color(0.2, 0.4, 0.6, 1) # Slot preenchido fica azul escuro
	else:
		clear_slot()

func clear_slot() -> void:
	action_data = null
	icon_title.text = ""
	color_rect.color = Color(0.15, 0.15, 0.15, 1)
	is_on_cooldown = false
	current_cooldown = 0.0
	cooldown_overlay.anchor_top = 1.0
	cooldown_label.visible = false
	if amount_label: amount_label.visible = false

func trigger_cooldown(time: float) -> void:
	if action_data == null: return
	is_on_cooldown = true
	max_cooldown = time
	current_cooldown = time
	cooldown_overlay.anchor_top = 0.0 # Filtro preto preenche 100% (Subindo a âncora Top pra 0)
	cooldown_label.visible = true

func _process(delta: float) -> void:
	if is_on_cooldown:
		current_cooldown -= delta
		if current_cooldown <= 0.0:
			is_on_cooldown = false
			current_cooldown = 0.0
			cooldown_overlay.anchor_top = 1.0
			cooldown_label.visible = false
		else:
			# Escalonamento da altura da sombra do Cooldown estilo LoL/RF
			cooldown_overlay.anchor_top = 1.0 - (current_cooldown / max_cooldown)
			cooldown_label.text = str(snapped(current_cooldown, 0.1))

var is_locked: bool = false # Controlado pela SkillBar
var is_dragging: bool = false # Flag para saber se este slot iniciou o drag

# --- Drag and Drop Logic Nativa do Godot ---
func _get_drag_data(_at_position: Vector2) -> Variant:
	if is_locked or action_data == null or is_on_cooldown: return null
	
	# Preview Flutuário grudado no mouse
	var preview_label = Label.new()
	preview_label.text = icon_title.text
	var ctrl = Control.new()
	ctrl.add_child(preview_label)
	preview_label.position = Vector2(-20, -20)
	set_drag_preview(ctrl)
	
	is_dragging = true
	return {"type": "action_slot", "from_index": slot_index, "data": action_data}

func _notification(what: int) -> void:
	if what == NOTIFICATION_DRAG_END:
		if is_dragging:
			is_dragging = false
			# Se o drag não foi bem sucedido (soltou no vazio, ou na bolsa que não aceita drops), ele apaga o atalho!
			if not get_viewport().gui_is_drag_successful():
				clear_slot()

func _can_drop_data(_at_position: Vector2, data: Variant) -> bool:
	if is_on_cooldown: return false
	if typeof(data) != TYPE_DICTIONARY or not data.has("type"): return false
	return data["type"] == "action_slot" or data["type"] == "inventory_slot"

func _drop_data(_at_position: Vector2, data: Variant) -> void:
	if data["type"] == "action_slot":
		slot_dragged.emit(data["from_index"], slot_index)
	elif data["type"] == "inventory_slot":
		# Avisa a SkillBar para gerenciar duplicatas e então setar a action
		inventory_item_dropped.emit(data["data"], slot_index)

# Clique Direto com o Mouse
func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_RIGHT:
			get_viewport().set_input_as_handled() # Impede que o Player capture o mouse
			
		if event.button_index == MOUSE_BUTTON_LEFT and not event.pressed:
			if action_data and not is_on_cooldown:
				action_requested.emit(slot_index)
