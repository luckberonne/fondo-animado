import QtQuick
import org.kde.kirigami as Kirigami
import org.kde.plasma.core as PlasmaCore
import org.kde.plasma.plasmoid
import "util.js" as Util

WallpaperItem {
    id: root

    readonly property var cfg: root.configuration

    // Último cuadro de audio (128 valores) para los fondos web; lo llena AudioFeed.
    property var audioFrame: []

    // ---------- proyecto activo ----------
    Library {
        id: library
        onFailed: (message) => console.warn("livewallpaper:", message)
        onImported: (project) => {
            root.configuration.Project = project.dir;
            root.configuration.writeConfig();
        }
        onLoadedChanged: root.resolveProject()
        onProjectsChanged: root.resolveProject()
    }
    Component.onCompleted: {
        root.loading = true;  // retrasa la pantalla de inicio hasta el primer fotograma
        library.refresh();
    }

    readonly property string projectDir: cfg.Project
    onProjectDirChanged: {
        // Un proyecto recién importado todavía no está en la lista: releer.
        if (projectDir && !library.find(projectDir))
            library.refresh();
        resolveProject();
    }
    readonly property string legacyUrl: cfg.VideoUrl
    onLegacyUrlChanged: resolveProject()

    // La pantalla de bloqueo la dibuja otro proceso (kscreenlocker_greet), que no hereda el ajuste de GPU de
    // plasmashell: un video ahí abre la NVIDIA y la despierta. Allí se muestra el primer fotograma con el
    // zoom lento de las imágenes; un fondo web, su miniatura (si tiene); y no se pausa por bloqueo ni ventanas.
    // Las escenas sí se animan (no usan video ni WebEngine).
    readonly property bool isLockScreen: Qt.application.name === "kscreenlocker_greet"

    function forLockScreen(p) {
        // Imágenes y escenas (solo shaders y capas de imagen: no abren la NVIDIA) se ven animadas.
        if (!p || p.type === "image" || p.type === "scene")
            return p;
        const firstImage = p.scene && p.scene.layers ? (p.scene.layers.find(l => l.image) || {}).image : "";
        const still = p.poster || p.preview || firstImage;
        if (!still || !p.dir)
            return null;
        return Object.assign({}, p, { type: "image", file: still, poster: "", preview: "", audio: false, properties: {} });
    }

    function resolveProject() {
        if (!library.loaded)
            return;
        let p = projectDir ? library.find(projectDir) : null;
        if (!p && !projectDir && legacyUrl)
            p = { dir: "", url: legacyUrl, type: "video", title: "", properties: {} };
        stage.show(isLockScreen ? forLockScreen(p) : p);
    }

    // ---------- audio para los fondos web ----------
    AudioFeed {
        id: audioFeed
        active: stage.shown !== null && stage.shown.type === "web" && !!stage.shown.audio && pauseCtl.shouldPlay
        onFrameChanged: root.audioFrame = frame
    }

    // ---------- soltar archivos sobre el escritorio ----------
    onOpenUrlRequested: (url) => library.importFile(Util.localPath(url))

    // ---------- lista de reproducción ----------
    readonly property var candidates: {
        const all = library.projects.map(p => p.dir);
        const chosen = (cfg.PlaylistProjects || []).filter(d => all.indexOf(d) !== -1);
        return chosen.length > 0 ? chosen : all;
    }
    readonly property bool canRotate: candidates.length > 1

    function next() {
        if (!canRotate)
            return;
        const i = candidates.indexOf(projectDir);
        let j;
        if (cfg.PlaylistRandom) {
            do { j = Math.floor(Math.random() * candidates.length); } while (j === i);
        } else {
            j = (i + 1) % candidates.length;
        }
        root.configuration.Project = candidates[j];
        root.configuration.writeConfig();
    }

    // Cuenta solo los minutos en que el fondo está a la vista.
    property int visibleMinutes: 0
    Timer {
        interval: 60 * 1000
        repeat: true
        running: root.cfg.PlaylistEnabled && root.canRotate && pauseCtl.shouldPlay
        onTriggered: {
            if (++root.visibleMinutes >= Math.max(1, root.cfg.PlaylistMinutes)) {
                root.visibleMinutes = 0;
                root.next();
            }
        }
    }

    contextualActions: [
        PlasmaCore.Action {
            text: pauseCtl.manualPause ? "Reanudar fondo animado" : "Pausar fondo animado"
            icon.name: pauseCtl.manualPause ? "media-playback-start" : "media-playback-pause"
            onTriggered: pauseCtl.manualPause = !pauseCtl.manualPause
        },
        PlasmaCore.Action {
            text: "Siguiente fondo"
            icon.name: "media-skip-forward"
            visible: root.canRotate
            onTriggered: {
                root.visibleMinutes = 0;
                root.next();
            }
        }
    ]

    PauseController {
        id: pauseCtl
        anchors.fill: parent
        pauseOnMaximized: root.cfg.PauseOnMaximized && !root.isLockScreen
        pauseOnBattery: root.cfg.PauseOnBattery
        pauseOnLock: root.cfg.PauseOnLock && !root.isLockScreen
    }

    Rectangle {
        anchors.fill: parent
        color: "black"
    }

    // ---------- escenario: dos capas con fundido cruzado ----------
    Item {
        id: stage
        anchors.fill: parent

        property int front: -1          // índice de la capa visible (0 o 1)
        property var shown: null        // proyecto de la capa visible
        property int fading: -1         // capa que está entrando

        function key(p) { return p ? (p.dir || p.url) : ""; }

        function show(p) {
            if (!p) {
                for (let i = 0; i < 2; i++)
                    slots.itemAt(i).project = null;
                front = -1; shown = null; fading = -1;
                root.loading = false;
                return;
            }
            // El que ya está entrando: dejarlo seguir.
            if (fading !== -1 && key(p) === key(slots.itemAt(fading).project))
                return;
            // El que ya se ve (p. ej. se releyó la biblioteca, o se volvió atrás a mitad de un fundido):
            // cancelar lo que estuviera entrando. Las propiedades van por binding.
            if (key(p) === key(shown)) {
                if (fading !== -1) {
                    fadeIn.stop();
                    slots.itemAt(fading).project = null;
                    fading = -1;
                }
                return;
            }
            const back = front === 0 ? 1 : 0;
            fading = back;
            slots.itemAt(back).project = p;
        }

        function layerReady(index) {
            if (index !== fading)
                return;
            const incoming = slots.itemAt(index);
            fadeIn.target = incoming;
            fadeIn.from = front === -1 ? 1 : 0;   // el primero aparece de una
            fadeIn.restart();
        }

        function fadeFinished() {
            const old = front;
            front = fading;
            fading = -1;
            shown = slots.itemAt(front).project;
            if (old >= 0 && old !== front)
                slots.itemAt(old).project = null;   // libera el decodificador
            root.loading = false;
            accentTimer.restart();
        }

        NumberAnimation {
            id: fadeIn
            property: "opacity"
            to: 1
            duration: 1200
            easing.type: Easing.InOutQuad
            onFinished: stage.fadeFinished()
        }

        Repeater {
            id: slots
            model: 2
            delegate: Loader {
                id: slot
                required property int index
                property var project: null

                anchors.fill: parent
                z: index === stage.fading ? 2 : 1
                opacity: 0

                onProjectChanged: {
                    source = "";
                    opacity = 0;
                    if (!project)
                        return;
                    // Valores iniciales al crear la capa (así la imagen se decodifica una sola vez
                    // al tamaño correcto); después se reemplazan por bindings en onLoaded.
                    const isImage = project.type === "image";
                    const isWeb = project.type === "web";
                    const isScene = project.type === "scene";
                    const init = { project: project, fillMode: root.cfg.FillMode };
                    if (isImage)
                        init.props = Util.effectiveProps(project, root.cfg.PropertyOverrides);
                    else if (isWeb || isScene)
                        init.props = Util.webOverrides(project, root.cfg.PropertyOverrides);
                    setSource(isImage ? "ImageLayer.qml" : isWeb ? "WebLayer.qml" : isScene ? "SceneLayer.qml" : "VideoLayer.qml", init);
                }
                onLoaded: {
                    item.playing = Qt.binding(() => pauseCtl.shouldPlay
                                                   && (slot.index === stage.front || slot.index === stage.fading));
                    item.fillMode = Qt.binding(() => root.cfg.FillMode);
                    item.muted = Qt.binding(() => root.cfg.Muted);
                    item.volume = Qt.binding(() => root.cfg.Volume / 100);
                    if (slot.project.type === "web") {
                        item.props = Qt.binding(() => Util.webOverrides(slot.project, root.cfg.PropertyOverrides));
                        item.audio = Qt.binding(() => root.audioFrame);
                        item.fps = Qt.binding(() => root.cfg.WebFps);
                    } else if (slot.project.type === "scene") {
                        item.props = Qt.binding(() => Util.webOverrides(slot.project, root.cfg.PropertyOverrides));
                        item.fps = Qt.binding(() => root.cfg.ImageFps);
                    } else if (slot.project.type === "image") {
                        item.props = Qt.binding(() => Util.effectiveProps(slot.project, root.cfg.PropertyOverrides));
                        item.fps = Qt.binding(() => root.cfg.ImageFps);
                    }
                }
                Connections {
                    target: slot.item
                    function onReady() { stage.layerReady(slot.index) }
                    function onFailed(message) {
                        if (slot.index === stage.fading) {
                            stage.fading = -1;
                            slot.project = null;
                            root.loading = false;
                        }
                    }
                }
            }
        }
    }

    // ---------- color de acento a partir de lo que se ve ----------
    Kirigami.ImageColors {
        id: colors
        source: stage.front >= 0 && slots.itemAt(stage.front).item ? slots.itemAt(stage.front).item.visualItem : null
        onPaletteChanged: root.accentColor = colors.dominant
    }
    Timer {
        id: accentTimer
        interval: 1000
        onTriggered: colors.update()
    }
}
