#version 440
// Viento: balanceo horizontal que crece hacia arriba (follaje, pasto, telas).
layout(location = 0) in vec2 qt_TexCoord0;
layout(location = 0) out vec4 fragColor;
layout(std140, binding = 0) uniform buf {
    mat4 qt_Matrix;
    float qt_Opacity;
    float time;
    float strength;
    float speed;
    float horizon;      // altura (0 arriba, 1 abajo) donde la capa está anclada y no se mueve
};
layout(binding = 1) uniform sampler2D source;

void main() {
    vec2 uv = qt_TexCoord0;
    float free_ = clamp((horizon - uv.y) / max(horizon, 0.001), 0.0, 1.0);
    float t = time * speed;
    float sway = sin(t * 1.3 + uv.y * 4.0) * 0.7 + sin(t * 2.1 + uv.x * 7.0) * 0.3;
    fragColor = texture(source, uv + vec2(sway * strength * free_ * free_, 0.0)) * qt_Opacity;
}
