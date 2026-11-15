#version 450

// Widget-canvas arrange grid: crisp tile cells every gridSize px,
// accented major guide lines every 6 cells (144px widget base unit),
// and intersection dots for accurate manual alignment. One fullscreen GPU pass;
// canvas resizes repaint free.

layout(location = 0) in vec2 qt_TexCoord0;
layout(location = 0) out vec4 fragColor;

layout(std140, binding = 0) uniform buf {
    mat4 qt_Matrix;
    float qt_Opacity;
    float widthPx;
    float heightPx;
    float gridSize;
    vec4 lineCol;
    vec4 dotCol;
    vec4 majorCol;
} ubuf;

void main() {
    // Pixel-center coords: grid features land mid-pixel, so 1px lines stay crisp
    vec2 px = qt_TexCoord0 * vec2(ubuf.widthPx, ubuf.heightPx) + vec2(0.5);

    // Minor tile cell lines (every gridSize px)
    vec2 gf = fract(px / ubuf.gridSize);
    vec2 cellDist = min(gf, 1.0 - gf) * ubuf.gridSize;
    float minorDist = min(cellDist.x, cellDist.y);
    float minorMask = 1.0 - smoothstep(0.0, 1.0, minorDist);

    // Major guide lines every 6 cells (144px = 6 * 24px widget base unit)
    float majorStep = ubuf.gridSize * 6.0;
    vec2 mf = fract(px / majorStep);
    vec2 majorDist = min(mf, 1.0 - mf) * majorStep;
    float majorMask = 1.0 - smoothstep(0.0, 1.2, min(majorDist.x, majorDist.y));

    // Intersection dots on every cell corner
    float dotMask = 1.0 - smoothstep(0.5, 1.6, length(cellDist));

    // Premultiplied over: minor lines, major lines, then intersection dots
    vec4 linePx = ubuf.lineCol * minorMask * ubuf.qt_Opacity;
    vec4 majorPx = ubuf.majorCol * majorMask * ubuf.qt_Opacity;
    vec4 combinedLine = majorPx + linePx * (1.0 - majorPx.a);

    vec4 dotPx = ubuf.dotCol * dotMask * ubuf.qt_Opacity;
    fragColor = dotPx + combinedLine * (1.0 - dotPx.a);
}
