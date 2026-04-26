extends Control

@onready var char_list = $Center/VBox/CharList
@onready var create_new_btn = $Center/VBox/CreateNewBtn
@onready var logout_btn = $LogoutBtn

func _ready() -> void:
	create_new_btn.pressed.connect(_on_create_new_pressed)
	logout_btn.pressed.connect(func(): get_tree().change_scene_to_file("res://ui/menu/LoginUI.tscn"))
	
	_load_characters()

func _load_characters():
	# Limpa lista atual
	for child in char_list.get_children():
		child.queue_free()
	
	var acc = AccountManager.get_logged_in_account()
	var characters = acc.get("characters", [])
	
	if characters.size() == 0:
		# Se por algum motivo chegou aqui sem chars, redireciona
		_on_create_new_pressed()
		return
		
	for data in characters:
		_create_char_card(data)

func _create_char_card(data: Dictionary):
	var panel = PanelContainer.new()
	panel.custom_minimum_size = Vector2(200, 250)
	char_list.add_child(panel)
	
	var vbox = VBoxContainer.new()
	panel.add_child(vbox)
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_theme_constant_override("separation", 15)
	
	# Cor baseada na raça
	var race = data.get("race", "")
	var accent_color = Color(0.8, 0.8, 0.8)
	match race:
		"Cora": accent_color = Color(0.7, 0.4, 1.0)
		"Bellato": accent_color = Color(0.4, 0.7, 1.0)
		"Accretia": accent_color = Color(1.0, 0.4, 0.3)

	# Nome
	var name_lbl = Label.new()
	name_lbl.text = data.get("name", "Unknown")
	name_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_lbl.add_theme_font_size_override("font_size", 22)
	name_lbl.add_theme_color_override("font_color", accent_color)
	vbox.add_child(name_lbl)
	
	# Raça e Classe
	var info_lbl = Label.new()
	info_lbl.text = race + " - " + data.get("class", "")
	info_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	info_lbl.add_theme_color_override("font_color", Color(0.6, 0.6, 0.6))
	vbox.add_child(info_lbl)
	
	# Botão de Jogar
	var play_btn = Button.new()
	play_btn.text = "PLAY"
	play_btn.custom_minimum_size = Vector2(120, 40)
	play_btn.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	play_btn.pressed.connect(_on_play_character.bind(data))
	vbox.add_child(play_btn)

func _on_play_character(data: Dictionary):
	# Salva os dados no GameManager para o Player.gd ler ao carregar o mundo
	GameManager.player_name = data["name"]
	GameManager.player_race = data["race"]
	GameManager.player_class = data["class"]
	
	# Define o mapa inicial baseado na raça
	match data["race"]:
		"Accretia": GameManager.current_map_id = "accretia_hq"
		"Cora":     GameManager.current_map_id = "cora_hq"
		"Bellato":  GameManager.current_map_id = "bellato_hq"
		
	# Vai para o mundo principal (que gerencia o carregamento de mapas)
	get_tree().change_scene_to_file("res://world/World.tscn")

func _on_create_new_pressed():
	get_tree().change_scene_to_file("res://ui/menu/RaceSelection.tscn")
