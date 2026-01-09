# SCRIPT: MainMenu.gd
# ATTACH TO: MainMenu (Control) root node in MainMenu.tscn
# LOCATION: res://Scripts/UI/MainMenu.gd
# PURPOSE: Main menu with Play, Settings, Quit buttons

extends Control

# UI References
var title_label: Label
var play_button: Button
var settings_button: Button
var quit_button: Button
var version_label: Label

# Settings panel reference
var settings_panel: Control = null

func _ready():
	# Apply saved settings on game start
	SaveManager.apply_all_settings()

	# Build UI
	_build_menu_ui()

	# Animate entrance
	_animate_entrance()

func _build_menu_ui():
	# Background
	var bg = ColorRect.new()
	bg.color = Color(0.05, 0.03, 0.08, 1)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)

	# Animated background particles (optional visual flair)
	_add_background_particles()

	# Main container
	var center_container = CenterContainer.new()
	center_container.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(center_container)

	var main_vbox = VBoxContainer.new()
	main_vbox.add_theme_constant_override("separation", 30)
	center_container.add_child(main_vbox)

	# Game Title
	title_label = Label.new()
	title_label.text = "CHAOS"
	title_label.add_theme_font_size_override("font_size", 96)
	title_label.add_theme_color_override("font_color", Color(0.9, 0.3, 0.2))
	title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	main_vbox.add_child(title_label)

	# Subtitle
	var subtitle = Label.new()
	subtitle.text = "Arena Survival"
	subtitle.add_theme_font_size_override("font_size", 24)
	subtitle.add_theme_color_override("font_color", Color(0.7, 0.6, 0.5))
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	main_vbox.add_child(subtitle)

	# Spacer
	var spacer = Control.new()
	spacer.custom_minimum_size.y = 40
	main_vbox.add_child(spacer)

	# Button container
	var button_container = VBoxContainer.new()
	button_container.add_theme_constant_override("separation", 15)
	main_vbox.add_child(button_container)

	# Play Button
	play_button = _create_menu_button("PLAY", Color(0.2, 0.7, 0.3))
	play_button.pressed.connect(_on_play_pressed)
	button_container.add_child(play_button)

	# Settings Button
	settings_button = _create_menu_button("SETTINGS", Color(0.5, 0.5, 0.6))
	settings_button.pressed.connect(_on_settings_pressed)
	button_container.add_child(settings_button)

	# Quit Button
	quit_button = _create_menu_button("QUIT", Color(0.7, 0.3, 0.3))
	quit_button.pressed.connect(_on_quit_pressed)
	button_container.add_child(quit_button)

	# Version label at bottom
	version_label = Label.new()
	version_label.text = "v0.1.0 Alpha"
	version_label.add_theme_font_size_override("font_size", 14)
	version_label.add_theme_color_override("font_color", Color(0.4, 0.4, 0.4))
	version_label.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	version_label.position = Vector2(-120, -30)
	add_child(version_label)

	# Create settings panel (hidden by default)
	_create_settings_panel()

func _create_menu_button(text: String, color: Color) -> Button:
	var btn = Button.new()
	btn.text = text
	btn.custom_minimum_size = Vector2(280, 60)
	btn.add_theme_font_size_override("font_size", 28)

	# Custom styling
	var normal_style = StyleBoxFlat.new()
	normal_style.bg_color = Color(color.r * 0.3, color.g * 0.3, color.b * 0.3, 0.9)
	normal_style.border_color = color
	normal_style.set_border_width_all(2)
	normal_style.set_corner_radius_all(8)
	normal_style.content_margin_left = 20
	normal_style.content_margin_right = 20
	normal_style.content_margin_top = 10
	normal_style.content_margin_bottom = 10
	btn.add_theme_stylebox_override("normal", normal_style)

	var hover_style = normal_style.duplicate()
	hover_style.bg_color = Color(color.r * 0.5, color.g * 0.5, color.b * 0.5, 0.95)
	hover_style.border_color = Color(color.r * 1.2, color.g * 1.2, color.b * 1.2)
	btn.add_theme_stylebox_override("hover", hover_style)

	var pressed_style = normal_style.duplicate()
	pressed_style.bg_color = color
	btn.add_theme_stylebox_override("pressed", pressed_style)

	# Button hover animation
	btn.mouse_entered.connect(func(): _on_button_hover(btn, true))
	btn.mouse_exited.connect(func(): _on_button_hover(btn, false))

	return btn

func _on_button_hover(btn: Button, hovering: bool):
	var tween = create_tween()
	if hovering:
		tween.tween_property(btn, "scale", Vector2(1.05, 1.05), 0.1)
	else:
		tween.tween_property(btn, "scale", Vector2(1.0, 1.0), 0.1)

func _add_background_particles():
	# Simple floating particles for atmosphere
	var particle_container = Control.new()
	particle_container.set_anchors_preset(Control.PRESET_FULL_RECT)
	particle_container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(particle_container)

	for i in range(20):
		var particle = ColorRect.new()
		particle.size = Vector2(4, 4)
		particle.color = Color(0.9, 0.3, 0.2, randf_range(0.1, 0.3))
		particle.position = Vector2(randf_range(0, 1280), randf_range(0, 720))
		particle_container.add_child(particle)

		# Animate floating upward
		_animate_particle(particle)

func _animate_particle(particle: ColorRect):
	var duration = randf_range(8, 15)
	var start_y = particle.position.y

	var tween = create_tween().set_loops()
	tween.tween_property(particle, "position:y", start_y - 200, duration)
	tween.tween_property(particle, "position:y", start_y, duration)

	# Slight horizontal drift
	var drift_tween = create_tween().set_loops()
	drift_tween.tween_property(particle, "position:x", particle.position.x + randf_range(-30, 30), duration * 0.5)
	drift_tween.tween_property(particle, "position:x", particle.position.x, duration * 0.5)

func _animate_entrance():
	# Title animation
	title_label.modulate.a = 0
	title_label.position.y -= 50

	var tween = create_tween()
	tween.tween_property(title_label, "modulate:a", 1.0, 0.8).set_ease(Tween.EASE_OUT)
	tween.parallel().tween_property(title_label, "position:y", title_label.position.y + 50, 0.8).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)

	# Button animations with delay
	var buttons = [play_button, settings_button, quit_button]
	for i in range(buttons.size()):
		var btn = buttons[i]
		btn.modulate.a = 0
		btn.position.x -= 100

		var btn_tween = create_tween()
		btn_tween.tween_interval(0.3 + i * 0.1)
		btn_tween.tween_property(btn, "modulate:a", 1.0, 0.4)
		btn_tween.parallel().tween_property(btn, "position:x", btn.position.x + 100, 0.4).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)

# ============================================
# SETTINGS PANEL
# ============================================

func _create_settings_panel():
	settings_panel = Control.new()
	settings_panel.set_anchors_preset(Control.PRESET_FULL_RECT)
	settings_panel.visible = false
	add_child(settings_panel)

	# Dark overlay
	var overlay = ColorRect.new()
	overlay.color = Color(0, 0, 0, 0.7)
	overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	overlay.gui_input.connect(_on_overlay_input)
	settings_panel.add_child(overlay)

	# Settings container
	var center = CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	settings_panel.add_child(center)

	var panel = PanelContainer.new()
	panel.custom_minimum_size = Vector2(500, 450)
	center.add_child(panel)

	var panel_style = StyleBoxFlat.new()
	panel_style.bg_color = Color(0.1, 0.08, 0.12, 0.98)
	panel_style.border_color = Color(0.4, 0.3, 0.5)
	panel_style.set_border_width_all(2)
	panel_style.set_corner_radius_all(12)
	panel_style.content_margin_left = 30
	panel_style.content_margin_right = 30
	panel_style.content_margin_top = 25
	panel_style.content_margin_bottom = 25
	panel.add_theme_stylebox_override("panel", panel_style)

	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 20)
	panel.add_child(vbox)

	# Settings title
	var title = Label.new()
	title.text = "SETTINGS"
	title.add_theme_font_size_override("font_size", 32)
	title.add_theme_color_override("font_color", Color(0.9, 0.8, 0.6))
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(title)

	vbox.add_child(HSeparator.new())

	# Audio section
	var audio_label = Label.new()
	audio_label.text = "Audio"
	audio_label.add_theme_font_size_override("font_size", 20)
	audio_label.add_theme_color_override("font_color", Color(0.7, 0.7, 0.8))
	vbox.add_child(audio_label)

	# Master Volume
	var master_row = _create_slider_row("Master Volume", "master_volume")
	vbox.add_child(master_row)

	# Music Volume
	var music_row = _create_slider_row("Music", "music_volume")
	vbox.add_child(music_row)

	# SFX Volume
	var sfx_row = _create_slider_row("Sound Effects", "sfx_volume")
	vbox.add_child(sfx_row)

	vbox.add_child(HSeparator.new())

	# Graphics section
	var graphics_label = Label.new()
	graphics_label.text = "Graphics"
	graphics_label.add_theme_font_size_override("font_size", 20)
	graphics_label.add_theme_color_override("font_color", Color(0.7, 0.7, 0.8))
	vbox.add_child(graphics_label)

	# Fullscreen toggle
	var fullscreen_row = _create_toggle_row("Fullscreen", "fullscreen")
	vbox.add_child(fullscreen_row)

	# VSync toggle
	var vsync_row = _create_toggle_row("VSync", "vsync")
	vbox.add_child(vsync_row)

	vbox.add_child(HSeparator.new())

	# Gameplay section
	var gameplay_label = Label.new()
	gameplay_label.text = "Gameplay"
	gameplay_label.add_theme_font_size_override("font_size", 20)
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
	close_btn.text = "Close"
	close_btn.custom_minimum_size = Vector2(150, 45)
	close_btn.add_theme_font_size_override("font_size", 20)
	close_btn.pressed.connect(_close_settings)
	close_container.add_child(close_btn)

func _create_slider_row(label_text: String, setting_key: String) -> HBoxContainer:
	var row = HBoxContainer.new()
	row.add_theme_constant_override("separation", 15)

	var label = Label.new()
	label.text = label_text
	label.add_theme_font_size_override("font_size", 16)
	label.custom_minimum_size.x = 150
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
	settings_panel.visible = false

func _open_settings():
	settings_panel.visible = true

# ============================================
# BUTTON HANDLERS
# ============================================

func _on_play_pressed():
	# Transition to Base (hub) scene
	var tween = create_tween()
	tween.tween_property(self, "modulate:a", 0.0, 0.3)
	tween.tween_callback(func(): get_tree().change_scene_to_file("res://Scenes/Main/Base.tscn"))

func _on_settings_pressed():
	_open_settings()

func _on_quit_pressed():
	get_tree().quit()

func _input(event: InputEvent):
	if event.is_action_pressed("ui_cancel"):
		if settings_panel.visible:
			_close_settings()
