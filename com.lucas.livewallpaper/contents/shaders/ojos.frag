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

// Neón: encendido fijo con un zumbido casi imperceptible y, cada tanto, un parpadeo de caídas rápidas que termina
// con una recuperación gradual. El intervalo y la duración varían de un ciclo a otro. `time` está en segundos
// reales (el proyecto fija speed = 1 / velocidad).
float neon(float t) {
    const float CICLO = 6.0;
    float k = floor(t / CICLO);
    float ph = t - k * CICLO;                              // segundo dentro del ciclo
    float inicio = 3.2 + 1.8 * hash(k + 3.0);             // cuándo empieza el parpadeo
    float dur = 0.8 + 0.7 * hash(k + 11.0);               // cuánto dura
    float level = 0.96 + 0.04 * sin(t * 47.0);             // zumbido
    float u = ph - inicio;
    if (u > 0.0 && u < dur) {
        float paso = floor(u * 12.0);                      // 12 cambios por segundo
        float on = step(0.42, hash(paso + k * 31.0));      // encendido/apagado al azar
        float caida = mix(0.10, 0.70, hash(paso + k * 17.0));
        float f = mix(caida, 1.0, on);
        float subida = smoothstep(dur * 0.55, dur, u);     // hacia el final vuelve a subir de a poco
        return level * mix(f, 1.0, subida);
    }
    if (u >= dur && u < dur + 0.5) {                       // pequeña bajada tras el parpadeo
        return level * mix(0.55, 1.0, smoothstep(dur, dur + 0.5, u));
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
