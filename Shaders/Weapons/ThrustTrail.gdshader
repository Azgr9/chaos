shader_type canvas_item;

// Thrust/Pierce Trail Shader
// For Spear and Rapier thrust attacks

uniform float progress : hint_range(0.0, 1.0) = 0.0;
uniform vec4 trail_color : source_color = vec4(1.0, 0.9, 0.5, 0.9);
uniform vec4 tip_color : source_color = vec4(1.0, 1.0, 1.0, 1.0);
uniform float sharpness : hint_range(1.0, 10.0) = 4.0;
uniform float length_fade : hint_range(0.0, 1.0) = 0.7;

void fragment() {
	vec2 uv = UV;

	// Sharp pointed shape (thin at start, gone at end)
	float width = 1.0 - uv.x * length_fade;
	float center_dist = abs(uv.y - 0.5) * 2.0;

	// Sharp edge falloff
	float edge = pow(1.0 - center_dist, sharpness) * width;

	// Bright tip at front
	float tip = smoothstep(0.3, 0.0, uv.x) * (1.0 - center_dist);

	// Progress fade
	float fade = 1.0 - progress;

	float alpha = edge * fade;

	// Color - tip is brighter
	vec3 final_color = mix(trail_color.rgb, tip_color.rgb, tip * 0.8);
	final_color += tip_color.rgb * tip * 0.3;

	COLOR = vec4(final_color, alpha * trail_color.a);
}
