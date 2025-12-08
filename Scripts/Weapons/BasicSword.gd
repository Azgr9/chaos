# SCRIPT: BasicSword.gd
# ATTACH TO: BasicSword (Node2D) root node in BasicSword.tscn
# LOCATION: res://Scripts/Weapons/BasicSword.gd

class_name BasicSword
extends MeleeWeapon

# ============================================
# SWORD-SPECIFIC SETTINGS
# ============================================
const SPIN_SLASH_SCENE = preload("res://Scenes/Weapons/SpinSlash.tscn")

func _weapon_ready():
	# BasicSword uses default settings from MeleeWeapon
	# Configure sword-specific values
	damage = 10.0
	attack_duration = 0.25
	attack_cooldown = 0.35
	swing_arc = 150.0
	weapon_length = 80.0
	weapon_color = Color("#c0c0c0")  # Silver
	skill_cooldown = 8.0

func _get_attack_pattern(attack_index: int) -> String:
	# BasicSword: horizontal -> horizontal_reverse -> overhead
	match attack_index:
		1: return "horizontal"
		2: return "horizontal_reverse"
		3: return "overhead"
		_: return "horizontal"

func _perform_skill() -> bool:
	# Spin Slash skill
	var player = get_tree().get_first_node_in_group("player")
	if not player:
		return false

	var spin_slash = SPIN_SLASH_SCENE.instantiate()
	get_tree().current_scene.add_child(spin_slash)

	var slash_damage = damage * 2.0 * damage_multiplier
	spin_slash.initialize(player.global_position, slash_damage)

	if spin_slash.has_signal("dealt_damage"):
		spin_slash.dealt_damage.connect(func(target, dmg):
			dealt_damage.emit(target, dmg)
		)

	return true
