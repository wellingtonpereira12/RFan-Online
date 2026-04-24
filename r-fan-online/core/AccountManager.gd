extends Node

const ACCOUNTS_PATH = "res://database/accounts.json"

var accounts: Array = []
var logged_in_email: String = ""

func _ready() -> void:
	_load_accounts()

func _load_accounts():
	if FileAccess.file_exists(ACCOUNTS_PATH):
		var file = FileAccess.open(ACCOUNTS_PATH, FileAccess.READ)
		var content = file.get_as_text()
		file.close()
		
		var json = JSON.new()
		var error = json.parse(content)
		if error == OK:
			accounts = json.data
			print("[AccountManager] Contas carregadas: ", accounts.size())

func register(email: String, password: String) -> Dictionary:
	# Validações básicas
	if email.length() < 5 or not "@" in email:
		return {"success": false, "message": "E-mail inválido!"}
	if password.length() < 4:
		return {"success": false, "message": "Senha muito curta!"}
	
	# Verifica se já existe
	for acc in accounts:
		if acc["email"] == email:
			return {"success": false, "message": "E-mail já cadastrado!"}
	
	# Cria a conta
	var new_acc = {
		"email": email,
		"password": password,
		"created_at": Time.get_datetime_string_from_system(),
		"characters": [] # Lista de personagens da conta
	}
	
	accounts.append(new_acc)
	_save_accounts()
	return {"success": true, "message": "Conta criada com sucesso!"}

func login(email: String, password: String) -> Dictionary:
	for acc in accounts:
		if acc["email"] == email:
			if acc["password"] == password:
				logged_in_email = email
				return {"success": true, "message": "Bem-vindo!"}
			else:
				return {"success": false, "message": "Senha incorreta!"}
	
	return {"success": false, "message": "Conta não encontrada!"}

func get_logged_in_account() -> Dictionary:
	for acc in accounts:
		if acc["email"] == logged_in_email:
			return acc
	return {}

func add_character_to_account(char_data: Dictionary):
	for acc in accounts:
		if acc["email"] == logged_in_email:
			if not acc.has("characters"): acc["characters"] = []
			acc["characters"].append(char_data)
			_save_accounts()
			return true
	return false

func update_character_data(char_name: String, new_data: Dictionary):
	for acc in accounts:
		if acc["email"] == logged_in_email:
			for i in range(acc["characters"].size()):
				if acc["characters"][i]["name"] == char_name:
					# Atualiza os campos (Merge)
					for key in new_data:
						acc["characters"][i][key] = new_data[key]
					_save_accounts()
					return true
	return false



func _save_accounts():
	var file = FileAccess.open(ACCOUNTS_PATH, FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify(accounts, "\t"))
		file.close()
