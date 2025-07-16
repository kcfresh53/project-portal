shader_type canvas_item;

uniform sampler2D camera_y;
uniform sampler2D camera_CbCr;

uniform bool flip_horz = false;
uniform bool flip_vert = false;

// Test different channel mappings
uniform int mapping_mode : hint_range(0, 11) = 0;
uniform float yellow_correction : hint_range(0.0, 2.0) = 1.049;

void vertex() {
	if (flip_horz) {
		UV.x = 1.0 - UV.x;
	}
	if (flip_vert) {
		UV.y = 1.0 - UV.y;
	}
}

void fragment() {
	float y = texture(camera_y, UV).r;
	vec2 cbcr = texture(camera_CbCr, UV).rg;

	vec3 color;

	if (mapping_mode == 0) {
		// R=Cb, G=Cr, B=Y (your current best)
		color = vec3(cbcr.r, cbcr.g * yellow_correction, y);
	}
	else if (mapping_mode == 1) {
		// R=Cr, G=Cb, B=Y (swap chroma channels)
		color = vec3(cbcr.g, cbcr.r * yellow_correction, y);
	}
	else if (mapping_mode == 2) {
		// R=Y, G=Cb, B=Cr
		color = vec3(y, cbcr.r * yellow_correction, cbcr.g);
	}
	else if (mapping_mode == 3) {
		// R=Y, G=Cr, B=Cb
		color = vec3(y, cbcr.g * yellow_correction, cbcr.r);
	}
	else if (mapping_mode == 4) {
		// R=Cb, G=Y, B=Cr
		color = vec3(cbcr.r, y * yellow_correction, cbcr.g);
	}
	else if (mapping_mode == 5) {
		// R=Cr, G=Y, B=Cb
		color = vec3(cbcr.g, y * yellow_correction, cbcr.r);
	}
	else if (mapping_mode == 6) {
		// Maybe it's actually RGB but in different texture channels?
		// R=Cb, G=Y, B=Cr (alternative)
		color = vec3(cbcr.r, y, cbcr.g * yellow_correction);
	}
	else if (mapping_mode == 7) {
		// R=Y, G=Cb, B=Cr with different yellow correction
		color = vec3(y * yellow_correction, cbcr.r, cbcr.g);
	}
	else if (mapping_mode == 8) {
		// Test if camera outputs RGB in weird way
		// What if Y texture has red, CbCr.r has green, CbCr.g has blue?
		color = vec3(y, cbcr.r * yellow_correction, cbcr.g);
	}
	else if (mapping_mode == 9) {
		// Another RGB possibility
		color = vec3(cbcr.r, y, cbcr.g);
	}
	else if (mapping_mode == 10) {
		// Try mixing Y into red and blue
		color = vec3(mix(cbcr.r, y, 0.3), cbcr.g * yellow_correction, mix(cbcr.g, y, 0.3));
	}
	else if (mapping_mode == 11) {
		// Maybe blue is hidden in a different combination
		color = vec3(cbcr.r, cbcr.g * yellow_correction, mix(y, 1.0 - cbcr.r, 0.5));
	}

	COLOR = vec4(clamp(color, 0.0, 1.0), 1.0);
}