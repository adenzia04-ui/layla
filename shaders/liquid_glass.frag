#version 460 core
#include <flutter/runtime_effect.glsl>

// Refraction for the tab bar's lens.
//
// Everything outside the capsule passes through untouched. Inside it, samples
// are pulled toward the centre in proportion to how close they are to the rim,
// which is what magnification actually is — and the red and blue channels are
// pulled by slightly different amounts, which is what an edge of real glass
// does to light.

uniform vec2 uSize;        // required first uniform: the filtered area
uniform vec2 uCenter;      // lens centre, in pixels
uniform vec2 uHalf;        // lens half-extent, in pixels
uniform float uRadius;     // corner radius of the capsule
uniform float uStrength;   // how far the rim bends light, in pixels
uniform sampler2D uTexture;

out vec4 fragColor;

float sdRoundBox(vec2 p, vec2 b, float r) {
    vec2 q = abs(p) - b + r;
    return min(max(q.x, q.y), 0.0) + length(max(q, 0.0)) - r;
}

void main() {
    vec2 uv = FlutterFragCoord().xy;
    vec2 p = uv - uCenter;
    float d = sdRoundBox(p, uHalf, uRadius);

    // Outside the lens: leave the bar exactly as it was.
    if (d > 0.0) {
        fragColor = texture(uTexture, uv / uSize);
        return;
    }

    // 0 at the rim, 1 in the middle.
    float inward = clamp(-d / max(uRadius, 1.0), 0.0, 1.0);
    float bend = pow(1.0 - inward, 2.2) * uStrength;

    vec2 dir = length(p) > 0.001 ? normalize(p) : vec2(0.0, -1.0);
    vec2 base = uv - dir * bend;

    // Channel split, strongest where the bend is strongest.
    float ca = bend * 0.14;
    vec3 col = vec3(
        texture(uTexture, (base - dir * ca) / uSize).r,
        texture(uTexture, base / uSize).g,
        texture(uTexture, (base + dir * ca) / uSize).b
    );

    // A specular arc along the upper rim, fading as it comes round the sides.
    float rim = 1.0 - inward;
    float upper = clamp(-p.y / max(uHalf.y, 1.0), 0.0, 1.0);
    col += vec3(0.62, 0.65, 0.72) * pow(rim, 3.0) * upper * 0.55;

    fragColor = vec4(col, 1.0);
}
