shader_type canvas_item;

uniform float flash_intensity : hint_range(0.0, 1.0) = 0.0;
uniform vec4 flash_color : source_color = vec4(1.0, 0.0, 0.0, 1.0); // Default to red

void fragment() {
    vec4 texture_color = texture(TEXTURE, UV);
    
    // Mix the texture color with the flash color based on intensity
    // This preserves transparency while still showing the red flash
    vec3 final_color = mix(texture_color.rgb, flash_color.rgb, flash_intensity);
    
    // Output the final color with original alpha
    COLOR = vec4(final_color, texture_color.a);
} 