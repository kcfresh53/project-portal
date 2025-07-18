shader_type canvas_item;

// Color replacement uniforms
uniform float color_tolerance: hint_range(0.0, 1.0, 0.01) = 0.1;
uniform float color_smoothness: hint_range(0.0, 0.5, 0.01) = 0.05;
uniform vec4 prev_color: source_color = vec4(0.0, 0.0, 0.0, 1.0);
uniform vec4 new_color: source_color = vec4(0.0, 0.0, 0.0, 0.0);

// Outline uniforms
uniform sampler2D scrollingTexture: hint_default_white;
uniform vec2 textureScale = vec2(1.0);
uniform float angle: hint_range(0.0, 360.0) = 45.0;
uniform float textureSpeed: hint_range(-10.0, 10.0) = 0.1;
uniform float textureStrength: hint_range(0.0, 1.0) = 0.5;
uniform float maxLineWidth: hint_range(0.0, 100.0) = 10.0;
uniform float minLineWidth: hint_range(0.0, 100.0) = 5.0;
uniform float speed: hint_range(0.0, 10.0) = 1.0;
uniform float blockSize: hint_range(0.001, 100.0) = 20.0;
uniform sampler2D color_tex: source_color;
uniform int gradientResolution: hint_range(1, 30) = 10;
uniform float tolerance: hint_range(0.0, 0.999) = 0.0;

// Pre-calculated values (moved from fragment to avoid recalculation)
varying float max_line_width;

void vertex() {
	max_line_width = max(maxLineWidth, minLineWidth);

	if (max_line_width > 0.0) {
		VERTEX = vec2(VERTEX.x * (1.0 + TEXTURE_PIXEL_SIZE.x * max_line_width * 2.0),
					  VERTEX.y * (1.0 + TEXTURE_PIXEL_SIZE.y * max_line_width * 2.0));
	}
}

// Optimized border check
bool border(vec2 uv) {
	vec2 uvBorder = abs(uv - 0.5);
	return max(uvBorder.x, uvBorder.y) > 0.5;
}

// Optimized alpha check with early exit
float get_alpha(sampler2D tex, vec2 uv, float inner_bound, float outer_bound) {
	if (border(uv)) return 0.0;

	vec4 tex_color = texture(tex, uv);
	vec3 delta = tex_color.rgb - prev_color.rgb;
	float d2 = dot(delta, delta);

	if (d2 > outer_bound) return tex_color.a;
	if (d2 < inner_bound) return new_color.a;

	float match = 1.0 - smoothstep(inner_bound, outer_bound, d2);
	return mix(tex_color.a, new_color.a, match);
}

// Optimized hash function
float hash(vec2 p, float s) {
	return fract(sin(dot(p, vec2(127.1, 311.7)) + s) * 43758.5453);
}

// Simplified noise function
float noise(vec2 p, float s) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f); // Smoothstep interpolation

	return mix(
		mix(hash(i, s), hash(i + vec2(1.0, 0.0), s), f.x),
		mix(hash(i + vec2(0.0, 1.0), s), hash(i + vec2(1.0, 1.0), s), f.x), f.y);
}

// Optimized line width calculation
float get_line_width(vec2 p, float s) {
	p /= blockSize;
	float w = noise(p, s);
	w = mix(w, noise(p * 2.0, s), 0.5);
	w = mix(w, noise(p * 4.0, s), 0.25);
	return mix(maxLineWidth, minLineWidth, w);
}

// Optimized neighbor checking with reduced redundancy
bool in_range(vec2 size, sampler2D tex, vec2 uv, float inner_bound, float outer_bound) {
	// Check cardinal directions first (most likely to hit)
	if (get_alpha(tex, uv + vec2(size.x, 0.0), inner_bound, outer_bound) > 0.0) return true;
	if (get_alpha(tex, uv + vec2(-size.x, 0.0), inner_bound, outer_bound) > 0.0) return true;
	if (get_alpha(tex, uv + vec2(0.0, size.y), inner_bound, outer_bound) > 0.0) return true;
	if (get_alpha(tex, uv + vec2(0.0, -size.y), inner_bound, outer_bound) > 0.0) return true;

	// Check diagonals
	if (get_alpha(tex, uv + size, inner_bound, outer_bound) > 0.0) return true;
	if (get_alpha(tex, uv + vec2(size.x, -size.y), inner_bound, outer_bound) > 0.0) return true;
	if (get_alpha(tex, uv + vec2(-size.x, size.y), inner_bound, outer_bound) > 0.0) return true;
	if (get_alpha(tex, uv + vec2(-size.x, -size.y), inner_bound, outer_bound) > 0.0) return true;

	// Check half-step positions (reduced from original)
	if (get_alpha(tex, uv + vec2(size.x, size.y * 0.5), inner_bound, outer_bound) > 0.0) return true;
	if (get_alpha(tex, uv + vec2(-size.x, size.y * 0.5), inner_bound, outer_bound) > 0.0) return true;

	return false;
}

// Optimized distance calculation with early exit
float get_distance(vec2 maxDistance, sampler2D tex, vec2 uv, float inner_bound, float outer_bound) {
	float inv_res = 1.0 / float(gradientResolution);

	for (int i = 1; i < gradientResolution; i++) {
		float step_dist = float(i) * inv_res;
		vec2 actualDistance = step_dist * maxDistance;

		if (in_range(actualDistance, tex, uv, inner_bound, outer_bound)) {
			return step_dist;
		}
	}
	return 1.0;
}

void fragment() {
	// Get original color
	vec4 color = texture(TEXTURE, UV);

	// Pre-calculate squared bounds (moved from repeated calculations)
	float tol_sq = color_tolerance * color_tolerance;
	float smooth_sq = color_smoothness * color_smoothness;
	float inner_bound = max(0.0, tol_sq - smooth_sq);
	float outer_bound = tol_sq + smooth_sq;

	// Color replacement with optimized distance calculation
	vec3 diff = color.rgb - prev_color.rgb;
	float dist_sq = dot(diff, diff);

	// Early exit for colors that don't need replacement
	if (dist_sq > outer_bound) {
		// No color replacement needed
		if (max_line_width <= 0.0) {
			COLOR = color;
		}
	} else {
		// Apply color replacement
		float match = (dist_sq < inner_bound) ? 1.0 : 1.0 - smoothstep(inner_bound, outer_bound, dist_sq);
		color = mix(color, new_color, match);
	}

	// Apply outline effect if enabled
	if (max_line_width > 0.0) {
		// Calculate corrected UV once
		vec2 uv = UV - 0.5;
		vec2 edge = TEXTURE_PIXEL_SIZE * max_line_width * 2.0;
		uv = uv + uv * edge + 0.5;

		// Check if we're in outline area
		if (color.a <= tolerance || border(uv)) {
			// Pre-calculate time-based values
			float radiansAngle = radians(angle + 180.0);
			vec2 vector = vec2(cos(radiansAngle), sin(radiansAngle));
			float timeStep = floor(TIME * speed);

			// Calculate line width and size
			vec2 size = TEXTURE_PIXEL_SIZE * get_line_width(uv / TEXTURE_PIXEL_SIZE, timeStep);

			// Get texture colors
			vec4 textureColor = texture(scrollingTexture, fract(UV / textureScale + vector * textureSpeed * TIME));
			vec4 actualColor = texture(color_tex, vec2(get_distance(edge * 0.5 + 0.01, TEXTURE, uv, inner_bound, outer_bound)));

			// Apply outline
			vec4 finalColor = step(1.0 - tolerance, in_range(size, TEXTURE, uv, inner_bound, outer_bound) ? 1.0 : 0.0) * mix(actualColor, textureColor, textureStrength);
			color = finalColor;
		}
	}

	COLOR = color;
}