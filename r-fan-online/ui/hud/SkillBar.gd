extends Control

@onready var slots_container: HBoxContainer = $SlotsContainer
var action_slot_scene = preload("res://ui/hud/ActionSlot.tscn")

var slots: Array = []
var is_locked: bool = true # Inicia travada por padrão, como nos MMOs
signal action_triggered(slot_index: int)

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

	# --- CRIAR SKILLS DE TESTE PARA VOCÊ PODER ARRASTAR ---
	var fake_skill1 = SkillResource.new()
	fake_skill1.skill_name = "Ataque Básico"
	fake_skill1.cooldown = 1.0
	set_slot_action(1, fake_skill1)
	
	var fake_skill2 = SkillResource.new()
	fake_skill2.skill_name = "Pote de HP"
	fake_skill2.cooldown = 2.0
	set_slot_action(2, fake_skill2)

func _on_lock_button_toggled(toggled_on: bool) -> void:
	toggle_lock(toggled_on)
	var btn = get_node_or_null("LockButton")
	if btn:
		if toggled_on:
			btn.text = "🔒"
		else:
			btn.text = "🔓"

func _on_bag_button_pressed() -> void:
	# Busca o inventário de forma global na cena para não errar o caminho!
	var inventory = get_tree().get_first_node_in_group("inventory_ui")
	if inventory:
		inventory.visible = !inventory.visible
	else:
		print("Inventário não encontrado na tela! Lembre de adicionar a cena InventoryUI.tscn no seu jogo!")

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
