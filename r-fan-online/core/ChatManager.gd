extends Node

const LOG_PATH = "res://database/chat_logs.json"

var chat_history: Array = []

# Canais Disponíveis
enum Channel { GLOBAL, LOCAL }

# Cores por Raça
const RACE_COLORS = {
	"Cora": "#bb66ff",    # Roxo
	"Bellato": "#44aaff", # Azul
	"Accretia": "#ff4422" # Vermelho
}

signal message_received(data: Dictionary)

func _ready() -> void:
	_load_logs_from_file()

func _load_logs_from_file():
	if FileAccess.file_exists(LOG_PATH):
		var file = FileAccess.open(LOG_PATH, FileAccess.READ)
		var content = file.get_as_text()
		file.close()
		
		var json = JSON.new()
		var error = json.parse(content)
		if error == OK:
			if typeof(json.data) == TYPE_ARRAY:
				chat_history = json.data
				print("[Chat] Histórico carregado: ", chat_history.size(), " mensagens.")


func send_message(text: String, channel: Channel = Channel.GLOBAL):
	if text.strip_edges() == "": return
	
	# Pega dados do jogador atual no GameManager
	var p_name = GameManager.player_name if GameManager.player_name != "" else "Player"
	var p_race = GameManager.player_race if GameManager.player_race != "" else "Accretia" # Default para teste
	
	# --- SISTEMA DE COMANDOS ADMIN ---
	if text.begins_with("/"):
		if _process_admin_command(text):
			return # Interrompe o envio se for um comando válido
	var message_data = {
		"sender": p_name,
		"text": text.substr(0, 100), # Limite de 100 caracteres
		"race": p_race,
		"channel": channel,
		"timestamp": Time.get_time_string_from_system()
	}
	
	# Simula o envio (No multiplayer, isso iria para o servidor)
	receive_message(message_data)

func receive_message(data: Dictionary):
	# REGRA DE RAÇA: Só recebe se for da mesma raça
	# (Em um servidor real, o servidor nem enviaria a mensagem para raças diferentes)
	var my_race = GameManager.player_race
	
	if data["race"] != my_race:
		print("[Chat] Mensagem de raça diferente ignorada.")
		return
	
	# Emite o sinal para a UI atualizar
	message_received.emit(data)
	
	# Adiciona ao histórico na memória
	chat_history.append(data)
	
	# Salva no log
	_save_to_log(data)

func _save_to_log(data: Dictionary):
	# Salva apenas a lista atualizada
	var file = FileAccess.open(LOG_PATH, FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify(chat_history, "\t"))
		file.close()

# --- COMANDOS ADMIN (GM) ---
func _process_admin_command(command_text: String) -> bool:
	var parts = command_text.split(" ", false)
	if parts.size() < 1: return false
	
	var cmd = parts[0].to_lower()
	
	# /LEVEL <VALOR>
	if cmd == "/level" and parts.size() >= 2:
		var val_str = parts[1]
		var current_lv = ExperienceManager.current_level
		var new_lv = current_lv
		
		if val_str.begins_with("+"):
			new_lv += val_str.to_int()
		elif val_str.begins_with("-"):
			new_lv += val_str.to_int()
		else:
			new_lv = val_str.to_int()
		
		ExperienceManager.set_level(new_lv)
		_send_system_message("Level atualizado para: " + str(ExperienceManager.current_level))
		return true
		
	# /ADDEXP <VALOR>
	if cmd == "/addexp" and parts.size() >= 2:
		var amount = parts[1].to_int()
		ExperienceManager.add_exp(amount)
		_send_system_message("Adicionado " + str(amount) + " de XP.")
		return true
		
	return false

func _send_system_message(text: String):
	receive_message({
		"sender": "SISTEMA",
		"text": text,
		"race": GameManager.player_race,
		"channel": Channel.LOCAL
	})
