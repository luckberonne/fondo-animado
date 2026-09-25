import QtQuick
import QtMultimedia
import "util.js" as Util

// Un video del fondo. Muestra el póster hasta tener el primer fotograma y avisa con ready().
Item {
    id: layer

    property var project: null
    property bool playing: false
    property int fillMode: 2
    property bool muted: true
    property real volume: 0.5
    property bool isReady: false
    readonly property Item visualItem: output

    signal ready()
    signal failed(string message)

    readonly property url source: Util.projectUrl(project)

    Image {
        anchors.fill: parent
        source: layer.isReady ? "" : Util.assetUrl(layer.project, layer.project ? layer.project.poster : "")
        fillMode: layer.fillMode
        asynchronous: true
        sourceSize: Qt.size(layer.width * Screen.devicePixelRatio, layer.height * Screen.devicePixelRatio)
    }

    MediaPlayer {
        id: player
        source: layer.source
        loops: MediaPlayer.Infinite
        videoOutput: output
        audioOutput: AudioOutput {
            muted: layer.muted
            volume: layer.volume
        }
        onSourceChanged: layer.sync()
        onErrorOccurred: (error, errorString) => {
            console.warn("livewallpaper: no se pudo reproducir", source, "-", errorString);
            layer.failed(errorString);
        }
    }

    VideoOutput {
        id: output
        anchors.fill: parent
        fillMode: layer.fillMode
    }

    // Primer fotograma: recién ahí se puede mostrar (y pausar si hace falta, quedando congelado).
    Connections {
        target: output.videoSink
        enabled: !layer.isReady
        function onVideoFrameChanged() {
            layer.isReady = true;
            layer.sync();
            layer.ready();
        }
    }

    onPlayingChanged: sync()

    function sync() {
        if (source.toString() === "")
            player.stop();
        else if (playing || !isReady)
            player.play();
        else
            player.pause();
    }
}
