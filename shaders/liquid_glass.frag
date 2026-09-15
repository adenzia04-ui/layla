#version 460 core
#include <flutter/runtime_effect.glsl>

// The tab bar's lens, as a piece of real glass.
//
// Applied as a backdrop filter. The image it is handed is the whole screen,
// in device pixels, with FlutterFragCoord() in the same space — measured,
// not assumed: an earlier version took the image to be the lens alone and
// sampled the wrong place at the wrong scale, so the glass came out as a
// dark smear. The lens's own position arrives in that space as uniforms.
//
// Inside the capsule, samples are pulled toward the centre in proportion to
// how close they are to the rim, following the profile of a sphere: almost
// straight through the middle, bending hard at the edge. That is what
// magnification is. Red and blue are pulled by slightly different amounts,
// which is what an edge of glass does to light.

uniform vec2 uSize;        // the filtered image — the screen, in pixels
uniform vec2 uCenter;      // lens centre, screen pixels
uniform vec2 uHalf;        // lens half-extent, pixels
uniform float uRadius;     // corner radius of the capsule, pixels
uniform float uStrength;   // how far the rim bends light, pixels
uniform float uLight;      // how much light sits on the glass, 0..1
uniform sampler2D uTexture;

out vec4 fragColor;

float sdRoundBox(vec2 p, vec2 b, float r) {
    vec2 q = abs(p) - b + r;
    return min(max(q.x, q.y), 0.0) + length(max(q, 0.0)) - r;
}

vec3 sampleAt(vec2 uv) {
    return texture(uTexture, clamp(uv / uSize, 0.0, 1.0)).rgb;
}

void main() {
    vec2 uv = FlutterFragCoord().xy;
    vec2 p = uv - uCenter;
    float d = sdRoundBox(p, uHalf, uRadius);

    // Outside the lens (the clip should already have removed this).
    if (d > 0.0) {
        fragColor = vec4(sampleAt(uv), 1.0);
        return;
    }

    // 0 at the rim, 1 along the spine of the capsule.
    float inward = clamp(-d / max(uRadius, 1.0), 0.0, 1.0);
    float e = 1.0 - inward;
    // Flat through the middle, so the label reads crisp; steep at the rim.
    float bend = pow(e, 4.0) * uStrength;

    vec2 dir = length(p) > 0.001 ? normalize(p) : vec2(0.0, -1.0);
    vec2 base = uv - dir * bend;

    float ca = bend * 0.22;
    vec3 col = vec3(
        sampleAt(base - dir * ca).r,
        sampleAt(base).g,
        sampleAt(base + dir * ca).b
    );

    // Light on the glass: a bright arc along the upper rim, a thinner one
    // along the lower, and a faint sheen across the top half.
    float upper = clamp(-p.y / max(uHalf.y, 1.0), 0.0, 1.0);
    float lower = clamp(p.y / max(uHalf.y, 1.0), 0.0, 1.0);
    col += vec3(0.92, 0.94, 1.0) * pow(e, 3.0) * upper * 0.75 * uLight;
    col += vec3(0.70, 0.76, 0.88) * pow(e, 5.0) * lower * 0.35 * uLight;
    col += vec3(0.86, 0.90, 1.0) * (0.06 + upper * 0.07) * uLight;

    fragColor = vec4(col, 1.0);
}
