extends Node
class_name VitalsComponent

# --- Signals (Usados pelo HUD) ---
signal hp_changed(current: int, max_val: int)
signal sp_changed(current: int, max_val: int)
signal fp_changed(current: int, max_val: int)
signal died()
signal damaged(attacker)

# --- Status Máximos ---
@export var max_hp: int = 100
@export var max_sp: int = 100
@export var max_fp: int = 100

# --- Status Atuais ---
var hp: int
var sp: int
var fp: int

# --- Configurações de Regeneração ---
var is_running: bool = false
var fp_drain_rate: float = 1.0 # Perde 1 ponto por segundo correndo
var fp_regen_rate: float = 2.0 # Recupera 2 pontos por segundo parado/andando

# Acumular decimais para regeneração suave
var hp_pool: float = 0.0
var sp_pool: float = 0.0
var fp_pool: float = 0.0

# Taxas de Regeneração (% por segundo)
var hp_regen_pct: float = 0.0
var sp_regen_pct: float = 0.0
var fp_regen_pct: float = 0.0

var _is_first_sync: bool = true

func _ready() -> void:
	# Aguarda um frame para garantir que o StatusManager calculou tudo
	call_deferred("sync_with_status")

func sync_with_status(refill: bool = false):
	# SÓ sincroniza com o StatusManager se for o Player!
	if not get_parent().is_in_group("players"):
		return

	var stats = StatusManager.get_total_status()
	if not stats.is_empty():
		max_hp = stats["hp"]
		max_sp = stats["sp"]
		max_fp = stats["fp"]
		
		hp_regen_pct = stats.get("hp_regen", 1.0)
		sp_regen_pct = stats.get("sp_regen", 1.0)
		fp_regen_pct = stats.get("fp_regen", 1.0)
		
		# Se for a PRIMEIRA sincronização ou um Level Up (refill), enche tudo.
		if _is_first_sync or refill:
			hp = max_hp
			sp = max_sp
			fp = max_fp
			hp_pool = float(hp)
			sp_pool = float(sp)
			fp_pool = float(fp)
			_is_first_sync = false
		else:
			# Garante que o atual não ultrapasse o novo máximo se o status diminuiu
			hp = clampi(hp, 0, max_hp)
			sp = clampi(sp, 0, max_sp)
			fp = clampi(fp, 0, max_fp)
			hp_pool = clampf(hp_pool, 0.0, float(max_hp))
			sp_pool = clampf(sp_pool, 0.0, float(max_sp))
			fp_pool = clampf(fp_pool, 0.0, float(max_fp))
		
		hp_changed.emit(hp, max_hp)
		sp_changed.emit(sp, max_sp)
		fp_changed.emit(fp, max_fp)
		print("[Vitals] Sincronizado com StatusManager: HP=", max_hp, " Regen=", hp_regen_pct, "%")

func restore_health(amount: int) -> void:
	if hp <= 0: return
	hp = clampi(hp + amount, 0, max_hp)
	hp_pool = float(hp) # SINCRONIZA O POOL
	hp_changed.emit(hp, max_hp)

func restore_sp(amount: int) -> void:
	if hp <= 0: return 
	sp = clampi(sp + amount, 0, max_sp)
	sp_pool = float(sp) # SINCRONIZA O POOL
	sp_changed.emit(sp, max_sp)

func restore_fp(amount: int) -> void:
	if hp <= 0: return
	fp_pool = clampf(fp_pool + float(amount), 0.0, float(max_fp))
	fp = int(fp_pool)
	fp_changed.emit(fp, max_fp)

func take_damage(amount: int, type = -1, attacker = null) -> void:
	if hp <= 0: return
	hp = clampi(hp - amount, 0, max_hp)
	hp_pool = float(hp) # Sincroniza o pool decimal ao tomar dano
	hp_changed.emit(hp, max_hp)
	
	if attacker:
		damaged.emit(attacker)
	
	# Exibir Texto de Dano
	var final_type = type
	if final_type == -1: # Se não foi passado um tipo específico
		final_type = DamageTextManager.DamageType.DEALT
		if get_parent().is_in_group("players"):
			final_type = DamageTextManager.DamageType.RECEIVED
	
	DamageTextManager.display_damage(amount, final_type, get_parent().global_position)
	
	# Aciona modo de combate se quem tomou dano foi o player
	if get_parent().has_method("set_in_combat"):
		get_parent().set_in_combat()
	if hp == 0:
		died.emit()

func consume_sp(amount: int) -> void:
	sp = clampi(sp - amount, 0, max_sp)
	sp_pool = float(sp) # SINCRONIZA O POOL DECIMAL
	sp_changed.emit(sp, max_sp)

func consume_fp(amount: int) -> void:
	fp_pool = clampf(fp_pool - float(amount), 0.0, float(max_fp))
	fp = int(fp_pool)
	fp_changed.emit(fp, max_fp)

func _process(delta: float) -> void:
	var player = get_parent()
	var in_combat = false
	if "is_in_combat" in player: # Se for o player, checamos o modo de batalha
		in_combat = player.is_in_combat
	
	# --- SISTEMA DE REGENERAÇÃO PASSIVA (FORA DE COMBATE) ---
	if not in_combat and hp > 0:
		# Regeneração de HP
		if hp < max_hp:
			var regen_amount = (max_hp * (hp_regen_pct / 100.0)) * delta
			hp_pool = clampf(hp_pool + regen_amount, 0.0, float(max_hp))
			var old_hp = hp
			hp = int(hp_pool)
			if hp != old_hp: hp_changed.emit(hp, max_hp)
			
		# Regeneração de SP
		if sp < max_sp:
			var regen_amount = (max_sp * (sp_regen_pct / 100.0)) * delta
			sp_pool = clampf(sp_pool + regen_amount, 0.0, float(max_sp))
			var old_sp = sp
			sp = int(sp_pool)
			if sp != old_sp: sp_changed.emit(sp, max_sp)
			
		# Regeneração de FP (Quando parado ou andando)
		if not is_running and fp < max_fp:
			var regen_amount = (max_fp * (fp_regen_pct / 100.0)) * delta
			fp_pool = clampf(fp_pool + regen_amount, 0.0, float(max_fp))
			var old_fp = fp
			fp = int(fp_pool)
			if fp != old_fp: fp_changed.emit(fp, max_fp)

	# --- SISTEMA DE CONSUMO DE FP (CORRENDO) ---
	if is_running and fp > 0:
		fp_pool -= fp_drain_rate * delta
		var old_fp = fp
		fp = clampi(int(fp_pool), 0, max_fp)
		if fp != old_fp:
			fp_changed.emit(fp, max_fp)
