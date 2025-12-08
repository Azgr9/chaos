# SCRIPT: UpgradeMenu.gd
# ATTACH TO: UpgradeMenu (CanvasLayer) root in UpgradeMenu.tscn
# LOCATION: res://scripts/ui/UpgradeMenu.gd

class_name UpgradeMenu
extends CanvasLayer

# Nodes
@onready var control: Control = $Control
@onready var background: ColorRect = $Control/Background
@onready var container: VBoxContainer = $Control/Container
@onready var title_label: Label = $Control/Container/Title
@onready var subtitle_label: Label = $Control/Container/Subtitle
@onready var upgrade_cards: HBoxContainer = $Control/Container/UpgradeCards
@onready var weapon_shop_button: Button = $Control/WeaponShopButton
@onready var staff_shop_button: Button = $Control/StaffShopButton
@onready var skip_button: Button = $Control/SkipButton

const KATANA_SCENE = preload("res://Scenes/Weapons/Katana.tscn")
const KATANA_PRICE = 10  # Gold price
const LIGHTNING_STAFF_SCENE = preload("res://Scenes/Weapons/LightningStaff.tscn")
const STAFF_PRICE = 10  # Gold price

# Card references
var card_panels: Array = []
var card_data: Array = []
var player_reference: Node2D = null
var upgrade_system: UpgradeSystem = null
var katana_purchased: bool = false
var staff_purchased: bool = false

# Signals
signal upgrade_selected(upgrade: Dictionary)
signal menu_closed()

func _ready():
	# Hide initially
	visible = false

	# Set to process when paused so menu works during pause
	process_mode = Node.PROCESS_MODE_ALWAYS

	# Create upgrade system instance
	upgrade_system = UpgradeSystem.new()
	add_child(upgrade_system)

	# Get card panels
	for child in upgrade_cards.get_children():
		if child is Panel:
			card_panels.append(child)

			# Connect button
			var button = child.get_node("VBox/SelectButton")
			if button:
				button.pressed.connect(_on_card_selected.bind(card_panels.size() - 1))

	# Connect skip button if it exists
	if skip_button:
		skip_button.pressed.connect(_on_skip_pressed)

	# Connect weapon shop button
	if weapon_shop_button:
		weapon_shop_button.pressed.connect(_on_weapon_shop_pressed)

	# Connect staff shop button
	if staff_shop_button:
		staff_shop_button.pressed.connect(_on_staff_shop_pressed)

func show_upgrades(player: Node2D):
	player_reference = player

	# CRITICAL: Clean up all active animations and effects BEFORE pausing
	_cleanup_active_effects()

	# Update weapon shop buttons
	_update_weapon_shop_button()
	_update_staff_shop_button()

	# Get random upgrades
	card_data = upgrade_system.get_random_upgrades(3)

	# Pause game
	get_tree().paused = true

	# Show menu with animation
	visible = true
	control.modulate.a = 0.0

	var tween = create_tween()
	tween.tween_property(control, "modulate:a", 1.0, 0.3)

	# Animate container
	container.position.y = -50
	tween.parallel().tween_property(container, "position:y", 0, 0.3)\
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

	# Setup cards
	_setup_cards()

	# Animate cards appearing
	_animate_cards_in()

func _setup_cards():
	for i in range(min(card_data.size(), card_panels.size())):
		var card = card_panels[i]
		var upgrade = card_data[i]

		# Get display data (handles both UpgradeResource and Dictionary)
		var data = upgrade_system.get_upgrade_display_data(upgrade)

		# Set card info
		var icon = card.get_node("VBox/Icon")
		var name_label = card.get_node("VBox/Name")
		var desc_label = card.get_node("VBox/Description")

		if icon:
			icon.color = data.get("icon_color", Color.WHITE)
		if name_label:
			name_label.text = data.get("name", "Unknown")
		if desc_label:
			desc_label.text = data.get("description", "")

		# Style the panel
		var style = StyleBoxFlat.new()
		style.bg_color = Color(0.1, 0.1, 0.15, 0.9)
		style.border_width_left = 2
		style.border_width_right = 2
		style.border_width_top = 2
		style.border_width_bottom = 2
		style.border_color = data.get("icon_color", Color.WHITE) * 0.8
		style.corner_radius_top_left = 8
		style.corner_radius_top_right = 8
		style.corner_radius_bottom_left = 8
		style.corner_radius_bottom_right = 8
		card.add_theme_stylebox_override("panel", style)

func _animate_cards_in():
	var delay = 0.0
	for card in card_panels:
		card.scale = Vector2(0.8, 0.8)
		card.modulate.a = 0.0

		var tween = create_tween()
		tween.tween_interval(delay)
		tween.tween_property(card, "scale", Vector2.ONE, 0.3)\
			.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		tween.parallel().tween_property(card, "modulate:a", 1.0, 0.3)

		delay += 0.1

func _on_card_selected(index: int):
	if index >= card_data.size():
		return

	var selected_upgrade = card_data[index]

	# Apply the upgrade
	if upgrade_system and player_reference:
		upgrade_system.apply_upgrade(player_reference, selected_upgrade)

	# Emit signal
	upgrade_selected.emit(selected_upgrade)

	# Animate selection
	var selected_card = card_panels[index]
	selected_card.scale = Vector2(1.1, 1.1)

	var tween = create_tween()
	tween.tween_property(selected_card, "scale", Vector2(1.2, 1.2), 0.2)
	tween.parallel().tween_property(selected_card, "modulate:a", 0.0, 0.3)

	# Fade out other cards
	for i in range(card_panels.size()):
		if i != index:
			var other_tween = create_tween()
			other_tween.tween_property(card_panels[i], "modulate:a", 0.0, 0.2)

	# Close menu after animation
	tween.tween_callback(_close_menu)

func _on_skip_pressed():
	_close_menu()

func _on_weapon_shop_pressed():
	var game_manager = get_tree().get_first_node_in_group("game_manager")
	if not game_manager:
		return

	# Check if player has enough gold
	if game_manager.get_gold() >= KATANA_PRICE:
		if game_manager.spend_gold(KATANA_PRICE):
			_swap_weapon_to_katana()
			_update_weapon_shop_button()

func _update_weapon_shop_button():
	if not weapon_shop_button:
		return

	# Hide button if already purchased
	if katana_purchased:
		weapon_shop_button.visible = false
		return

	weapon_shop_button.visible = true
	var game_manager = get_tree().get_first_node_in_group("game_manager")
	if not game_manager:
		return

	var current_gold = game_manager.get_gold()
	if current_gold >= KATANA_PRICE:
		weapon_shop_button.disabled = false
		weapon_shop_button.text = "Buy Katana (%d Gold)" % KATANA_PRICE
	else:
		weapon_shop_button.disabled = true
		weapon_shop_button.text = "Need %d Gold" % KATANA_PRICE

func _swap_weapon_to_katana():
	if not player_reference:
		return

	# Mark as purchased
	katana_purchased = true

	# CRITICAL: Reset ALL attack states immediately
	player_reference.is_attacking = false
	player_reference.is_melee_attacking = false

	# PROPER CLEANUP: Remove old weapon with full cleanup
	if player_reference.current_weapon:
		var old_weapon = player_reference.current_weapon

		# Cancel any active attacks/animations
		if old_weapon.has_method("finish_attack"):
			old_weapon.finish_attack()

		# Disconnect all signals to prevent orphan connections
		if old_weapon.has_signal("attack_finished"):
			for connection in old_weapon.attack_finished.get_connections():
				old_weapon.attack_finished.disconnect(connection["callable"])

		# Queue free the weapon (will be removed next frame)
		old_weapon.queue_free()
		player_reference.weapon_inventory.clear()
		player_reference.current_weapon = null

	# Wait one frame for old weapon to be fully removed
	await get_tree().process_frame

	# Add new katana
	var new_weapon = KATANA_SCENE.instantiate()
	var weapon_holder = player_reference.get_node("WeaponPivot/WeaponHolder")
	weapon_holder.add_child(new_weapon)
	new_weapon.position = Vector2.ZERO

	player_reference.current_weapon = new_weapon
	player_reference.weapon_inventory.append(new_weapon)

	# Connect signals
	if new_weapon.has_signal("attack_finished"):
		new_weapon.attack_finished.connect(player_reference._on_attack_finished)

	# Final reset after everything is set up
	player_reference.is_attacking = false
	player_reference.is_melee_attacking = false

func _on_staff_shop_pressed():
	var game_manager = get_tree().get_first_node_in_group("game_manager")
	if not game_manager:
		return

	# Check if player has enough gold
	if game_manager.get_gold() >= STAFF_PRICE:
		if game_manager.spend_gold(STAFF_PRICE):
			_swap_weapon_to_staff()
			_update_staff_shop_button()

func _update_staff_shop_button():
	if not staff_shop_button:
		return

	# Hide if already purchased
	if staff_purchased:
		staff_shop_button.visible = false
		return

	staff_shop_button.visible = true

	var game_manager = get_tree().get_first_node_in_group("game_manager")
	if not game_manager:
		return

	var current_gold = game_manager.get_gold()
	if current_gold >= STAFF_PRICE:
		staff_shop_button.disabled = false
		staff_shop_button.text = "Buy Lightning Staff (%d Gold)" % STAFF_PRICE
	else:
		staff_shop_button.disabled = true
		staff_shop_button.text = "Need %d Gold" % STAFF_PRICE

func _swap_weapon_to_staff():
	if not player_reference:
		return

	# Mark as purchased
	staff_purchased = true

	# CRITICAL: Reset ALL attack states immediately
	player_reference.is_attacking = false
	player_reference.is_magic_attacking = false

	# PROPER CLEANUP: Remove old staff with full cleanup
	if player_reference.current_staff:
		var old_staff = player_reference.current_staff

		# Disconnect all signals
		var staff_signals = ["projectile_fired", "skill_used", "skill_ready_changed"]
		for sig_name in staff_signals:
			if old_staff.has_signal(sig_name):
				for connection in old_staff.get(sig_name).get_connections():
					old_staff.get(sig_name).disconnect(connection["callable"])

		# Queue free the staff
		old_staff.queue_free()
		player_reference.staff_inventory.clear()
		player_reference.current_staff = null

	# Wait one frame for old staff to be fully removed
	await get_tree().process_frame

	# Add new lightning staff to staff holder
	var new_staff = LIGHTNING_STAFF_SCENE.instantiate()
	var staff_holder = player_reference.get_node("StaffPivot/StaffHolder")
	staff_holder.add_child(new_staff)
	new_staff.position = Vector2.ZERO

	player_reference.current_staff = new_staff
	player_reference.staff_inventory.append(new_staff)

	print("Lightning Staff equipped! Use right-click to attack, E key for chain lightning ability.")

	# Final reset
	player_reference.is_attacking = false
	player_reference.is_magic_attacking = false

func _close_menu():
	# Animate out
	var tween = create_tween()
	tween.tween_property(control, "modulate:a", 0.0, 0.3)
	tween.tween_callback(func():
		visible = false
		get_tree().paused = false
		menu_closed.emit()
	)

func _cleanup_active_effects():
	# Cancel all player attack animations
	if player_reference:
		# Reset all attack states
		player_reference.is_attacking = false
		player_reference.is_melee_attacking = false
		player_reference.is_magic_attacking = false

		# Cancel weapon attack animations
		if player_reference.current_weapon and player_reference.current_weapon.has_method("finish_attack"):
			player_reference.current_weapon.finish_attack()

		# Cancel staff attack animations
		if player_reference.current_staff and player_reference.current_staff.has_method("finish_attack"):
			player_reference.current_staff.finish_attack()

	# Clean up all damage numbers, projectiles, and visual effects in the scene
	_cleanup_scene_effects()

func _cleanup_scene_effects():
	var scene_root = get_tree().current_scene
	if not scene_root:
		return

	# Remove all damage numbers (DamageNumber nodes)
	for node in scene_root.get_children():
		if node.get_script() and node.get_script().resource_path.ends_with("DamageNumber.gd"):
			node.queue_free()

	# Remove floating projectiles and effects
	# Look for common effect node types
	for node in scene_root.get_children():
		# Remove projectiles
		if node.is_in_group("projectiles"):
			node.queue_free()
		# Remove visual effects
		elif node.is_in_group("effects"):
			node.queue_free()
		# Remove any nodes with "effect" or "projectile" in name
		elif "effect" in node.name.to_lower() or "projectile" in node.name.to_lower():
			node.queue_free()
