# SCRIPT: GameOverScreen.gd
# ATTACH TO: GameOverScreen (CanvasLayer) root in GameOverScreen.tscn
# LOCATION: res://Scripts/Ui/GameOverScreen.gd

class_name GameOverScreen
extends CanvasLayer

# Nodes
@onready var control: Control = $Control
@onready var background: ColorRect = $Control/Background
@onready var container: VBoxContainer = $Control/Container
@onready var title_label: Label = $Control/Container/Title
@onready var death_effect: ColorRect = $Control/DeathEffect

# Stats display
@onready var wave_value: Label = $Control/Container/StatsContainer/WaveStat/Value
@onready var enemies_value: Label = $Control/Container/StatsContainer/EnemiesStat/Value
@onready var score_value: Label = $Control/Container/StatsContainer/ScoreStat/Value

# Gold reward display
@onready var kept_gold_value: Label = $Control/Container/GoldSection/KeptGold/Value
@onready var wave_bonus_value: Label = $Control/Container/GoldSection/WaveBonus/Value
@onready var total_gold_value: Label = $Control/Container/GoldSection/TotalGold/Value

# Buttons
@onready var return_to_base_button: Button = $Control/Container/ButtonContainer/ReturnToBaseButton
@onready var restart_button: Button = $Control/Container/ButtonContainer/RestartButton
@onready var tip_label: Label = $Control/Container/TipLabel

# Kill breakdown (dynamically created)
var kill_breakdown_container: VBoxContainer = null

# Stats tracking
var waves_survived: int = 0
var enemies_killed: int = 0
var final_score: int = 0
var gold_earned: int = 0

# Enemy display info
const ENEMY_INFO = {
	"slime": {"emoji": "🟢", "color": Color(0.0, 1.0, 0.0), "name": "Slime"},
	"imp": {"emoji": "👿", "color": Color(0.6, 0.1, 0.2), "name": "Imp"},
	"goblin_archer": {"emoji": "🏹", "color": Color(0.18, 0.31, 0.09), "name": "Goblin Archer"},
	"unknown": {"emoji": "❓", "color": Color.GRAY, "name": "Unknown"}
}

# Death messages
var death_tips = [
	"Tip: Keep your distance from enemies!",
	"Tip: Magic attacks can hit multiple enemies!",
	"Tip: Upgrade at the Base to get stronger!",
	"Tip: Movement is key to survival!",
	"Tip: Each wave gets progressively harder!",
	"Tip: Collect Gold to unlock new items!",
	"Tip: Use dash to avoid enemy attacks!",
	"Tip: Trinkets stack - collect many!",
	"Tip: Unspent gold carries over to your savings!"
]

func _ready():
	visible = false

	# Connect buttons
	return_to_base_button.pressed.connect(_on_return_to_base_pressed)
	restart_button.pressed.connect(_on_restart_pressed)

func show_game_over(stats: Dictionary):
	# Set stats
	waves_survived = stats.get("waves", 0)
	enemies_killed = stats.get("enemies_killed", 0)
	final_score = stats.get("score", 0)
	var kept_gold = stats.get("gold", 0)

	# Calculate gold rewards (unspent gold + wave bonus only)
	var wave_bonus = waves_survived * 5  # 5 gold per wave
	gold_earned = kept_gold + wave_bonus

	# Update display
	wave_value.text = str(waves_survived)
	enemies_value.text = str(enemies_killed)
	score_value.text = str(final_score)

	# Update gold display
	kept_gold_value.text = "+%d" % kept_gold
	wave_bonus_value.text = "+%d" % wave_bonus
	total_gold_value.text = "+%d" % gold_earned

	# Random tip
	tip_label.text = death_tips[randi() % death_tips.size()]

	# Create kill breakdown display
	_create_kill_breakdown()

	# Show screen with animation
	_animate_in()

func _create_kill_breakdown():
	# Remove existing breakdown if present
	if kill_breakdown_container:
		kill_breakdown_container.queue_free()

	# Get kills by type from RunManager
	var kills_by_type = {}
	if RunManager:
		kills_by_type = RunManager.get_kills_by_type()

	if kills_by_type.is_empty():
		return

	# Create container for kill breakdown
	kill_breakdown_container = VBoxContainer.new()
	kill_breakdown_container.add_theme_constant_override("separation", 4)

	# Title
	var title = Label.new()
	title.text = "ENEMIES SLAIN"
	title.add_theme_color_override("font_color", Color(0.9, 0.4, 0.4))
	title.add_theme_font_size_override("font_size", 16)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	kill_breakdown_container.add_child(title)

	# Separator
	var sep = HSeparator.new()
	kill_breakdown_container.add_child(sep)

	# Sort by kill count (descending)
	var sorted_enemies: Array = []
	for enemy_type in kills_by_type:
		sorted_enemies.append({"type": enemy_type, "kills": kills_by_type[enemy_type]})
	sorted_enemies.sort_custom(func(a, b): return a.kills > b.kills)

	# Create entry for each enemy type
	for entry in sorted_enemies:
		var row = _create_kill_entry(entry.type, entry.kills)
		kill_breakdown_container.add_child(row)

	# Insert after stats container
	var stats_container = $Control/Container/StatsContainer
	var stats_index = stats_container.get_index()
	container.add_child(kill_breakdown_container)
	container.move_child(kill_breakdown_container, stats_index + 1)

func _create_kill_entry(enemy_type: String, kill_count: int) -> HBoxContainer:
	var row = HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)

	# Get enemy info
	var info = ENEMY_INFO.get(enemy_type, ENEMY_INFO["unknown"])

	# Emoji
	var emoji = Label.new()
	emoji.text = info.emoji
	emoji.add_theme_font_size_override("font_size", 18)
	row.add_child(emoji)

	# Name
	var name_label = Label.new()
	name_label.text = info.name
	name_label.add_theme_color_override("font_color", info.color)
	name_label.add_theme_font_size_override("font_size", 14)
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(name_label)

	# Kill count
	var count_label = Label.new()
	count_label.text = "x%d" % kill_count
	count_label.add_theme_color_override("font_color", Color(1, 0.85, 0.4))
	count_label.add_theme_font_size_override("font_size", 14)
	row.add_child(count_label)

	return row

func _animate_in():
	visible = true

	# Death flash effect
	death_effect.modulate.a = 0.5
	var flash_tween = create_tween()
	flash_tween.tween_property(death_effect, "modulate:a", 0.0, 0.5)

	# Fade in background
	background.modulate.a = 0.0
	var bg_tween = create_tween()
	bg_tween.tween_property(background, "modulate:a", 0.9, 0.5)

	# Slide in container
	container.position.y = 100
	container.modulate.a = 0.0
	var container_tween = create_tween()
	container_tween.tween_interval(0.3)
	container_tween.tween_property(container, "position:y", 0, 0.5)\
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	container_tween.parallel().tween_property(container, "modulate:a", 1.0, 0.5)

	# Dramatic title animation
	title_label.scale = Vector2(2, 2)
	var title_tween = create_tween()
	title_tween.tween_interval(0.5)
	title_tween.tween_property(title_label, "scale", Vector2.ONE, 0.5)\
		.set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)

	# Stats appear one by one
	var stats_nodes = $Control/Container/StatsContainer.get_children()
	var delay = 0.7
	for stat_node in stats_nodes:
		stat_node.modulate.a = 0.0
		var stat_tween = create_tween()
		stat_tween.tween_interval(delay)
		stat_tween.tween_property(stat_node, "modulate:a", 1.0, 0.3)
		delay += 0.1

	# Gold section appears after stats
	var gold_section = $Control/Container/GoldSection
	gold_section.modulate.a = 0.0
	var gold_tween = create_tween()
	gold_tween.tween_interval(delay + 0.2)
	gold_tween.tween_property(gold_section, "modulate:a", 1.0, 0.4)

	# Animate total gold with dramatic effect
	gold_tween.tween_callback(func():
		total_gold_value.scale = Vector2(1.5, 1.5)
		total_gold_value.modulate = Color(1, 0.85, 0.4, 1)  # Gold color
		var total_tween = create_tween()
		total_tween.tween_property(total_gold_value, "scale", Vector2.ONE, 0.3)\
			.set_trans(Tween.TRANS_BACK)
		total_tween.parallel().tween_property(total_gold_value, "modulate", Color.WHITE, 0.5)
	)

func _on_return_to_base_pressed():
	# End the run and add gold to savings
	if RunManager:
		var total_gold = RunManager.end_run()
		if SaveManager:
			SaveManager.add_gold(total_gold)

	# Transition to base scene
	var tween = create_tween()
	tween.tween_property(control, "modulate:a", 0.0, 0.3)
	tween.tween_callback(func():
		get_tree().change_scene_to_file("res://Scenes/Main/Base.tscn")
	)

func _on_restart_pressed():
	# End current run (gold is still earned)
	if RunManager:
		var total_gold = RunManager.end_run()
		if SaveManager:
			SaveManager.add_gold(total_gold)

	# Quick fade out and restart
	var tween = create_tween()
	tween.tween_property(control, "modulate:a", 0.0, 0.3)
	tween.tween_callback(func():
		# Start a new run
		if RunManager:
			RunManager.start_new_run()
		get_tree().reload_current_scene()
	)
