shader_type canvas_item;

uniform float time_scale : hint_range(0.1, 5.0) = 1.0;
uniform float ripple_speed : hint_range(0.1, 10.0) = 2.0;
uniform float ripple_frequency : hint_range(1.0, 20.0) = 6.0;
uniform float ripple_width : hint_range(0.01, 0.2) = 0.05;
uniform float max_distance : hint_range(0.1, 2.0) = 0.8;
uniform vec4 ripple_color : source_color = vec4(0.0, 0.8, 1.0, 1.0);
uniform float ripple_intensity : hint_range(0.0, 2.0) = 1.0;
uniform float fade_power : hint_range(0.5, 4.0) = 2.0;

varying vec2 world_position;

vec2 get_closest_mask_point(vec2 uv, sampler2D tex) {
    vec2 closest_point = uv;
    float min_distance = 999.0;

    // Sample in a grid pattern to find closest white pixel
    float step_size = 1.0 / 64.0; // Adjust resolution as needed

    for (float x = 0.0; x <= 1.0; x += step_size) {
        for (float y = 0.0; y <= 1.0; y += step_size) {
            vec2 sample_pos = vec2(x, y);
            float mask_value = texture(tex, sample_pos).r;

            if (mask_value > 0.5) {
                float dist = distance(uv, sample_pos);
                if (dist < min_distance) {
                    min_distance = dist;
                    closest_point = sample_pos;
                }
            }
        }
    }

    return closest_point;
}

float get_distance_to_mask(vec2 uv, sampler2D tex) {
    // Get the mask value at current position
    float mask_value = texture(tex, uv).r;

    // If we're inside the mask, return 0
    if (mask_value > 0.5) {
        return 0.0;
    }

    // Find minimum distance to any white pixel
    float min_distance = 999.0;
    float step_size = 1.0 / 128.0;

    // Search in expanding circles for efficiency
    for (float radius = step_size; radius < max_distance && min_distance > radius; radius += step_size) {
        float circumference = 2.0 * 3.14159 * radius;
        float angle_step = max(step_size / radius, 0.1);

        for (float angle = 0.0; angle < 6.28318; angle += angle_step) {
            vec2 sample_pos = uv + vec2(cos(angle), sin(angle)) * radius;

            // Check bounds
            if (sample_pos.x >= 0.0 && sample_pos.x <= 1.0 &&
                sample_pos.y >= 0.0 && sample_pos.y <= 1.0) {
                float sample_mask = texture(tex, sample_pos).r;

                if (sample_mask > 0.5) {
                    min_distance = min(min_distance, radius);
                    break;
                }
            }
        }
    }

    return min_distance;
}

void fragment() {
    vec2 uv = UV;
    float time = TIME * time_scale;

    // Original texture
    vec4 original_color = texture(TEXTURE, uv);

    // Check if we're inside the mask
    if (original_color.r > 0.5) {
        // Inside the mask, show original
        COLOR = original_color;
    } else {
        // Outside the mask, calculate ripple effect
        float dist_to_mask = get_distance_to_mask(uv, TEXTURE);
        float normalized_distance = dist_to_mask / max_distance;

        // Create animated ripples
        float ripple_phase = normalized_distance * ripple_frequency - time * ripple_speed;
        float ripple_wave = sin(ripple_phase);

        // Create ripple intensity based on distance
        float ripple_envelope = 1.0 - pow(normalized_distance, fade_power);
        ripple_envelope = max(0.0, ripple_envelope);

        // Create sharp ripple edges
        float ripple_mask = smoothstep(-ripple_width, ripple_width, ripple_wave);
        ripple_mask = abs(ripple_mask - 0.5) * 2.0; // Convert to outline

        // Combine everything
        float final_ripple = ripple_mask * ripple_envelope * ripple_intensity;

        // Mix with original color
        COLOR = mix(original_color, ripple_color, final_ripple);
    }
}