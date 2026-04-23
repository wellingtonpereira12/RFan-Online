extends Control

@onready var btn_cora: Button = $CenterContainer/VBoxContainer/RaceButtons/BtnCora
@onready var btn_bellato: Button = $CenterContainer/VBoxContainer/RaceButtons/BtnBellato
@onready var btn_accretia: Button = $CenterContainer/VBoxContainer/RaceButtons/BtnAccretia
@onready var name_input: LineEdit = $CenterContainer/VBoxContainer/NameContainer/NameInput
@onready var error_label: Label = $CenterContainer/VBoxContainer/ErrorLabel
@onready var play_button: Button = $CenterContainer/VBoxContainer/PlayButton

var selected_race: String = ""

func _ready() -> void:
	# Ocultar o InputMap do Mouse caso estivesse escondido por falha
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	
	# Usando binds para conectar com argumentos
	btn_cora.pressed.connect(_on_race_selected.bind("Cora"))
	btn_bellato.pressed.connect(_on_race_selected.bind("Bellato"))
	btn_accretia.pressed.connect(_on_race_selected.bind("Accretia"))
	
	play_button.pressed.connect(_on_play_button_pressed)

func _on_race_selected(race: String) -> void:
	selected_race = race
	error_label.text = ""
	
	# Feedback Visual super arrojado com Color Modulate nas interfaces
	btn_cora.modulate = Color(1, 1, 1, 1)        # Reset Branco
	btn_bellato.modulate = Color(1, 1, 1, 1)     # Reset Branco
	btn_accretia.modulate = Color(1, 1, 1, 1)    # Reset Branco
	
	match race:
		"Cora": 
			btn_cora.modulate = Color(0.8, 0.2, 0.8) # Roxo Majestoso
		"Bellato": 
			btn_bellato.modulate = Color(0.3, 0.6, 1.0) # Azul Esperança
		"Accretia": 
			btn_accretia.modulate = Color(1.0, 0.2, 0.2) # Vermelho Máquina

func _on_play_button_pressed() -> void:
	var final_name = name_input.text.strip_edges()
	
	if selected_race == "":
		error_label.text = ">>> ERRO: Por favor, selecione uma Raça!"
		return
		
	if final_name == "":
		error_label.text = ">>> ERRO: Seu Herói precisa de um Nome!"
		return
		
	# Mágica Global! Salvamos no Singleton antes de destruir o Menu
	GameManager.player_race = selected_race
	GameManager.player_name = final_name
	
	# Troca graciosamente de Cenário
	get_tree().change_scene_to_file("res://levels/TestWorld.tscn")
