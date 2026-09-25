#version 440
// Explosión: mueve solo lo que la máscara marca como libre (esquirlas, humo, salpicaduras) y deja quieto lo demás.
// La máscara es blanca donde algo debe quedarse inmóvil (los personajes) y negra donde se mueve.
layout(location = 0) in vec2 qt_TexCoord0;
layout(location = 0) out vec4 fragColor;
layout(std140, binding = 0) uniform buf {
    mat4 qt_Matrix;
    float qt_Opacity;
    float time;
    float strength;     // desplazamiento máximo, en fracción de la imagen (~0.012)
    float speed;
    float cx;           // centro de la explosión (0..1); las esquirlas «respiran» hacia/desde ahí
    float cy;
};
layout(binding = 1) uniform sampler2D source;
layout(binding = 2) uniform sampler2D mask;

float hash(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }
float vnoise(vec2 p) {
    vec2 i = floor(p), f = fract(p);
    f = f * f * (3.0 - 2.0 * f);
    return mix(mix(hash(i), hash(i + vec2(1, 0)), f.x), mix(hash(i + vec2(0, 1)), hash(i + vec2(1, 1)), f.x), f.y);
}

void main() {
    vec2 uv = qt_TexCoord0;
    float t = time * speed;
    float move = 1.0 - texture(mask, uv).r;

    // Flujo suave y lento (dos octavas de ruido), en una cuadrícula con la proporción de la imagen.
    vec2 p = uv * vec2(9.0, 5.0);
    vec2 flow = vec2(vnoise(p + vec2(t * 0.20, 0.0)) + 0.5 * vnoise(p * 2.1 + vec2(0.0, t * 0.27)),
                     vnoise(p + vec2(7.3, 2.1 - t * 0.17)) + 0.5 * vnoise(p * 2.3 + vec2(-t * 0.23, 4.0))) - 0.75;

    // «Respiración» radial desde el centro: cada zona con su propia fase, así no se mueve todo a la vez.
    vec2 dir = uv - vec2(cx, cy);
    float phase = vnoise(p * 0.6) * 6.28;
    vec2 breathe = normalize(dir + 1e-4) * sin(t * 0.9 + phase) * 0.6;

    vec2 offset = (flow * 1.4 + breathe) * strength * move;
    vec4 c = texture(source, uv + offset);

    // Destellos: los brillos de las esquirlas titilan.
    float luma = dot(c.rgb, vec3(0.299, 0.587, 0.114));
    float hi = smoothstep(0.70, 0.95, luma);
    float tw = 0.5 + 0.5 * sin(t * 2.6 + vnoise(uv * 40.0) * 30.0);
    c.rgb += hi * tw * 0.20 * move;

    fragColor = vec4(c.rgb, c.a) * qt_Opacity;
}
