# SCRIPT: Base.gd
# ATTACH TO: Base (Control) root node in Base.tscn
# LOCATION: res://Scripts/Ui/Base.gd
# PURPOSE: Hub scene controller - training, unlocks, and run start

extends Control

# Node references
@onready var gold_display: Label = $MarginContainer/VBoxContainer/Header/GoldDisplay
@onready var training_stats: VBoxContainer = $MarginContainer/VBoxContainer/MainContent/TrainingPanel/TrainingContent/TrainingStats
@onready var relic_grid: VBoxContainer = $MarginContainer/VBoxContainer/MainContent/RelicPanel/RelicContent/ScrollContainer/RelicGrid
@onready var enter_arena_button: Button = $MarginContainer/VBoxContainer/BottomBar/EnterArenaButton

# Stats display
@onready var highest_wave_label: Label = $MarginContainer/VBoxContainer/BottomBar/StatsPanel/HighestWave
@onready var total_runs_label: Label = $MarginContainer/VBoxContainer/BottomBar/StatsPanel/TotalRuns
@onready var total_kills_label: Label = $MarginContainer/VBoxContainer/BottomBar/StatsPanel/TotalKills
@onready var health_stat_label: Label = $MarginContainer/VBoxContainer/BottomBar/StartingStats/HealthStat
@onready var damage_stat_label: Label = $MarginContainer/VBoxContainer/BottomBar/StartingStats/DamageStat
@onready var speed_stat_label: Label = $MarginContainer/VBoxContainer/BottomBar/StartingStats/SpeedStat
@onready var gold_stat_label: Label = $MarginContainer/VBoxContainer/BottomBar/StartingStats/GoldStat

# Training row references
var training_rows: Dictionary = {}

# Loaded resources
var all_relics: Array = []

# Training stat info
const TRAINING_INFO = {
	"vitality": {
		"display_name": "Vitality",
		"color": Color(0.8, 0.3, 0.3),
		"description": "+20 Max Health per level"
	},
	"strength": {
		"display_name": "Strength",
		"color": Color(0.9, 0.5, 0.2),
		"description": "+5% Damage per level"
	},
	"agility": {
		"display_name": "Agility",
		"color": Color(0.3, 0.8, 0.4),
		"description": "+4% Speed per level"
	},
	"reflexes": {
		"display_name": "Reflexes",
		"color": Color(0.3, 0.6, 0.9),
		"description": "-5% Cooldowns per level"
	},
	"fortune": {
		"display_name": "Fortune",
		"color": Color(0.9, 0.8, 0.2),
		"description": "+20 Starting Gold per level"
	}
}

func _ready():
	# Connect signals
	SaveManager.gold_changed.connect(_on_gold_changed)
	SaveManager.training_upgraded.connect(_on_training_upgraded)
	enter_arena_button.pressed.connect(_on_enter_arena_pressed)

	# Load resources
	_load_all_relics()

	# Setup UI
	_setup_training_rows()
	_populate_relic_grid()

	# Update displays
	_update_gold_display()
	_update_statistics_display()
	_update_starting_stats_display()

func _load_all_relics():
	var dir = DirAccess.open("res://Resources/Relics")
	if dir:
		dir.list_dir_begin()
		var file_name = dir.get_next()
		while file_name != "":
			if file_name.ends_with(".tres"):
				var relic = load("res://Resources/Relics/" + file_name)
				if relic:
					all_relics.append(relic)
			file_name = dir.get_next()
		dir.list_dir_end()
	print("[Base] Loaded %d relics" % all_relics.size())

# ============================================
# TRAINING SETUP
# ============================================

func _setup_training_rows():
	var stat_names = ["vitality", "strength", "agility", "reflexes", "fortune"]

	for i in range(stat_names.size()):
		var stat_name = stat_names[i]
		var row = training_stats.get_child(i)
		if row:
			training_rows[stat_name] = row
			var upgrade_btn = row.get_node("UpgradeBtn")
			if upgrade_btn:
				upgrade_btn.pressed.connect(_on_training_upgrade_pressed.bind(stat_name))

	_update_all_training_rows()

func _update_all_training_rows():
	for stat_name in training_rows:
		_update_training_row(stat_name)

func _update_training_row(stat_name: String):
	if not training_rows.has(stat_name):
		return

	var row = training_rows[stat_name]
	var level = SaveManager.get_training_level(stat_name)
	var cost = SaveManager.get_training_cost(stat_name)

	var level_label = row.get_node("StatLevel")
	var upgrade_btn = row.get_node("UpgradeBtn")

	if level_label:
		level_label.text = "Lv. %d/5" % level

	if upgrade_btn:
		if cost < 0:
			upgrade_btn.text = "MAX"
			upgrade_btn.disabled = true
		else:
			upgrade_btn.text = "%d Gold" % cost
			upgrade_btn.disabled = SaveManager.get_gold() < cost

func _on_training_upgrade_pressed(stat_name: String):
	if SaveManager.upgrade_training(stat_name):
		_update_all_training_rows()
		_update_starting_stats_display()

func _on_training_upgraded(stat_name: String, new_level: int):
	_update_training_row(stat_name)
	_update_starting_stats_display()

# ============================================
# RELIC GRID
# ============================================

func _populate_relic_grid():
	# Clear existing children
	for child in relic_grid.get_children():
		child.queue_free()

	# Create cards for each relic
	for relic in all_relics:
		var card = _create_relic_card(relic)
		relic_grid.add_child(card)

func _create_relic_card(relic: Resource) -> Control:
	var card = PanelContainer.new()
	card.custom_minimum_size = Vector2(160, 120)

	var vbox = VBoxContainer.new()
	card.add_child(vbox)

	# Name with emoji
	var name_label = Label.new()
	name_label.text = "%s %s" % [relic.emoji, relic.relic_name if relic.relic_name else relic.id]
	name_label.add_theme_color_override("font_color", relic.get_rarity_color() if relic.has_method("get_rarity_color") else Color.WHITE)
	name_label.add_theme_font_size_override("font_size", 14)
	vbox.add_child(name_label)

	# Effect
	var effect_label = Label.new()
	effect_label.text = relic.effect_description
	effect_label.add_theme_font_size_override("font_size", 12)
	effect_label.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7))
	effect_label.autowrap_mode = TextServer.AUTOWRAP_WORD
	vbox.add_child(effect_label)

	# Flavor text
	var flavor_label = Label.new()
	flavor_label.text = relic.flavor_text
	flavor_label.add_theme_font_size_override("font_size", 10)
	flavor_label.add_theme_color_override("font_color", Color(0.5, 0.5, 0.5))
	flavor_label.autowrap_mode = TextServer.AUTOWRAP_WORD
	vbox.add_child(flavor_label)

	# Unlock status / button
	var is_unlocked = SaveManager.is_relic_unlocked(relic.id)

	if not is_unlocked and relic.unlock_cost > 0:
		var unlock_btn = Button.new()
		unlock_btn.text = "Unlock: %d Gold" % relic.unlock_cost
		unlock_btn.disabled = SaveManager.get_gold() < relic.unlock_cost
		unlock_btn.pressed.connect(_on_unlock_pressed.bind(relic, unlock_btn))
		vbox.add_child(unlock_btn)
	else:
		var status_label = Label.new()
		status_label.text = "UNLOCKED" if is_unlocked else "FREE"
		status_label.add_theme_color_override("font_color", Color.GREEN if is_unlocked else Color.YELLOW)
		status_label.add_theme_font_size_override("font_size", 12)
		vbox.add_child(status_label)

	return card

func _on_unlock_pressed(relic: Resource, button: Button):
	var cost = relic.unlock_cost
	if SaveManager.spend_gold(cost):
		SaveManager.unlock_relic(relic.id)

		# Update button to show unlocked
		button.text = "UNLOCKED"
		button.disabled = true

		# Update all UI (some buttons may now be affordable)
		_update_all_training_rows()
		_populate_relic_grid()

# ============================================
# DISPLAY UPDATES
# ============================================

func _update_gold_display():
	gold_display.text = "Gold: %d" % SaveManager.get_gold()

func _on_gold_changed(new_amount: int):
	gold_display.text = "Gold: %d" % new_amount
	_update_all_training_rows()

func _update_statistics_display():
	var stats = SaveManager.get_statistics()
	highest_wave_label.text = "Highest Wave: %d" % stats.highest_wave
	total_runs_label.text = "Total Runs: %d" % stats.total_runs
	total_kills_label.text = "Total Kills: %d" % stats.total_kills

func _update_starting_stats_display():
	# Calculate what stats would be at run start
	var base_health = 100 + SaveManager.get_training_bonus("vitality")
	var damage_bonus = SaveManager.get_training_bonus("strength") * 100
	var speed_bonus = SaveManager.get_training_bonus("agility") * 100
	var starting_gold = int(SaveManager.get_training_bonus("fortune"))

	health_stat_label.text = "Max Health: %d" % base_health
	damage_stat_label.text = "Damage: +%d%%" % damage_bonus
	speed_stat_label.text = "Speed: +%d%%" % speed_bonus
	gold_stat_label.text = "Starting Gold: %d" % starting_gold

# ============================================
# ARENA ENTRY
# ============================================

func _on_enter_arena_pressed():
	# Start new run
	RunManager.start_new_run()

	# Give random starting relic from unlocked relics
	_give_random_starting_relic()

	# Transition to arena
	get_tree().change_scene_to_file("res://Scenes/Game/Game.tscn")

func _give_random_starting_relic():
	# Get all unlocked relics
	var unlocked_relics: Array = []
	for relic in all_relics:
		if SaveManager.is_relic_unlocked(relic.id) or relic.unlock_cost == 0:
			unlocked_relics.append(relic)

	if unlocked_relics.size() > 0:
		# Pick a random relic
		var random_relic = unlocked_relics[randi() % unlocked_relics.size()]
		RunManager.add_relic(random_relic)
		print("[Base] Starting run with relic: %s" % random_relic.relic_name)
