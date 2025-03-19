shader_type canvas_item;

uniform vec4 base_color: source_color = vec4(0.8, 0.4, 0.0, 1.0);
uniform vec4 glow_color: source_color = vec4(1.0, 0.7, 0.2, 1.0);
uniform float intensity: hint_range(0.0, 2.0) = 1.0;
uniform float speed: hint_range(0.1, 5.0) = 1.0;
uniform float noise_scale: hint_range(1.0, 30.0) = 10.0;
uniform bool enabled = true;

// Simplex noise function
vec3 mod289(vec3 x) { return x - floor(x * (1.0 / 289.0)) * 289.0; }
vec2 mod289(vec2 x) { return x - floor(x * (1.0 / 289.0)) * 289.0; }
vec3 permute(vec3 x) { return mod289(((x*34.0)+1.0)*x); }

float snoise(vec2 v) {
    const vec4 C = vec4(0.211324865405187, 0.366025403784439,
                         -0.577350269189626, 0.024390243902439);
    vec2 i  = floor(v + dot(v, C.yy));
    vec2 x0 = v -   i + dot(i, C.xx);
    vec2 i1;
    i1 = (x0.x > x0.y) ? vec2(1.0, 0.0) : vec2(0.0, 1.0);
    vec4 x12 = x0.xyxy + C.xxzz;
    x12.xy -= i1;
    i = mod289(i);
    vec3 p = permute(permute(i.y + vec3(0.0, i1.y, 1.0))
        + i.x + vec3(0.0, i1.x, 1.0));
    vec3 m = max(0.5 - vec3(dot(x0, x0), dot(x12.xy, x12.xy),
        dot(x12.zw, x12.zw)), 0.0);
    m = m*m;
    m = m*m;
    vec3 x = 2.0 * fract(p * C.www) - 1.0;
    vec3 h = abs(x) - 0.5;
    vec3 ox = floor(x + 0.5);
    vec3 a0 = x - ox;
    m *= 1.79284291400159 - 0.85373472095314 * (a0*a0 + h*h);
    vec3 g;
    g.x  = a0.x  * x0.x  + h.x  * x0.y;
    g.yz = a0.yz * x12.xz + h.yz * x12.yw;
    return 130.0 * dot(m, g);
}

void fragment() {
    vec4 color = texture(TEXTURE, UV);
    
    if (enabled && color.a > 0.1) {
        // Create animated noise pattern
        float time = TIME * speed;
        float noise1 = snoise(UV * noise_scale + vec2(time * 0.1, time * 0.2)) * 0.5 + 0.5;
        float noise2 = snoise(UV * noise_scale * 0.5 + vec2(-time * 0.15, time * 0.1)) * 0.5 + 0.5;
        
        // Combine noise patterns
        float combined_noise = noise1 * 0.6 + noise2 * 0.4;
        
        // Create pulsing effect
        float pulse = (sin(time) * 0.1 + 0.9) * intensity;
        
        // Apply effects
        float effect = combined_noise * pulse;
        
        // Mix original with ember glow effect
        color.rgb = mix(base_color.rgb, glow_color.rgb, effect);
        color.a = min(color.a + effect * 0.3, 1.0); // Boost alpha a bit for glow effect
    }
    
    COLOR = color;
} 