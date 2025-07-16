shader_type canvas_item;

uniform float tolerance: hint_range(0.0, 1.0, 0.01) = 0.1;
uniform vec4 prev_color: source_color = vec4(0.0, 0.0, 0.0, 1.0); // default black
uniform vec4 new_color: source_color = vec4(0.0, 0.0, 0.0, 0.0); // transparent

void fragment() {
    vec4 color = texture(TEXTURE, UV);

    // Calculate squared difference only for RGB, ignore alpha
    vec3 diff = color.rgb - prev_color.rgb;
    float dist_sq = dot(diff, diff);

    // Compare squared distance to avoid sqrt()
    float tol_sq = tolerance * tolerance;

    // Smoothly transition alpha using step function to avoid branch
    float match = step(dist_sq, tol_sq); // 1.0 if within tolerance, 0.0 otherwise

    // Linearly blend based on match value (0 or 1)
    color = mix(color, new_color, match);

    COLOR = color;
}
