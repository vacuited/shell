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
    int i0 = int(floor(fIdx));
    int i1 = min(i0 + 1, max(barCount - 1, 0));
    float f = fract(fIdx);
    return mix(sampleData(i0, barCount), sampleData(i1, barCount), smoothstep(0.0, 1.0, f));
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
    float t = clamp(mix(uFreq, hNorm, 0.35), 0.0, 1.0);
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
    float time = dims.w;
    float heightScale = params0.w;
    int edge = int(params1.x + 0.5);
    bool isFull = params1.y > 0.5;
    bool mirrored = params1.z > 0.5;
    float splitGap = params1.w;
    float glowAmt = params2.y;
    float beatEnergy = params2.z;
    float idleFactor = params2.w;
    float spread = clamp(styleOpts.x, 0.25, 1.5);
    bool allEdges = styleOpts.y > 0.5;

    float uFreq = clamp(qt_TexCoord0.x, 0.0, 1.0);
    float normDist = 1.0;

    if (allEdges) {
        float dx = min(px, w - px) / max(w * heightScale * 0.5 * spread, 1.0);
        float dy = min(py, h - py) / max(h * heightScale * 0.5 * spread, 1.0);
        normDist = min(dx, dy);
        vec2 centered = qt_TexCoord0 - 0.5;
        float angle = dot(centered, centered) > 1e-8 ? atan(abs(centered.y), centered.x) : 0.0;
        uFreq = clamp(angle / 3.14159265, 0.0, 1.0);
    } else {
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
            distEdge = abs(py - h * 0.5);
        }

        float uSpan = clamp(spanPos / max(spanLen, 1.0), 0.0, 1.0);
        if (!isFull) {
            float halfGap = splitGap * 0.5;
            uFreq = clamp((abs(uSpan - 0.5) - halfGap) / max(0.5 - halfGap, 0.01), 0.0, 1.0);
        } else {
            uFreq = uSpan;
        }
        normDist = distEdge / max(orthoLen * heightScale * spread, 1.0);
    }

    vec4 s = sampleSmooth(uFreq, barCount);
    float breath = 0.22 + 0.14 * sin(time * 1.1 + uFreq * 6.28318) + 0.08 * cos(time * 0.7 - uFreq * 9.42);
    float energy = mix(s.r, max(s.r, breath), idleFactor);
    float spark = s.b;

    float intensity = exp(-normDist * (2.6 - 0.9 * energy)) * (0.28 + 0.72 * energy + 0.35 * beatEnergy);
    intensity *= (0.75 + 0.5 * glowAmt);
    intensity += exp(-normDist * 6.0) * spark * 0.25;

    float baseA = max(primaryColor.a, max(secondaryColor.a, accentColor.a));
    float outAlpha = clamp(intensity * baseA, 0.0, 1.0);
    vec3 col = evalGradient(uFreq, clamp(1.0 - normDist, 0.0, 1.0), energy);

    fragColor = vec4(col * outAlpha, outAlpha) * qt_Opacity;
}
