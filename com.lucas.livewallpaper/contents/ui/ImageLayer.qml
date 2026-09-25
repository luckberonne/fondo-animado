import QtQuick
import "util.js" as Util

// Imagen fija animada: zoom y paneo lentos (Ken Burns) más partículas opcionales.
// La animación avanza con un Timer a `fps` cuadros por segundo en vez de al ritmo de la pantalla:
// cada cuadro obliga a plasmashell y a KWin a redibujar la pantalla entera.
Item {
    id: layer

    property var project: null
    property var props: ({})
    property bool playing: false
    property int fillMode: 2
    property bool muted: true      // sin uso: misma interfaz que VideoLayer
    property real volume: 0.5
    property bool isReady: false
    property int fps: 20
    readonly property Item visualItem: img

    signal ready()
    signal failed(string message)

    readonly property real zoom: Math.max(0, Number(props.zoom) || 0) / 100
    readonly property real period: Math.max(5, Number(props.periodo) || 40)

    // Segundos de animación transcurridos (solo avanzan mientras se reproduce).
    property real t: 0
    Timer {
        interval: Math.round(1000 / Math.max(5, layer.fps))
        repeat: true
        running: layer.playing && layer.isReady && layer.zoom > 0
        onTriggered: layer.t += interval / 1000
    }

    // Fase 0 → 1 → 0 con aceleración suave; el paneo usa otros períodos para no repetirse igual.
    readonly property real phase: (1 - Math.cos(2 * Math.PI * t / period)) / 2
    readonly property real currentScale: 1 + zoom * phase
    readonly property real panX: Math.sin(2 * Math.PI * t / (period * 1.7))
    readonly property real panY: Math.sin(2 * Math.PI * t / (period * 2.3))

    Image {
        id: img
        width: layer.width
        height: layer.height
        source: Util.projectUrl(layer.project)
        fillMode: layer.fillMode
        asynchronous: true
        smooth: true
        mipmap: true
        cache: false
        // Decodificar al tamaño que realmente se usa (con el margen del zoom), no a 4K.
        sourceSize: Qt.size(layer.width * (1 + layer.zoom) * Screen.devicePixelRatio,
                            layer.height * (1 + layer.zoom) * Screen.devicePixelRatio)
        scale: layer.currentScale
        // El desplazamiento nunca supera lo que sobra por el zoom: no aparecen bordes.
        x: layer.panX * (layer.currentScale - 1) * layer.width / 2
        y: layer.panY * (layer.currentScale - 1) * layer.height / 2

        onStatusChanged: {
            if (status === Image.Ready && !layer.isReady) {
                layer.isReady = true;
                layer.ready();
            } else if (status === Image.Error) {
                layer.failed("no se pudo abrir la imagen");
            }
        }
    }

    Loader {
        anchors.fill: parent
        active: layer.props.particulas && layer.props.particulas !== "ninguna"
        sourceComponent: Particles {
            preset: layer.props.particulas
            count: Number(layer.props.cantidad) || 60
            running: layer.playing
        }
    }
}
