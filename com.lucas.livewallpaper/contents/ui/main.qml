import QtQuick
import QtMultimedia
import org.kde.kirigami as Kirigami
import org.kde.plasma.core as PlasmaCore
import org.kde.plasma.plasmoid

WallpaperItem {
    id: root

    readonly property string videoUrl: root.configuration.VideoUrl
    readonly property bool hasVideo: videoUrl !== ""
    readonly property var videoSuffixes: ["mp4", "webm", "mkv", "mov", "avi", "m4v", "gif"]

    Component.onCompleted: root.loading = hasVideo  // retrasa la pantalla de inicio hasta el primer fotograma

    // Soltar un video sobre el escritorio lo aplica como fondo.
    onOpenUrlRequested: (url) => {
        const s = url.toString();
        const ext = s.split(".").pop().toLowerCase();
        if (videoSuffixes.indexOf(ext) === -1)
            return;
        root.configuration.VideoUrl = s;
        root.configuration.writeConfig();
    }

    contextualActions: [
        PlasmaCore.Action {
            text: pauseCtl.manualPause ? "Reanudar fondo animado" : "Pausar fondo animado"
            icon.name: pauseCtl.manualPause ? "media-playback-start" : "media-playback-pause"
            enabled: root.hasVideo
            onTriggered: pauseCtl.manualPause = !pauseCtl.manualPause
        }
    ]

    PauseController {
        id: pauseCtl
        anchors.fill: parent
        pauseOnMaximized: root.configuration.PauseOnMaximized
        pauseOnBattery: root.configuration.PauseOnBattery
        pauseOnLock: root.configuration.PauseOnLock
        onShouldPlayChanged: player.sync()
    }

    Rectangle {
        anchors.fill: parent
        color: "black"
    }

    MediaPlayer {
        id: player
        source: root.videoUrl
        loops: MediaPlayer.Infinite
        videoOutput: output
        audioOutput: AudioOutput {
            muted: root.configuration.Muted
            volume: root.configuration.Volume / 100
        }

        // Pausar deja congelado el último fotograma; no se vuelve a negro.
        function sync() {
            if (!root.hasVideo)
                stop();
            else if (pauseCtl.shouldPlay)
                play();
            else
                pause();
        }

        onSourceChanged: {
            root.loading = root.hasVideo;
            sync();
        }
        onMediaStatusChanged: {
            if (mediaStatus === MediaPlayer.LoadedMedia || mediaStatus === MediaPlayer.BufferedMedia) {
                root.loading = false;
                accentTimer.restart();
            } else if (mediaStatus === MediaPlayer.InvalidMedia || mediaStatus === MediaPlayer.NoMedia) {
                root.loading = false;
            }
        }
        onErrorOccurred: (error, errorString) => {
            console.warn("livewallpaper: no se pudo reproducir", source, "-", errorString);
            root.loading = false;
        }
        Component.onCompleted: sync()
    }

    VideoOutput {
        id: output
        anchors.fill: parent
        // 0 = Stretch, 1 = PreserveAspectFit, 2 = PreserveAspectCrop
        fillMode: root.configuration.FillMode
    }

    // Color de acento de Plasma a partir de un fotograma del video.
    Kirigami.ImageColors {
        id: colors
        source: output
        onPaletteChanged: root.accentColor = colors.dominant
    }
    Timer {
        id: accentTimer
        interval: 1500  // dar tiempo a que haya un fotograma dibujado
        onTriggered: colors.update()
    }
}
