shader_type spatial;
render_mode diffuse_burley;
#include "res://shaders/tidal_pattern.gdshaderinc"
global uniform float tidal_scattering;
uniform vec4 tint : source_color = vec4(0.4, 0.8, 1.0, 1.0);
uniform bool cage_pattern = false;
varying vec3 pattern_position;
void vertex() {
    pattern_position = cage_pattern ? COLOR.rgb * 2.0 - 1.0 : normalize(VERTEX);
}
void fragment() {
    vec3 p = normalize(pattern_position);
    vec2 jelly = jelly_pattern(p);
    float facing = clamp(dot(normalize(NORMAL), normalize(VIEW)), 0.0, 1.0);
    float tissue = 0.94 + 0.06 * sin(p.x * 22.0 + sin(p.z * 17.0)) * sin(p.y * 26.0);
    vec3 pearl = mix(tint.rgb, vec3(0.7, 0.91, 1.0), 0.45);
    ALBEDO = tint.rgb * tissue * 0.64 + pearl * jelly.x * 0.13;
    ROUGHNESS = 0.33;
    SPECULAR = 0.42;
    BACKLIGHT = tint.rgb * 0.48;
    EMISSION = tint.rgb * (0.10 + 0.08 * (1.0 - facing)) + pearl * jelly.x * (0.32 + jelly.y * 0.38);
    if (OUTPUT_IS_SRGB) { EMISSION += tint.rgb * 0.18; }
    EMISSION *= tidal_emission;
    // Only Forward+ implements this scattering pass; Web uses BACKLIGHT.
    #if CURRENT_RENDERER == RENDERER_FORWARD_PLUS
    SSS_STRENGTH = tidal_scattering;
    SSS_TRANSMITTANCE_COLOR = vec4(tint.rgb * tidal_scattering, tidal_scattering);
    // A zero depth can produce invalid lighting even when scattering is off.
    SSS_TRANSMITTANCE_DEPTH = 0.35;
    SSS_TRANSMITTANCE_BOOST = 0.1 * tidal_scattering;
    #endif
}
