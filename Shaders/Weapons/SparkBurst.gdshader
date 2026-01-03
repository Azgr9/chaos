shader_type canvas_item;

// Spark Burst Shader
// For metal impacts, finisher hits, skill effects

uniform float progress : hint_range(0.0, 1.0) = 0.0;
uniform vec4 spark_color : source_color = vec4(1.0, 0.9, 0.5, 1.0);
uniform vec4 hot_color : source_color = vec4(1.0, 1.0, 1.0, 1.0);
uniform float spark_count : hint_range(2.0, 12.0) = 6.0;
uniform float rotation_speed : hint_range(0.0, 10.0) = 3.0;

void fragment() {
	vec2 uv = UV - 0.5;
	float dist = length(uv) * 2.0;
	float angle = atan(uv.y, uv.x);

	// Rotating spark pattern
	float rotated_angle = angle + TIME * rotation_speed;
	float spark_pattern = abs(sin(rotated_angle * spark_count));
	spark_pattern = pow(spark_pattern, 3.0); // Sharpen sparks

	// Radial expansion
	float expand = progress * 0.8;
	float spark_ring = smoothstep(expand + 0.3, expand, dist) * smoothstep(expand - 0.1, expand + 0.1, dist);

	// Central flash
	float flash = smoothstep(0.3, 0.0, dist) * (1.0 - progress * 2.0);
	flash = max(flash, 0.0);

	// Combine
	float fade = 1.0 - pow(progress, 0.5);
	float alpha = (spark_pattern * spark_ring + flash) * fade;

	// Color - center is white hot
	vec3 final_color = mix(spark_color.rgb, hot_color.rgb, flash);

	COLOR = vec4(final_color, alpha * spark_color.a);
}
