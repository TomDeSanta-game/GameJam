shader_type canvas_item;

// How intense the white flash effect is (0.0 - 1.0)
uniform float flash_intensity : hint_range(0.0, 1.0) = 0.0;
// White color for the flash
uniform vec4 flash_color : source_color = vec4(1.0, 1.0, 1.0, 1.0);

void fragment() {
    // Get the original pixel color from the sprite texture
    vec4 original_color = texture(TEXTURE, UV);
    
    // Skip fully transparent pixels to avoid affecting background
    if (original_color.a < 0.01) {
        COLOR = original_color;
        return;
    }
    
    // Create a white flash effect
    // Use a more direct approach for consistent application across all non-transparent pixels
    vec4 final_color;
    
    if (flash_intensity > 0.0) {
        // Linear interpolation with stronger weighting toward white
        final_color = mix(original_color, flash_color, flash_intensity);
        
        // Ensure the alpha stays the same as the original
        final_color.a = original_color.a;
    } else {
        final_color = original_color;
    }
    
    // Set the final pixel color
    COLOR = final_color;
} 