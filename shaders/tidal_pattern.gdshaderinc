global uniform float tidal_time;
global uniform float tidal_emission;

// Cage-attached coordinates stretch the canals with the soft body.
vec2 jelly_pattern(vec3 p) {
	float latitude = acos(clamp(p.y, -0.999, 0.999));
	float longitude = atan(p.z, p.x);
	float canal = abs(sin(longitude * 6.0 + 0.32 * sin(latitude * 3.0)));
	float aa = max(fwidth(canal), 0.015);
	float lines = 1.0 - smoothstep(0.018, 0.045 + aa, canal);
	lines *= smoothstep(0.12, 0.45, latitude) * (1.0 - smoothstep(2.8, 3.1, latitude));
	float branch = abs(sin(longitude * 12.0 - latitude * 3.0));
	float fine = (1.0 - smoothstep(0.012, 0.035 + fwidth(branch), branch)) * 0.07;
	fine *= smoothstep(0.7, 1.8, latitude);
	float pulse = pow(0.5 + 0.5 * sin(latitude * 5.0 - tidal_time * 1.7), 8.0);
	return vec2(clamp(lines + fine, 0.0, 1.0), pulse);
}
