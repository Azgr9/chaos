# SCRIPT: WeaponShop.gd
# ATTACH TO: WeaponShop (Control) root node in WeaponShop.tscn
# LOCATION: res://Scripts/Ui/WeaponShop.gd

extends Control

@onready var title_label: Label = $Panel/VBoxContainer/TitleLabel
@onready var crystal_label: Label = $Panel/VBoxContainer/CrystalCount
@onready var buy_button: Button = $Panel/VBoxContainer/BuyButton
@onready var close_button: Button = $Panel/VBoxContainer/CloseButton

const KATANA_SCENE = preload("res://Scenes/Weapons/Katana.tscn")
const KATANA_PRICE = 1

var player_reference: Node2D = null
var game_manager: Node = null

signal weapon_purchased(weapon_scene: PackedScene)
signal shop_closed

func _ready():
	# Hide by default
	visible = false

	# Connect buttons
	buy_button.pressed.connect(_on_buy_pressed)
	close_button.pressed.connect(_on_close_pressed)

	# Find references
	player_reference = get_tree().get_first_node_in_group("player")
	game_manager = get_tree().get_first_node_in_group("game_manager")

func open_shop():
	visible = true
	_update_display()

func close_shop():
	visible = false
	shop_closed.emit()

func _update_display():
	if game_manager and game_manager.has_method("get_crystal_count"):
		var crystals = game_manager.get_crystal_count()
		crystal_label.text = "Chaos Crystals: %d" % crystals

		# Update button state
		if crystals >= KATANA_PRICE:
			buy_button.disabled = false
			buy_button.text = "Buy Katana (%d Crystals)" % KATANA_PRICE
		else:
			buy_button.disabled = true
			buy_button.text = "Not Enough Crystals (%d/%d)" % [crystals, KATANA_PRICE]
	else:
		crystal_label.text = "Chaos Crystals: 0"
		buy_button.disabled = true

func _on_buy_pressed():
	if not game_manager or not game_manager.has_method("spend_crystals"):
		return

	if game_manager.spend_crystals(KATANA_PRICE):
		# Purchase successful
		weapon_purchased.emit(KATANA_SCENE)
		_swap_weapon_for_player()
		_update_display()

		# Close shop after purchase
		await get_tree().create_timer(0.5).timeout
		close_shop()

func _swap_weapon_for_player():
	if not player_reference:
		return

	# Remove old weapon
	if player_reference.current_weapon:
		player_reference.current_weapon.queue_free()
		player_reference.weapon_inventory.clear()

	# Add new weapon
	var new_weapon = KATANA_SCENE.instantiate()
	var weapon_holder = player_reference.get_node("WeaponPivot/WeaponHolder")
	weapon_holder.add_child(new_weapon)
	new_weapon.position = Vector2.ZERO

	player_reference.current_weapon = new_weapon
	player_reference.weapon_inventory.append(new_weapon)

	# Connect signals
	if new_weapon.has_signal("attack_finished"):
		new_weapon.attack_finished.connect(player_reference._on_attack_finished)

func _on_close_pressed():
	close_shop()
