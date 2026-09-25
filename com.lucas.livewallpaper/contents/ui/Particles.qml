import QtQuick
import QtQuick.Particles

// Partículas sobre el fondo. Presets: "nieve", "polvo", "luciernagas".
Item {
    id: root

    property string preset: "nieve"
    property int count: 60
    property bool running: true

    readonly property var cfg: ({
        nieve:       { image: "qrc:///particleresources/fuzzydot.png", color: "#ffffff", alpha: 0.85,
                       size: 10, sizeVar: 6, life: 14000, speed: 45, speedVar: 20, angle: 90, wander: 30, from: "top" },
        polvo:       { image: "qrc:///particleresources/glowdot.png", color: "#fff2d6", alpha: 0.35,
                       size: 6, sizeVar: 4, life: 16000, speed: 8, speedVar: 6, angle: 270, wander: 15, from: "area" },
        luciernagas: { image: "qrc:///particleresources/glowdot.png", color: "#d8ff6a", alpha: 0.9,
                       size: 14, sizeVar: 8, life: 9000, speed: 12, speedVar: 10, angle: 270, wander: 25, from: "area" }
    })
    readonly property var c: cfg[preset] || cfg.nieve

    ParticleSystem {
        id: system
        anchors.fill: parent
        running: root.running
        paused: !root.running
    }

    ImageParticle {
        system: system
        source: root.c.image
        color: root.c.color
        alpha: root.c.alpha
        alphaVariation: 0.3
        // Las luciérnagas titilan: nacen y mueren con fundido.
        entryEffect: root.preset === "luciernagas" ? ImageParticle.Fade : ImageParticle.None
    }

    Emitter {
        system: system
        x: 0
        y: root.c.from === "top" ? -20 : 0
        width: root.width
        height: root.c.from === "top" ? 1 : root.height
        emitRate: root.count / (root.c.life / 1000)
        maximumEmitted: root.count
        lifeSpan: root.c.life
        lifeSpanVariation: root.c.life / 4
        size: root.c.size
        sizeVariation: root.c.sizeVar
        velocity: AngleDirection {
            angle: root.c.angle
            angleVariation: root.preset === "nieve" ? 15 : 180
            magnitude: root.c.speed
            magnitudeVariation: root.c.speedVar
        }
    }

    Wander {
        system: system
        xVariance: root.c.wander
        yVariance: root.preset === "nieve" ? 0 : root.c.wander
        pace: 40
    }
}
