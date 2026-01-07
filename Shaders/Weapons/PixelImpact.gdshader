shader_type canvas_item;

// Pixel Art Impact/Flash Effect Shader
// Creates pixelated impact bursts for hits

uniform float progress : hint_range(0.0, 1.0) = 0.0;
uniform vec4 impact_color : source_color = vec4(1.0, 1.0, 1.0, 1.0);
uniform vec4 outer_color : source_color = vec4(0.8, 0.8, 0.8, 0.8);
uniform float pixel_size : hint_range(1.0, 16.0) = 4.0;
uniform float ring_count : hint_range(1.0, 4.0) = 2.0;

vec2 pixelate(vec2 uv, float size) {
	return floor(uv * size) / size;
}

void fragment() {
	vec2 uv = UV;
	vec2 center = vec2(0.5, 0.5);

	// Pixelate
	float pixel_scale = 32.0 / pixel_size;
	vec2 pixel_uv = pixelate(uv, pixel_scale);

	// Distance from center (pixelated)
	float dist = length(pixel_uv - center) * 2.0;

	// Expanding ring effect
	float ring_radius = progress * 1.2;
	float ring_width = 0.2 / ring_count;

	// Multiple rings
	float alpha = 0.0;
	float color_mix = 0.0;

	for (float i = 0.0; i < 4.0; i++) {
		if (i >= ring_count) break;

		float ring_offset = i * 0.15;
		float ring_pos = ring_radius - ring_offset;

		// Hard step for pixel look
		float ring = step(ring_pos - ring_width, dist) * step(dist, ring_pos + ring_width);
		ring *= step(0.0, ring_pos);  // Don't show before animation starts

		alpha = max(alpha, ring * (1.0 - i / ring_count));
		color_mix = max(color_mix, ring * (1.0 - i / (ring_count + 1.0)));
	}

	// Center flash at start
	float center_flash = step(dist, 0.3) * step(progress, 0.3) * (1.0 - progress * 3.0);
	alpha = max(alpha, center_flash);
	color_mix = max(color_mix, center_flash);

	// Fade out
	alpha *= 1.0 - smoothstep(0.7, 1.0, progress);

	vec3 final_color = mix(outer_color.rgb, impact_color.rgb, color_mix);

	COLOR = vec4(final_color, alpha * impact_color.a);
}
