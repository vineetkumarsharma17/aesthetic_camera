#version 460 core
#include <flutter/runtime_effect.glsl>

// "Vintage" — heavier film emulation: sepia-leaning warmth, strong fade,
// low saturation, coarse grain, pronounced vignette.
uniform vec2 uSize;
uniform float uTime;
uniform sampler2D uTexture;

out vec4 fragColor;

const vec3 kLuma = vec3(0.2126, 0.7152, 0.0722);

float grain(vec2 p) {
    return fract(sin(dot(p, vec2(12.9898, 78.233))) * 43758.5453);
}

void main() {
    vec2 uv = FlutterFragCoord().xy / uSize;
    vec3 color = texture(uTexture, uv).rgb;

    // 1. Gentle contrast.
    color = (color - 0.5) * 1.05 + 0.5;

    // 2. Strong desaturation.
    float luma = dot(color, kLuma);
    color = mix(vec3(luma), color, 0.6);

    // 3. Blend toward a classic sepia.
    vec3 sepia = vec3(
        dot(color, vec3(0.393, 0.769, 0.189)),
        dot(color, vec3(0.349, 0.686, 0.168)),
        dot(color, vec3(0.272, 0.534, 0.131))
    );
    color = mix(color, sepia, 0.35);

    // 4. Extra warm push.
    color *= vec3(1.08, 1.00, 0.88);

    // 5. Heavier faded blacks.
    vec3 lift = vec3(0.10, 0.08, 0.06);
    color = lift + color * (1.0 - lift);

    // 6. Pronounced vignette.
    vec2 d = uv - 0.5;
    float vig = 1.0 - dot(d, d) * 1.4;
    color *= clamp(vig, 0.0, 1.0);

    // 7. Coarse film grain.
    float g = grain(uv * uSize + fract(uTime) * 100.0);
    color += (g - 0.5) * 0.10;

    fragColor = vec4(clamp(color, 0.0, 1.0), 1.0);
}
