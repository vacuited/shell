#version 440

layout(location = 0) in vec2 qt_TexCoord0;
layout(location = 0) out vec4 fragColor;

layout(binding = 1) uniform sampler2D dataTex;

layout(std140, binding = 0) uniform buf {
    mat4 qt_Matrix;
    float qt_Opacity;
    float _pad0;
    float _pad1;
    float _pad2;
    vec4 dims;
    vec4 params0;
    vec4 params1;
    vec4 params2;
    vec4 styleOpts;
    vec4 primaryColor;
    vec4 secondaryColor;
    vec4 accentColor;
};

vec4 sampleData(int i, int barCount) {
    int ci = clamp(i, 0, max(barCount - 1, 0));
    float u = (float(ci) + 0.5) / float(max(barCount, 1));
    vec4 t = texture(dataTex, vec2(u, 0.5));
    float val = clamp(t.r * (256.0 / 255.0) + t.g * (1.0 / 255.0), 0.0, 1.0);
    return vec4(val, t.b, t.a, 1.0);
}

vec4 sampleSmooth(float uFreq, int barCount) {
    float fIdx = clamp(uFreq, 0.0, 1.0) * float(max(barCount - 1, 0));
    int i1 = int(floor(fIdx));
    float f = fract(fIdx);
    vec4 s0 = sampleData(i1 - 1, barCount);
    vec4 s1 = sampleData(i1, barCount);
    vec4 s2 = sampleData(i1 + 1, barCount);
    vec4 s3 = sampleData(i1 + 2, barCount);
    float f2 = f * f;
    float f3 = f2 * f;
    vec4 cat = 0.5 * ((2.0 * s1) + (-s0 + s2) * f + (2.0 * s0 - 5.0 * s1 + 4.0 * s2 - s3) * f2 + (-s0 + 3.0 * s1 - 3.0 * s2 + s3) * f3);
    return clamp(cat, 0.0, 1.0);
}

float hash21(vec2 p) {
    p = fract(p * vec2(123.34, 456.21));
    p += dot(p, p + 45.32);
    return fract(p.x * p.y);
}

float noise(vec2 p) {
    vec2 i = floor(p);
    vec2 f = fract(p);
    vec2 u = f * f * (3.0 - 2.0 * f);
    float a = hash21(i);
    float b = hash21(i + vec2(1.0, 0.0));
    float c = hash21(i + vec2(0.0, 1.0));
    float d = hash21(i + vec2(1.0, 1.0));
    return mix(mix(a, b, u.x), mix(c, d, u.x), u.y);
}

float fbm(vec2 p) {
    float v = 0.0;
    float amp = 0.5;
    for (int k = 0; k < 4; ++k) {
        v += amp * noise(p);
        p = p * 2.03 + vec2(13.1, 7.7);
        amp *= 0.5;
    }
    return v;
}

vec3 evalGradient(float uFreq, float hNorm, float ampVal) {
    int mode = int(params2.x + 0.5);
    vec3 c1 = primaryColor.rgb;
    vec3 c2 = secondaryColor.rgb;
    vec3 c3 = accentColor.rgb;
    if (mode == 1) {
        return mix(c2, c1, clamp(hNorm, 0.0, 1.0));
    }
    if (mode == 2) {
        return mix(c1, c2, clamp(uFreq, 0.0, 1.0));
    }
    if (mode == 3) {
        vec3 mid = mix(c2, c1, smoothstep(0.0, 0.65, ampVal));
        return mix(mid, c3, smoothstep(0.55, 1.0, ampVal));
    }
    float t = clamp(mix(uFreq, hNorm, 0.4), 0.0, 1.0);
    return t < 0.5 ? mix(c1, c2, t * 2.0) : mix(c2, c3, (t - 0.5) * 2.0);
}

void main() {
    float w = dims.x;
    float h = dims.y;
    if (qt_Opacity <= 0.001 || w <= 0.0 || h <= 0.0) {
        fragColor = vec4(0.0);
        return;
    }

    float px = qt_TexCoord0.x * w;
    float py = qt_TexCoord0.y * h;
    int edge = int(params1.x + 0.5);
    bool mirrored = params1.z > 0.5;
    float heightScale = params0.w;

    float spanPos = px;
    float spanLen = w;
    float distEdge = h - py;
    float orthoLen = h;
    if (edge == 1) {
        distEdge = py;
    } else if (edge == 2) {
        spanPos = py;
        spanLen = h;
        distEdge = px;
        orthoLen = w;
    } else if (edge == 3) {
        spanPos = py;
        spanLen = h;
        distEdge = w - px;
        orthoLen = w;
    } else if (edge == 4) {
        distEdge = mirrored ? abs(py - h * 0.5) : (h * 0.5 - py);
    }

    float maxReach = orthoLen * heightScale;
    float localOrtho = distEdge;
    float reach = maxReach;
    if (edge == 4 && mirrored) {
        reach = maxReach * 0.5;
    } else if (edge != 4 && mirrored) {
        float baseline = maxReach * 0.5;
        localOrtho = abs(distEdge - baseline);
        reach = baseline;
    }

    float uSpan = clamp(spanPos / max(spanLen, 1.0), 0.0, 1.0);
    bool isFull = params1.y > 0.5;
    float splitMask = 1.0;
    float uFreq = uSpan;
    if (!isFull) {
        float halfGap = params1.w * 0.5;
        float distCenter = abs(uSpan - 0.5);
        uFreq = clamp((distCenter - halfGap) / max(0.5 - halfGap, 0.01), 0.0, 1.0);
        splitMask = smoothstep(0.0, halfGap + 0.08, distCenter);
    }

    int barCount = int(params0.x + 0.5);
    vec4 s = sampleSmooth(uFreq, barCount);
    float specVal = s.r;
    float sparkVal = s.b;

    float time = dims.w;
    float layers = clamp(styleOpts.x, 2.0, 4.0);
    float speed = styleOpts.y;
    float shimmer = styleOpts.z;
    float glowAmt = params2.y;
    float beatEnergy = params2.z;
    float idleFactor = params2.w;

    float rawYNorm = localOrtho / max(reach, 1.0);
    if (rawYNorm > 1.35 || localOrtho < -20.0) {
        fragColor = vec4(0.0);
        return;
    }
    float yNorm = clamp(rawYNorm, -0.1, 1.5);
    float negFade = smoothstep(-20.0, 0.0, localOrtho);

    vec3 accumRgb = vec3(0.0);
    float accumAlpha = 0.0;
    float accumWeight = 0.0;
    int layerCount = int(layers + 0.5);

    for (int idx = 0; idx < 4; ++idx) {
        if (idx >= layerCount)
            break;
        float fi = float(idx);
        float layerFrac = fi / max(layers - 1.0, 1.0);

        float drift = time * speed * (0.14 + 0.05 * fi) * (idx % 2 == 0 ? 1.0 : -0.8);
        float n1 = fbm(vec2(uSpan * (2.6 + fi * 0.9) + drift, fi * 3.17 + time * 0.08));
        float n2 = fbm(vec2(uSpan * (5.2 + fi * 1.4) - drift * 1.3, fi * 7.41 + time * 0.12));

        // Base flowing ribbon center height (northern-lights curtains anchored cleanly at baseline)
        float waveBase = 0.12 + 0.16 * n1 + 0.09 * sin(uSpan * 6.28318 * (1.2 + 0.4 * fi) + time * speed * 0.5 + fi);
        float audioLift = mix(specVal * (0.58 + 0.25 * beatEnergy), 0.18 * n2, idleFactor * 0.85);
        float curtainBottom = idx == 0 ? (0.015 * n1) : (waveBase * (0.18 + 0.26 * layerFrac));
        float curtainPeak = clamp(curtainBottom + 0.24 + audioLift * (0.72 + 0.15 * n2), 0.15, 0.96);

        // Layer 0 stays grounded to yNorm = 0; upper curtains form floating folds
        float lowerEdge = idx == 0 ? smoothstep(-0.02, 0.025, yNorm) : smoothstep(curtainBottom - 0.07, curtainBottom + 0.05, yNorm);
        float upperFade = exp(-max(0.0, yNorm - curtainBottom) / max(0.16, (curtainPeak - curtainBottom) * 0.58));
        float ribbon = lowerEdge * upperFade * (1.0 - smoothstep(0.56, 1.0, yNorm)) * negFade;

        // Vertical aurora curtain rays
        float rayNoise = noise(vec2(uSpan * (28.0 + fi * 11.0) + drift * 2.2, yNorm * 1.8 + fi * 4.0));
        float rays = mix(1.0, 0.45 + 0.75 * rayNoise, 0.55 + 0.35 * shimmer);

        float layerIntensity = ribbon * rays * (0.55 + 0.45 * (1.0 - layerFrac * 0.35));
        layerIntensity *= (1.0 + sparkVal * 0.40 + beatEnergy * 0.20) * splitMask;

        vec3 col = evalGradient(fract(uFreq + layerFrac * 0.28 + n1 * 0.18), clamp(yNorm, 0.0, 1.0), specVal);
        // Tinted luminous core near lower curtain fold (preserve M3 saturation, avoid white clipping)
        float coreCrest = exp(-pow((yNorm - curtainBottom - 0.035) * 9.0, 2.0)) * (0.35 + 0.65 * shimmer);
        vec3 crestTint = mix(mix(primaryColor.rgb, accentColor.rgb, 0.55), vec3(1.0), 0.18 * glowAmt);
        col = mix(col, max(col, crestTint), coreCrest * (0.28 + 0.32 * glowAmt));

        accumRgb += col * layerIntensity;
        accumWeight += layerIntensity;
        accumAlpha += layerIntensity * 0.54;
    }

    float maxColorAlpha = max(primaryColor.a, max(secondaryColor.a, accentColor.a));
    float baseAlpha = clamp(accumAlpha, 0.0, 1.0) * maxColorAlpha;
    // Soft horizon glow anchored down to yNorm = 0
    float horizonGlow = exp(-max(yNorm, 0.0) * 4.5) * negFade * (0.22 + 0.28 * specVal + 0.18 * beatEnergy) * (0.45 + 0.55 * glowAmt) * splitMask * (1.0 - smoothstep(0.56, 1.0, yNorm));
    baseAlpha = clamp(baseAlpha + horizonGlow * primaryColor.a * 0.45, 0.0, 1.0);
    vec3 finalRgb = accumWeight > 0.001 ? (accumRgb / max(accumWeight, 0.45)) : primaryColor.rgb;
    finalRgb = clamp(mix(finalRgb, finalRgb + secondaryColor.rgb * 0.25, horizonGlow), 0.0, 1.0);

    fragColor = vec4(finalRgb * baseAlpha, baseAlpha) * qt_Opacity;
}
