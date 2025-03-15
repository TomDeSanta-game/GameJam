shader_type canvas_item;

uniform float flash_intensity : hint_range(0.0, 1.0) = 0.0;
uniform vec4 flash_color : source_color = vec4(1.0, 1.0, 1.0, 1.0);
uniform bool enabled = false;

void fragment() {
	vec4 texture_color = texture(TEXTURE, UV);
	
	if (enabled) {
		// Mix between original and flash color based on intensity
		COLOR = mix(texture_color, flash_color, flash_intensity);
		// Preserve original alpha
		COLOR.a = texture_color.a;
	} else {
		COLOR = texture_color;
	}
}
