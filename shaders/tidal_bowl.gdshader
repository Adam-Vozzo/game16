shader_type spatial;
render_mode cull_disabled;
global uniform float tidal_time;
varying vec3 local_position;
void vertex() { local_position = VERTEX; }
void fragment() {
	vec2 p = local_position.xz;
	float grain = sin(p.x * 43.0 + sin(p.y * 27.0)) * sin(p.y * 51.0);
	float tide = sin(p.x * 2.8 + sin(p.y * 2.2 + tidal_time * 0.17)) + sin(p.y * 3.1 + cos(p.x * 2.1 - tidal_time * 0.13));
	float caustic = pow(1.0 - abs(tide) * 0.5, 16.0);
	ALBEDO = mix(vec3(0.028, 0.055, 0.10), vec3(0.065, 0.13, 0.20), caustic * 0.5 + 0.2) * (1.0 + grain * 0.06);
	ROUGHNESS = 0.32;
	SPECULAR = 0.55;
	EMISSION = vec3(0.025, 0.085, 0.13) * caustic * 0.35;
	if (OUTPUT_IS_SRGB) {
		ALBEDO *= 2.0;
		EMISSION *= 1.5;
	} else {
		ALBEDO *= 0.55;
		EMISSION *= 0.4;
	}
}
