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
		
		# Tecla ESC (Fecha se estiver aberto)
		elif event.keycode == KEY_ESCAPE and panel.visible:
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
	if parts.size() >= 2:
		var cmd = parts[0].to_lower().trim_prefix("/")
		var search_id = parts[1].to_lower()
		var matches = []
		
		if cmd == "item":
			for item_id in ItemDatabase.ITEMS.keys():
				if item_id.begins_with(search_id):
					matches.append(item_id)
		elif cmd == "mob":
			for mob_id in MobDatabase.MOBS.keys():
				if mob_id.begins_with(search_id):
					matches.append(mob_id)
		
		if matches.size() > 0:
			suggestion_label.text = "Sugestão (TAB): " + ", ".join(matches)

# A melhor forma de tratar o TAB no LineEdit sem perder foco é checar na gui_input dele
func _on_input_gui_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and event.keycode == KEY_TAB:
		get_viewport().set_input_as_handled() # Bloqueia mudar o foco do input
		_apply_autocomplete()

func _apply_autocomplete() -> void:
	var text = input_line.text
	var parts = text.split(" ", false)
	if parts.size() >= 2:
		var raw_cmd = parts[0]
		var cmd = raw_cmd.to_lower().trim_prefix("/")
		var search_id = parts[1].to_lower()
		
		if cmd == "item":
			for item_id in ItemDatabase.ITEMS.keys():
				if item_id.begins_with(search_id):
					input_line.text = raw_cmd + " " + item_id + " "
					input_line.caret_column = input_line.text.length()
					suggestion_label.text = ""
					return
		elif cmd == "mob":
			for mob_id in MobDatabase.MOBS.keys():
				if mob_id.begins_with(search_id):
					input_line.text = raw_cmd + " " + mob_id + " "
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
	
	var command = parts[0].to_lower().trim_prefix("/")
	
	if command == "item":
		_cmd_item(parts)
	elif command == "mob":
		_cmd_mob(parts)
	elif command == "reload":
		_cmd_reload(parts)
	elif command == "level":
		_cmd_level(parts)
	elif command == "addexp":
		_cmd_addexp(parts)
	elif command == "speed":
		_cmd_speed(parts)
	elif command == "attackspeed":
		_cmd_attackspeed(parts)
	elif command == "map":
		_cmd_map(parts)
	elif command == "pos":
		_cmd_pos(parts)
	elif command == "clear":
		history.text = "[color=yellow]=== Painel Administrativo GM Iniciado ===[/color]"
	elif command == "help" or command == "ajuda":
		print_to_console("=== Lista de Comandos Disponíveis (GM) ===", "yellow")
		print_to_console("/item <id> <quantidade> - Adiciona item ao seu inventário", "cyan")
		print_to_console("/mob <id> [quantidade] - Spawna mobs perto de você", "cyan")
		print_to_console("/level <valor> - Define ou altera seu nível (1-50)", "cyan")
		print_to_console("/addexp <valor> - Adiciona XP ao personagem", "cyan")
		print_to_console("/speed <1.0-7.0> - Ajusta a velocidade de movimento", "cyan")
		print_to_console("/attackspeed <1.0-7.0> - Ajusta a velocidade de ataque", "cyan")
		print_to_console("/map <id> - Teleporta para outro mapa", "cyan")
		print_to_console("/pos <x> <z> - Move para coordenadas específicas", "cyan")
		print_to_console("/reload mobs - Remove mobs do mapa e recarrega o mobs.json", "cyan")
		print_to_console("/clear - Limpa o histórico deste console", "cyan")
		print_to_console("/ajuda - Mostra esta lista", "cyan")
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

func _cmd_mob(args: PackedStringArray) -> void:
	# Aqui no futuro validar permissão de GM, por enquanto todos com acesso ao console podem usar.
	if args.size() < 2:
		print_to_console("Uso correto: /mob <key> [quantidade]", "red")
		return
		
	var mob_key = args[1].to_lower()
	
	if mob_key == "list":
		var mob_names = []
		for k in MobDatabase.MOBS.keys():
			mob_names.append(k + " (" + MobDatabase.MOBS[k]["nome"] + ")")
		print_to_console("Mobs disponíveis:\n" + "\n".join(mob_names), "cyan")
		return
	
	var amount = 1
	if args.size() >= 3:
		amount = args[2].to_int()
		
	# Limitar spam para não quebrar o jogo
	amount = clampi(amount, 1, 10)
	
	var mob_data = MobDatabase.get_mob(mob_key)
	if mob_data.is_empty():
		print_to_console("ERRO: Mob não cadastrado no banco de dados.", "red")
		return
		
	var player = get_tree().get_first_node_in_group("players")
	if not player:
		print_to_console("ERRO INTERNO: Player não encontrado no mundo para base de spawn.", "red")
		return
		
	var spawn_radius = 5.0
	
	for i in range(amount):
		var rand_x = randf_range(-spawn_radius, spawn_radius)
		var rand_z = randf_range(-spawn_radius, spawn_radius)
		var spawn_pos = player.global_position + Vector3(rand_x, 0, rand_z)
		
		# ENVIAR PARA O SERVIDOR PARA BROADCAST
		NetworkManager.send_data({
			"type": "admin_spawn_mob",
			"mob_id": mob_key,
			"pos": {"x": spawn_pos.x, "y": spawn_pos.y, "z": spawn_pos.z}
		})
		
	print_to_console("Solicitando spawn de %d x %s no servidor..." % [amount, mob_data["nome"]], "yellow")

func _cmd_reload(args: PackedStringArray) -> void:
	if args.size() < 2:
		print_to_console("Uso: /reload mobs", "red")
		return

	var target = args[1].to_lower()
	if target == "mobs":
		# 1. Remove todos os mobs vivos do mundo
		var enemies = get_tree().get_nodes_in_group("enemies")
		for e in enemies:
			e.queue_free()
		
		# 2. Recarrega o banco de dados do JSON
		MobDatabase.reload()
		print_to_console("SUCESSO: " + str(enemies.size()) + " mob(s) removido(s). MobDatabase recarregado! (" + str(MobDatabase.MOBS.size()) + " mobs)", "green")
	else:
		print_to_console("Alvo inválido. Uso: /reload mobs", "red")

func _cmd_level(args: PackedStringArray) -> void:
	if args.size() < 2:
		print_to_console("Uso correto: /level <valor> ou /level +1 ou /level -1", "red")
		return
		
	var val_str = args[1]
	var current_lv = ExperienceManager.current_level
	var new_lv = current_lv
	
	if val_str.begins_with("+"):
		new_lv += val_str.to_int()
	elif val_str.begins_with("-"):
		new_lv += val_str.to_int()
	else:
		new_lv = val_str.to_int()
	
	ExperienceManager.set_level(new_lv)
	print_to_console("SUCESSO: Nível atualizado para " + str(ExperienceManager.current_level), "green")

func _cmd_addexp(args: PackedStringArray) -> void:
	if args.size() < 2:
		print_to_console("Uso correto: /addexp <quantidade>", "red")
		return
		
	var amount = args[1].to_int()
	ExperienceManager.add_exp(amount)
	print_to_console("SUCESSO: Adicionado " + str(amount) + " de XP.", "green")

func _cmd_speed(args: PackedStringArray) -> void:
	if args.size() < 2:
		print_to_console("Uso correto: /speed <valor> (Ex: /speed 3.5)", "red")
		return
		
	var speed_val = args[1].to_float()
	var final_speed = MovementSpeedManager.set_speed(speed_val)
	var bonus_pct = MovementSpeedManager.get_bonus_percent(final_speed)
	
	print_to_console("SUCESSO: Velocidade ajustada para %.1f (+%d%%)" % [final_speed, bonus_pct], "green")
	
	# Mensagem no Chat para feedback visual ao jogador
	ChatManager.receive_message({
		"sender": "SISTEMA",
		"text": "Velocidade ajustada para [color=yellow]%.1f (+%d%%)[/color]" % [final_speed, bonus_pct],
		"race": GameManager.player_race,
		"channel": ChatManager.Channel.LOCAL
	})

func _cmd_attackspeed(args: PackedStringArray) -> void:
	if args.size() < 2:
		print_to_console("Uso correto: /attackspeed <valor> (Ex: /attackspeed 2.0)", "red")
		return
		
	var speed_val = args[1].to_float()
	var final_speed = AttackSpeedManager.set_attack_speed(speed_val)
	var bonus_pct = AttackSpeedManager.get_bonus_percent(final_speed)
	
	print_to_console("SUCESSO: Velocidade de ataque ajustada para %.1f (+%d%%)" % [final_speed, bonus_pct], "green")
	
	ChatManager.receive_message({
		"sender": "SISTEMA",
		"text": "Velocidade de ataque ajustada para [color=yellow]%.1f (+%d%%)[/color]" % [final_speed, bonus_pct],
		"race": GameManager.player_race,
		"channel": ChatManager.Channel.LOCAL
	})

func _cmd_map(args: PackedStringArray) -> void:
	if args.size() < 2:
		print_to_console("Uso: /map <id>", "red")
		return
	
	NetworkManager.send_data({
		"type": "admin_map",
		"target_map": args[1]
	})
	print_to_console("Solicitando teleporte para: " + args[1], "yellow")

func _cmd_pos(args: PackedStringArray) -> void:
	if args.size() < 3:
		print_to_console("Uso: /pos <x> <z>", "red")
		return
	
	NetworkManager.send_data({
		"type": "admin_pos",
		"x": args[1].to_float(),
		"z": args[2].to_float()
	})
	print_to_console("Solicitando nova posição: (" + args[1] + ", " + args[2] + ")", "yellow")
