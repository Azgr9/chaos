# SCRIPT: PauseMenu.gd
# ATTACH TO: PauseMenu (CanvasLayer) root in PauseMenu.tscn
# LOCATION: res://scripts/ui/PauseMenu.gd

class_name PauseMenu
extends CanvasLayer

@onready var control: Control = $Control
@onready var background: ColorRect = $Control/Background
@onready var container: VBoxContainer = $Control/Container
@onready var resume_button: Button = $Control/Container/ResumeButton
@onready var restart_button: Button = $Control/Container/RestartButton
@onready var quit_button: Button = $Control/Container/QuitButton

var is_paused: bool = false

func _ready():
	visible = false
	process_mode = Node.PROCESS_MODE_ALWAYS

	# Connect buttons
	resume_button.pressed.connect(_on_resume_pressed)
	restart_button.pressed.connect(_on_restart_pressed)
	quit_button.pressed.connect(_on_quit_pressed)

func _input(event):
	if event.is_action_pressed("ui_cancel"):
		if is_paused:
			resume_game()
		else:
			pause_game()

func pause_game():
	is_paused = true
	visible = true
	get_tree().paused = true

	# Animate in
	control.modulate.a = 0.0
	var tween = create_tween()
	tween.set_pause_mode(Tween.TweenPauseMode.TWEEN_PAUSE_PROCESS)
	tween.tween_property(control, "modulate:a", 1.0, 0.2)

func resume_game():
	is_paused = false

	# Animate out
	var tween = create_tween()
	tween.set_pause_mode(Tween.TweenPauseMode.TWEEN_PAUSE_PROCESS)
	tween.tween_property(control, "modulate:a", 0.0, 0.2)
	tween.tween_callback(func():
		visible = false
		get_tree().paused = false
	)

func _on_resume_pressed():
	resume_game()

func _on_restart_pressed():
	get_tree().paused = false
	get_tree().reload_current_scene()

func _on_quit_pressed():
	get_tree().quit()
