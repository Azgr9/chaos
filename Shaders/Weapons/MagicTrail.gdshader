shader_type canvas_item;

// Magic Staff Trail Shader
// Pixel-art friendly magic trail for staffs

uniform vec4 trail_color : source_color = vec4(0.4, 0.8, 1.0, 0.9);
uniform vec4 glow_color : source_color = vec4(1.0, 1.0, 1.0, 1.0);
uniform float glow_intensity : hint_range(0.0, 3.0) = 1.5;
uniform float pulse_speed : hint_range(0.0, 10.0) = 4.0;
uniform float sparkle_amount : hint_range(0.0, 1.0) = 0.3;

void fragment() {
	vec2 uv = UV;

	// UV.x = along the line (0 = old, 1 = new)
	// UV.y = across the width (0.5 = center)

	// Center brightness
	float center_dist = abs(uv.y - 0.5) * 2.0;
	float core = 1.0 - smoothstep(0.0, 0.6, center_dist);

	// Edge fade
	float edge = 1.0 - smoothstep(0.4, 1.0, center_dist);

	// Length fade - newer is brighter
	float length_fade = pow(uv.x, 0.4);

	// Simple pulse
	float pulse = sin(uv.x * 8.0 + TIME * pulse_speed) * 0.5 + 0.5;
	pulse = mix(1.0, pulse, 0.2);

	// Sparkle effect (pixel-art friendly - discrete)
	float sparkle = 0.0;
	if (sparkle_amount > 0.0) {
		// Create discrete sparkle points
		float sparkle_grid = floor(uv.x * 12.0 + TIME * 2.0);
		sparkle = step(0.7, fract(sin(sparkle_grid * 12.9898) * 43758.5453));
		sparkle *= step(0.3, 1.0 - center_dist) * sparkle_amount;
	}

	// Combine
	float alpha = edge * length_fade * pulse;

	// Color blend
	vec3 final_color = mix(trail_color.rgb, glow_color.rgb, core * 0.6);
	final_color += glow_color.rgb * core * glow_intensity * 0.2 * length_fade;
	final_color += vec3(sparkle) * glow_color.rgb;

	COLOR = vec4(final_color, alpha * trail_color.a);
}
