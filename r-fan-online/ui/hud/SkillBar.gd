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

	# --- Criando o Botão de Cadeado via Código ---
	var lock_btn = Button.new()
	lock_btn.toggle_mode = true
	lock_btn.text = "🔒"
	lock_btn.button_pressed = true # Começa apertado (Fechado)
	lock_btn.focus_mode = Control.FOCUS_NONE # Evita roubar o foco
	lock_btn.toggled.connect(_on_lock_button_toggled)
	
	# Adiciona ao SkillBar (fora do HBoxContainer) para não quebrar o layout!
	self.add_child(lock_btn)
	# Posiciona ao lado direito da barra
	lock_btn.position = Vector2(size.x + 5, 10)

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
	var btn = get_child(get_child_count() - 1)
	if toggled_on:
		btn.text = "🔒"
	else:
		btn.text = "🔓"

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
