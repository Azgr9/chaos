# SCRIPT: Base.gd
# ATTACH TO: Base (Control) root node in Base.tscn
# LOCATION: res://Scripts/Ui/Base.gd
# PURPOSE: Hub scene controller with tabbed interface

extends Control

# Tab system
var current_tab: String = "main"
var tab_buttons: Dictionary = {}
var tab_panels: Dictionary = {}

# Training row references
var training_rows: Dictionary = {}

# Loaded resources
var all_relics: Array = []

# Dynamic UI containers
var content_container: VBoxContainer = null
var tab_button_container: HBoxContainer = null

# Training stat info
const TRAINING_INFO = {
	"vitality": {"display_name": "Vitality", "color": Color(0.8, 0.3, 0.3), "bonus": "+20 HP"},
	"strength": {"display_name": "Strength", "color": Color(0.9, 0.5, 0.2), "bonus": "+5% Dmg"},
	"agility": {"display_name": "Agility", "color": Color(0.3, 0.8, 0.4), "bonus": "+4% Spd"},
	"reflexes": {"display_name": "Reflexes", "color": Color(0.3, 0.6, 0.9), "bonus": "-5% CD"},
	"fortune": {"display_name": "Fortune", "color": Color(0.9, 0.8, 0.2), "bonus": "+20 Gold"}
}

# Enemy info for bestiary
const ENEMY_INFO = {
	"slime": {"emoji": "🟢", "color": Color(0.0, 1.0, 0.0), "name": "Slime"},
	"imp": {"emoji": "👿", "color": Color(0.6, 0.1, 0.2), "name": "Imp"},
	"goblin_archer": {"emoji": "🏹", "color": Color(0.18, 0.31, 0.09), "name": "Goblin Archer"},
	"unknown": {"emoji": "❓", "color": Color.GRAY, "name": "Unknown"}
}

func _ready():
	# Connect signals
	SaveManager.gold_changed.connect(_on_gold_changed)

	# Load resources
	_load_all_relics()

	# Build the entire UI dynamically
	_build_hub_ui()

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

# ============================================
# BUILD UI
# ============================================

func _build_hub_ui():
	# Clear existing children from the scene
	for child in get_children():
		child.queue_free()

	# Background
	var bg = ColorRect.new()
	bg.color = Color(0.08, 0.06, 0.12, 1)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)

	# Main margin container
	var margin = MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 40)
	margin.add_theme_constant_override("margin_right", 40)
	margin.add_theme_constant_override("margin_top", 20)
	margin.add_theme_constant_override("margin_bottom", 20)
	add_child(margin)

	var main_vbox = VBoxContainer.new()
	main_vbox.add_theme_constant_override("separation", 15)
	margin.add_child(main_vbox)

	# === HEADER ===
	var header = _create_header()
	main_vbox.add_child(header)

	# === TAB BUTTONS ===
	tab_button_container = _create_tab_buttons()
	main_vbox.add_child(tab_button_container)

	# === CONTENT AREA ===
	content_container = VBoxContainer.new()
	content_container.size_flags_vertical = Control.SIZE_EXPAND_FILL
	main_vbox.add_child(content_container)

	# === BOTTOM BAR (Enter Arena) ===
	var bottom = _create_bottom_bar()
	main_vbox.add_child(bottom)

	# Show main tab by default
	_switch_tab("main")

func _create_header() -> HBoxContainer:
	var header = HBoxContainer.new()
	header.add_theme_constant_override("separation", 20)

	# Title
	var title = Label.new()
	title.text = "THE BASE"
	title.add_theme_color_override("font_color", Color(0.9, 0.8, 0.6))
	title.add_theme_font_size_override("font_size", 36)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(title)

	# Gold display
	var gold = Label.new()
	gold.name = "GoldDisplay"
	gold.text = "💰 %d" % SaveManager.get_gold()
	gold.add_theme_color_override("font_color", Color(1, 0.85, 0.4))
	gold.add_theme_font_size_override("font_size", 24)
	header.add_child(gold)

	return header

func _create_tab_buttons() -> HBoxContainer:
	var container = HBoxContainer.new()
	container.add_theme_constant_override("separation", 10)
	container.alignment = BoxContainer.ALIGNMENT_CENTER

	var tabs = [
		{"id": "main", "text": "🏠 Main", "color": Color(0.9, 0.8, 0.6)},
		{"id": "training", "text": "⚔️ Training", "color": Color(0.9, 0.5, 0.2)},
		{"id": "relics", "text": "💎 Relics", "color": Color(0.6, 0.4, 0.9)},
		{"id": "bestiary", "text": "📖 Bestiary", "color": Color(0.9, 0.4, 0.4)},
		{"id": "stats", "text": "📊 Stats", "color": Color(0.4, 0.7, 0.9)}
	]

	for tab_data in tabs:
		var btn = Button.new()
		btn.text = tab_data.text
		btn.custom_minimum_size = Vector2(120, 40)
		btn.add_theme_font_size_override("font_size", 16)
		btn.pressed.connect(_switch_tab.bind(tab_data.id))
		container.add_child(btn)
		tab_buttons[tab_data.id] = {"button": btn, "color": tab_data.color}

	return container

func _create_bottom_bar() -> HBoxContainer:
	var bar = HBoxContainer.new()
	bar.alignment = BoxContainer.ALIGNMENT_CENTER

	var enter_btn = Button.new()
	enter_btn.text = "⚔️  ENTER ARENA  ⚔️"
	enter_btn.custom_minimum_size = Vector2(250, 60)
	enter_btn.add_theme_font_size_override("font_size", 22)
	enter_btn.pressed.connect(_on_enter_arena_pressed)
	bar.add_child(enter_btn)

	return bar

# ============================================
# TAB SWITCHING
# ============================================

func _switch_tab(tab_id: String):
	current_tab = tab_id

	# Update button styles
	for id in tab_buttons:
		var btn = tab_buttons[id].button
		if id == tab_id:
			btn.modulate = tab_buttons[id].color
		else:
			btn.modulate = Color(0.6, 0.6, 0.6)

	# Clear content
	for child in content_container.get_children():
		child.queue_free()

	# Build tab content
	match tab_id:
		"main":
			_build_main_tab()
		"training":
			_build_training_tab()
		"relics":
			_build_relics_tab()
		"bestiary":
			_build_bestiary_tab()
		"stats":
			_build_stats_tab()

# ============================================
# MAIN TAB
# ============================================

func _build_main_tab():
	var panel = PanelContainer.new()
	panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	content_container.add_child(panel)

	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 20)
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	panel.add_child(vbox)

	# Welcome message
	var welcome = Label.new()
	welcome.text = "Welcome, Warrior!"
	welcome.add_theme_font_size_override("font_size", 28)
	welcome.add_theme_color_override("font_color", Color(0.9, 0.8, 0.6))
	welcome.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(welcome)

	# Quick stats
	var stats = SaveManager.get_statistics()

	var stats_text = Label.new()
	stats_text.text = "Highest Wave: %d  |  Total Runs: %d  |  Total Kills: %d" % [
		stats.highest_wave, stats.total_runs, stats.total_kills
	]
	stats_text.add_theme_font_size_override("font_size", 16)
	stats_text.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7))
	stats_text.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(stats_text)

	# Starting stats preview
	var sep = HSeparator.new()
	vbox.add_child(sep)

	var starting_title = Label.new()
	starting_title.text = "Your Starting Stats:"
	starting_title.add_theme_font_size_override("font_size", 18)
	starting_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(starting_title)

	var base_health = 100 + SaveManager.get_training_bonus("vitality")
	var damage_bonus = SaveManager.get_training_bonus("strength") * 100
	var speed_bonus = SaveManager.get_training_bonus("agility") * 100
	var starting_gold = int(SaveManager.get_training_bonus("fortune"))

	var starting_stats = Label.new()
	starting_stats.text = "❤️ %d HP  |  ⚔️ +%d%% Dmg  |  👟 +%d%% Spd  |  💰 %d Gold" % [
		base_health, damage_bonus, speed_bonus, starting_gold
	]
	starting_stats.add_theme_font_size_override("font_size", 16)
	starting_stats.add_theme_color_override("font_color", Color(0.5, 0.8, 0.5))
	starting_stats.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(starting_stats)

	# Tip
	var tip = Label.new()
	tip.text = "\nUse the tabs above to train stats, unlock relics, or view your bestiary!"
	tip.add_theme_font_size_override("font_size", 14)
	tip.add_theme_color_override("font_color", Color(0.5, 0.5, 0.5))
	tip.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(tip)

# ============================================
# TRAINING TAB
# ============================================

func _build_training_tab():
	var scroll = ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	content_container.add_child(scroll)

	var vbox = VBoxContainer.new()
	vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vbox.add_theme_constant_override("separation", 10)
	scroll.add_child(vbox)

	# Title
	var title = Label.new()
	title.text = "TRAINING GROUNDS"
	title.add_theme_font_size_override("font_size", 24)
	title.add_theme_color_override("font_color", Color(0.9, 0.5, 0.2))
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(title)

	var subtitle = Label.new()
	subtitle.text = "Spend gold to permanently increase your starting stats"
	subtitle.add_theme_font_size_override("font_size", 14)
	subtitle.add_theme_color_override("font_color", Color(0.6, 0.6, 0.6))
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(subtitle)

	vbox.add_child(HSeparator.new())

	# Training rows
	training_rows.clear()
	for stat_name in ["vitality", "strength", "agility", "reflexes", "fortune"]:
		var row = _create_training_row(stat_name)
		vbox.add_child(row)
		training_rows[stat_name] = row

func _create_training_row(stat_name: String) -> HBoxContainer:
	var info = TRAINING_INFO[stat_name]
	var level = SaveManager.get_training_level(stat_name)
	var cost = SaveManager.get_training_cost(stat_name)

	var row = HBoxContainer.new()
	row.add_theme_constant_override("separation", 15)

	# Stat name
	var name_label = Label.new()
	name_label.text = info.display_name
	name_label.add_theme_color_override("font_color", info.color)
	name_label.add_theme_font_size_override("font_size", 18)
	name_label.custom_minimum_size.x = 120
	row.add_child(name_label)

	# Bonus description
	var bonus_label = Label.new()
	bonus_label.text = "(%s per level)" % info.bonus
	bonus_label.add_theme_font_size_override("font_size", 14)
	bonus_label.add_theme_color_override("font_color", Color(0.6, 0.6, 0.6))
	bonus_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(bonus_label)

	# Level display
	var level_label = Label.new()
	level_label.name = "Level"
	level_label.text = "Lv. %d/5" % level
	level_label.add_theme_font_size_override("font_size", 16)
	level_label.custom_minimum_size.x = 80
	row.add_child(level_label)

	# Upgrade button
	var btn = Button.new()
	btn.name = "UpgradeBtn"
	btn.custom_minimum_size = Vector2(100, 35)
	if cost < 0:
		btn.text = "MAX"
		btn.disabled = true
	else:
		btn.text = "%d 💰" % cost
		btn.disabled = SaveManager.get_gold() < cost
	btn.pressed.connect(_on_training_upgrade.bind(stat_name))
	row.add_child(btn)

	return row

func _on_training_upgrade(stat_name: String):
	if SaveManager.upgrade_training(stat_name):
		_build_training_tab()  # Rebuild to update

# ============================================
# RELICS TAB
# ============================================

func _build_relics_tab():
	var scroll = ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	content_container.add_child(scroll)

	var vbox = VBoxContainer.new()
	vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vbox.add_theme_constant_override("separation", 10)
	scroll.add_child(vbox)

	# Title
	var title = Label.new()
	title.text = "RELIC SHRINE"
	title.add_theme_font_size_override("font_size", 24)
	title.add_theme_color_override("font_color", Color(0.6, 0.4, 0.9))
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(title)

	var subtitle = Label.new()
	subtitle.text = "Unlock relics to find them during your runs"
	subtitle.add_theme_font_size_override("font_size", 14)
	subtitle.add_theme_color_override("font_color", Color(0.6, 0.6, 0.6))
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(subtitle)

	vbox.add_child(HSeparator.new())

	# Relic grid
	var grid = GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 15)
	grid.add_theme_constant_override("v_separation", 15)
	vbox.add_child(grid)

	for relic in all_relics:
		var card = _create_relic_card(relic)
		grid.add_child(card)

func _create_relic_card(relic: Resource) -> PanelContainer:
	var card = PanelContainer.new()
	card.custom_minimum_size = Vector2(280, 100)

	var hbox = HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 10)
	card.add_child(hbox)

	# Emoji icon
	var emoji = Label.new()
	emoji.text = relic.emoji
	emoji.add_theme_font_size_override("font_size", 32)
	hbox.add_child(emoji)

	var info_vbox = VBoxContainer.new()
	info_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hbox.add_child(info_vbox)

	# Name
	var name_label = Label.new()
	name_label.text = relic.relic_name if relic.relic_name else relic.id
	name_label.add_theme_color_override("font_color", relic.get_rarity_color() if relic.has_method("get_rarity_color") else Color.WHITE)
	name_label.add_theme_font_size_override("font_size", 16)
	info_vbox.add_child(name_label)

	# Effect
	var effect = Label.new()
	effect.text = relic.effect_description
	effect.add_theme_font_size_override("font_size", 12)
	effect.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7))
	info_vbox.add_child(effect)

	# Status/Button
	var is_unlocked = SaveManager.is_relic_unlocked(relic.id)
	if is_unlocked or relic.unlock_cost == 0:
		var status = Label.new()
		status.text = "✓ UNLOCKED" if is_unlocked else "✓ FREE"
		status.add_theme_color_override("font_color", Color.GREEN)
		status.add_theme_font_size_override("font_size", 12)
		info_vbox.add_child(status)
	else:
		var btn = Button.new()
		btn.text = "Unlock: %d 💰" % relic.unlock_cost
		btn.disabled = SaveManager.get_gold() < relic.unlock_cost
		btn.pressed.connect(_on_unlock_relic.bind(relic))
		info_vbox.add_child(btn)

	return card

func _on_unlock_relic(relic: Resource):
	if SaveManager.spend_gold(relic.unlock_cost):
		SaveManager.unlock_relic(relic.id)
		_build_relics_tab()  # Rebuild

# ============================================
# BESTIARY TAB
# ============================================

func _build_bestiary_tab():
	var scroll = ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	content_container.add_child(scroll)

	var vbox = VBoxContainer.new()
	vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vbox.add_theme_constant_override("separation", 10)
	scroll.add_child(vbox)

	# Title
	var title = Label.new()
	title.text = "BESTIARY"
	title.add_theme_font_size_override("font_size", 24)
	title.add_theme_color_override("font_color", Color(0.9, 0.4, 0.4))
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(title)

	var subtitle = Label.new()
	subtitle.text = "Enemies you have slain"
	subtitle.add_theme_font_size_override("font_size", 14)
	subtitle.add_theme_color_override("font_color", Color(0.6, 0.6, 0.6))
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(subtitle)

	vbox.add_child(HSeparator.new())

	var bestiary = SaveManager.get_bestiary()

	if bestiary.is_empty():
		var placeholder = Label.new()
		placeholder.text = "\n\nNo enemies slain yet.\n\nEnter the arena to fill your bestiary!"
		placeholder.add_theme_color_override("font_color", Color(0.5, 0.5, 0.5))
		placeholder.add_theme_font_size_override("font_size", 16)
		placeholder.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		vbox.add_child(placeholder)
		return

	# Sort by kills
	var sorted_enemies: Array = []
	for enemy_type in bestiary:
		sorted_enemies.append({"type": enemy_type, "kills": bestiary[enemy_type]})
	sorted_enemies.sort_custom(func(a, b): return a.kills > b.kills)

	# Enemy entries
	for entry in sorted_enemies:
		var row = _create_bestiary_row(entry.type, entry.kills)
		vbox.add_child(row)

	vbox.add_child(HSeparator.new())

	# Total
	var total = Label.new()
	total.text = "Total Kills: %d" % SaveManager.get_total_bestiary_kills()
	total.add_theme_font_size_override("font_size", 18)
	total.add_theme_color_override("font_color", Color(1, 0.85, 0.4))
	total.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(total)

func _create_bestiary_row(enemy_type: String, kills: int) -> HBoxContainer:
	var info = ENEMY_INFO.get(enemy_type, ENEMY_INFO["unknown"])

	var row = HBoxContainer.new()
	row.add_theme_constant_override("separation", 15)

	# Emoji
	var emoji = Label.new()
	emoji.text = info.emoji
	emoji.add_theme_font_size_override("font_size", 28)
	emoji.custom_minimum_size.x = 50
	row.add_child(emoji)

	# Name
	var name_label = Label.new()
	name_label.text = info.name
	name_label.add_theme_color_override("font_color", info.color)
	name_label.add_theme_font_size_override("font_size", 18)
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(name_label)

	# Kill count
	var count = Label.new()
	count.text = "x%d" % kills
	count.add_theme_color_override("font_color", Color(1, 0.85, 0.4))
	count.add_theme_font_size_override("font_size", 18)
	row.add_child(count)

	return row

# ============================================
# STATS TAB
# ============================================

func _build_stats_tab():
	var panel = PanelContainer.new()
	panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	content_container.add_child(panel)

	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 15)
	panel.add_child(vbox)

	# Title
	var title = Label.new()
	title.text = "STATISTICS"
	title.add_theme_font_size_override("font_size", 24)
	title.add_theme_color_override("font_color", Color(0.4, 0.7, 0.9))
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(title)

	vbox.add_child(HSeparator.new())

	var stats = SaveManager.get_statistics()

	var stats_data = [
		{"label": "Highest Wave Reached", "value": str(stats.highest_wave), "color": Color(0.9, 0.8, 0.2)},
		{"label": "Total Runs", "value": str(stats.total_runs), "color": Color(0.7, 0.7, 0.7)},
		{"label": "Total Kills", "value": str(stats.total_kills), "color": Color(0.9, 0.4, 0.4)},
		{"label": "Total Gold Earned", "value": str(stats.total_gold_earned), "color": Color(1, 0.85, 0.4)},
		{"label": "Current Gold", "value": str(SaveManager.get_gold()), "color": Color(1, 0.85, 0.4)}
	]

	for data in stats_data:
		var row = HBoxContainer.new()

		var label = Label.new()
		label.text = data.label
		label.add_theme_font_size_override("font_size", 16)
		label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(label)

		var value = Label.new()
		value.text = data.value
		value.add_theme_font_size_override("font_size", 18)
		value.add_theme_color_override("font_color", data.color)
		row.add_child(value)

		vbox.add_child(row)

	# Training summary
	vbox.add_child(HSeparator.new())

	var training_title = Label.new()
	training_title.text = "Training Levels"
	training_title.add_theme_font_size_override("font_size", 18)
	training_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(training_title)

	var training_row = HBoxContainer.new()
	training_row.alignment = BoxContainer.ALIGNMENT_CENTER
	training_row.add_theme_constant_override("separation", 20)
	vbox.add_child(training_row)

	for stat_name in TRAINING_INFO:
		var info = TRAINING_INFO[stat_name]
		var level = SaveManager.get_training_level(stat_name)

		var stat_label = Label.new()
		stat_label.text = "%s: %d" % [info.display_name, level]
		stat_label.add_theme_color_override("font_color", info.color)
		stat_label.add_theme_font_size_override("font_size", 14)
		training_row.add_child(stat_label)

# ============================================
# EVENT HANDLERS
# ============================================

func _on_gold_changed(new_amount: int):
	# Update gold display in header
	var gold_label = get_node_or_null("MarginContainer/HBoxContainer/GoldDisplay")
	if gold_label:
		gold_label.text = "💰 %d" % new_amount

	# Rebuild current tab to update buttons
	_switch_tab(current_tab)

func _on_enter_arena_pressed():
	RunManager.start_new_run()
	_give_random_starting_relic()
	get_tree().change_scene_to_file("res://Scenes/Game/Game.tscn")

func _give_random_starting_relic():
	var unlocked_relics: Array = []
	for relic in all_relics:
		if SaveManager.is_relic_unlocked(relic.id) or relic.unlock_cost == 0:
			unlocked_relics.append(relic)

	if unlocked_relics.size() > 0:
		var random_relic = unlocked_relics[randi() % unlocked_relics.size()]
		RunManager.add_relic(random_relic)
