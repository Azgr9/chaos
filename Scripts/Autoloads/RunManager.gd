# SCRIPT: RunManager.gd
# AUTOLOAD: RunManager
# LOCATION: res://Scripts/Autoloads/RunManager.gd
# PURPOSE: Manages current run state, collected items, and calculated stats

extends Node

# Signals
signal run_started
signal run_ended(souls_earned: int)
signal relic_collected(relic: Resource)
signal trinket_collected(trinket: Resource)
signal stats_changed
signal gold_changed(new_amount: int)
signal wave_completed(wave_number: int)

# Run data structure - resets each run
var run_data: Dictionary = {
	"current_gold": 0,
	"current_wave": 0,
	"souls_earned": 0,
	"kills_this_run": 0,
	"run_active": false,

	"collected_relics": [],
	"collected_trinkets": [],

	"calculated_stats": {
		"max_health": 100.0,
		"damage_multiplier": 1.0,
		"speed_multiplier": 1.0,
		"cooldown_multiplier": 1.0,
		"crit_chance": 0.0,
		"crit_damage": 1.5,
		"lifesteal": 0.0,
		"damage_reduction": 0.0,
		"gold_multiplier": 1.0,
		"durability_multiplier": 1.0
	}
}

# Base stats before any bonuses
const BASE_STATS = {
	"max_health": 100.0,
	"damage_multiplier": 1.0,
	"speed_multiplier": 1.0,
	"cooldown_multiplier": 1.0,
	"crit_chance": 0.0,
	"crit_damage": 1.5,
	"lifesteal": 0.0,
	"damage_reduction": 0.0,
	"gold_multiplier": 1.0,
	"durability_multiplier": 1.0
}

func _ready():
	pass

# ============================================
# RUN LIFECYCLE
# ============================================

func start_new_run():
	# Reset run data
	run_data.current_gold = 0
	run_data.current_wave = 0
	run_data.souls_earned = 0
	run_data.kills_this_run = 0
	run_data.run_active = true
	run_data.collected_relics.clear()
	run_data.collected_trinkets.clear()

	# Apply training bonuses from SaveManager
	_apply_training_bonuses()

	# Add starting gold from fortune training
	var fortune_bonus = SaveManager.get_training_bonus("fortune")
	run_data.current_gold = int(fortune_bonus)

	recalculate_stats()
	run_started.emit()
	gold_changed.emit(run_data.current_gold)

	print("[RunManager] New run started with %d starting gold" % run_data.current_gold)

func end_run():
	if not run_data.run_active:
		return 0

	run_data.run_active = false

	# Calculate souls earned
	var wave_bonus = run_data.current_wave * 2
	var kill_bonus = run_data.kills_this_run / 10
	var total_souls = wave_bonus + kill_bonus
	run_data.souls_earned = total_souls

	# Update statistics in SaveManager
	SaveManager.update_statistics(run_data.current_wave, run_data.kills_this_run)

	run_ended.emit(total_souls)
	print("[RunManager] Run ended. Souls earned: %d (wave: %d, kills: %d)" % [total_souls, wave_bonus, kill_bonus])

	return total_souls

func is_run_active() -> bool:
	return run_data.run_active

# ============================================
# TRAINING BONUSES
# ============================================

func _apply_training_bonuses():
	# Reset to base stats first
	for key in BASE_STATS:
		run_data.calculated_stats[key] = BASE_STATS[key]

	# Apply vitality: +20 max health per level
	run_data.calculated_stats.max_health += SaveManager.get_training_bonus("vitality")

	# Apply strength: +5% damage per level
	run_data.calculated_stats.damage_multiplier += SaveManager.get_training_bonus("strength")

	# Apply agility: +4% speed per level
	run_data.calculated_stats.speed_multiplier += SaveManager.get_training_bonus("agility")

	# Apply reflexes: -5% cooldown per level (reduce multiplier)
	run_data.calculated_stats.cooldown_multiplier -= SaveManager.get_training_bonus("reflexes")
	run_data.calculated_stats.cooldown_multiplier = max(0.5, run_data.calculated_stats.cooldown_multiplier)

# ============================================
# GOLD
# ============================================

func get_gold() -> int:
	return run_data.current_gold

func add_gold(amount: int):
	var multiplied = int(amount * run_data.calculated_stats.gold_multiplier)
	run_data.current_gold += multiplied
	gold_changed.emit(run_data.current_gold)

func spend_gold(amount: int) -> bool:
	if run_data.current_gold >= amount:
		run_data.current_gold -= amount
		gold_changed.emit(run_data.current_gold)
		return true
	return false

# ============================================
# ITEMS
# ============================================

func add_relic(relic: Resource):
	if relic and relic not in run_data.collected_relics:
		run_data.collected_relics.append(relic)
		relic_collected.emit(relic)
		recalculate_stats()
		var relic_display_name = relic.relic_name if "relic_name" in relic else relic.id
		print("[RunManager] Relic collected: %s" % relic_display_name)

func add_trinket(trinket: Resource):
	if trinket:
		run_data.collected_trinkets.append(trinket)
		trinket_collected.emit(trinket)
		recalculate_stats()
		var trinket_display_name = trinket.trinket_name if "trinket_name" in trinket else trinket.id
		print("[RunManager] Trinket collected: %s" % trinket_display_name)

func get_collected_relics() -> Array:
	return run_data.collected_relics.duplicate()

func get_collected_trinkets() -> Array:
	return run_data.collected_trinkets.duplicate()

# ============================================
# STATS CALCULATION
# ============================================

func recalculate_stats():
	# Start with training bonuses
	_apply_training_bonuses()

	# Add relic bonuses
	for relic in run_data.collected_relics:
		_apply_item_stats(relic)

	# Add trinket bonuses
	for trinket in run_data.collected_trinkets:
		_apply_item_stats(trinket)

	stats_changed.emit()

func _apply_item_stats(item: Resource):
	if not item:
		return

	# Apply stat bonuses from item
	if "max_health_bonus" in item and item.max_health_bonus != 0:
		run_data.calculated_stats.max_health += item.max_health_bonus

	if "damage_percent" in item and item.damage_percent != 0:
		run_data.calculated_stats.damage_multiplier += item.damage_percent

	if "speed_percent" in item and item.speed_percent != 0:
		run_data.calculated_stats.speed_multiplier += item.speed_percent

	if "cooldown_percent" in item and item.cooldown_percent != 0:
		run_data.calculated_stats.cooldown_multiplier += item.cooldown_percent
		run_data.calculated_stats.cooldown_multiplier = max(0.3, run_data.calculated_stats.cooldown_multiplier)

	if "crit_chance" in item and item.crit_chance != 0:
		run_data.calculated_stats.crit_chance += item.crit_chance

	if "crit_damage" in item and item.crit_damage != 0:
		run_data.calculated_stats.crit_damage += item.crit_damage

	if "lifesteal" in item and item.lifesteal != 0:
		run_data.calculated_stats.lifesteal += item.lifesteal

	if "damage_reduction" in item and item.damage_reduction != 0:
		run_data.calculated_stats.damage_reduction += item.damage_reduction

	if "gold_multiplier" in item and item.gold_multiplier != 0:
		run_data.calculated_stats.gold_multiplier += item.gold_multiplier

	if "durability_bonus" in item and item.durability_bonus != 0:
		run_data.calculated_stats.durability_multiplier += item.durability_bonus

func get_stat(stat_name: String) -> float:
	if run_data.calculated_stats.has(stat_name):
		return run_data.calculated_stats[stat_name]
	return 0.0

func get_all_stats() -> Dictionary:
	return run_data.calculated_stats.duplicate()

# ============================================
# PROGRESS TRACKING
# ============================================

func add_kill():
	run_data.kills_this_run += 1

func get_kills() -> int:
	return run_data.kills_this_run

func complete_wave(wave_number: int = -1):
	if wave_number > 0:
		run_data.current_wave = wave_number
	else:
		run_data.current_wave += 1
	wave_completed.emit(run_data.current_wave)

func get_current_wave() -> int:
	return run_data.current_wave

func get_souls_for_run() -> int:
	var wave_bonus = run_data.current_wave * 2
	var kill_bonus = run_data.kills_this_run / 10
	return wave_bonus + kill_bonus

# ============================================
# SPECIAL EFFECTS CHECK
# ============================================

func has_special_effect(effect_name: String) -> bool:
	for relic in run_data.collected_relics:
		if "special_effect" in relic and relic.special_effect == effect_name:
			return true
	return false
