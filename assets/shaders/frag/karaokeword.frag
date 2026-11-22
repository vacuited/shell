#version 450

layout(location = 0) in vec2 qt_TexCoord0;
layout(location = 0) out vec4 fragColor;

layout(std140, binding = 0) uniform buf {
    mat4 qt_Matrix;
    float qt_Opacity;
    float progress;
    float feather;
    float glowBoost;
    vec4 activeColor;
    vec4 unsungColor;
    vec4 glowColor;
} ubuf;

layout(binding = 1) uniform sampler2D source;

void main() {
    vec4 tex = texture(source, qt_TexCoord0);
    float a = tex.a;
    if (a <= 0.001) {
        fragColor = vec4(0.0);
        return;
    }

    float f = clamp(ubuf.feather, 0.02, 0.35);
    float p = clamp(ubuf.progress, 0.0, 1.0);
    float edge = mix(-f, 1.0 + f, p);
    float fill = 1.0 - smoothstep(edge - f, edge + f, qt_TexCoord0.x);

    // Subtle leading-edge shimmer right across the active sweep frontier
    float distToEdge = abs(qt_TexCoord0.x - edge);
    float leadGlow = exp(-pow(distToEdge / max(f * 1.15, 0.04), 2.0)) * ubuf.glowBoost * sin(p * 3.14159265);

    vec4 baseCol = mix(ubuf.unsungColor, ubuf.activeColor, fill);
    vec3 rgb = clamp(baseCol.rgb + ubuf.glowColor.rgb * leadGlow * 0.45, 0.0, 1.0);
    float outAlpha = clamp(a * baseCol.a * ubuf.qt_Opacity, 0.0, 1.0);

    fragColor = vec4(rgb * outAlpha, outAlpha);
}
