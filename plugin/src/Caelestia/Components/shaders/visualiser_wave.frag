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
    float t = clamp(mix(uFreq, hNorm, 0.45), 0.0, 1.0);
    return t < 0.5 ? mix(c1, c2, t * 2.0) : mix(c2, c3, (t - 0.5) * 2.0);
}

void main() {
    float w = dims.x;
    float h = dims.y;
    int barCount = int(params0.x + 0.5);
    if (qt_Opacity <= 0.001 || barCount <= 0 || w <= 0.0 || h <= 0.0) {
        fragColor = vec4(0.0);
        return;
    }

    float px = qt_TexCoord0.x * w;
    float py = qt_TexCoord0.y * h;
    float dpr = max(dims.z, 1.0);
    float time = dims.w;
    int edge = int(params1.x + 0.5);
    bool isFull = params1.y > 0.5;
    bool mirrored = params1.z > 0.5;
    float splitGap = params1.w;
    float heightScale = params0.w;
    float glowAmt = params2.y;
    float beatEnergy = params2.z;
    float idleFactor = params2.w;

    float waveLayers = clamp(styleOpts.x, 1.0, 3.0);
    float fillStrength = clamp(styleOpts.y, 0.1, 0.95);
    float crestThick = clamp(styleOpts.z, 0.5, 6.0);

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
    if (mirrored && edge != 4) {
        float baseline = maxReach * 0.5;
        localOrtho = abs(distEdge - baseline);
        maxReach = baseline;
    } else if (mirrored && edge == 4) {
        maxReach *= 0.5;
    }

    if (localOrtho > maxReach + 32.0 || localOrtho < -32.0) {
        fragColor = vec4(0.0);
        return;
    }

    float uSpan = clamp(spanPos / max(spanLen, 1.0), 0.0, 1.0);
    float uFreq = uSpan;
    float wingMask = 1.0;
    if (!isFull) {
        float halfGap = splitGap * 0.5;
        float distCenter = abs(uSpan - 0.5);
        if (distCenter < halfGap) {
            fragColor = vec4(0.0);
            return;
        }
        uFreq = clamp((distCenter - halfGap) / max(0.5 - halfGap, 0.01), 0.0, 1.0);
        wingMask = smoothstep(halfGap, halfGap + 0.04, distCenter);
    }

    int countInt = int(waveLayers + 0.5);
    vec3 accumRgb = vec3(0.0);
    float accumWeight = 0.0;
    float totalAlpha = 0.0;
    float baseAA = smoothstep(-1.0 / dpr, 0.0, localOrtho);
    float negHaloFade = smoothstep(-32.0, 0.0, localOrtho);

    for (int idx = 0; idx < 3; ++idx) {
        if (idx >= countInt)
            break;
        float fi = float(idx);
        float layerU = clamp(uFreq * (1.0 - 0.08 * fi) + 0.03 * fi, 0.0, 1.0);
        vec4 s = sampleSmooth(layerU, barCount);
        float idleSine = 0.06 + 0.04 * sin(uSpan * 8.0 + time * (1.2 + 0.35 * fi) + fi * 1.4) + 0.025 * cos(uSpan * 15.0 - time * 0.9);
        float val = mix(s.r * (1.0 - 0.14 * fi), idleSine, idleFactor);
        val = clamp(val * (1.0 + 0.12 * beatEnergy * (1.0 - 0.25 * fi)), 0.0, 1.0) * wingMask;

        float waveY = val * maxReach;
        float d = localOrtho - waveY;

        float bodyFill = (1.0 - smoothstep(-1.0 / dpr, 1.0 / dpr, d)) * baseAA * (fillStrength * (0.85 - 0.2 * fi));
        float crest = 1.0 - smoothstep(0.0, crestThick + 1.0 / dpr, abs(d));
        float halo = glowAmt > 0.01 ? exp(-abs(d) / (6.0 + 18.0 * glowAmt)) * glowAmt * (0.35 + 0.45 * val) * negHaloFade : 0.0;

        float hNorm = clamp(localOrtho / max(waveY, 1.0), 0.0, 1.0);
        vec3 col = evalGradient(layerU, hNorm, val);
        if (idx == 1) col = mix(col, secondaryColor.rgb, 0.35);
        if (idx == 2) col = mix(col, accentColor.rgb, 0.45);

        float layerA = clamp(max(bodyFill * mix(0.35, 1.0, hNorm), max(crest, halo)), 0.0, 1.0);
        vec3 layerCol = col + accentColor.rgb * s.b * 0.25;
        float wLayer = layerA * (1.0 - totalAlpha * 0.45);
        accumRgb += layerCol * wLayer;
        accumWeight += wLayer;
        totalAlpha = clamp(totalAlpha + layerA * (1.0 - totalAlpha * 0.5), 0.0, 1.0);
    }

    vec3 finalRgb = accumWeight > 0.001 ? clamp(accumRgb / accumWeight, 0.0, 1.0) : primaryColor.rgb;
    float baseA = max(primaryColor.a, max(secondaryColor.a, accentColor.a));
    float outAlpha = clamp(totalAlpha * baseA, 0.0, 1.0);
    fragColor = vec4(finalRgb * outAlpha, outAlpha) * qt_Opacity;
}
