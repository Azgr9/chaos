# SCRIPT: CombatEventBus.gd
# AUTOLOAD: CombatEventBus
# LOCATION: res://Scripts/Systems/CombatEventBus.gd
# PURPOSE: Centralized combat event system for decoupled communication
# NOTE: Signals are designed to be emitted by external systems and listened to by others

extends Node

# ============================================
# COMBAT EVENTS - Emitted when combat actions occur
# These signals are emitted by various systems (weapons, enemies, player)
# and listened to by other systems (VFX, audio, achievements, relics)
# ============================================

# Damage Events
signal damage_dealt(event: DamageEvent)
signal damage_received(event: DamageEvent)
signal kill(event: KillEvent)

# Attack Events
signal attack_started(event: AttackEvent)
signal attack_hit(event: AttackEvent)
signal attack_finished(event: AttackEvent)

# Combo Events
signal combo_increased(attacker: Node2D, combo_count: int)
signal combo_finished(attacker: Node2D, final_count: int)
signal combo_reset(attacker: Node2D)

# Critical/Special Hit Events
signal critical_hit(event: DamageEvent)
signal finisher_hit(event: DamageEvent)
signal dash_attack_hit(event: DamageEvent)

# Status Effect Events
signal status_applied(target: Node2D, effect_type: int, stacks: int)
signal status_removed(target: Node2D, effect_type: int)
signal status_triggered(target: Node2D, effect_type: int, damage: float)

# Skill Events
signal skill_used(user: Node2D, skill_id: String, cooldown: float)
signal skill_ready(user: Node2D, skill_id: String)
signal skill_hit(user: Node2D, skill_id: String, targets: Array)

# Player Events
signal player_healed(amount: float, source: String)
signal player_damaged(amount: float, source: Node2D)
signal player_died()
signal player_revived()

# Enemy Events
signal enemy_spawned(enemy: Node2D, enemy_type: String)
signal enemy_died(enemy: Node2D, killer: Node2D)
signal wave_started(wave_number: int)
signal wave_completed(wave_number: int)

# ============================================
# EVENT DATA CLASSES
# ============================================

class DamageEvent:
	var attacker: Node2D = null
	var target: Node2D = null
	var damage: float = 0.0
	var damage_type: int = 0  # DamageTypes.Type
	var is_crit: bool = false
	var is_finisher: bool = false
	var is_dash_attack: bool = false
	var knockback: float = 0.0
	var hit_position: Vector2 = Vector2.ZERO
	var weapon: Node2D = null

	func _init(atk: Node2D = null, tgt: Node2D = null, dmg: float = 0.0):
		attacker = atk
		target = tgt
		damage = dmg
		if tgt:
			hit_position = tgt.global_position

class AttackEvent:
	var attacker: Node2D = null
	var weapon: Node2D = null
	var attack_pattern: String = ""
	var combo_count: int = 0
	var is_skill: bool = false
	var direction: Vector2 = Vector2.RIGHT
	var targets_hit: Array = []

	func _init(atk: Node2D = null, wpn: Node2D = null):
		attacker = atk
		weapon = wpn

class KillEvent:
	var killer: Node2D = null
	var victim: Node2D = null
	var damage_event: DamageEvent = null
	var victim_type: String = ""
	var was_elite: bool = false
	var was_boss: bool = false

	func _init(k: Node2D = null, v: Node2D = null):
		killer = k
		victim = v
		if victim:
			victim_type = victim.get_class()
			was_elite = victim.get("is_elite") if victim.get("is_elite") != null else false
			was_boss = victim.is_in_group("boss") if victim else false

# ============================================
# HELPER FUNCTIONS - Emit events easily
# ============================================

## Emit a damage dealt event with all relevant info
func emit_damage(attacker: Node2D, target: Node2D, damage: float, damage_type: int = 0,
				  is_crit: bool = false, is_finisher: bool = false, is_dash: bool = false,
				  knockback: float = 0.0, weapon: Node2D = null) -> DamageEvent:
	var event = DamageEvent.new(attacker, target, damage)
	event.damage_type = damage_type
	event.is_crit = is_crit
	event.is_finisher = is_finisher
	event.is_dash_attack = is_dash
	event.knockback = knockback
	event.weapon = weapon

	damage_dealt.emit(event)

	# Also emit specialized events
	if is_crit:
		critical_hit.emit(event)
	if is_finisher:
		finisher_hit.emit(event)
	if is_dash:
		dash_attack_hit.emit(event)

	return event

## Emit a kill event
func emit_kill(killer: Node2D, victim: Node2D, damage_event: DamageEvent = null) -> KillEvent:
	var event = KillEvent.new(killer, victim)
	event.damage_event = damage_event
	kill.emit(event)
	enemy_died.emit(victim, killer)
	return event

## Emit attack started
func emit_attack_start(attacker: Node2D, weapon: Node2D, pattern: String, combo: int, direction: Vector2) -> AttackEvent:
	var event = AttackEvent.new(attacker, weapon)
	event.attack_pattern = pattern
	event.combo_count = combo
	event.direction = direction
	attack_started.emit(event)
	return event

## Emit attack hit
func emit_attack_hit(attacker: Node2D, weapon: Node2D, targets: Array) -> AttackEvent:
	var event = AttackEvent.new(attacker, weapon)
	event.targets_hit = targets
	attack_hit.emit(event)
	return event

## Emit skill usage
func emit_skill(user: Node2D, skill_id: String, cooldown: float):
	skill_used.emit(user, skill_id, cooldown)

## Emit player heal
func emit_heal(amount: float, source: String = "unknown"):
	player_healed.emit(amount, source)

## Emit status effect applied
func emit_status_applied(target: Node2D, effect_type: int, stacks: int):
	status_applied.emit(target, effect_type, stacks)

## Emit status effect removed
func emit_status_removed(target: Node2D, effect_type: int):
	status_removed.emit(target, effect_type)

## Emit status effect triggered (DoT tick, etc)
func emit_status_triggered(target: Node2D, effect_type: int, damage: float):
	status_triggered.emit(target, effect_type, damage)

## Emit attack finished
func emit_attack_finished(attacker: Node2D, weapon: Node2D) -> AttackEvent:
	var event = AttackEvent.new(attacker, weapon)
	attack_finished.emit(event)
	return event

## Emit combo increased
func emit_combo_increased(attacker: Node2D, combo_count: int):
	combo_increased.emit(attacker, combo_count)

## Emit combo finished
func emit_combo_finished(attacker: Node2D, final_count: int):
	combo_finished.emit(attacker, final_count)

## Emit combo reset
func emit_combo_reset(attacker: Node2D):
	combo_reset.emit(attacker)

## Emit skill ready
func emit_skill_ready(user: Node2D, skill_id: String):
	skill_ready.emit(user, skill_id)

## Emit skill hit
func emit_skill_hit(user: Node2D, skill_id: String, targets: Array):
	skill_hit.emit(user, skill_id, targets)

## Emit player damaged
func emit_player_damaged(amount: float, source: Node2D):
	player_damaged.emit(amount, source)

## Emit player died
func emit_player_died():
	player_died.emit()

## Emit player revived
func emit_player_revived():
	player_revived.emit()

## Emit enemy spawned
func emit_enemy_spawned(enemy: Node2D, enemy_type: String):
	enemy_spawned.emit(enemy, enemy_type)

## Emit wave started
func emit_wave_started(wave_number: int):
	wave_started.emit(wave_number)

## Emit wave completed
func emit_wave_completed(wave_number: int):
	wave_completed.emit(wave_number)

## Emit damage received (for when player/entity takes damage)
func emit_damage_received(attacker: Node2D, target: Node2D, damage: float, damage_type: int = 0) -> DamageEvent:
	var event = DamageEvent.new(attacker, target, damage)
	event.damage_type = damage_type
	damage_received.emit(event)
	return event

# ============================================
# LISTENER REGISTRATION HELPERS
# ============================================

## Register a callback for when player deals damage
func on_player_damage(callback: Callable) -> void:
	damage_dealt.connect(func(event: DamageEvent):
		if event.attacker and event.attacker.is_in_group("player"):
			callback.call(event)
	)

## Register a callback for when player takes damage
func on_player_hurt(callback: Callable) -> void:
	damage_received.connect(func(event: DamageEvent):
		if event.target and event.target.is_in_group("player"):
			callback.call(event)
	)

## Register a callback for critical hits by player
func on_player_crit(callback: Callable) -> void:
	critical_hit.connect(func(event: DamageEvent):
		if event.attacker and event.attacker.is_in_group("player"):
			callback.call(event)
	)

## Register a callback for when player kills enemy
func on_player_kill(callback: Callable) -> void:
	kill.connect(func(event: KillEvent):
		if event.killer and event.killer.is_in_group("player"):
			callback.call(event)
	)

# ============================================
# DEBUG
# ============================================

var _debug_enabled: bool = false

func enable_debug():
	_debug_enabled = true
	damage_dealt.connect(_debug_damage)
	kill.connect(_debug_kill)
	critical_hit.connect(_debug_crit)

func _debug_damage(event: DamageEvent):
	if _debug_enabled:
		var attacker_name: String = str(event.attacker.name) if event.attacker else "null"
		var target_name: String = str(event.target.name) if event.target else "null"
		print("[CombatEvent] Damage: %.1f from %s to %s" % [event.damage, attacker_name, target_name])

func _debug_kill(event: KillEvent):
	if _debug_enabled:
		var killer_name: String = str(event.killer.name) if event.killer else "null"
		var victim_name: String = str(event.victim.name) if event.victim else "null"
		print("[CombatEvent] Kill: %s killed %s" % [killer_name, victim_name])

func _debug_crit(event: DamageEvent):
	if _debug_enabled:
		print("[CombatEvent] CRIT! %.1f damage" % event.damage)
