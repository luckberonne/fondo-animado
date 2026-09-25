import QtQuick

// Partículas sobre el fondo. Presets: "nieve", "polvo", "luciernagas".
// No usa QtQuick.Particles: ese sistema se redibuja a la frecuencia de la pantalla (144 Hz aquí) sin tope y
// costaba ~8 % de CPU y ~14 % de GPU con 50 partículas. Estas se mueven con `time`, que avanza al ritmo
// limitado (cuadros/s) de la capa que las contiene, y se congelan solas al pausar.
Item {
    id: root

    property string preset: "nieve"
    property int count: 60
    property bool running: true        // sin uso: si `time` no avanza, no se mueven
    property real time: 0              // segundos

    readonly property var cfg: ({
        nieve:       { image: "brillo-nieve.png",     alpha: 0.85, size: 9,  sizeVar: 7  },
        polvo:       { image: "brillo-polvo.png",     alpha: 0.35, size: 6,  sizeVar: 5  },
        luciernagas: { image: "brillo-luciernaga.png", alpha: 0.95, size: 16, sizeVar: 10 }
    })
    readonly property var c: cfg[preset] || cfg.nieve

    // Número pseudoaleatorio estable por partícula (0..1).
    function rnd(i, k) {
        const x = Math.sin(i * 127.1 + k * 311.7) * 43758.5453;
        return x - Math.floor(x);
    }

    Repeater {
        model: root.count
        delegate: Image {
            id: dot
            required property int index
            readonly property real r0: root.rnd(index, 0)
            readonly property real r1: root.rnd(index, 1)
            readonly property real r2: root.rnd(index, 2)
            readonly property real r3: root.rnd(index, 3)
            readonly property real t: root.time

            source: Qt.resolvedUrl("../images/" + root.c.image)
            width: root.c.size + r2 * root.c.sizeVar
            height: width
            smooth: true
            asynchronous: true
            cache: true
            sourceSize: Qt.size(64, 64)
            opacity: root.preset === "luciernagas" ? root.c.alpha * Math.max(0, Math.sin(t * (0.5 + r3) + index * 3.1) * 0.8 + 0.2)
                   : root.preset === "polvo" ? root.c.alpha * (0.4 + 0.6 * r3)
                   : root.c.alpha * (0.4 + 0.6 * r3)
            x: root.preset === "nieve"
               ? r0 * root.width + Math.sin(t * 0.4 + index) * 22
               : r0 * root.width + Math.sin(t * 0.13 * (0.5 + r3) + index) * 70
            y: root.preset === "nieve"
               ? ((r1 * (root.height + 30) + t * (28 + r3 * 45)) % (root.height + 30)) - 20
               : r1 * root.height + Math.cos(t * 0.11 * (0.5 + r2) + index * 1.7) * 45
        }
    }
}
