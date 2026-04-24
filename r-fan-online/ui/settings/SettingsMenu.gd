extends Panel

@onready var fullscreen_check = $VBox/Scroll/Content/ScreenSection/FullscreenRow/FullscreenCheck
@onready var res_option = $VBox/Scroll/Content/ScreenSection/ResRow/ResOption
@onready var music_slider = $VBox/Scroll/Content/AudioSection/MusicRow/MusicSlider
@onready var sfx_slider = $VBox/Scroll/Content/AudioSection/SFXRow/SFXSlider
@onready var save_btn = $VBox/Footer/SaveBtn
@onready var logout_btn = $VBox/Footer/HBox/LogoutBtn
@onready var exit_btn = $VBox/Footer/HBox/ExitBtn
@onready var confirm_exit = $ConfirmExit

const RESOLUTIONS = ["1280x720", "1600x900", "1920x1080", "2560x1440"]

# Variáveis para Movimentação
var is_dragging = false
var drag_offset = Vector2.ZERO

func _ready():
	visible = false
	_setup_options()
	_load_current_values()
	
	save_btn.pressed.connect(_on_save_pressed)
	logout_btn.pressed.connect(_on_logout_pressed)
	exit_btn.pressed.connect(_on_exit_pressed)
	confirm_exit.confirmed.connect(_on_exit_confirmed)
	
	# Conecta sinal para mover a janela
	gui_input.connect(_on_gui_input)

func _setup_options():
	res_option.clear()
	for res in RESOLUTIONS:
		res_option.add_item(res)

func _load_current_values():
	var s = SettingsManager.settings
	fullscreen_check.button_pressed = s["fullscreen"]
	music_slider.value = s["volume_music"]
	sfx_slider.value = s["volume_effects"]
	
	var idx = RESOLUTIONS.find(s["resolution"])
	if idx != -1:
		res_option.selected = idx

func show_menu():
	visible = true
	move_to_front()
	_load_current_values()

func hide_menu():
	visible = false

func _on_save_pressed():
	SettingsManager.settings["fullscreen"] = fullscreen_check.button_pressed
	SettingsManager.settings["resolution"] = RESOLUTIONS[res_option.selected]
	SettingsManager.settings["volume_music"] = music_slider.value
	SettingsManager.settings["volume_effects"] = sfx_slider.value
	
	SettingsManager.save_settings()
	SettingsManager.apply_settings()
	print("[Settings] Configurações aplicadas com sucesso.")

func _on_logout_pressed():
	print("[System] Realizando Logout...")
	# get_tree().change_scene_to_file("res://scenes/LoginScene.tscn")

func _on_exit_pressed():
	confirm_exit.popup_centered()

func _on_exit_confirmed():
	SettingsManager.save_settings()
	get_tree().quit()

func _input(event):
	if visible and event.is_action_pressed("ui_cancel"):
		hide_menu()
		get_viewport().set_input_as_handled()

func _on_gui_input(event: InputEvent):
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			is_dragging = true
			drag_offset = get_global_mouse_position() - global_position
			move_to_front()
		else:
			is_dragging = false
	elif event is InputEventMouseMotion and is_dragging:
		global_position = get_global_mouse_position() - drag_offset
