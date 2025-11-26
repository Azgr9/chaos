# SCRIPT: GameManager.gd
# ATTACH TO: A new Node in Game.tscn (we'll create it)
# LOCATION: res://scripts/game/GameManager.gd

class_name GameManager
extends Node

# Game state
enum GameState { MENU, PLAYING, PAUSED, UPGRADE, GAME_OVER }
var current_state: GameState = GameState.PLAYING
var score: int = 0
var waves_completed: int = 0

# References
@onready var wave_manager: WaveManager = $"../WaveManager"
var player_reference: Node2D = null

# Signals
signal game_started()
signal game_over()
signal game_paused()
signal game_resumed()
signal score_changed(new_score: int)

func _ready():
	# Find player
	var players = get_tree().get_nodes_in_group("player")
	if players.size() > 0:
		player_reference = players[0]
		player_reference.player_died.connect(_on_player_died)
	
	# Connect wave manager signals
	if wave_manager:
		wave_manager.wave_completed.connect(_on_wave_completed)
		wave_manager.all_waves_completed.connect(_on_all_waves_completed)
		wave_manager.enemy_killed.connect(_on_enemy_killed)
	
	# Start game
	start_game()

func start_game():
	current_state = GameState.PLAYING
	score = 0
	waves_completed = 0
	emit_signal("game_started")

func _on_player_died():
	current_state = GameState.GAME_OVER
	emit_signal("game_over")
	
	# Show game over screen (simple version for now)
	_show_game_over()

func _on_wave_completed(wave_number: int):
	waves_completed = wave_number
	score += wave_number * 100
	emit_signal("score_changed", score)

	# Show upgrade menu after wave (except last wave)
	if wave_number < 5:
		_show_upgrade_menu()

func _show_upgrade_menu():
	# Get upgrade menu (it's a sibling in the Game scene)
	var upgrade_menu = get_node_or_null("../UpgradeMenu")

	if not upgrade_menu:
		# Load and instance upgrade menu if it doesn't exist
		var menu_scene = load("res://Scenes/Ui/UpgradeMenu.tscn")
		upgrade_menu = menu_scene.instantiate()
		get_parent().add_child(upgrade_menu)
		print("Created new UpgradeMenu instance")
	else:
		print("Found existing UpgradeMenu")

	# Show upgrades
	if upgrade_menu and upgrade_menu.has_method("show_upgrades"):
		print("Calling show_upgrades on menu")
		upgrade_menu.show_upgrades(player_reference)
	else:
		print("ERROR: Could not show upgrades - menu or method missing")

func _on_all_waves_completed():
	# Victory!
	score += 1000
	emit_signal("score_changed", score)
	_show_victory_screen()

func _on_enemy_killed(enemies_remaining: int):
	score += 10
	emit_signal("score_changed", score)

func _show_game_over():
	# Create simple game over message
	var game_over_label = Label.new()
	game_over_label.text = "GAME OVER\nWaves Survived: %d\nScore: %d\n\nPress R to Restart" % [waves_completed, score]
	game_over_label.add_theme_font_size_override("font_size", 24)
	game_over_label.modulate = Color.RED
	
	get_parent().add_child(game_over_label)
	game_over_label.global_position = Vector2(320, 180) - game_over_label.size / 2

func _show_victory_screen():
	var victory_label = Label.new()
	victory_label.text = "VICTORY!\nAll Waves Completed!\nScore: %d\n\nPress R to Restart" % score
	victory_label.add_theme_font_size_override("font_size", 24)
	victory_label.modulate = Color.GOLD
	
	get_parent().add_child(victory_label)
	victory_label.global_position = Vector2(320, 180) - victory_label.size / 2

func _input(event):
	if event.is_action_pressed("ui_cancel"):
		toggle_pause()
	
	if current_state == GameState.GAME_OVER and event.is_action_pressed("restart"):
		restart_game()

func toggle_pause():
	if current_state == GameState.PLAYING:
		current_state = GameState.PAUSED
		get_tree().paused = true
		emit_signal("game_paused")
	elif current_state == GameState.PAUSED:
		current_state = GameState.PLAYING
		get_tree().paused = false
		emit_signal("game_resumed")

func restart_game():
	get_tree().reload_current_scene()
