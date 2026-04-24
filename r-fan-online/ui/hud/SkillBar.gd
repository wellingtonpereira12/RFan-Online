extends Control

@onready var slots_container: HBoxContainer = $SlotsContainer
var action_slot_scene = preload("res://ui/hud/ActionSlot.tscn")

var slots: Array = []
var is_locked: bool = true
var is_running: bool = true
var is_auto_attack: bool = true
var atk_cooldown_bar: ProgressBar = null

signal action_triggered(slot_index: int)
signal run_mode_changed(is_run: bool)
signal auto_attack_changed(is_auto: bool)
signal skills_pressed()

func _ready() -> void:
	# Montador Dinâmico de Vagas (Gera visualmente 1 a 0)
	for i in range(1, 11):
		var slot = action_slot_scene.instantiate()
		slots_container.add_child(slot)
		slots.append(slot)
		
		# Ajusta os mapeamentos visuais F1, F2, ... F10
		var key_str = "F" + str(i)
			
		slot.setup(i, key_str)
		slot.is_locked = self.is_locked
		slot.slot_dragged.connect(_on_slot_dragged)
		slot.action_requested.connect(_on_action_requested)
		slot.inventory_item_dropped.connect(_on_inventory_item_dropped)

	# --- Botão de Correr/Andar (esquerda da barra, 2a posição) ---
	var run_btn = Button.new()
	run_btn.name = "RunButton"
	run_btn.toggle_mode = true
	run_btn.text = "🏃"
	run_btn.tooltip_text = "Correndo (clique para andar)"
	run_btn.button_pressed = true
	run_btn.focus_mode = Control.FOCUS_NONE
	run_btn.toggled.connect(_on_run_btn_toggled)
	self.add_child(run_btn)
	run_btn.position = Vector2(-115, 10)

	# --- Botão de Ataque Auto/Manual (esquerda da barra, 1a posição) ---
	var atk_btn = Button.new()
	atk_btn.name = "AtkButton"
	atk_btn.toggle_mode = true
	atk_btn.text = "⚔️ A"
	atk_btn.tooltip_text = "Ataque AUTO (clique para manual)"
	atk_btn.button_pressed = true
	atk_btn.focus_mode = Control.FOCUS_NONE
	atk_btn.toggled.connect(_on_atk_btn_toggled)
	self.add_child(atk_btn)
	atk_btn.position = Vector2(-75, 10)

	# --- Barrinha de Cooldown de Ataque (sob o AtkButton) ---
	atk_cooldown_bar = ProgressBar.new()
	atk_cooldown_bar.max_value = 1.0
	atk_cooldown_bar.value = 1.0
	atk_cooldown_bar.show_percentage = false
	atk_cooldown_bar.custom_minimum_size = Vector2(37, 5)
	atk_cooldown_bar.size = Vector2(37, 5)
	atk_cooldown_bar.position = Vector2(-75, 40)
	atk_cooldown_bar.modulate = Color(0.2, 1.0, 0.3, 1) # Verde brilhante
	self.add_child(atk_cooldown_bar)

	# --- Criando o Botão de Cadeado via Código ---
	var lock_btn = Button.new()
	lock_btn.name = "LockButton"
	lock_btn.toggle_mode = true
	lock_btn.text = "🔒"
	lock_btn.button_pressed = true # Começa apertado (Fechado)
	lock_btn.focus_mode = Control.FOCUS_NONE # Evita roubar o foco
	lock_btn.toggled.connect(_on_lock_button_toggled)
	
	# Adiciona ao SkillBar (fora do HBoxContainer) para não quebrar o layout!
	self.add_child(lock_btn)
	# Posiciona ao lado direito da barra
	lock_btn.position = Vector2(size.x + 5, 10)

	# --- Criando o Botão da Bolsinha de Inventário ---
	var bag_btn = Button.new()
	bag_btn.text = "🎒"
	bag_btn.focus_mode = Control.FOCUS_NONE
	bag_btn.pressed.connect(_on_bag_button_pressed)
	self.add_child(bag_btn)
	# Posiciona ao lado do cadeado (lock_btn tem uns 30px de largura)
	bag_btn.position = Vector2(size.x + 40, 10)

	# --- Botão de Equipamentos ---
	var equip_btn = Button.new()
	equip_btn.text = "🛡"
	equip_btn.tooltip_text = "Equipamentos (E)"
	equip_btn.focus_mode = Control.FOCUS_NONE
	equip_btn.pressed.connect(_on_equip_button_pressed)
	self.add_child(equip_btn)
	equip_btn.position = Vector2(size.x + 75, 10)

	# --- Botão de Macro Settings ---
	var macro_btn = Button.new()
	macro_btn.text = "⚙️" # Ícone de engrenagem para Macro/Settings
	macro_btn.tooltip_text = "Macro Settings (Y)"
	macro_btn.focus_mode = Control.FOCUS_NONE
	macro_btn.pressed.connect(_on_macro_button_pressed)
	self.add_child(macro_btn)
	macro_btn.position = Vector2(size.x + 110, 10)

	# --- Botão de Skills (Emoji) ---
	var skills_btn = Button.new()
	skills_btn.text = "⚔️" 
	skills_btn.tooltip_text = "Habilidades (B)"
	skills_btn.focus_mode = Control.FOCUS_NONE
	skills_btn.pressed.connect(func(): skills_pressed.emit())
	self.add_child(skills_btn)
	skills_btn.position = Vector2(size.x + 145, 10)

	# --- BOTÕES DE SISTEMA FINALIZADOS ---

func _on_lock_button_toggled(toggled_on: bool) -> void:
	toggle_lock(toggled_on)
	var btn = get_node_or_null("LockButton")
	if btn:
		if toggled_on:
			btn.text = "🔒"
		else:
			btn.text = "🔓"

func _on_bag_button_pressed() -> void:
	var inventory = get_tree().get_first_node_in_group("inventory_ui")
	if inventory:
		inventory.visible = !inventory.visible
	else:
		print("Inventário não encontrado!")

func _on_equip_button_pressed() -> void:
	var equip_ui = get_tree().get_first_node_in_group("equipment_ui")
	if equip_ui:
		equip_ui.visible = !equip_ui.visible
	else:
		print("EquipmentUI não encontrado!")

func _on_macro_button_pressed() -> void:
	var macro_ui = get_tree().get_first_node_in_group("macro_ui")
	if macro_ui:
		macro_ui.visible = !macro_ui.visible
	else:
		print("MacroUI não encontrado!")

func _on_run_btn_toggled(pressed: bool) -> void:
	is_running = pressed
	var btn = get_node_or_null("RunButton")
	if btn:
		btn.text = "🏃" if pressed else "🚶"
		btn.tooltip_text = "Correndo (clique para andar)" if pressed else "Andando (clique para correr)"
	run_mode_changed.emit(pressed)

func _on_atk_btn_toggled(pressed: bool) -> void:
	is_auto_attack = pressed
	var btn = get_node_or_null("AtkButton")
	if btn:
		btn.text = "⚔️ A" if pressed else "⚔️ M"
		btn.tooltip_text = "Ataque AUTO (clique para manual)" if pressed else "Ataque MANUAL (clique para auto)"
	auto_attack_changed.emit(pressed)

func update_attack_cooldown(timer: float, max_time: float) -> void:
	if atk_cooldown_bar == null: return
	if max_time <= 0.0:
		atk_cooldown_bar.value = 1.0
		return
	# ratio 0.0 = recarregando, 1.0 = pronto
	var ratio = 1.0 - clamp(timer / max_time, 0.0, 1.0)
	atk_cooldown_bar.value = ratio
	# Cor: vermelho (recarregando) -> amarelo -> verde (pronto)
	var r = 1.0 - ratio
	var g = ratio
	atk_cooldown_bar.modulate = Color(r, g, 0.1, 1.0)

func toggle_lock(locked: bool) -> void:
	is_locked = locked
	for slot in slots:
		slot.is_locked = locked

func set_slot_action(index: int, resource: Resource) -> void:
	if index >= 1 and index <= 10:
		slots[index - 1].set_action(resource)

func trigger_cooldown(index: int, duration: float) -> void:
	if index >= 1 and index <= 10:
		slots[index - 1].trigger_cooldown(duration)

func _on_action_requested(index: int) -> void:
	action_triggered.emit(index)

# Permuta Orgânica de Drag and Drop (Sem precisar tocar no Backend por enquanto)
func _on_slot_dragged(from_index: int, to_index: int) -> void:
	if from_index == to_index: return
	
	var from_slot = slots[from_index - 1]
	var to_slot = slots[to_index - 1]
	
	if from_slot.is_on_cooldown or to_slot.is_on_cooldown:
		return
	
	var temp_data = to_slot.action_data
	
	to_slot.set_action(from_slot.action_data)
	from_slot.set_action(temp_data)

# Varredor de Teclado Global
func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		# Filtra teclas F1 a F10
		for i in range(1, 11):
			if event.keycode == OS.find_keycode_from_string("F" + str(i)):
				_try_trigger_slot(i)
				return

func _try_trigger_slot(index: int) -> void:
	var slot = slots[index - 1]
	if slot.action_data and not slot.is_on_cooldown:
		action_triggered.emit(index)

func _on_inventory_item_dropped(item: Variant, to_index: int) -> void:
	# Previne duplicatas de itens do mesmo tipo na barra
	for slot in slots:
		if slot.action_data != null:
			if typeof(slot.action_data) == typeof(item) and slot.action_data == item:
				slot.clear_slot()
			elif typeof(item) == TYPE_DICTIONARY and typeof(slot.action_data) == TYPE_DICTIONARY and item.get("id") == slot.action_data.get("id"):
				slot.clear_slot()
			elif typeof(item) != TYPE_DICTIONARY and typeof(slot.action_data) != TYPE_DICTIONARY and item.get("skill_name") != null and slot.action_data.get("skill_name") != null and item.get("skill_name") == slot.action_data.get("skill_name"):
				slot.clear_slot()

	# Define o item no novo slot
	slots[to_index - 1].set_action(item)

func _process(_delta: float) -> void:
	# Sincroniza as quantidades dos itens na barra de atalhos (espelho do inventário)
	var inv_manager = get_tree().get_first_node_in_group("inventory_manager") if get_tree().has_group("inventory_manager") else get_node_or_null("../../InventoryManager")
	# Nota: para ser mais robusto, no Player.gd podemos adicionar add_to_group("inventory_manager")
	
	if inv_manager:
		# Conta totais de cada ID no inventário
		var item_counts = {}
		for slot in inv_manager.slots:
			if slot["id"] != "":
				var id = slot["id"]
				if not item_counts.has(id):
					item_counts[id] = 0
				item_counts[id] += slot["amount"]
				
		# Atualiza a interface gráfica dos atalhos
		for slot in slots:
			if typeof(slot.action_data) == TYPE_DICTIONARY and slot.action_data.has("id"):
				var total = item_counts.get(slot.action_data["id"], 0)
				if total > 0:
					if slot.amount_label:
						slot.amount_label.visible = true
						slot.amount_label.text = str(total)
				else:
					# Acabou o item!
					slot.clear_slot()
			else:
				if slot.amount_label:
					slot.amount_label.visible = false
