shader_type canvas_item;

uniform float darkness: hint_range(0.0, 1.0) = 0.3;
uniform float contrast: hint_range(0.0, 2.0) = 1.3;
uniform float saturation: hint_range(0.0, 1.0) = 0.7;
uniform float vignette_intensity: hint_range(0.0, 1.0) = 0.4;
uniform float vignette_opacity: hint_range(0.0, 1.0) = 0.5;
uniform vec4 tint_color: source_color = vec4(0.9, 0.8, 0.7, 1.0);
uniform bool enabled = true;

void fragment() {
    vec4 color = texture(TEXTURE, UV);
    
    if (enabled) {
        // Apply darkness
        color.rgb = mix(color.rgb, vec3(0.0), darkness);
        
        // Apply contrast
        color.rgb = mix(vec3(0.5), color.rgb, contrast);
        
        // Apply tint
        color.rgb = mix(color.rgb, tint_color.rgb, 0.15);
        
        // Desaturate (convert to grayscale and mix back with original)
        float gray = dot(color.rgb, vec3(0.299, 0.587, 0.114));
        color.rgb = mix(vec3(gray), color.rgb, saturation);
        
        // Vignette effect
        vec2 center_uv = UV - vec2(0.5);
        float vignette = length(center_uv) * vignette_intensity;
        vignette = smoothstep(0.8, 0.25, vignette);
        color.rgb = mix(color.rgb, color.rgb * vignette, vignette_opacity);
    }
    
    COLOR = color;
} 