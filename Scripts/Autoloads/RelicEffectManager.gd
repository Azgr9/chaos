# SCRIPT: RelicEffectManager.gd
# AUTOLOAD: RelicEffectManager
# LOCATION: res://Scripts/Autoloads/RelicEffectManager.gd
# PURPOSE: Handles all relic special effects that need runtime processing

extends Node

# ============================================
# SIGNALS
# ============================================
signal effect_triggered(effect_name: String)

# ============================================
# STATE
# ============================================
var _player: Node2D = null
var _regen_timer: float = 0.0
var _berserker_active: bool = false
var _guardian_angel_used_this_wave: bool = false

# ============================================
# LIFECYCLE
# ============================================
func _ready():
	# Connect to RunManager signals
	if RunManager:
		RunManager.wave_completed.connect(_on_wave_completed)
		RunManager.relic_collected.connect(_on_relic_collected)
		RunManager.run_started.connect(_on_run_started)

	# Connect to combat events for kill-based effects
	if CombatEventBus:
		CombatEventBus.enemy_died.connect(_on_enemy_died)

func _process(delta):
	_update_player_reference()

	if not _player or not is_instance_valid(_player):
		return

	# Process regeneration effect
	if _has_effect("regen"):
		_process_regen(delta)

	# Process berserker effect (check health threshold)
	if _has_effect("berserker"):
		_process_berserker()

func _update_player_reference():
	if not _player or not is_instance_valid(_player):
		_player = get_tree().get_first_node_in_group("player")

# ============================================
# EFFECT CHECKS
# ============================================
func _has_effect(effect_name: String) -> bool:
	if not RunManager:
		return false
	return RunManager.has_special_effect(effect_name)

func _get_effect_value(effect_name: String) -> float:
	if not RunManager:
		return 0.0

	for relic in RunManager.run_data.collected_relics:
		if "special_effect" in relic and relic.special_effect == effect_name:
			if "special_value" in relic:
				return relic.special_value
	return 0.0

# ============================================
# PASSIVE EFFECTS
# ============================================
func _process_regen(delta):
	_regen_timer += delta
	if _regen_timer >= 1.0:  # Tick every second
		_regen_timer = 0.0
		var regen_amount = _get_effect_value("regen")
		if regen_amount <= 0:
			regen_amount = 1.0  # Default 1 HP/sec

		if _player and _player.has_method("heal"):
			# Only heal if not at max health
			if _player.stats and _player.stats.current_health < _player.stats.max_health:
				_player.heal(regen_amount)

func _process_berserker():
	if not _player or not _player.stats:
		return

	var health_percent = _player.stats.current_health / _player.stats.max_health
	var should_be_active = health_percent <= 0.3

	if should_be_active != _berserker_active:
		_berserker_active = should_be_active
		if _berserker_active:
			# Apply +20% damage at low health
			_trigger_berserker_buff()
		else:
			# Remove buff
			_remove_berserker_buff()

func _trigger_berserker_buff():
	if RunManager:
		RunManager.recalculate_stats()
	effect_triggered.emit("berserker_activated")
	print("[RelicEffects] BERSERKER MODE ACTIVATED!")

func _remove_berserker_buff():
	if RunManager:
		RunManager.recalculate_stats()
	print("[RelicEffects] Berserker mode deactivated")

# ============================================
# KILL-BASED EFFECTS
# ============================================
func _on_enemy_died(victim: Node2D, killer: Node2D):
	if not _player or not is_instance_valid(_player):
		return

	# Bloodthirst - Kills restore 5% max HP
	if _has_effect("kill_heal"):
		var heal_amount = _player.stats.max_health * 0.05
		_player.heal(heal_amount)
		_create_heal_effect(_player.global_position, Color(1, 0.2, 0.2))

	# Burn Spread - Fire spreads on kill
	if _has_effect("burn_spread"):
		if victim and victim.has_method("has_status_effect"):
			# Check if victim was burning
			if victim.has_status_effect(StatusEffects.EffectType.BURN) if victim.has_method("has_status_effect") else false:
				_spread_burn_to_nearby(victim.global_position)

	# Shatter - Frozen enemies explode on death
	if _has_effect("shatter"):
		if victim and victim.has_method("has_status_effect"):
			if victim.has_status_effect(StatusEffects.EffectType.CHILL) if victim.has_method("has_status_effect") else false:
				_trigger_shatter(victim.global_position)

	# Phantom Cloak - Dash reset on kill
	if _has_effect("flash_step"):
		if _player.has_method("reset_dash_cooldown"):
			_player.dash_cooldown_timer = 0.0
			_create_flash_effect(_player.global_position)

# ============================================
# ON-HIT EFFECTS
# ============================================
## Called when player hits an enemy - apply on-hit effects
func on_enemy_hit(enemy: Node2D, from_position: Vector2):
	if not is_instance_valid(enemy):
		return

	# Burn on hit - apply burn status
	if _has_effect("burn_on_hit"):
		if enemy.has_method("apply_status_effect"):
			enemy.apply_status_effect(StatusEffects.EffectType.BURN, _player, 1)

	# Chill on hit - apply slow status
	if _has_effect("chill_on_hit"):
		if enemy.has_method("apply_status_effect"):
			enemy.apply_status_effect(StatusEffects.EffectType.CHILL, _player, 1)

	# Void vulnerability - mark for extra damage
	if _has_effect("void_vulnerability"):
		mark_void_vulnerable(enemy)

# ============================================
# DAMAGE MODIFICATION
# ============================================
## Called when calculating damage - returns multiplier
func get_damage_multiplier() -> float:
	var mult = 1.0

	# Berserker effect - +20% damage below 30% HP
	if _has_effect("berserker") and _berserker_active:
		mult *= 1.2

	# Void Vulnerability check is done per-enemy

	return mult

## Called when enemy takes damage - check void vulnerability
func apply_void_vulnerability(enemy: Node2D) -> float:
	if not _has_effect("void_vulnerability"):
		return 1.0

	# Check if enemy was recently hit (has vulnerability debuff)
	if enemy.has_meta("void_vulnerable"):
		var expiry = enemy.get_meta("void_vulnerable")
		if Time.get_ticks_msec() < expiry:
			return 1.15  # +15% damage

	return 1.0

## Mark enemy as void vulnerable (called when hit)
func mark_void_vulnerable(enemy: Node2D):
	if _has_effect("void_vulnerability"):
		# Mark for 3 seconds
		enemy.set_meta("void_vulnerable", Time.get_ticks_msec() + 3000)

# ============================================
# DEFENSIVE EFFECTS
# ============================================
## Guardian Angel - Prevent fatal blow once per wave
func try_guardian_angel_save() -> bool:
	if not _has_effect("revive_enhance"):
		return false

	if _guardian_angel_used_this_wave:
		return false

	_guardian_angel_used_this_wave = true

	# Restore to 20% HP
	if _player and _player.stats:
		_player.stats.current_health = _player.stats.max_health * 0.2
		_player.health_changed.emit(_player.stats.current_health, _player.stats.max_health)
		_create_guardian_angel_effect()

	effect_triggered.emit("guardian_angel")
	print("[RelicEffects] Guardian Angel saved the player!")
	return true

## Riposte - Perfect dodge counter attack
func trigger_riposte():
	if not _has_effect("riposte"):
		return

	if not _player or not is_instance_valid(_player):
		return

	# Deal damage to all nearby enemies
	var enemies = get_tree().get_nodes_in_group("enemies")
	for enemy in enemies:
		if not is_instance_valid(enemy):
			continue
		var dist = _player.global_position.distance_to(enemy.global_position)
		if dist < 150:  # Riposte range
			if enemy.has_method("take_damage"):
				enemy.take_damage(25, _player.global_position, 200, 0.1, _player)

	_create_riposte_effect()
	effect_triggered.emit("riposte")

# ============================================
# VISUAL EFFECTS
# ============================================
func _spread_burn_to_nearby(position: Vector2):
	var enemies = get_tree().get_nodes_in_group("enemies")
	for enemy in enemies:
		if not is_instance_valid(enemy):
			continue
		var dist = position.distance_to(enemy.global_position)
		if dist < 120:  # Spread range
			if enemy.has_method("apply_status_effect"):
				enemy.apply_status_effect(StatusEffects.EffectType.BURN, _player, 2)

	# Fire explosion visual
	_create_explosion_effect(position, Color(1, 0.4, 0.1, 0.8))
	effect_triggered.emit("burn_spread")

func _trigger_shatter(position: Vector2):
	# Deal AoE damage
	var enemies = get_tree().get_nodes_in_group("enemies")
	for enemy in enemies:
		if not is_instance_valid(enemy):
			continue
		var dist = position.distance_to(enemy.global_position)
		if dist < 100:  # Shatter range
			if enemy.has_method("take_damage"):
				enemy.take_damage(30, position, 300, 0.2, _player, DamageTypes.Type.ICE)

	# Ice shatter visual
	_create_shatter_effect(position)
	effect_triggered.emit("shatter")

func _create_heal_effect(pos: Vector2, color: Color):
	var scene = get_tree().current_scene
	if not scene:
		return

	var heal_fx = ColorRect.new()
	heal_fx.size = Vector2(30, 30)
	heal_fx.pivot_offset = Vector2(15, 15)
	heal_fx.color = color
	heal_fx.global_position = pos - Vector2(15, 15)
	scene.add_child(heal_fx)

	var tween = TweenHelper.new_tween()
	tween.set_parallel(true)
	tween.tween_property(heal_fx, "global_position:y", pos.y - 50, 0.5)
	tween.tween_property(heal_fx, "modulate:a", 0.0, 0.5)
	tween.tween_callback(heal_fx.queue_free)

func _create_flash_effect(pos: Vector2):
	var scene = get_tree().current_scene
	if not scene:
		return

	var flash = ColorRect.new()
	flash.size = Vector2(40, 40)
	flash.pivot_offset = Vector2(20, 20)
	flash.color = Color(0.5, 0.2, 0.8, 0.7)
	flash.global_position = pos - Vector2(20, 20)
	scene.add_child(flash)

	var tween = TweenHelper.new_tween()
	tween.set_parallel(true)
	tween.tween_property(flash, "scale", Vector2(2, 2), 0.2)
	tween.tween_property(flash, "modulate:a", 0.0, 0.2)
	tween.tween_callback(flash.queue_free)

func _create_explosion_effect(pos: Vector2, color: Color):
	var scene = get_tree().current_scene
	if not scene:
		return

	var ring = ColorRect.new()
	ring.size = Vector2(50, 50)
	ring.pivot_offset = Vector2(25, 25)
	ring.color = color
	ring.global_position = pos - Vector2(25, 25)
	scene.add_child(ring)

	var tween = TweenHelper.new_tween()
	tween.set_parallel(true)
	tween.tween_property(ring, "scale", Vector2(3, 3), 0.3)
	tween.tween_property(ring, "modulate:a", 0.0, 0.3)
	tween.tween_callback(ring.queue_free)

func _create_shatter_effect(pos: Vector2):
	var scene = get_tree().current_scene
	if not scene:
		return

	# Create ice shards
	for i in range(8):
		var shard = ColorRect.new()
		shard.size = Vector2(8, 20)
		shard.pivot_offset = Vector2(4, 10)
		shard.color = Color(0.5, 0.8, 1.0, 0.9)
		shard.global_position = pos
		shard.rotation = randf() * TAU
		scene.add_child(shard)

		var angle = (i / 8.0) * TAU
		var end_pos = pos + Vector2.from_angle(angle) * 80

		var tween = TweenHelper.new_tween()
		tween.set_parallel(true)
		tween.tween_property(shard, "global_position", end_pos, 0.3)
		tween.tween_property(shard, "modulate:a", 0.0, 0.3)
		tween.tween_property(shard, "rotation", shard.rotation + PI, 0.3)
		tween.tween_callback(shard.queue_free)

func _create_guardian_angel_effect():
	if not _player:
		return

	var scene = get_tree().current_scene
	if not scene:
		return

	# Golden wings effect
	var wing = ColorRect.new()
	wing.size = Vector2(100, 100)
	wing.pivot_offset = Vector2(50, 50)
	wing.color = Color(1, 0.9, 0.4, 0.8)
	wing.global_position = _player.global_position - Vector2(50, 50)
	scene.add_child(wing)

	var tween = TweenHelper.new_tween()
	tween.set_parallel(true)
	tween.tween_property(wing, "scale", Vector2(3, 3), 0.5)
	tween.tween_property(wing, "modulate:a", 0.0, 0.5)
	tween.tween_callback(wing.queue_free)

	# Make player invulnerable briefly
	if _player.has_method("set_invulnerable"):
		_player.set_invulnerable(true)
		await get_tree().create_timer(1.0).timeout
		if is_instance_valid(_player) and _player.has_method("set_invulnerable"):
			_player.set_invulnerable(false)

func _create_riposte_effect():
	if not _player:
		return

	var scene = get_tree().current_scene
	if not scene:
		return

	# Slash effect around player
	var slash = ColorRect.new()
	slash.size = Vector2(80, 80)
	slash.pivot_offset = Vector2(40, 40)
	slash.color = Color(1, 1, 0.5, 0.7)
	slash.global_position = _player.global_position - Vector2(40, 40)
	scene.add_child(slash)

	var tween = TweenHelper.new_tween()
	tween.set_parallel(true)
	tween.tween_property(slash, "scale", Vector2(2, 2), 0.15)
	tween.tween_property(slash, "modulate:a", 0.0, 0.15)
	tween.tween_property(slash, "rotation", PI, 0.15)
	tween.tween_callback(slash.queue_free)

# ============================================
# EVENT HANDLERS
# ============================================
func _on_wave_completed(_wave_number: int):
	# Reset guardian angel for new wave
	_guardian_angel_used_this_wave = false

func _on_relic_collected(_relic: Resource):
	# Recalculate when new relic is collected
	pass

func _on_run_started():
	# Reset all state for new run
	_berserker_active = false
	_guardian_angel_used_this_wave = false
	_regen_timer = 0.0
