#version 440
// Ojos: resplandor que late sobre las zonas que marca la máscara. Se suma a lo que hay debajo (alfa 0 = aditivo).
layout(location = 0) in vec2 qt_TexCoord0;
layout(location = 0) out vec4 fragColor;
layout(std140, binding = 0) uniform buf {
    mat4 qt_Matrix;
    float qt_Opacity;
    float time;
    float strength;     // intensidad del brillo (0..2)
    float speed;
    float cr;           // color del resplandor
    float cg;
    float cb;
};
layout(binding = 1) uniform sampler2D source;
layout(binding = 2) uniform sampler2D mask;

void main() {
    vec2 uv = qt_TexCoord0;
    float t = time * speed;
    float m = texture(mask, uv).r;
    // Latido lento con un parpadeo leve; nunca se apaga del todo.
    float pulse = 0.55 + 0.32 * sin(t * 1.3) + 0.10 * sin(t * 3.9 + 1.0) + 0.03 * sin(t * 11.0);
    vec3 col = vec3(cr, cg, cb);
    vec3 add = col * m * pulse * strength * 0.75;
    // Cuando el latido está alto, el centro se calienta hacia el blanco.
    add += vec3(1.0, 0.82, 0.88) * pow(m, 2.5) * max(pulse - 0.72, 0.0) * strength * 1.1;
    fragColor = vec4(add, 0.0) * qt_Opacity;
}
