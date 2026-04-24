extends Control

@onready var email_input = $Center/Panel/Margin/VBox/EmailInput
@onready var pass_input = $Center/Panel/Margin/VBox/PassInput
@onready var action_btn = $Center/Panel/Margin/VBox/ActionBtn
@onready var switch_btn = $Center/Panel/Margin/VBox/SwitchBtn
@onready var error_label = $Center/Panel/Margin/VBox/ErrorLabel
@onready var sub_title = $Center/Panel/Margin/VBox/SubTitle

var is_register_mode = false

func _ready() -> void:
	action_btn.pressed.connect(_on_action_pressed)
	switch_btn.pressed.connect(_on_switch_pressed)
	_update_ui()

func _update_ui():
	if is_register_mode:
		sub_title.text = "Account Registration"
		action_btn.text = "REGISTER ACCOUNT"
		switch_btn.text = "Already have an account? Login"
	else:
		sub_title.text = "Authentication"
		action_btn.text = "LOGIN"
		switch_btn.text = "Don't have an account? Create one"
	error_label.text = ""

func _on_switch_pressed():
	is_register_mode = !is_register_mode
	_update_ui()

func _on_action_pressed():
	var email = email_input.text.strip_edges()
	var password = pass_input.text.strip_edges()
	
	if email == "" or password == "":
		error_label.text = "Please fill all fields!"
		return
	
	if is_register_mode:
		var result = AccountManager.register(email, password)
		if result["success"]:
			error_label.text = "[color=green]" + result["message"] + "[/color]"
			# Volta para o login após registrar
			is_register_mode = false
			_update_ui()
			error_label.modulate = Color.GREEN
			error_label.text = result["message"]
		else:
			error_label.modulate = Color.RED
			error_label.text = result["message"]
	else:
		var result = AccountManager.login(email, password)
		if result["success"]:
			# Verifica se tem personagens
			var acc = AccountManager.get_logged_in_account()
			var chars = acc.get("characters", [])
			
			if chars.size() > 0:
				get_tree().change_scene_to_file("res://ui/menu/CharacterSelection.tscn")
			else:
				get_tree().change_scene_to_file("res://ui/menu/RaceSelection.tscn")
		else:
			error_label.modulate = Color.RED
			error_label.text = result["message"]
