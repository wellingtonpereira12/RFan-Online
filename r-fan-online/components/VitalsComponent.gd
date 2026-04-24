extends Node
class_name VitalsComponent

# --- Signals (Usados pelo HUD) ---
signal hp_changed(current: int, max_val: int)
signal sp_changed(current: int, max_val: int)
signal fp_changed(current: int, max_val: int)
signal died()

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
var fp_drain_rate: float = 15.0 # Quanto tempo perde por segundo correndo
var fp_regen_rate: float = 10.0 # Quanto recupera por segundo parado/andando

# Acumular decimal
var fp_pool: float = 0.0

func _ready() -> void:
	hp = max_hp
	sp = max_sp
	fp = max_fp
	fp_pool = float(fp)

func restore_health(amount: int) -> void:
	if hp <= 0: return
	hp = clampi(hp + amount, 0, max_hp)
	hp_changed.emit(hp, max_hp)

func restore_sp(amount: int) -> void:
	if hp <= 0: return # Não recupera SP se estiver morto
	sp = clampi(sp + amount, 0, max_sp)
	sp_changed.emit(sp, max_sp)

func restore_fp(amount: int) -> void:
	if hp <= 0: return
	fp_pool = clampf(fp_pool + float(amount), 0.0, float(max_fp))
	fp = int(fp_pool)
	fp_changed.emit(fp, max_fp)

func take_damage(amount: int) -> void:
	if hp <= 0: return
	hp = clampi(hp - amount, 0, max_hp)
	hp_changed.emit(hp, max_hp)
	if hp == 0:
		died.emit()

func consume_sp(amount: int) -> void:
	sp = clampi(sp - amount, 0, max_sp)
	sp_changed.emit(sp, max_sp)

func consume_fp(amount: int) -> void:
	fp_pool = clampf(fp_pool - float(amount), 0.0, float(max_fp))
	fp = int(fp_pool)
	fp_changed.emit(fp, max_fp)

func _process(delta: float) -> void:
	# Sistema de consumo e regeneração de FP
	if is_running:
		if fp > 0:
			fp_pool -= fp_drain_rate * delta
			var old_fp = fp
			fp = clampi(int(fp_pool), 0, max_fp)
			if fp != old_fp:
				fp_changed.emit(fp, max_fp)
	else:
		if fp < max_fp:
			fp_pool += fp_regen_rate * delta
			var old_fp = fp
			fp = clampi(int(fp_pool), 0, max_fp)
			if fp != old_fp:
				fp_changed.emit(fp, max_fp)
