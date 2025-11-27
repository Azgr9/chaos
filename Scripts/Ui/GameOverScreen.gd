# SCRIPT: GameOverScreen.gd
# ATTACH TO: GameOverScreen (CanvasLayer) root in GameOverScreen.tscn
# LOCATION: res://scripts/ui/GameOverScreen.gd

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
@onready var best_value: Label = $Control/Container/StatsContainer/BestStat/Value

# Buttons
@onready var restart_button: Button = $Control/Container/ButtonContainer/RestartButton
@onready var quit_button: Button = $Control/Container/ButtonContainer/QuitButton
@onready var tip_label: Label = $Control/Container/TipLabel

# Stats tracking
var waves_survived: int = 0
var enemies_killed: int = 0
var final_score: int = 0
var best_score: int = 0

# Death messages
var death_tips = [
	"Tip: Keep your distance from enemies!",
	"Tip: Save weapon durability for tough waves!",
	"Tip: Magic attacks can hit multiple enemies!",
	"Tip: Health upgrades also heal you!",
	"Tip: Movement is key to survival!",
	"Tip: Each wave gets progressively harder!",
	"Tip: Lifesteal helps sustain through waves!",
	"Tip: Repair your weapon between waves!"
]

func _ready():
	visible = false

	# Connect buttons
	restart_button.pressed.connect(_on_restart_pressed)
	quit_button.pressed.connect(_on_quit_pressed)

	# Load best score
	_load_best_score()

func show_game_over(stats: Dictionary):
	# Set stats
	waves_survived = stats.get("waves", 0)
	enemies_killed = stats.get("enemies_killed", 0)
	final_score = stats.get("score", 0)

	# Update best score
	if final_score > best_score:
		best_score = final_score
		_save_best_score()
		_show_new_record()

	# Update display
	wave_value.text = str(waves_survived)
	enemies_value.text = str(enemies_killed)
	score_value.text = str(final_score)
	best_value.text = str(best_score)

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

func _show_new_record():
	# Special effect for new record
	var record_label = Label.new()
	record_label.text = "NEW RECORD!"
	record_label.add_theme_font_size_override("font_size", 36)
	record_label.modulate = Color.GOLD
	container.add_child(record_label)
	container.move_child(record_label, 2)  # After title

	# Animate
	record_label.scale = Vector2(0.5, 0.5)
	var tween = create_tween()
	tween.tween_property(record_label, "scale", Vector2(1.2, 1.2), 0.3)\
		.set_trans(Tween.TRANS_BACK)
	tween.tween_property(record_label, "scale", Vector2.ONE, 0.2)

	# Pulse
	tween.tween_property(record_label, "modulate:v", 1.5, 0.5)
	tween.tween_property(record_label, "modulate:v", 1.0, 0.5)
	tween.set_loops(3)

func _on_restart_pressed():
	# Quick fade out
	var tween = create_tween()
	tween.tween_property(control, "modulate:a", 0.0, 0.3)
	tween.tween_callback(func(): get_tree().reload_current_scene())

func _on_quit_pressed():
	# For now, just quit the game
	# Later you can make this go to main menu
	get_tree().quit()

func _save_best_score():
	var save_file = FileAccess.open("user://chaos_save.dat", FileAccess.WRITE)
	if save_file:
		save_file.store_32(best_score)
		save_file.close()

func _load_best_score():
	if FileAccess.file_exists("user://chaos_save.dat"):
		var save_file = FileAccess.open("user://chaos_save.dat", FileAccess.READ)
		if save_file:
			best_score = save_file.get_32()
			save_file.close()
