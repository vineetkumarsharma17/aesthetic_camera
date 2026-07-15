#version 460 core
#include <flutter/runtime_effect.glsl>

// "Aesthetic" — the reference TikTok/Snapchat look:
// warm tones, faded blacks, low saturation, film grain, vignette, slight
// contrast boost. All GPU, no LUTs.
uniform vec2 uSize;
uniform float uTime;
uniform sampler2D uTexture;

out vec4 fragColor;

const vec3 kLuma = vec3(0.2126, 0.7152, 0.0722);

// Cheap animated hash noise for film grain.
float grain(vec2 p) {
    return fract(sin(dot(p, vec2(12.9898, 78.233))) * 43758.5453);
}

void main() {
    vec2 uv = FlutterFragCoord().xy / uSize;
    vec3 color = texture(uTexture, uv).rgb;

    // 1. Slight contrast boost around mid-gray.
    color = (color - 0.5) * 1.08 + 0.5;

    // 2. Lower saturation for a muted, editorial feel.
    float luma = dot(color, kLuma);
    color = mix(vec3(luma), color, 0.85);

    // 3. Warm tone — lift reds, drop blues.
    color *= vec3(1.06, 1.02, 0.94);

    // 4. Faded blacks — lift the shadow floor toward a warm gray.
    vec3 lift = vec3(0.06, 0.05, 0.04);
    color = lift + color * (1.0 - lift);

    // 5. Soft vignette.
    vec2 d = uv - 0.5;
    float vig = 1.0 - dot(d, d) * 0.9;
    color *= clamp(vig, 0.0, 1.0);

    // 6. Film grain (animated over time).
    float g = grain(uv * uSize + fract(uTime) * 100.0);
    color += (g - 0.5) * 0.06;

    fragColor = vec4(clamp(color, 0.0, 1.0), 1.0);
}
