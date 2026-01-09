# SCRIPT: RunManager.gd
# AUTOLOAD: RunManager
# LOCATION: res://Scripts/Autoloads/RunManager.gd
# PURPOSE: Manages current run state, collected items, and calculated stats

extends Node

# Signals
signal run_started
signal run_ended(gold_earned: int)
signal relic_collected(relic: Resource)
signal stats_changed
signal gold_changed(new_amount: int)
signal tickets_changed(new_amount: int)
signal wave_completed(wave_number: int)
signal bloodlust_activated(stack_count: int)
signal bloodlust_cleared
signal shop_entered(ticket_count: int)

# Run data structure - resets each run
var run_data: Dictionary = {
	"current_gold": 0,
	"current_wave": 0,
	"gold_earned": 0,
	"kills_this_run": 0,
	"run_active": false,

	"collected_relics": [],

	# Coliseum Tickets - shop currency earned per wave
	"coliseum_tickets": 0,
	"tickets_earned_this_wave": false,  # Prevents double ticket gain
	"portal_destroyed": false,  # If true, no tickets this wave

	# Bestiary - kills by enemy type this run
	"kills_by_type": {},

	# Bloodlust system - skip portal for stacking bonuses
	"bloodlust_stacks": 0,

	# Weapon count for scaling bonuses
	"weapons_collected": 0,

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
		"durability_multiplier": 1.0,
		"ticket_bonus": 0.0  # Bonus tickets from relics/upgrades
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
	"durability_multiplier": 1.0,
	"ticket_bonus": 0.0
}

# Coliseum Ticket costs by rarity
const TICKET_COSTS = {
	"common": 1,
	"uncommon": 2,
	"rare": 3,
	"legendary": 4
}

const TICKETS_PER_WAVE := 1
const TICKETS_PER_BOSS := 2

func _ready():
	pass

# ============================================
# RUN LIFECYCLE
# ============================================

func start_new_run():
	# Reset run data
	run_data.current_gold = 0
	run_data.current_wave = 0
	run_data.gold_earned = 0
	run_data.kills_this_run = 0
	run_data.run_active = true
	run_data.collected_relics.clear()
	run_data.kills_by_type.clear()
	run_data.bloodlust_stacks = 0
	run_data.coliseum_tickets = 0
	run_data.tickets_earned_this_wave = false
	run_data.portal_destroyed = false
	run_data.weapons_collected = 2  # Start with 2 weapons (sword + staff)

	# Apply training bonuses from SaveManager
	_apply_training_bonuses()

	# Add starting gold from fortune training
	var fortune_bonus = SaveManager.get_training_bonus("fortune")
	run_data.current_gold = int(fortune_bonus)

	recalculate_stats()
	run_started.emit()
	gold_changed.emit(run_data.current_gold)
	tickets_changed.emit(run_data.coliseum_tickets)

	print("[RunManager] New run started with %d starting gold" % run_data.current_gold)

func end_run():
	if not run_data.run_active:
		return 0

	run_data.run_active = false

	# Gold earned = remaining gold + wave bonus (no kill bonus)
	var wave_bonus = run_data.current_wave * 5  # 5 gold per wave survived
	var total_gold = run_data.current_gold + wave_bonus
	run_data.gold_earned = total_gold

	# Update statistics in SaveManager
	SaveManager.update_statistics(run_data.current_wave, run_data.kills_this_run)

	run_ended.emit(total_gold)
	print("[RunManager] Run ended. Gold earned: %d (kept: %d, wave: %d)" % [total_gold, run_data.current_gold, wave_bonus])

	return total_gold

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
# COLISEUM TICKETS
# ============================================

func get_tickets() -> int:
	return run_data.coliseum_tickets

func add_tickets(amount: int):
	run_data.coliseum_tickets += amount
	tickets_changed.emit(run_data.coliseum_tickets)
	print("[RunManager] +%d Coliseum Tickets (Total: %d)" % [amount, run_data.coliseum_tickets])

func spend_tickets(amount: int) -> bool:
	if run_data.coliseum_tickets >= amount:
		run_data.coliseum_tickets -= amount
		tickets_changed.emit(run_data.coliseum_tickets)
		return true
	return false

func get_ticket_cost(rarity: String) -> int:
	var base_cost = TICKET_COSTS.get(rarity, 2)
	# Apply bargain hunter discount from SaveManager
	var discount = SaveManager.get_training_bonus("bargain_hunter") if SaveManager else 0.0
	var final_cost = max(1, base_cost - int(discount))
	return final_cost

## Called when wave is completed - awards tickets if portal wasn't destroyed
func award_wave_tickets(is_boss_wave: bool = false):
	if run_data.tickets_earned_this_wave:
		return  # Already earned tickets this wave

	if run_data.portal_destroyed:
		print("[RunManager] Portal destroyed - no tickets earned this wave")
		run_data.portal_destroyed = false  # Reset for next wave
		run_data.tickets_earned_this_wave = true
		return

	# Calculate tickets to award
	var tickets = TICKETS_PER_BOSS if is_boss_wave else TICKETS_PER_WAVE

	# Apply ticket bonus from relics/training
	var bonus_chance = run_data.calculated_stats.ticket_bonus
	if bonus_chance > 0 and randf() < bonus_chance:
		tickets += 1
		print("[RunManager] Bonus ticket from luck!")

	add_tickets(tickets)
	run_data.tickets_earned_this_wave = true

## Called when entering the shop - awards bonus tickets from relics
func on_shop_entered():
	# Reset wave ticket tracking for next wave
	run_data.tickets_earned_this_wave = false
	run_data.portal_destroyed = false

	# Check for Ticket Collector relic (+1 ticket on shop entry)
	if has_special_effect("ticket_collector"):
		add_tickets(1)
		print("[RunManager] Ticket Collector bonus!")

	shop_entered.emit(run_data.coliseum_tickets)

## Called when portal is destroyed (bloodlust) - prevents ticket gain
func mark_portal_destroyed():
	run_data.portal_destroyed = true
	print("[RunManager] Portal destroyed - will not earn tickets this wave")

func add_weapon_collected():
	run_data.weapons_collected += 1
	recalculate_stats()  # Recalc for weapon scaling bonuses

func get_weapons_collected() -> int:
	return run_data.weapons_collected

# ============================================
# ITEMS
# ============================================

func add_relic(relic: Resource):
	if relic and relic not in run_data.collected_relics:
		run_data.collected_relics.append(relic)
		relic_collected.emit(relic)
		recalculate_stats()

		# Track in relic bestiary (permanent discovery)
		var relic_id = relic.id if "id" in relic else ""
		if relic_id and SaveManager:
			var is_new = SaveManager.discover_relic(relic_id)
			if is_new:
				print("[RunManager] NEW RELIC DISCOVERED: %s" % relic_id)

		var relic_display_name = relic.relic_name if "relic_name" in relic else relic.id
		print("[RunManager] Relic collected: %s" % relic_display_name)

func get_collected_relics() -> Array:
	return run_data.collected_relics.duplicate()

# ============================================
# STATS CALCULATION
# ============================================

func recalculate_stats():
	# Start with training bonuses
	_apply_training_bonuses()

	# Add relic bonuses
	for relic in run_data.collected_relics:
		_apply_item_stats(relic)

	# Apply weapon scaling bonuses (Arsenal Mastery)
	var arsenal_bonus = SaveManager.get_training_bonus("arsenal_mastery") if SaveManager else 0.0
	if arsenal_bonus > 0 and run_data.weapons_collected > 0:
		run_data.calculated_stats.damage_multiplier += arsenal_bonus * run_data.weapons_collected

	# Apply relic scaling bonuses (Relic Attunement)
	var relic_bonus = SaveManager.get_training_bonus("relic_attunement") if SaveManager else 0.0
	if relic_bonus > 0 and run_data.collected_relics.size() > 0:
		run_data.calculated_stats.damage_multiplier += relic_bonus * run_data.collected_relics.size()

	# Apply ticket pouch bonus (extra ticket chance)
	var ticket_pouch_bonus = SaveManager.get_training_bonus("ticket_pouch") if SaveManager else 0.0
	run_data.calculated_stats.ticket_bonus = ticket_pouch_bonus

	# Apply bloodlust bonuses
	if run_data.bloodlust_stacks > 0:
		run_data.calculated_stats.damage_multiplier *= get_bloodlust_damage_multiplier()
		run_data.calculated_stats.gold_multiplier *= get_bloodlust_gold_multiplier()

	stats_changed.emit()

func _apply_item_stats(item: Resource):
	if not item:
		return

	# Use relic's apply method if available (new system)
	if item is RelicResource and item.has_method("apply_to_stats"):
		run_data.calculated_stats = item.apply_to_stats(run_data.calculated_stats)
		return

	# Legacy fallback for items without apply method
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

func add_kill_by_type(enemy_type: String):
	run_data.kills_this_run += 1
	if not run_data.kills_by_type.has(enemy_type):
		run_data.kills_by_type[enemy_type] = 0
	run_data.kills_by_type[enemy_type] += 1

	# Also update permanent bestiary in SaveManager
	SaveManager.add_bestiary_kill(enemy_type)

func get_kills() -> int:
	return run_data.kills_this_run

func get_kills_by_type() -> Dictionary:
	return run_data.kills_by_type.duplicate()

func complete_wave(wave_number: int = -1):
	if wave_number > 0:
		run_data.current_wave = wave_number
	else:
		run_data.current_wave += 1
	wave_completed.emit(run_data.current_wave)

func get_current_wave() -> int:
	return run_data.current_wave

func get_gold_for_run() -> int:
	var wave_bonus = run_data.current_wave * 5
	return run_data.current_gold + wave_bonus

# ============================================
# SPECIAL EFFECTS CHECK
# ============================================

func has_special_effect(effect_name: String) -> bool:
	for relic in run_data.collected_relics:
		if "special_effect" in relic and relic.special_effect == effect_name:
			return true
	return false

# ============================================
# BLOODLUST SYSTEM
# ============================================
# Bloodlust is activated when player destroys the portal instead of entering
# Each stack gives bonuses but prevents healing/shopping for that wave transition

const BLOODLUST_GOLD_BONUS := 0.25  # +25% gold per stack
const BLOODLUST_DAMAGE_BONUS := 0.15  # +15% damage per stack
const BLOODLUST_ENEMY_HP_PENALTY := 0.10  # +10% enemy HP per stack (after 2 stacks)

func activate_bloodlust():
	run_data.bloodlust_stacks += 1
	bloodlust_activated.emit(run_data.bloodlust_stacks)
	recalculate_stats()
	print("[RunManager] BLOODLUST activated! Stack: %d" % run_data.bloodlust_stacks)

func clear_bloodlust():
	if run_data.bloodlust_stacks > 0:
		run_data.bloodlust_stacks = 0
		bloodlust_cleared.emit()
		recalculate_stats()
		print("[RunManager] Bloodlust cleared")

func get_bloodlust_stacks() -> int:
	return run_data.bloodlust_stacks

func has_bloodlust() -> bool:
	return run_data.bloodlust_stacks > 0

func get_bloodlust_gold_multiplier() -> float:
	return 1.0 + (run_data.bloodlust_stacks * BLOODLUST_GOLD_BONUS)

func get_bloodlust_damage_multiplier() -> float:
	return 1.0 + (run_data.bloodlust_stacks * BLOODLUST_DAMAGE_BONUS)

func get_bloodlust_enemy_hp_multiplier() -> float:
	# Only applies penalty after 2+ stacks
	if run_data.bloodlust_stacks >= 2:
		return 1.0 + ((run_data.bloodlust_stacks - 1) * BLOODLUST_ENEMY_HP_PENALTY)
	return 1.0
