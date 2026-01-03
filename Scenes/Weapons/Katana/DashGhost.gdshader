shader_type canvas_item;

// Katana Dash Ghost/Afterimage Shader
// Creates a ghostly afterimage trail effect

uniform float progress : hint_range(0.0, 1.0) = 0.0;
uniform vec4 ghost_color : source_color = vec4(1.0, 0.3, 0.3, 0.6);
uniform float distortion_amount : hint_range(0.0, 0.1) = 0.02;
uniform float scan_line_density : hint_range(10.0, 100.0) = 40.0;
uniform float flicker_speed : hint_range(0.0, 20.0) = 10.0;

void fragment() {
	vec2 uv = UV;

	// Slight horizontal distortion for speed effect
	float distort = sin(uv.y * 20.0 + TIME * 5.0) * distortion_amount * (1.0 - progress);
	uv.x += distort;

	// Sample original texture
	vec4 tex = texture(TEXTURE, uv);

	// Scan line effect
	float scan = sin(uv.y * scan_line_density + TIME * flicker_speed) * 0.5 + 0.5;
	scan = mix(0.7, 1.0, scan);

	// Edge fade effect
	float edge_fade = smoothstep(0.0, 0.2, uv.x) * smoothstep(1.0, 0.8, uv.x);
	edge_fade *= smoothstep(0.0, 0.1, uv.y) * smoothstep(1.0, 0.9, uv.y);

	// Progress-based fade
	float fade = 1.0 - progress;
	fade = pow(fade, 1.5); // Faster fade at end

	// Apply ghost color
	vec3 final_color = ghost_color.rgb;
	final_color *= scan;

	// Add slight glow at edges
	float glow = (1.0 - edge_fade) * 0.3;
	final_color += vec3(glow);

	float alpha = ghost_color.a * fade * edge_fade * tex.a;

	COLOR = vec4(final_color, alpha);
}
