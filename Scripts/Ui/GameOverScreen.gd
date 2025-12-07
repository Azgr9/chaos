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

# Stats tracking
var waves_survived: int = 0
var enemies_killed: int = 0
var final_score: int = 0
var gold_earned: int = 0

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

	# Show screen with animation
	_animate_in()

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
