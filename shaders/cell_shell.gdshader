shader_type spatial;
render_mode blend_mix, depth_draw_never, cull_back;
#include "res://shaders/tidal_pattern.gdshaderinc"
uniform vec4 tint : source_color = vec4(0.4, 0.8, 1.0, 1.0);
uniform bool cage_pattern = false;
varying vec3 pattern_position;
void vertex() {
    pattern_position = cage_pattern ? COLOR.rgb * 2.0 - 1.0 : normalize(VERTEX);
}
void fragment() {
    vec3 p = normalize(pattern_position);
    float facing = clamp(dot(normalize(NORMAL), normalize(VIEW)), 0.0, 1.0);
    float rim = pow(1.0 - facing, 2.8);
    vec2 jelly = jelly_pattern(p);
    vec3 pearl = mix(tint.rgb, vec3(0.65, 0.9, 1.0), 0.5);
    ALBEDO = mix(tint.rgb * 0.6, pearl, rim + jelly.x * 0.3);
    ROUGHNESS = 0.19;
    SPECULAR = 0.65;
    CLEARCOAT = 0.5;
    CLEARCOAT_ROUGHNESS = 0.2;
    EMISSION = pearl * (rim * 0.45 + jelly.x * (0.5 + jelly.y * 0.7));
    ALPHA = 0.12 + rim * 0.48 + jelly.x * 0.14;
}
