extends Control

# ============================================================
# DADOS DAS RAÇAS E CLASSES
# ============================================================
const CLASSES_BY_RACE: Dictionary = {
	"Bellato": ["Warrior", "Ranger", "Spiritualist", "Specialist"],
	"Cora":    ["Warrior", "Ranger", "Spiritualist", "Specialist"],
	"Accretia":["Warrior", "Ranger", "Specialist"],
}

const RACE_COLORS: Dictionary = {
	"Bellato":  Color(0.3,  0.6,  1.0, 1.0),  # Azul
	"Cora":     Color(0.8,  0.2,  0.8, 1.0),  # Roxo
	"Accretia": Color(1.0,  0.2,  0.2, 1.0),  # Vermelho
}

const RACE_DESCRIPTIONS: Dictionary = {
	"Bellato":  "União Bellato\nOs engenheiros da galáxia.\nDominadores de mechas e tecnologia.",
	"Cora":     "Sagrada Cora\nServos da Deusa Bell.\nMestres das artes arcanas e espirituais.",
	"Accretia": "Império Accretia\nSeres de metal e aço.\nSem alma, mas com força inigualável.",
}

# ============================================================
# ESTADO
# ============================================================
var selected_race: String = ""
var selected_class: String = ""

# Referências dinâmicas aos botões criados por código
var race_buttons: Dictionary = {}
var class_buttons: Array = []

# ============================================================
# NÓS DA CENA
# ============================================================
@onready var race_container:       HBoxContainer   = $BG/Center/MainPanel/VBox/HBox/Left/RaceContainer
@onready var class_container:      VBoxContainer   = $BG/Center/MainPanel/VBox/HBox/Right/ClassScroll/ClassContainer
@onready var race_desc_label:      Label           = $BG/Center/MainPanel/VBox/HBox/Left/RaceDescLabel
@onready var name_input:           LineEdit        = $BG/Center/MainPanel/VBox/Bottom/NameRow/NameInput
@onready var play_button:          Button          = $BG/Center/MainPanel/VBox/Bottom/PlayButton
@onready var error_label:          Label           = $BG/Center/MainPanel/VBox/Bottom/ErrorLabel
@onready var class_scroll:         ScrollContainer = $BG/Center/MainPanel/VBox/HBox/Right/ClassScroll
@onready var selected_class_label: Label           = $BG/Center/MainPanel/VBox/HBox/Right/SelectedClassLabel

# ============================================================
# READY
# ============================================================
func _ready() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

	# Cria os 3 botões de raça dinamicamente
	for race in CLASSES_BY_RACE.keys():
		var btn = Button.new()
		btn.text = race
		btn.custom_minimum_size = Vector2(160, 70)
		btn.pressed.connect(_on_race_selected.bind(race))
		race_container.add_child(btn)
		race_buttons[race] = btn

	play_button.pressed.connect(_on_play_pressed)

	# Começa sem classe visível
	_clear_class_buttons()

# ============================================================
# SELEÇÃO DE RAÇA
# ============================================================
func _on_race_selected(race: String) -> void:
	selected_race = race
	selected_class = ""
	selected_class_label.text = "Classe: —"
	error_label.text = ""

	# Destaque visual dos botões de raça
	for r in race_buttons:
		var btn: Button = race_buttons[r]
		if r == race:
			btn.modulate = RACE_COLORS[r]
		else:
			btn.modulate = Color(1, 1, 1, 0.5)

	# Descrição da raça
	race_desc_label.text = RACE_DESCRIPTIONS[race]

	# Anima os botões de classe com slide
	_show_classes_with_slide(race)

# ============================================================
# ANIMAÇÃO DE SLIDE DAS CLASSES
# ============================================================
func _clear_class_buttons() -> void:
	for child in class_container.get_children():
		child.queue_free()
	class_buttons.clear()

func _show_classes_with_slide(race: String) -> void:
	_clear_class_buttons()
	var classes = CLASSES_BY_RACE[race]

	for i in range(classes.size()):
		var cls = classes[i]
		var btn = Button.new()
		btn.text = cls
		btn.custom_minimum_size = Vector2(200, 50)
		btn.pressed.connect(_on_class_selected.bind(cls, btn))
		class_container.add_child(btn)
		class_buttons.append(btn)

		# Começa fora da tela (à direita) e desliza para dentro
		btn.modulate = Color(1, 1, 1, 0)
		btn.position.x = 300.0

		var delay = i * 0.07  # cada botão com um pequeno atraso

		var tween = create_tween()
		tween.set_parallel(true)
		tween.tween_property(btn, "position:x", 0.0, 0.25) \
			.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT).set_delay(delay)
		tween.tween_property(btn, "modulate:a", 1.0, 0.2) \
			.set_ease(Tween.EASE_IN).set_delay(delay)

# ============================================================
# SELEÇÃO DE CLASSE
# ============================================================
func _on_class_selected(cls: String, pressed_btn: Button) -> void:
	selected_class = cls
	selected_class_label.text = "Classe: " + cls
	error_label.text = ""

	for btn in class_buttons:
		if btn == pressed_btn:
			btn.modulate = RACE_COLORS.get(selected_race, Color(1, 1, 0))
		else:
			btn.modulate = Color(1, 1, 1, 0.6)

# ============================================================
# JOGAR
# ============================================================
func _on_play_pressed() -> void:
	var final_name = name_input.text.strip_edges()

	if selected_race == "":
		error_label.text = "❌ Selecione uma raça!"
		return
	if selected_class == "":
		error_label.text = "❌ Selecione uma classe!"
		return
	if final_name == "":
		error_label.text = "❌ Digite um nome para o personagem!"
		return
	if final_name.length() < 3:
		error_label.text = "❌ O nome precisa ter pelo menos 3 letras!"
		return

	# Salva no Singleton
	GameManager.player_name  = final_name
	GameManager.player_race  = selected_race
	GameManager.player_class = selected_class

	# Entra no jogo
	get_tree().change_scene_to_file("res://levels/TestWorld.tscn")
