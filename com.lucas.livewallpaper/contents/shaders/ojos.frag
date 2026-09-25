#version 440
// Ojos: resplandor de neón sobre las zonas que marca la máscara. Se suma a lo que hay debajo (alfa 0 = aditivo).
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

// Hash solo aritmético (Hoskins): fract(sin(x) * 43758) no es portable entre CPU y GPU.
float hash(float p) { p = fract(p * 0.1031); p *= p + 33.33; p *= p + p; return fract(p); }

// Neón: encendido fijo con un zumbido casi imperceptible y, cada tanto, una atenuación lenta con oscilaciones suaves
// (unos 3 cambios por segundo, sin saltos bruscos) que termina con una recuperación gradual. El momento y la duración
// varían de un ciclo a otro. `time` está en segundos reales (el proyecto fija speed = 1 / velocidad).
float neon(float t) {
    const float CICLO = 8.0;
    float k = floor(t / CICLO);
    float ph = t - k * CICLO;                              // segundo dentro del ciclo
    float inicio = 4.0 + 2.5 * hash(k + 3.0);             // cuándo empieza
    float dur = 1.8 + 1.0 * hash(k + 11.0);               // cuánto dura la parte oscilante
    float level = 0.97 + 0.03 * sin(t * 47.0);             // zumbido
    float u = ph - inicio;
    if (u > 0.0 && u < dur + 1.0) {
        float bajada = smoothstep(0.0, 0.45, u);           // se atenúa en ~0,45 s, no de golpe
        float p = u * 3.0;
        float n = floor(p);
        float a = mix(0.12, 0.85, hash(n + k * 31.0));
        float b = mix(0.12, 0.85, hash(n + 1.0 + k * 31.0));
        float ondas = mix(a, b, smoothstep(0.0, 1.0, fract(p)));   // interpola: sin saltos
        float dip = mix(1.0, ondas, bajada);
        float subida = smoothstep(dur * 0.6, dur + 1.0, u); // vuelve a encenderse de a poco
        return level * mix(dip, 1.0, subida);
    }
    return level;
}

void main() {
    vec2 uv = qt_TexCoord0;
    float t = time * speed;
    float m = texture(mask, uv).r;
    float pulse = neon(t);
    vec3 col = vec3(cr, cg, cb);
    vec3 add = col * m * pulse * strength * 0.85;
    // Neón encendido: el centro se calienta hacia el blanco.
    add += vec3(1.0, 0.7, 0.8) * pow(m, 2.0) * max(pulse - 0.6, 0.0) * strength * 0.30;
    // En las caídas el neón se apaga de verdad: además de quitar resplandor, se oscurece el propio ojo
    // (alfa > 0 tapa lo de abajo; con el neón encendido el alfa es 0 y solo suma luz).
    float apagado = clamp((1.0 - pulse) * 1.15, 0.0, 1.0);
    float a = clamp(pow(m, 1.2) * apagado * 0.9, 0.0, 1.0);
    fragColor = vec4(add, a) * qt_Opacity;
}
