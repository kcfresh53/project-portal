shader_type canvas_item;

uniform float tolerance: hint_range(0.0, 1.0, 0.01) = 0.1;
uniform float smoothness: hint_range(0.0, 0.5, 0.01) = 0.05;
uniform vec4 prev_color: source_color = vec4(0.0, 0.0, 0.0, 1.0);
uniform vec4 new_color: source_color = vec4(0.0, 0.0, 0.0, 0.0);

void fragment() {
    vec4 color = texture(TEXTURE, UV);

    // Calculate squared difference for RGB only
    vec3 diff = color.rgb - prev_color.rgb;
    float dist_sq = dot(diff, diff);

    // Pre-calculate squared values to avoid repeated multiplication
    float tol_sq = tolerance * tolerance;
    float smooth_sq = smoothness * smoothness;

    // Create smooth transition zone
    float inner_bound = max(0.0, tol_sq - smooth_sq);
    float outer_bound = tol_sq + smooth_sq;

    // Smooth interpolation factor using smoothstep for anti-aliasing
    float match = 1.0 - smoothstep(inner_bound, outer_bound, dist_sq);

    // Apply smooth blending
    color = mix(color, new_color, match);

    COLOR = color;
}