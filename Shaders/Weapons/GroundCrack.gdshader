shader_type canvas_item;

// Ground Crack Shader
// For Warhammer, ExecutionersAxe slam impacts

uniform float progress : hint_range(0.0, 1.0) = 0.0;
uniform vec4 crack_color : source_color = vec4(0.3, 0.2, 0.15, 0.9);
uniform vec4 glow_color : source_color = vec4(1.0, 0.5, 0.2, 0.6);
uniform float crack_width : hint_range(0.01, 0.2) = 0.08;
uniform float jagged_amount : hint_range(0.0, 0.3) = 0.15;

void fragment() {
	vec2 uv = UV;

	// Jagged crack pattern
	float jagged = sin(uv.x * 30.0) * jagged_amount;
	float center_dist = abs(uv.y - 0.5 + jagged) * 2.0;

	// Crack shape
	float crack = smoothstep(crack_width, 0.0, center_dist);

	// Glowing edges
	float edge_glow = smoothstep(crack_width * 3.0, crack_width, center_dist);

	// Extend from center outward with progress (reversed for crack spreading)
	float spread = smoothstep(0.0, 1.0 - progress, uv.x);

	// Fade after full spread
	float fade = 1.0 - smoothstep(0.7, 1.0, progress);

	float alpha = (crack + edge_glow * 0.4) * spread * fade;

	// Color
	vec3 final_color = mix(crack_color.rgb, glow_color.rgb, edge_glow * 0.5);

	COLOR = vec4(final_color, alpha * crack_color.a);
}
