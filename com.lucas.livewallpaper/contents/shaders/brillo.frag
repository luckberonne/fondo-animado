#version 440
// Brillo: una franja de luz que barre la capa en diagonal.
layout(location = 0) in vec2 qt_TexCoord0;
layout(location = 0) out vec4 fragColor;
layout(std140, binding = 0) uniform buf {
    mat4 qt_Matrix;
    float qt_Opacity;
    float time;
    float strength;
    float speed;
    float horizon;
};
layout(binding = 1) uniform sampler2D source;

void main() {
    vec2 uv = qt_TexCoord0;
    vec4 c = texture(source, uv);
    float pos = uv.x + uv.y * 0.4;
    float sweep = fract(time * speed * 0.05) * 2.6 - 0.6;
    float band = exp(-pow((pos - sweep) * 5.0, 2.0));
    fragColor = vec4(c.rgb + c.a * strength * band * vec3(1.0, 0.95, 0.85), c.a) * qt_Opacity;
}
