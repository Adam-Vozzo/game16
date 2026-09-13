shader_type spatial;
render_mode diffuse_burley;

uniform vec4 tint : source_color = vec4(0.8, 0.55, 0.3, 1.0);
varying vec3 local_position;

void vertex() {
	local_position = VERTEX;
}

void fragment() {
	float grain = sin(local_position.x * 115.0) * sin(local_position.y * 109.0) * sin(local_position.z * 121.0);
	float facing = clamp(dot(normalize(NORMAL), normalize(VIEW)), 0.0, 1.0);
	ALBEDO = tint.rgb * (0.96 + grain * 0.035);
	ROUGHNESS = 0.48 + grain * 0.04;
	SPECULAR = 0.35;
	BACKLIGHT = tint.rgb * 0.28;
	EMISSION = tint.rgb * 0.06 * (1.0 - facing);
}
