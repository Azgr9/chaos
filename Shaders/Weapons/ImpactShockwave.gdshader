shader_type canvas_item;

// Impact Shockwave Shader
// Expanding ring effect for heavy hits and skill impacts

uniform float progress : hint_range(0.0, 1.0) = 0.0;
uniform vec4 wave_color : source_color = vec4(1.0, 0.5, 0.2, 0.8);
uniform float ring_thickness : hint_range(0.01, 0.5) = 0.15;
uniform float inner_glow : hint_range(0.0, 2.0) = 1.0;
uniform float distortion : hint_range(0.0, 0.1) = 0.02;

void fragment() {
	vec2 uv = UV - 0.5;
	float dist = length(uv) * 2.0;

	// Ring expands with progress
	float ring_radius = progress;
	float ring_dist = abs(dist - ring_radius);

	// Ring shape
	float ring = 1.0 - smoothstep(0.0, ring_thickness, ring_dist);

	// Inner glow (fills center initially, shrinks)
	float inner = smoothstep(ring_radius, ring_radius * 0.3, dist) * (1.0 - progress);

	// Edge distortion effect
	float noise = sin(atan(uv.y, uv.x) * 8.0 + progress * 10.0) * distortion;
	ring *= 1.0 + noise;

	// Fade out as it expands
	float fade = 1.0 - pow(progress, 0.5);

	// Combine ring and inner glow
	float alpha = (ring + inner * inner_glow) * fade;

	// Color - inner is brighter
	vec3 final_color = wave_color.rgb;
	final_color += vec3(inner * 0.5);

	COLOR = vec4(final_color, alpha * wave_color.a);
}
