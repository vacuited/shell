#version 440

layout(location = 0) in vec4 qt_VertexPosition;
layout(location = 1) in vec2 qt_VertexTexCoord;

layout(location = 0) out vec2 qt_TexCoord0;

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

void main() {
    gl_Position = qt_Matrix * qt_VertexPosition;
    qt_TexCoord0 = qt_VertexTexCoord;
}
