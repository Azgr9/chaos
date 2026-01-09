# SCRIPT: SaveManager.gd
# AUTOLOAD: SaveManager
# LOCATION: res://Scripts/Autoloads/SaveManager.gd
# PURPOSE: Handles persistent save data for permanent upgrades, unlocks, and statistics

extends Node

const SAVE_PATH = "user://save_data.json"

# Signals
signal gold_changed(new_amount: int)
signal training_upgraded(stat_name: String, new_level: int)
signal item_unlocked(item_id: String)

# Save data structure
var save_data: Dictionary = {
	"gold": 0,
	"statistics": {
		"highest_wave": 0,
		"total_runs": 0,
		"total_kills": 0,
		"total_gold_earned": 0
	},
	"training_levels": {
		"vitality": 0,
		"strength": 0,
		"agility": 0,
		"reflexes": 0,
		"fortune": 0,
		# New scaling upgrades
		"arsenal_mastery": 0,   # +2% damage per weapon owned
		"relic_attunement": 0,  # +3% stats per relic owned
		"ticket_pouch": 0,      # +15% bonus ticket chance per level
		"bargain_hunter": 0     # -1 ticket cost per level (applied in shop)
	},
	"unlocked_relics": [],  # Legacy - kept for compatibility
	# Relic Bestiary - discovered relics during runs
	"relic_bestiary": {},   # {relic_id: {discovered: true, times_collected: int}}
	# Bestiary - total kills per enemy type (permanent)
	"bestiary": {},
	# Settings
	"settings": {
		"master_volume": 1.0,
		"music_volume": 0.8,
		"sfx_volume": 1.0,
		"fullscreen": false,
		"vsync": true,
		"screen_shake": true,
		"damage_numbers": true
	}
}

# Settings changed signal
signal settings_changed()

# Enemy display names for bestiary UI
const ENEMY_DISPLAY_NAMES = {
	"slime": "Slime",
	"goblin_dual": "Goblin Warrior",
	"goblin_archer": "Goblin Archer",
	"healer": "Healer",
	"spawner": "Spawner",
	"boss": "Chaos Champion",
	"unknown": "Unknown"
}

# Training cost per level (index = level, value = cost)
# Balanced for ~420-500 gold per full 10-wave run:
# Level 1: ~half of early wave earnings (accessible after 1 run)
# Level 5: requires saving from multiple runs
const TRAINING_COSTS = [15, 35, 75, 150, 300]
const MAX_TRAINING_LEVEL = 5

# Training bonuses per level
const TRAINING_BONUSES = {
	"vitality": 15.0,    # +15 max health per level (75 at max)
	"strength": 0.06,    # +6% damage per level (30% at max)
	"agility": 0.05,     # +5% speed per level (25% at max)
	"reflexes": 0.04,    # -4% cooldown per level (20% at max)
	"fortune": 10,       # +10 starting gold per level (50 at max)
	# Scaling upgrades (applied via RunManager)
	"arsenal_mastery": 0.02,   # +2% damage per weapon owned, per level
	"relic_attunement": 0.03,  # +3% all stats per relic owned, per level
	"ticket_pouch": 0.15,      # +15% bonus ticket chance per level
	"bargain_hunter": 1        # -1 ticket cost per level (min 1)
}

# Fortune also gives +5% gold drop bonus per level (25% at max)
const FORTUNE_GOLD_BONUS_PER_LEVEL: float = 0.05

func _ready():
	load_game()

# ============================================
# SAVE/LOAD
# ============================================

func save_game():
	var file = FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file:
		var json_string = JSON.stringify(save_data, "\t")
		file.store_string(json_string)
		file.close()
		print("[SaveManager] Game saved successfully")
	else:
		push_error("[SaveManager] Failed to save game: " + str(FileAccess.get_open_error()))

func load_game():
	if not FileAccess.file_exists(SAVE_PATH):
		print("[SaveManager] No save file found, using defaults")
		_ensure_starter_items_unlocked()
		return

	var file = FileAccess.open(SAVE_PATH, FileAccess.READ)
	if file:
		var json_string = file.get_as_text()
		file.close()

		var json = JSON.new()
		var error = json.parse(json_string)
		if error == OK:
			var loaded_data = json.get_data()
			if loaded_data is Dictionary:
				_merge_save_data(loaded_data)
				print("[SaveManager] Game loaded successfully")
		else:
			push_error("[SaveManager] Failed to parse save file")

	_ensure_starter_items_unlocked()

func _merge_save_data(loaded: Dictionary):
	# Merge loaded data into save_data, preserving structure
	if loaded.has("gold"):
		save_data.gold = loaded.gold
	# Legacy support: convert old chaos_souls to gold
	elif loaded.has("chaos_souls"):
		save_data.gold = loaded.chaos_souls

	if loaded.has("statistics"):
		for key in loaded.statistics:
			if save_data.statistics.has(key):
				save_data.statistics[key] = loaded.statistics[key]
		# Legacy support: convert old total_souls_earned
		if loaded.statistics.has("total_souls_earned") and not loaded.statistics.has("total_gold_earned"):
			save_data.statistics.total_gold_earned = loaded.statistics.total_souls_earned

	if loaded.has("training_levels"):
		for key in loaded.training_levels:
			if save_data.training_levels.has(key):
				save_data.training_levels[key] = loaded.training_levels[key]

	if loaded.has("unlocked_relics"):
		save_data.unlocked_relics = loaded.unlocked_relics

	if loaded.has("bestiary"):
		save_data.bestiary = loaded.bestiary

	if loaded.has("relic_bestiary"):
		save_data.relic_bestiary = loaded.relic_bestiary

	if loaded.has("settings"):
		for key in loaded.settings:
			if save_data.settings.has(key):
				save_data.settings[key] = loaded.settings[key]

func _ensure_starter_items_unlocked():
	# Ensure free starter items are always unlocked
	var starter_relics = ["iron_ring", "chipped_fang", "trolls_heart", "thiefs_anklet"]

	for relic_id in starter_relics:
		if relic_id not in save_data.unlocked_relics:
			save_data.unlocked_relics.append(relic_id)

# ============================================
# GOLD (Permanent Currency)
# ============================================

func get_gold() -> int:
	return save_data.gold

func add_gold(amount: int):
	save_data.gold += amount
	save_data.statistics.total_gold_earned += amount
	gold_changed.emit(save_data.gold)
	save_game()

func spend_gold(amount: int) -> bool:
	if save_data.gold >= amount:
		save_data.gold -= amount
		gold_changed.emit(save_data.gold)
		save_game()
		return true
	return false

# ============================================
# TRAINING
# ============================================

func get_training_level(stat_name: String) -> int:
	if save_data.training_levels.has(stat_name):
		return save_data.training_levels[stat_name]
	return 0

func get_training_cost(stat_name: String) -> int:
	var level = get_training_level(stat_name)
	if level >= MAX_TRAINING_LEVEL:
		return -1  # Max level
	return TRAINING_COSTS[level]

func upgrade_training(stat_name: String) -> bool:
	if not save_data.training_levels.has(stat_name):
		return false

	var level = save_data.training_levels[stat_name]
	if level >= MAX_TRAINING_LEVEL:
		return false

	var cost = TRAINING_COSTS[level]
	if spend_gold(cost):
		save_data.training_levels[stat_name] += 1
		training_upgraded.emit(stat_name, save_data.training_levels[stat_name])
		save_game()
		return true
	return false

func get_training_bonus(stat_name: String) -> float:
	var level = get_training_level(stat_name)
	if TRAINING_BONUSES.has(stat_name):
		return TRAINING_BONUSES[stat_name] * level
	return 0.0

## Returns the gold drop multiplier from fortune training (1.0 = no bonus)
func get_fortune_gold_multiplier() -> float:
	var level = get_training_level("fortune")
	return 1.0 + (FORTUNE_GOLD_BONUS_PER_LEVEL * level)

# ============================================
# UNLOCKS
# ============================================

func is_relic_unlocked(relic_id: String) -> bool:
	return relic_id in save_data.unlocked_relics

func unlock_relic(relic_id: String) -> bool:
	if relic_id not in save_data.unlocked_relics:
		save_data.unlocked_relics.append(relic_id)
		item_unlocked.emit(relic_id)
		save_game()
		return true
	return false

func get_unlocked_relics() -> Array:
	return save_data.unlocked_relics.duplicate()

# ============================================
# STATISTICS
# ============================================

func update_statistics(wave: int, kills: int):
	save_data.statistics.total_runs += 1
	save_data.statistics.total_kills += kills
	if wave > save_data.statistics.highest_wave:
		save_data.statistics.highest_wave = wave
	save_game()

func get_statistics() -> Dictionary:
	return save_data.statistics.duplicate()

# ============================================
# BESTIARY
# ============================================

func add_bestiary_kill(enemy_type: String):
	if not save_data.bestiary.has(enemy_type):
		save_data.bestiary[enemy_type] = 0
	save_data.bestiary[enemy_type] += 1
	# Don't save on every kill, that's handled by end_run
	# Save is called when run ends via update_statistics

func get_bestiary() -> Dictionary:
	return save_data.bestiary.duplicate()

func get_bestiary_kill_count(enemy_type: String) -> int:
	if save_data.bestiary.has(enemy_type):
		return save_data.bestiary[enemy_type]
	return 0

func get_enemy_display_name(enemy_type: String) -> String:
	if ENEMY_DISPLAY_NAMES.has(enemy_type):
		return ENEMY_DISPLAY_NAMES[enemy_type]
	return enemy_type.capitalize().replace("_", " ")

func get_total_bestiary_kills() -> int:
	var total = 0
	for enemy_type in save_data.bestiary:
		total += save_data.bestiary[enemy_type]
	return total

# ============================================
# RELIC BESTIARY
# ============================================

## Discover a relic (called when player collects a relic during a run)
func discover_relic(relic_id: String) -> bool:
	var is_new = false
	if not save_data.relic_bestiary.has(relic_id):
		save_data.relic_bestiary[relic_id] = {
			"discovered": true,
			"times_collected": 0
		}
		is_new = true

	save_data.relic_bestiary[relic_id].times_collected += 1
	# Don't save on every discovery, save happens at run end
	return is_new

## Check if a relic has been discovered
func is_relic_discovered(relic_id: String) -> bool:
	return save_data.relic_bestiary.has(relic_id)

## Get the full relic bestiary
func get_relic_bestiary() -> Dictionary:
	return save_data.relic_bestiary.duplicate(true)

## Get how many times a relic has been collected
func get_relic_times_collected(relic_id: String) -> int:
	if save_data.relic_bestiary.has(relic_id):
		return save_data.relic_bestiary[relic_id].times_collected
	return 0

## Get total number of discovered relics
func get_discovered_relic_count() -> int:
	return save_data.relic_bestiary.size()

# ============================================
# SCALING UPGRADES (for RunManager)
# ============================================

## Get arsenal mastery bonus (damage % per weapon owned)
func get_arsenal_mastery_bonus() -> float:
	var level = get_training_level("arsenal_mastery")
	return TRAINING_BONUSES.arsenal_mastery * level

## Get relic attunement bonus (stat % per relic owned)
func get_relic_attunement_bonus() -> float:
	var level = get_training_level("relic_attunement")
	return TRAINING_BONUSES.relic_attunement * level

## Get ticket pouch bonus (bonus ticket chance %)
func get_ticket_pouch_bonus() -> float:
	var level = get_training_level("ticket_pouch")
	return TRAINING_BONUSES.ticket_pouch * level

## Get bargain hunter discount (ticket cost reduction)
func get_bargain_hunter_discount() -> int:
	var level = get_training_level("bargain_hunter")
	return int(TRAINING_BONUSES.bargain_hunter * level)

# ============================================
# RESET (for testing)
# ============================================

func reset_training_and_refund() -> int:
	# Calculate total gold spent on training
	var refund_amount = 0
	for stat_name in save_data.training_levels:
		var level = save_data.training_levels[stat_name]
		for i in range(level):
			refund_amount += TRAINING_COSTS[i]
		# Reset the level
		save_data.training_levels[stat_name] = 0

	# Add refund to gold
	save_data.gold += refund_amount
	gold_changed.emit(save_data.gold)
	save_game()

	return refund_amount

func reset_save():
	save_data = {
		"gold": 0,
		"statistics": {
			"highest_wave": 0,
			"total_runs": 0,
			"total_kills": 0,
			"total_gold_earned": 0
		},
		"training_levels": {
			"vitality": 0,
			"strength": 0,
			"agility": 0,
			"reflexes": 0,
			"fortune": 0,
			"arsenal_mastery": 0,
			"relic_attunement": 0,
			"ticket_pouch": 0,
			"bargain_hunter": 0
		},
		"unlocked_relics": [],
		"relic_bestiary": {},
		"bestiary": {},
		"settings": {
			"master_volume": 1.0,
			"music_volume": 0.8,
			"sfx_volume": 1.0,
			"fullscreen": false,
			"vsync": true,
			"screen_shake": true,
			"damage_numbers": true
		}
	}
	_ensure_starter_items_unlocked()
	save_game()
	gold_changed.emit(0)

# ============================================
# SETTINGS
# ============================================

func get_setting(key: String):
	if save_data.settings.has(key):
		return save_data.settings[key]
	return null

func set_setting(key: String, value) -> void:
	if save_data.settings.has(key):
		save_data.settings[key] = value
		_apply_setting(key, value)
		save_game()
		settings_changed.emit()

func get_all_settings() -> Dictionary:
	return save_data.settings.duplicate()

func _apply_setting(key: String, value) -> void:
	match key:
		"master_volume":
			AudioServer.set_bus_volume_db(AudioServer.get_bus_index("Master"), linear_to_db(value))
		"music_volume":
			var music_bus = AudioServer.get_bus_index("Music")
			if music_bus >= 0:
				AudioServer.set_bus_volume_db(music_bus, linear_to_db(value))
		"sfx_volume":
			var sfx_bus = AudioServer.get_bus_index("SFX")
			if sfx_bus >= 0:
				AudioServer.set_bus_volume_db(sfx_bus, linear_to_db(value))
		"fullscreen":
			if value:
				DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
			else:
				DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
		"vsync":
			if value:
				DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_ENABLED)
			else:
				DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)

func apply_all_settings() -> void:
	for key in save_data.settings:
		_apply_setting(key, save_data.settings[key])
