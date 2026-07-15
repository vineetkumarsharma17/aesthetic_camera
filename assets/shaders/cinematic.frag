#version 460 core
#include <flutter/runtime_effect.glsl>

// "Cinematic" — teal-orange color grade: teal-leaning shadows, warm highlights,
// higher contrast, mild desaturation, subtle vignette and fine grain.
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

    // 1. Stronger contrast for a filmic curve.
    color = (color - 0.5) * 1.15 + 0.5;

    // 2. Split tone: teal into shadows, orange into highlights.
    float luma = dot(color, kLuma);
    color += vec3(-0.02, 0.03, 0.06) * (1.0 - luma); // teal shadows
    color += vec3(0.06, 0.03, -0.04) * luma;         // warm highlights

    // 3. Mild global desaturation.
    luma = dot(color, kLuma);
    color = mix(vec3(luma), color, 0.92);

    // 4. Subtle vignette.
    vec2 d = uv - 0.5;
    float vig = 1.0 - dot(d, d) * 1.0;
    color *= clamp(vig, 0.0, 1.0);

    // 5. Fine grain.
    float g = grain(uv * uSize + fract(uTime) * 100.0);
    color += (g - 0.5) * 0.04;

    fragColor = vec4(clamp(color, 0.0, 1.0), 1.0);
}
