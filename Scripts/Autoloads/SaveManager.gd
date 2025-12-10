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
		"fortune": 0
	},
	"unlocked_relics": [],
	# Bestiary - total kills per enemy type (permanent)
	"bestiary": {}
}

# Enemy display names for bestiary UI
const ENEMY_DISPLAY_NAMES = {
	"slime": "Slime",
	"imp": "Imp",
	"goblin_archer": "Goblin Archer",
	"healer": "Healer",
	"tank": "Tank",
	"spawner": "Spawner",
	"unknown": "Unknown"
}

# Training cost per level (index = level, value = cost)
const TRAINING_COSTS = [20, 50, 100, 200, 400]
const MAX_TRAINING_LEVEL = 5

# Training bonuses per level
const TRAINING_BONUSES = {
	"vitality": 20.0,    # +20 max health per level
	"strength": 0.05,    # +5% damage per level
	"agility": 0.04,     # +4% speed per level
	"reflexes": 0.05,    # -5% cooldown per level
	"fortune": 20        # +20 starting gold per level
}

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
# RESET (for testing)
# ============================================

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
			"fortune": 0
		},
		"unlocked_relics": [],
		"bestiary": {}
	}
	_ensure_starter_items_unlocked()
	save_game()
	gold_changed.emit(0)
