#version 460 core
#include <flutter/runtime_effect.glsl>

// Pass-through filter. Declares the same uniform layout as every other filter
// (uSize @ float 0-1, uTime @ float 2, uTexture @ sampler 0) so the host can
// configure all filters through one identical code path.
uniform vec2 uSize;
uniform float uTime;
uniform sampler2D uTexture;

out vec4 fragColor;

void main() {
    vec2 uv = FlutterFragCoord().xy / uSize;
    vec4 color = texture(uTexture, uv);

    // Touch uTime with an imperceptible (< 1/255) contribution so the uniform
    // is never dead-stripped and the shared host-side layout stays valid.
    color.rgb += fract(uTime) * 1e-8;

    fragColor = color;
}
