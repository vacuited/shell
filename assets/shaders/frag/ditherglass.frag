#version 450

// Custom Liquid Frosted Glass Shader:
// Single-pass high-quality Golden-Angle Fermat spiral bokeh blur with 4x4 Bayer
// micro-dither, real-time screen UV tracking, SDF rounded-box cutout, and
// luminous frosted rim glow (lighter than the blur).

layout(location = 0) in vec2 qt_TexCoord0;
layout(location = 0) out vec4 fragColor;

layout(std140, binding = 0) uniform buf {
    mat4 qt_Matrix;
    float qt_Opacity;
    float itemWidth;
    float itemHeight;
    float cornerRadius;
    vec2 uvOffset;
    vec2 uvScale;
    float blurRadius;
    float ditherStrength;
    float frostOpacity;
    float brightnessBoost;
    float saturation;
    float rimGlow;
    float pad0;
    float pad1;
    vec4 tintColor;
    vec4 highlightColor;
} ubuf;

layout(binding = 1) uniform sampler2D sourceTex;

float bayer4(vec2 p) {
    vec2 p4 = mod(floor(p), 4.0);
    vec4 row = (p4.y < 1.0) ? vec4(0.0, 8.0, 2.0, 10.0) :
               (p4.y < 2.0) ? vec4(12.0, 4.0, 14.0, 6.0) :
               (p4.y < 3.0) ? vec4(3.0, 11.0, 1.0, 9.0) :
                              vec4(15.0, 7.0, 13.0, 5.0);
    float v = (p4.x < 1.0) ? row.x :
              (p4.x < 2.0) ? row.y :
              (p4.x < 3.0) ? row.z : row.w;
    return v / 16.0;
}

// 2D Signed Distance Field for Rounded Box
float sdRoundedBox(vec2 p, vec2 b, float r) {
    vec2 q = abs(p) - b + vec2(r);
    return min(max(q.x, q.y), 0.0) + length(max(q, vec2(0.0))) - r;
}

void main() {
    vec2 fragCoord = vec2(qt_TexCoord0.x * ubuf.itemWidth, qt_TexCoord0.y * ubuf.itemHeight);
    vec2 halfSize = vec2(ubuf.itemWidth * 0.5, ubuf.itemHeight * 0.5);
    vec2 p = fragCoord - halfSize;

    // cornerRadius < 0 disables rounded-box clipping and rim for external MaterialShape masks.
    bool shapedMask = ubuf.cornerRadius < 0.0;
    float dist = -10.0;
    float shapeAlpha = 1.0;
    if (!shapedMask) {
        float radius = clamp(ubuf.cornerRadius, 0.0, min(halfSize.x, halfSize.y));
        dist = sdRoundedBox(p, halfSize, radius);
        shapeAlpha = 1.0 - smoothstep(-0.75, 0.75, dist);
        if (shapeAlpha <= 0.001) {
            fragColor = vec4(0.0);
            return;
        }
    }

    float bayerVal = bayer4(fragCoord);

    // 2. Calculate center screen UV in captured wallpaper texture
    vec2 centerUv = ubuf.uvOffset + qt_TexCoord0 * ubuf.uvScale;

    // 3. Aspect-corrected Golden-Angle Fermat Spiral Bokeh Blur Kernel (28 taps)
    float aspect = max(0.1, ubuf.pad0 > 0.05 ? ubuf.pad0 : 1.0);
    vec4 accum = vec4(0.0);
    float totalWeight = 0.0;
    float jitterAngle = bayerVal * 6.2831853;
    float blurRad = max(ubuf.blurRadius, 0.001);

    const int SAMPLES = 28;
    for (int i = 0; i < SAMPLES; i++) {
        float frac = (float(i) + 0.5) / float(SAMPLES);
        float r = blurRad * sqrt(frac);
        float theta = float(i) * 2.39996323 + jitterAngle;

        vec2 sampleOffset = vec2(cos(theta) / aspect, sin(theta)) * r;
        vec2 sampleUv = clamp(centerUv + sampleOffset, vec2(0.002), vec2(0.998));

        float weight = exp(-1.7 * frac);
        accum += texture(sourceTex, sampleUv) * weight;
        totalWeight += weight;
    }

    vec4 blurred = accum / totalWeight;

    // 4. Color enhancement (Saturation & Vibrancy)
    float luma = dot(blurred.rgb, vec3(0.299, 0.587, 0.114));
    vec3 vibrant = mix(vec3(luma), blurred.rgb, ubuf.saturation);

    // 5. Luminous frosted glass glaze & brightness lift
    vec3 frosted = mix(vibrant, ubuf.tintColor.rgb, ubuf.frostOpacity);
    frosted = clamp(frosted + vec3(ubuf.brightnessBoost), 0.0, 1.0);

    // 6. Luminous Frosted Rim Glow (rectangular cards) + soft top glare
    float rim = shapedMask ? 0.0 : (smoothstep(-2.5, -0.5, dist) * (1.0 - smoothstep(-0.5, 0.5, dist)));
    float topGlare = (1.0 - smoothstep(0.0, 0.40, qt_TexCoord0.y)) * 0.09;

    vec3 specular = ubuf.highlightColor.rgb * (topGlare + rim * ubuf.rimGlow);

    // 7. Micro-dither pattern (-0.5 to 0.5) for silky smooth frosted finish
    float dither = (bayerVal - 0.5) * ubuf.ditherStrength;

    vec3 finalRgb = clamp(frosted + specular + vec3(dither), 0.0, 1.0);
    float alpha = clamp(shapeAlpha * ubuf.qt_Opacity, 0.0, 1.0);

    // Premultiplied alpha output
    fragColor = vec4(finalRgb * alpha, alpha);
}
