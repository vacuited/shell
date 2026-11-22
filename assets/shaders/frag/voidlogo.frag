#version 450

// Scheme-adaptive crescent corona + interactive gravitational shockwave ripple
// rendered behind the Vacuited Crescent Moon in VoidLogo.qml.

layout(location = 0) in vec2 qt_TexCoord0;
layout(location = 0) out vec4 fragColor;

layout(std140, binding = 0) uniform buf {
    mat4 qt_Matrix;
    float qt_Opacity;
    float time;
    float intro;
    float ripple;
    float hover;
    float lightMode;
    vec2 pointer;
    vec4 auraColor;
} ubuf;

const float PI = 3.14159265;

void main() {
    vec2 p = (qt_TexCoord0 - vec2(0.5)) * 2.0;
    float r = length(p) + 1e-5;

    float introEnv = smoothstep(0.05, 0.70, clamp(ubuf.intro, 0.0, 1.0));
    float breath = 1.0 + 0.09 * sin(ubuf.time * 1.15);
    float hoverBoost = 1.0 + 0.42 * ubuf.hover;

    // C-shaped crescent corona cradling the left/outer arc of the moon
    vec2 pm = p - vec2(-0.04, 0.02);
    float rm = length(pm) + 1e-5;
    float crescentWeight = smoothstep(0.85, -0.35, pm.x / rm);
    float arcGlow = exp(-pow((rm - 0.50) / (0.22 * breath), 2.0)) * (0.42 + 0.58 * crescentWeight) * 0.26;
    float coreGlow = exp(-pow(rm / (0.48 * breath), 2.0)) * 0.13;

    // Subtle cursor-following moonlight sheen on hover
    float cursorSheen = exp(-pow(length(p - ubuf.pointer * 0.34) / 0.44, 2.0)) * 0.22 * ubuf.hover;

    // Interactive gravitational shockwave ring on click / surge()
    float rippleGlow = 0.0;
    if (ubuf.ripple > 0.001 && ubuf.ripple < 0.999) {
        float rWave = mix(0.16, 0.88, ubuf.ripple);
        float wEnv = sin(ubuf.ripple * PI);
        rippleGlow = exp(-pow((r - rWave) / 0.042, 2.0)) * wEnv * 0.68;
    }

    float edgeFade = smoothstep(0.96, 0.50, r);
    float baseLevel = (arcGlow + coreGlow) * hoverBoost * introEnv * edgeFade;
    float hotLevel = (cursorSheen + rippleGlow) * introEnv * edgeFade;
    float lightLevel = baseLevel + hotLevel;

    vec3 baseTint = ubuf.auraColor.rgb;
    vec3 hotTint = mix(baseTint, vec3(1.0), 0.38);
    float hotMix = clamp(hotLevel / (lightLevel + 1e-4), 0.0, 1.0);

    vec3 outCol;
    float outAlpha;
    if (ubuf.lightMode < 0.5) {
        outCol = mix(baseTint, hotTint, hotMix);
        outAlpha = clamp(lightLevel, 0.0, 0.88);
    } else {
        outCol = baseTint * 0.75;
        outAlpha = clamp(lightLevel * 0.48, 0.0, 0.44);
    }

    fragColor = vec4(outCol * outAlpha, outAlpha) * ubuf.qt_Opacity;
}
