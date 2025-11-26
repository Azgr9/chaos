# SCRIPT: WaveHUD.gd
# ATTACH TO: A new CanvasLayer > Control node (we'll create it)
# LOCATION: res://scripts/ui/WaveHUD.gd

class_name WaveHUD
extends Control

@onready var wave_label: Label = $WaveLabel
@onready var enemies_label: Label = $EnemiesLabel
@onready var score_label: Label = $ScoreLabel

var wave_manager: WaveManager
var game_manager: GameManager

func _ready():
	# Find managers
	wave_manager = get_node("/root/Game/WaveManager")
	game_manager = get_node("/root/Game/GameManager")
	
	# Connect signals
	if wave_manager:
		wave_manager.wave_started.connect(_on_wave_started)
		wave_manager.enemy_killed.connect(_on_enemy_killed)
	
	if game_manager:
		game_manager.score_changed.connect(_on_score_changed)

func _on_wave_started(wave_number: int):
	wave_label.text = "Wave: %d / 5" % wave_number

func _on_enemy_killed(enemies_remaining: int):
	enemies_label.text = "Enemies: %d" % enemies_remaining

func _on_score_changed(score: int):
	score_label.text = "Score: %d" % score
