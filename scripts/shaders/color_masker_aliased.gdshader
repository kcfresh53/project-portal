shader_type canvas_item;

uniform float tolerance: hint_range(0.0, 1.0, 0.01) = 0.1;
uniform vec4 prev_color: source_color = vec4(0.0, 0.0, 0.0, 1.0); // Target color to replace
uniform vec4 new_color: source_color = vec4(0.0, 0.0, 0.0, 0.0);  // Usually transparent

uniform sampler2D overlay_texture;                // Overlay texture
uniform vec2 scroll_direction = vec2(1.0, 0.0);   // Direction of scroll
uniform float scroll_speed = 0.2;                 // Speed of scroll
uniform float repeat_scale = 1.0;                 // Controls tiling frequency

void fragment() {
    vec4 color = texture(TEXTURE, UV);

    // Detect target color (e.g., black)
    vec3 diff = color.rgb - prev_color.rgb;
    float dist_sq = dot(diff, diff);
    float tol_sq = tolerance * tolerance;

    float match = step(dist_sq, tol_sq); // 1.0 = match (to replace), 0.0 = normal

    // Replace with transparent
    color = mix(color, new_color, match);

    // Scroll and tile overlay texture
    vec2 tiled_uv = fract(UV * repeat_scale + TIME * scroll_speed * scroll_direction);
    vec4 overlay = texture(overlay_texture, tiled_uv);

    // Apply overlay ONLY on visible (non-masked) parts
    color.rgb = mix(color.rgb, overlay.rgb, 1.0 - match);

    COLOR = color;
}
