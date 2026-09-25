#version 440
// Agua: ondulación horizontal que crece con la distancia al horizonte, más destellos.
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
    float d = clamp((uv.y - horizon) / max(1.0 - horizon, 0.001), 0.0, 1.0);
    float amp = strength * (0.15 + d);
    float t = time * speed;
    float wx = sin(uv.y * 90.0 + t * 1.7) * 0.6 + sin(uv.y * 47.0 - t * 1.1 + uv.x * 6.0) * 0.4;
    float wy = sin(uv.x * 60.0 + t * 1.3) * 0.5;
    vec4 c = texture(source, uv + vec2(wx * amp, wy * amp * 0.25));
    float glint = pow(max(0.0, sin(uv.x * 420.0 + uv.y * 30.0 + t * 2.3) * sin(uv.y * 260.0 - t * 1.6)), 10.0) * d * 0.16;
    fragColor = vec4(c.rgb + glint * c.a, c.a) * qt_Opacity;
}
