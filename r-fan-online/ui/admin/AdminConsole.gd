extends CanvasLayer

@onready var panel: Panel = $Panel
@onready var history: RichTextLabel = $Panel/VBoxContainer/History
@onready var input_line: LineEdit = $Panel/VBoxContainer/InputLine
@onready var suggestion_label: Label = $Panel/VBoxContainer/SuggestionLabel

func _ready() -> void:
	panel.visible = false
	input_line.text_submitted.connect(_on_text_submitted)
	input_line.text_changed.connect(_on_text_changed)
	input_line.gui_input.connect(_on_input_gui_input)

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		# Tecla aspas simples/apóstrofo (')
		if event.keycode == KEY_APOSTROPHE or event.keycode == KEY_QUOTELEFT:
			toggle_console()
			get_viewport().set_input_as_handled()

func toggle_console() -> void:
	panel.visible = !panel.visible
	if panel.visible:
		input_line.grab_focus()
		input_line.clear()
		suggestion_label.text = ""
	else:
		input_line.release_focus()

func print_to_console(msg: String, color: String = "white") -> void:
	history.text += "\n[color=" + color + "]" + msg + "[/color]"

func _on_text_changed(new_text: String) -> void:
	# Sistema de Autocomplete para itens
	suggestion_label.text = ""
	var parts = new_text.split(" ", false)
	if parts.size() >= 2 and parts[0].to_lower() == "item":
		var search_id = parts[1].to_lower()
		var matches = []
		for item_id in ItemDatabase.ITEMS.keys():
			if item_id.begins_with(search_id):
				matches.append(item_id)
		
		if matches.size() > 0:
			suggestion_label.text = "Sugestão (Pressione TAB): " + ", ".join(matches)

# A melhor forma de tratar o TAB no LineEdit sem perder foco é checar na gui_input dele
func _on_input_gui_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and event.keycode == KEY_TAB:
		get_viewport().set_input_as_handled() # Bloqueia mudar o foco do input
		_apply_autocomplete()

func _apply_autocomplete() -> void:
	var text = input_line.text
	var parts = text.split(" ", false)
	if parts.size() >= 2 and parts[0].to_lower() == "item":
		var search_id = parts[1].to_lower()
		for item_id in ItemDatabase.ITEMS.keys():
			if item_id.begins_with(search_id):
				# Aplica o autocomplete com o primeiro resultado
				input_line.text = "item " + item_id + " "
				input_line.caret_column = input_line.text.length()
				suggestion_label.text = ""
				return

func _on_text_submitted(new_text: String) -> void:
	if new_text.strip_edges() == "": return
	
	input_line.clear()
	suggestion_label.text = ""
	print_to_console("> " + new_text, "gray")
	
	var parts = new_text.split(" ", false)
	if parts.size() == 0: return
	
	var command = parts[0].to_lower()
	
	if command == "item":
		_cmd_item(parts)
	elif command == "clear":
		history.text = "[color=yellow]=== Painel Administrativo GM Iniciado ===[/color]"
	elif command == "help":
		print_to_console("Comandos disponíveis: item <id> <qtd>, clear, help", "cyan")
	else:
		print_to_console("Comando inválido: " + command, "red")

func _cmd_item(args: PackedStringArray) -> void:
	if args.size() < 3:
		print_to_console("Uso correto: item <id_item> <quantidade>", "red")
		return
		
	var item_id = args[1].to_lower()
	var amount = args[2].to_int()
	
	if amount <= 0:
		print_to_console("A quantidade deve ser maior que zero.", "red")
		return
		
	# 1. Validação no Banco de Dados Central
	var item_data = ItemDatabase.get_item(item_id)
	if item_data.is_empty():
		print_to_console("ERRO: Item '" + item_id + "' não encontrado no banco de dados.", "red")
		return
		
	# 2. Adição ao Inventário
	var inv_manager = get_tree().get_first_node_in_group("inventory_manager")
	if inv_manager:
		var rem = inv_manager.add_item(item_id, amount)
		if rem == amount:
			print_to_console("ERRO: Inventário cheio! Nenhum item adicionado.", "red")
		elif rem > 0:
			print_to_console("SUCESSO PARCIAL: Adicionado " + str(amount - rem) + "x " + item_data["nome"] + ". Sem espaço para o resto.", "yellow")
		else:
			print_to_console("SUCESSO: " + str(amount) + "x " + item_data["nome"] + " adicionado(s) ao inventário.", "green")
	else:
		print_to_console("ERRO INTERNO: InventoryManager não encontrado no mundo.", "red")
