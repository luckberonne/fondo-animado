import QtQuick
import QtQuick.Window
import "util.js" as Util

// Escena: capas de imagen apiladas con paralaje de cámara (deriva lenta), efectos de shader y partículas.
//
// project.scene = { "layers": [
//    { "image": "cielo.png", "depth": 0.0 },
//    { "image": "lago.png",  "depth": 0.3, "effect": { "shader": "agua", "strength": 0.006, "speed": 1, "horizon": 0.58 } },
//    { "particles": "luciernagas", "count": 40, "depth": 0.6 }
// ] }
// depth: 0 = fondo lejano (no se mueve), 1 = primer plano (se mueve lo máximo).
// Propiedades (project.json → general.properties): parallax (0-100, amplitud del movimiento), velocidad.
Item {
    id: scn

    property var project: null
    property var props: ({})            // valores editados: {nombre: valor}
    property bool playing: false
    property int fillMode: 2            // las capas siempre cubren la pantalla
    property bool muted: true
    property real volume: 0.5
    property bool isReady: false
    property int fps: 20
    readonly property Item visualItem: sceneRoot

    signal ready()
    signal failed(string message)

    readonly property var layers: (project && project.scene && project.scene.layers) || []

    // Valor efectivo de una propiedad (la editada, o el valor por defecto del project.json).
    function prop(name, fallback) {
        if (props[name] !== undefined)
            return Number(props[name]);
        const d = project && project.properties && project.properties[name];
        return d !== undefined && d.value !== undefined ? Number(d.value) : fallback;
    }
    readonly property real parallax: prop("parallax", 50) / 100      // 0 = quieto, 1 = máximo
    readonly property real speedScale: prop("velocidad", 1)
    readonly property real margin: 0.08 * parallax                   // cuánto se agranda cada capa para poder moverse

    // ---------- tiempo de los shaders, a `fps` cuadros por segundo ----------
    property real t: 0
    Timer {
        interval: Math.round(1000 / Math.max(5, scn.fps))
        repeat: true
        running: scn.playing && scn.isReady
        onTriggered: scn.t += interval / 1000 * scn.speedScale
    }

    // ---------- movimiento de cámara ----------
    // Deriva lenta y suave (no sigue al puntero: el motor «mouse» de Plasma usa X11 y tumba plasmashell en Wayland).
    readonly property real px: Math.sin(2 * Math.PI * t / 70) * 0.9
    readonly property real py: Math.sin(2 * Math.PI * t / 110 + 1.2) * 0.5

    // ---------- capas ----------
    property int loadedImages: 0
    readonly property int totalImages: layers.filter(l => l.image).length
    onLoadedImagesChanged: checkReady()
    onTotalImagesChanged: checkReady()
    function checkReady() {
        if (!isReady && totalImages > 0 && loadedImages >= totalImages) {
            isReady = true;
            ready();
        }
    }

    Rectangle { anchors.fill: parent; color: "black" }

    Item {
        id: sceneRoot
        anchors.fill: parent
        clip: true

        Repeater {
            model: scn.layers
            delegate: Item {
                id: wrap
                required property var modelData
                readonly property real depth: Number(modelData.depth) || 0

                anchors.fill: parent
                scale: 1 + scn.margin
                x: -scn.px * depth * scn.margin * width / 2
                y: -scn.py * depth * scn.margin * height / 2

                Image {
                    id: img
                    anchors.fill: parent
                    visible: !wrap.modelData.effect      // con efecto, lo dibuja el ShaderEffect
                    source: wrap.modelData.image ? Util.assetUrl(scn.project, wrap.modelData.image) : ""
                    fillMode: Image.PreserveAspectCrop
                    asynchronous: true
                    mipmap: true
                    cache: false
                    sourceSize: Qt.size(scn.width * (1 + scn.margin) * Screen.devicePixelRatio,
                                        scn.height * (1 + scn.margin) * Screen.devicePixelRatio)
                    onStatusChanged: {
                        if (status === Image.Ready)
                            scn.loadedImages++;
                        else if (status === Image.Error)
                            scn.failed("no se pudo abrir " + wrap.modelData.image);
                    }
                }

                ShaderEffect {
                    anchors.fill: parent
                    visible: !!wrap.modelData.effect && img.status === Image.Ready
                    property variant source: img
                    property real time: scn.t
                    property real strength: wrap.modelData.effect ? Number(wrap.modelData.effect.strength) || 0.005 : 0
                    property real speed: wrap.modelData.effect ? Number(wrap.modelData.effect.speed) || 1 : 1
                    property real horizon: wrap.modelData.effect ? Number(wrap.modelData.effect.horizon) || 0 : 0
                    fragmentShader: wrap.modelData.effect
                        ? Qt.resolvedUrl("../shaders/" + wrap.modelData.effect.shader + ".frag.qsb") : ""
                }

                Loader {
                    anchors.fill: parent
                    active: !!wrap.modelData.particles
                    sourceComponent: Particles {
                        preset: wrap.modelData.particles
                        count: Number(wrap.modelData.count) || 60
                        time: scn.t
                    }
                }
            }
        }
    }
}
