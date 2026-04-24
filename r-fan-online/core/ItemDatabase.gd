class_name ItemDatabase

const ITEMS: Dictionary = {
	"pote_hp_p": {
		"id": "pote_hp_p",
		"nome": "Potion HP Pequenaaa",
		"tipo": "potion",
		"descricao": "Recupera uma pequena quantidade de vida",
		"efeito": "hp",
		"valor": 50,
		"max_stack": 99
	},
	"pote_hp_m": {
		"id": "pote_hp_m",
		"nome": "Potion HP Média",
		"tipo": "potion",
		"descricao": "Recupera vida média",
		"efeito": "hp",
		"valor": 150,
		"max_stack": 99
	},
	"pote_hp_g": {
		"id": "pote_hp_g",
		"nome": "Potion HP Grande",
		"tipo": "potion",
		"descricao": "Recupera muita vida",
		"efeito": "hp",
		"valor": 300,
		"max_stack": 99
	},
	"pote_sp_p": {
		"id": "pote_sp_p",
		"nome": "Potion SP Pequena",
		"tipo": "potion",
		"descricao": "Recupera mana",
		"efeito": "sp",
		"valor": 50,
		"max_stack": 99
	},
	"pote_sp_g": {
		"id": "pote_sp_g",
		"nome": "Potion SP Grande",
		"tipo": "potion",
		"descricao": "Recupera muita mana",
		"efeito": "sp",
		"valor": 200,
		"max_stack": 99
	},
	"pote_fp": {
		"id": "pote_fp",
		"nome": "Potion FP",
		"tipo": "potion",
		"descricao": "Recupera stamina",
		"efeito": "fp",
		"valor": 100,
		"max_stack": 99
	},
	"super_pote": {
		"id": "super_pote",
		"nome": "Super Potion",
		"tipo": "potion",
		"descricao": "Recupera HP e SP",
		"efeito": "hp_sp",
		"valor": 300,
		"max_stack": 99
	}
}

static func get_item(item_id: String) -> Dictionary:
	if ITEMS.has(item_id):
		return ITEMS[item_id]
	else:
		printerr("Item não cadastrado no banco de dados -> ID: " + item_id)
		return {}
