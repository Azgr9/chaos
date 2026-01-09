# SCRIPT: PauseMenu.gd
# ATTACH TO: PauseMenu (CanvasLayer) root in PauseMenu.tscn
# LOCATION: res://scripts/ui/PauseMenu.gd

class_name PauseMenu
extends CanvasLayer

@onready var control: Control = $Control
@onready var background: ColorRect = $Control/Background
@onready var container: VBoxContainer = $Control/Container
@onready var resume_button: Button = $Control/Container/ResumeButton
@onready var settings_button: Button = $Control/Container/SettingsButton
@onready var restart_button: Button = $Control/Container/RestartButton
@onready var main_menu_button: Button = $Control/Container/MainMenuButton
@onready var quit_button: Button = $Control/Container/QuitButton

var is_paused: bool = false
var settings_panel: Control = null

func _ready():
	visible = false
	process_mode = Node.PROCESS_MODE_ALWAYS

	# Connect buttons
	resume_button.pressed.connect(_on_resume_pressed)
	settings_button.pressed.connect(_on_settings_pressed)
	restart_button.pressed.connect(_on_restart_pressed)
	main_menu_button.pressed.connect(_on_main_menu_pressed)
	quit_button.pressed.connect(_on_quit_pressed)

	# Create settings panel
	_create_settings_panel()

func _input(event):
	if event.is_action_pressed("ui_cancel"):
		if settings_panel and settings_panel.visible:
			_close_settings()
		elif is_paused:
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

	# Close settings if open
	if settings_panel and settings_panel.visible:
		settings_panel.visible = false

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

func _on_settings_pressed():
	if settings_panel:
		settings_panel.visible = true

func _on_restart_pressed():
	get_tree().paused = false
	get_tree().reload_current_scene()

func _on_main_menu_pressed():
	get_tree().paused = false
	get_tree().change_scene_to_file("res://Scenes/Main/MainMenu.tscn")

func _on_quit_pressed():
	get_tree().quit()

# ============================================
# SETTINGS PANEL
# ============================================

func _create_settings_panel():
	settings_panel = Control.new()
	settings_panel.set_anchors_preset(Control.PRESET_FULL_RECT)
	settings_panel.visible = false
	settings_panel.process_mode = Node.PROCESS_MODE_ALWAYS
	control.add_child(settings_panel)

	# Dark overlay
	var overlay = ColorRect.new()
	overlay.color = Color(0, 0, 0, 0.5)
	overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	overlay.gui_input.connect(_on_overlay_input)
	settings_panel.add_child(overlay)

	# Settings container
	var center = CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	settings_panel.add_child(center)

	var panel = PanelContainer.new()
	panel.custom_minimum_size = Vector2(450, 400)
	center.add_child(panel)

	var panel_style = StyleBoxFlat.new()
	panel_style.bg_color = Color(0.1, 0.08, 0.12, 0.98)
	panel_style.border_color = Color(0.4, 0.3, 0.5)
	panel_style.set_border_width_all(2)
	panel_style.set_corner_radius_all(12)
	panel_style.content_margin_left = 25
	panel_style.content_margin_right = 25
	panel_style.content_margin_top = 20
	panel_style.content_margin_bottom = 20
	panel.add_theme_stylebox_override("panel", panel_style)

	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 15)
	panel.add_child(vbox)

	# Settings title
	var title = Label.new()
	title.text = "SETTINGS"
	title.add_theme_font_size_override("font_size", 28)
	title.add_theme_color_override("font_color", Color(0.9, 0.8, 0.6))
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(title)

	vbox.add_child(HSeparator.new())

	# Audio section
	var audio_label = Label.new()
	audio_label.text = "Audio"
	audio_label.add_theme_font_size_override("font_size", 18)
	audio_label.add_theme_color_override("font_color", Color(0.7, 0.7, 0.8))
	vbox.add_child(audio_label)

	# Master Volume
	var master_row = _create_slider_row("Master", "master_volume")
	vbox.add_child(master_row)

	# Music Volume
	var music_row = _create_slider_row("Music", "music_volume")
	vbox.add_child(music_row)

	# SFX Volume
	var sfx_row = _create_slider_row("SFX", "sfx_volume")
	vbox.add_child(sfx_row)

	vbox.add_child(HSeparator.new())

	# Gameplay section
	var gameplay_label = Label.new()
	gameplay_label.text = "Gameplay"
	gameplay_label.add_theme_font_size_override("font_size", 18)
	gameplay_label.add_theme_color_override("font_color", Color(0.7, 0.7, 0.8))
	vbox.add_child(gameplay_label)

	# Screen shake toggle
	var shake_row = _create_toggle_row("Screen Shake", "screen_shake")
	vbox.add_child(shake_row)

	# Damage numbers toggle
	var damage_row = _create_toggle_row("Damage Numbers", "damage_numbers")
	vbox.add_child(damage_row)

	# Close button
	var close_container = HBoxContainer.new()
	close_container.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_child(close_container)

	var close_btn = Button.new()
	close_btn.text = "Back"
	close_btn.custom_minimum_size = Vector2(120, 40)
	close_btn.add_theme_font_size_override("font_size", 18)
	close_btn.pressed.connect(_close_settings)
	close_container.add_child(close_btn)

func _create_slider_row(label_text: String, setting_key: String) -> HBoxContainer:
	var row = HBoxContainer.new()
	row.add_theme_constant_override("separation", 15)

	var label = Label.new()
	label.text = label_text
	label.add_theme_font_size_override("font_size", 16)
	label.custom_minimum_size.x = 80
	row.add_child(label)

	var slider = HSlider.new()
	slider.min_value = 0.0
	slider.max_value = 1.0
	slider.step = 0.05
	slider.value = SaveManager.get_setting(setting_key)
	slider.custom_minimum_size.x = 200
	slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	slider.value_changed.connect(func(val): SaveManager.set_setting(setting_key, val))
	row.add_child(slider)

	var value_label = Label.new()
	value_label.text = "%d%%" % int(slider.value * 100)
	value_label.add_theme_font_size_override("font_size", 14)
	value_label.custom_minimum_size.x = 50
	slider.value_changed.connect(func(val): value_label.text = "%d%%" % int(val * 100))
	row.add_child(value_label)

	return row

func _create_toggle_row(label_text: String, setting_key: String) -> HBoxContainer:
	var row = HBoxContainer.new()
	row.add_theme_constant_override("separation", 15)

	var label = Label.new()
	label.text = label_text
	label.add_theme_font_size_override("font_size", 16)
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(label)

	var toggle = CheckButton.new()
	toggle.button_pressed = SaveManager.get_setting(setting_key)
	toggle.toggled.connect(func(pressed): SaveManager.set_setting(setting_key, pressed))
	row.add_child(toggle)

	return row

func _on_overlay_input(event: InputEvent):
	if event is InputEventMouseButton and event.pressed:
		_close_settings()

func _close_settings():
	if settings_panel:
		settings_panel.visible = false
