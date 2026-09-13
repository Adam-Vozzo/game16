shader_type spatial;
render_mode blend_mix, depth_draw_never, cull_back;

uniform vec4 tint : source_color = vec4(0.8, 0.95, 0.87, 1.0);
varying vec3 local_position;

void vertex() {
	local_position = VERTEX;
}

void fragment() {
	float facing = clamp(dot(normalize(NORMAL), normalize(VIEW)), 0.0, 1.0);
	float rim = pow(1.0 - facing, 3.0);
	float grain = sin(local_position.x * 93.0) * sin(local_position.y * 87.0) * sin(local_position.z * 101.0);
	ALBEDO = mix(tint.rgb, vec3(1.0, 0.98, 0.91), 0.65);
	ROUGHNESS = 0.14 + grain * 0.025;
	SPECULAR = 0.8;
	CLEARCOAT = 1.0;
	CLEARCOAT_ROUGHNESS = 0.15;
	EMISSION = ALBEDO * rim * 0.22;
	ALPHA = 0.065 + rim * 0.66;
}
