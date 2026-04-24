class_name ItemDatabase

const ITEMS: Dictionary = {
	"pote_hp_p": {
		"id": "pote_hp_p",
		"nome": "Potion HP Pequena",
		"tipo": "potion",
		"descricao": "Recupera uma pequena quantidade de vida",
		"efeito": "hp",
		"valor": 50,
		"max_stack": 99,
		"cooldown_ms": 1000
	},
	"pote_hp_m": {
		"id": "pote_hp_m",
		"nome": "Potion HP Média",
		"tipo": "potion",
		"descricao": "Recupera vida média",
		"efeito": "hp",
		"valor": 150,
		"max_stack": 99,
		"cooldown_ms": 2000
	},
	"pote_hp_g": {
		"id": "pote_hp_g",
		"nome": "Potion HP Grande",
		"tipo": "potion",
		"descricao": "Recupera muita vida",
		"efeito": "hp",
		"valor": 300,
		"max_stack": 99,
		"cooldown_ms": 4000
	},
	"pote_sp_p": {
		"id": "pote_sp_p",
		"nome": "Potion SP Pequena",
		"tipo": "potion",
		"descricao": "Recupera mana",
		"efeito": "sp",
		"valor": 50,
		"max_stack": 99,
		"cooldown_ms": 1500
	},
	"pote_sp_g": {
		"id": "pote_sp_g",
		"nome": "Potion SP Grande",
		"tipo": "potion",
		"descricao": "Recupera muita mana",
		"efeito": "sp",
		"valor": 200,
		"max_stack": 99,
		"cooldown_ms": 3000
	},
	"pote_fp": {
		"id": "pote_fp",
		"nome": "Potion FP",
		"tipo": "potion",
		"descricao": "Recupera stamina",
		"efeito": "fp",
		"valor": 100,
		"max_stack": 99,
		"cooldown_ms": 2500
	},
	"super_pote": {
		"id": "super_pote",
		"nome": "Super Potion",
		"tipo": "potion",
		"descricao": "Recupera HP e SP simultaneamente",
		"efeito": "hp_sp",
		"valor": 300,
		"max_stack": 99,
		"cooldown_ms": 6000
	},

	# === EQUIPAMENTOS ===
	"espada_ferro": {
		"id": "espada_ferro",
		"nome": "Espada de Ferro",
		"tipo": "equipment",
		"descricao": "Uma espada básica de ferro forjado",
		"equip_slot": "weapon",
		"mao": "esquerda",
		"ataque": 15,
		"max_stack": 1,
		"cooldown_ms": 0
	},
	"espada_dupla": {
		"id": "espada_dupla",
		"nome": "Espada Dupla",
		"tipo": "equipment",
		"descricao": "Uma espada que pode ser usada em ambas as mãos",
		"equip_slot": "weapon",
		"mao": "ambas",
		"ataque": 10,
		"max_stack": 1,
		"cooldown_ms": 0
	},
	"capacete_couro": {
		"id": "capacete_couro",
		"nome": "Capacete de Couro",
		"tipo": "equipment",
		"descricao": "Um capacete leve de couro curtido",
		"equip_slot": "head",
		"defesa": 5,
		"max_stack": 1,
		"cooldown_ms": 0
	},
	"armadura_couro": {
		"id": "armadura_couro",
		"nome": "Armadura de Couro",
		"tipo": "equipment",
		"descricao": "Armadura leve que garante mobilidade",
		"equip_slot": "body",
		"defesa": 10,
		"max_stack": 1,
		"cooldown_ms": 0
	},
	"escudo_madeira": {
		"id": "escudo_madeira",
		"nome": "Escudo de Madeira",
		"tipo": "equipment",
		"descricao": "Um escudo básico feito de madeira dura",
		"equip_slot": "shield",
		"mao": "direita",
		"defesa": 8,
		"max_stack": 1,
		"cooldown_ms": 0
	},
	"botas_couro": {
		"id": "botas_couro",
		"nome": "Botas de Couro",
		"tipo": "equipment",
		"descricao": "Botas leves que aumentam a mobilidade",
		"equip_slot": "boots",
		"velocidade": 5,
		"max_stack": 1,
		"cooldown_ms": 0
	},
	"anel_forca": {
		"id": "anel_forca",
		"nome": "Anel da Força",
		"tipo": "equipment",
		"descricao": "Um anel antigo que emana poder",
		"equip_slot": "accessory",
		"ataque": 5,
		"max_stack": 1,
		"cooldown_ms": 0
	}
}

static func get_item(item_id: String) -> Dictionary:
	if ITEMS.has(item_id):
		return ITEMS[item_id]
	else:
		printerr("Item não cadastrado no banco de dados -> ID: " + item_id)
		return {}
