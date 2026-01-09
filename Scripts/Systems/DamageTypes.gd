# SCRIPT: DamageTypes.gd
# LOCATION: res://Scripts/Systems/DamageTypes.gd
# Damage type enum for colored damage numbers - standalone to avoid circular dependencies

class_name DamageTypes
extends RefCounted

enum Type {
	PHYSICAL,   # White - melee, basic attacks
	FIRE,       # Orange - fire grates, burn effects -> applies BURN
	ICE,        # Light blue - ice effects -> applies CHILL
	POISON,     # Green - poison effects
	ELECTRIC,   # Cyan/Blue - lightning, shock -> applies SHOCK
	SPIKE,      # Gray - spikes, crushers
	CRIT,       # Yellow - critical hits
	HEAL,       # Green (bright) - healing numbers
	BLEED       # Dark red - bleed effects -> applies BLEED
}

# Color mapping for each damage type
# Updated colors based on user request:
# crit = red, heal = green, poison = purple, electric = blue
const COLORS = {
	Type.PHYSICAL: Color.WHITE,
	Type.FIRE: Color(1.0, 0.5, 0.1, 1.0),      # Orange - fire damage
	Type.ICE: Color(0.6, 0.85, 1.0, 1.0),      # Light blue - ice/freeze
	Type.POISON: Color(0.7, 0.2, 0.9, 1.0),    # PURPLE - poison (updated)
	Type.ELECTRIC: Color(0.2, 0.6, 1.0, 1.0),  # BLUE - electric (updated)
	Type.SPIKE: Color(0.7, 0.7, 0.7, 1.0),     # Gray - spikes
	Type.CRIT: Color(1.0, 0.2, 0.2, 1.0),      # RED - critical hits (updated)
	Type.HEAL: Color(0.2, 1.0, 0.4, 1.0),      # GREEN - healing (kept)
	Type.BLEED: Color(0.8, 0.1, 0.1, 1.0)      # Dark red - bleed
}
