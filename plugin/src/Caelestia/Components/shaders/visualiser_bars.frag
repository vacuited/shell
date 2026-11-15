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

float sdRoundBox(vec2 p, vec2 b, float r) {
    vec2 q = abs(p) - b + r;
    return min(max(q.x, q.y), 0.0) + length(max(q, 0.0)) - r;
}

void main() {
    float w = dims.x;
    float h = dims.y;
    int barCount = int(params0.x + 0.5);
    if (barCount <= 0 || w <= 0.0 || h <= 0.0) {
        fragColor = vec4(0.0);
        return;
    }

    float px = qt_TexCoord0.x * w;
    float py = qt_TexCoord0.y * h;
    float dpr = max(dims.z, 1.0);
    float time = dims.w;
    float rounding = params0.y;
    float spacing = params0.z;
    float heightScale = params0.w;
    int edge = int(params1.x + 0.5);
    bool isFull = params1.y > 0.5;
    bool mirrored = params1.z > 0.5;
    float splitGap = params1.w;
    float glowAmt = params2.y;
    float beatEnergy = params2.z;
    float idleFactor = params2.w;
    bool showPeakCaps = styleOpts.x > 0.5;

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
        distEdge = mirrored ? abs(py - h * 0.5) : max(0.0, h * 0.5 - py);
    }

    float maxBarH = orthoLen * heightScale;
    float localOrtho = distEdge;
    if (mirrored && edge != 4) {
        float baseline = maxBarH * 0.5;
        localOrtho = abs(distEdge - baseline);
        maxBarH = baseline;
    } else if (mirrored && edge == 4) {
        maxBarH *= 0.5;
    }

    if (localOrtho > maxBarH + 28.0) {
        fragColor = vec4(0.0);
        return;
    }

    float groupOffset = 0.0;
    float groupWidth = spanLen;
    bool reverse = false;

    if (!isFull) {
        float wingW = spanLen * (1.0 - splitGap) * 0.5;
        if (spanPos < wingW) {
            groupOffset = 0.0;
            groupWidth = wingW;
            reverse = true;
        } else if (spanPos >= spanLen - wingW) {
            groupOffset = spanLen - wingW;
            groupWidth = wingW;
            reverse = false;
        } else {
            fragColor = vec4(0.0);
            return;
        }
    }

    float safeSpacing = min(spacing, max(groupWidth / float(barCount) - 1.0, 0.0));
    float slotWidth = (groupWidth + safeSpacing) / float(barCount);
    float barWidth = max(1.0, slotWidth - safeSpacing);
    float localX = spanPos - groupOffset;
    int i = clamp(int(floor(localX / slotWidth)), 0, barCount - 1);
    int valueIndex = reverse ? (barCount - 1 - i) : i;
    float uFreq = float(valueIndex) / float(max(barCount - 1, 1));

    vec4 s = sampleData(valueIndex, barCount);
    float idleWave = 0.035 + 0.03 * sin(uFreq * 12.0 + time * 1.8) + 0.02 * cos(uFreq * 5.0 - time * 1.1);
    float val = mix(s.r, max(s.r, idleWave), idleFactor);
    float peakVal = mix(s.g, max(s.g, val), idleFactor);
    float spark = s.b;

    float barH = clamp(val * (1.0 + 0.08 * beatEnergy), 0.0, 1.0) * maxBarH;
    float barLeft = groupOffset + float(i) * slotWidth;
    float halfW = barWidth * 0.5;
    float cx = barLeft + halfW;

    float barAlpha = 0.0;
    float glowAlpha = 0.0;
    if (barH > 0.5) {
        float r = min(min(rounding, halfW), mirrored ? barH : barH * 0.99);
        float halfH = barH * 0.5;
        vec2 boxCenter = vec2(cx, halfH);
        vec2 p = vec2(spanPos, localOrtho) - boxCenter;
        float dist = sdRoundBox(p, vec2(halfW, halfH), r);
        // Flat baseline on non-mirrored bars
        if (!mirrored && localOrtho < r) {
            dist = max(abs(spanPos - cx) - halfW, -localOrtho);
        }
        barAlpha = clamp(0.5 - dist * dpr, 0.0, 1.0);
        if (glowAmt > 0.01) {
            glowAlpha = exp(-max(dist, 0.0) / (4.0 + 16.0 * glowAmt)) * glowAmt * (0.28 + 0.45 * val + 0.25 * beatEnergy);
        }
    }

    float capAlpha = 0.0;
    if (showPeakCaps && peakVal > 0.02) {
        float capH = clamp(barWidth * 0.28, 2.0, 4.5);
        float capY = clamp(peakVal * maxBarH, capH, maxBarH - capH * 0.5);
        float capDist = sdRoundBox(vec2(spanPos - cx, localOrtho - capY), vec2(halfW, capH * 0.5), min(halfW, capH * 0.5));
        capAlpha = clamp(0.5 - capDist * dpr, 0.0, 1.0);
    }

    float hNorm = clamp(localOrtho / max(maxBarH, 1.0), 0.0, 1.0);
    vec3 col = evalGradient(uFreq, hNorm, val);
    col += accentColor.rgb * spark * 0.35;

    float baseAlpha = max(primaryColor.a, secondaryColor.a);
    float bodyCoverage = clamp(max(barAlpha, glowAlpha), 0.0, 1.0);
    vec3 outRgb = mix(col, accentColor.rgb, capAlpha * 0.85);
    float outAlpha = clamp(max(bodyCoverage * baseAlpha, capAlpha * accentColor.a), 0.0, 1.0);

    fragColor = vec4(outRgb * outAlpha, outAlpha) * qt_Opacity;
}
