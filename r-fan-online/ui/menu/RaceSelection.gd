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
	"Bellato":  "The Bellato Union\nMasters of technology and massive mechas. They combine engineering with tactical prowess.",
	"Cora":     "The Holy Cora\nDevoted servants of the Goddess Decem. They wield pure spiritual energy and destructive magic.",
	"Accretia": "The Accretia Empire\nA cold civilization of steel and circuitry. Powerful cyborgs built for absolute conquest.",
}

# ============================================================
# ESTADO
# ============================================================
var selected_race: String = ""
var selected_class: String = ""
var race_buttons: Dictionary = {}
var class_buttons: Array = []

# ============================================================
# NÓS DA CENA
# ============================================================
@onready var main_panel:     PanelContainer = $BG/Center/MainPanel
@onready var title_bar:      Panel          = $BG/Center/MainPanel/VBox/TitleBar
@onready var portrait_glow:  ColorRect      = $BG/Center/MainPanel/VBox/HBox/Left/PortraitPanel/CharPortrait/Glow
@onready var race_container: HBoxContainer  = $BG/Center/MainPanel/VBox/HBox/Left/RaceContainer
@onready var race_desc_label: Label         = $BG/Center/MainPanel/VBox/HBox/Left/RaceDescBox/RaceDescLabel
@onready var class_container: VBoxContainer = $BG/Center/MainPanel/VBox/HBox/Right/ClassScroll/ClassContainer
@onready var selected_class_label: Label    = $BG/Center/MainPanel/VBox/HBox/Right/SelectedClassLabel
@onready var name_input:     LineEdit       = $BG/Center/MainPanel/VBox/Bottom/VBox/NameRow/NameInput
@onready var play_button:    Button         = $BG/Center/MainPanel/VBox/Bottom/VBox/PlayButton
@onready var error_label:    Label          = $BG/Center/MainPanel/VBox/Bottom/VBox/ErrorLabel

# ============================================================
# READY
# ============================================================
func _ready() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	
	# Animação inicial de entrada do painel
	main_panel.modulate.a = 0
	main_panel.position.y += 50
	var t = create_tween()
	t.set_parallel(true)
	t.tween_property(main_panel, "modulate:a", 1.0, 0.5)
	t.tween_property(main_panel, "position:y", main_panel.position.y - 50, 0.5).set_trans(Tween.TRANS_QUART).set_ease(Tween.EASE_OUT)

	# Cria os botões de raça
	for race in CLASSES_BY_RACE.keys():
		var btn = Button.new()
		btn.text = race.to_upper()
		btn.custom_minimum_size = Vector2(120, 50)
		btn.pressed.connect(_on_race_selected.bind(race))
		btn.mouse_entered.connect(_on_btn_hover.bind(btn))
		race_container.add_child(btn)
		race_buttons[race] = btn

	play_button.pressed.connect(_on_play_pressed)
	_clear_class_buttons()

func _on_btn_hover(btn: Button) -> void:
	var t = create_tween()
	t.tween_property(btn, "scale", Vector2(1.05, 1.05), 0.1)
	btn.mouse_exited.connect(func():
		var t2 = create_tween()
		t2.tween_property(btn, "scale", Vector2(1.0, 1.0), 0.1)
	)

# ============================================================
# SELEÇÃO DE RAÇA
# ============================================================
func _on_race_selected(race: String) -> void:
	selected_race = race
	selected_class = ""
	selected_class_label.text = "Class: —"
	error_label.text = ""

	var theme_color = RACE_COLORS[race]
	
	# Destaque visual
	for r in race_buttons:
		var btn: Button = race_buttons[r]
		if r == race:
			btn.modulate = theme_color
			var t = create_tween()
			t.tween_property(btn, "custom_minimum_size:y", 60, 0.2)
		else:
			btn.modulate = Color(1, 1, 1, 0.4)
			var t = create_tween()
			t.tween_property(btn, "custom_minimum_size:y", 50, 0.2)

	# Atualiza Cores do Tema
	var t = create_tween()
	t.set_parallel(true)
	t.tween_property(title_bar, "modulate", theme_color, 0.4)
	t.tween_property(portrait_glow, "color", theme_color, 0.4)
	t.tween_property(race_desc_label, "modulate", theme_color, 0.4)

	race_desc_label.text = RACE_DESCRIPTIONS[race]
	_show_classes_with_slide(race)

# ============================================================
# CLASSES COM SLIDE
# ============================================================
func _clear_class_buttons() -> void:
	for child in class_container.get_children():
		child.queue_free()
	class_buttons.clear()

func _show_classes_with_slide(race: String) -> void:
	_clear_class_buttons()
	var classes = CLASSES_BY_RACE[race]
	var theme_color = RACE_COLORS[race]

	for i in range(classes.size()):
		var cls = classes[i]
		var btn = Button.new()
		btn.text = "  " + cls.to_upper()
		btn.alignment = HorizontalAlignment.HORIZONTAL_ALIGNMENT_LEFT
		btn.custom_minimum_size = Vector2(0, 45)
		btn.pressed.connect(_on_class_selected.bind(cls, btn))
		class_container.add_child(btn)
		class_buttons.append(btn)

		# Efeito de entrada
		btn.modulate.a = 0
		btn.position.x = 40
		var delay = i * 0.05
		var t = create_tween().set_parallel(true)
		t.tween_property(btn, "modulate:a", 0.7, 0.3).set_delay(delay)
		t.tween_property(btn, "position:x", 0.0, 0.4).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT).set_delay(delay)

func _on_class_selected(cls: String, pressed_btn: Button) -> void:
	selected_class = cls
	selected_class_label.text = "Class: " + cls.to_upper()
	
	for btn in class_buttons:
		if btn == pressed_btn:
			btn.modulate = Color(1, 1, 1, 1)
			btn.add_theme_color_override("font_color", RACE_COLORS[selected_race])
		else:
			btn.modulate = Color(1, 1, 1, 0.5)
			btn.add_theme_color_override("font_color", Color.WHITE)

# ============================================================
# JOGAR
# ============================================================
func _on_play_pressed() -> void:
	var final_name = name_input.text.strip_edges()
	if selected_race == "" or selected_class == "" or final_name == "":
		error_label.text = "COMPLETE ALL FIELDS TO BEGIN"
		return

	GameManager.player_name = final_name
	GameManager.player_race = selected_race
	GameManager.player_class = selected_class
	
	# PERSISTÊNCIA: Salva o novo personagem na conta logada!
	var new_char_data = {
		"name": final_name,
		"race": selected_race,
		"class": selected_class,
		"created_at": Time.get_datetime_string_from_system(),
		"inventory": [],
		"equipment": {},
		"level": 1,
		"exp": 0
	}
	AccountManager.add_character_to_account(new_char_data)
	
	# Inicia o jogo
	get_tree().change_scene_to_file("res://levels/TestWorld.tscn")
