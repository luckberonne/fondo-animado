import QtQuick
import QtWebEngine
import "util.js" as Util

// Fondo web al estilo Wallpaper Engine. El HTML define `window.wallpaperPropertyListener` y llama a
// `window.wallpaperRegisterAudioListener(cb)`; este componente les entrega propiedades y audio.
Item {
    id: layer

    property var project: null
    property var props: ({})            // valores editados: {nombre: valor}
    property bool playing: false
    property int fillMode: 2            // sin uso (la página escala sola)
    property bool muted: true
    property real volume: 0.5
    property bool isReady: false
    property int fps: 20                // tope de cuadros por segundo de la página
    property var audio: []              // 128 valores 0-1 (izq 0-63, der 64-127)
    readonly property Item visualItem: view

    signal ready()
    signal failed(string message)

    // Definido antes de que cargue la página: guarda el callback de audio y expone la entrada de datos.
    readonly property string bridge: `
        // Tope de cuadros: la página pide requestAnimationFrame a 60 Hz y cada cuadro cuesta CPU y GPU.
        (function () {
            var raf = window.requestAnimationFrame.bind(window), last = 0;
            window.__wpFps = ${fps};
            window.requestAnimationFrame = function (cb) {
                return raf(function step(t) {
                    if (t - last < 1000 / window.__wpFps - 2) return raf(step);
                    last = t; cb(t);
                });
            };
        })();
        window.__wpAudioCb = null;
        window.wallpaperRegisterAudioListener = function (cb) { window.__wpAudioCb = cb; };
        window.__wpAudio = function (a) { if (window.__wpAudioCb) window.__wpAudioCb(a); };
        window.__wpProps = function (p) {
            var l = window.wallpaperPropertyListener;
            if (l && l.applyUserProperties) l.applyUserProperties(p);
        };
        window.__wpGeneral = function (g) {
            var l = window.wallpaperPropertyListener;
            if (l && l.applyGeneralProperties) l.applyGeneralProperties(g);
        };
    `

    // Propiedades declaradas por el proyecto, con el valor efectivo de cada una.
    readonly property var effective: {
        const decl = (project && project.properties) || {};
        const out = {};
        for (const name in decl) {
            const d = decl[name];
            out[name] = Object.assign({}, d, { value: props[name] !== undefined ? props[name] : d.value });
        }
        return out;
    }
    onEffectiveChanged: pushProps()
    onFpsChanged: if (isReady) view.runJavaScript("window.__wpFps = " + fps)

    function pushProps() {
        if (!isReady)
            return;
        view.runJavaScript("window.__wpProps(" + JSON.stringify(effective) + ")");
    }

    // Lo llama main.qml ~30 veces/s con el audio del sistema.
    onAudioChanged: {
        if (isReady && playing && audio && audio.length === 128)
            view.runJavaScript("window.__wpAudio([" + audio.join(",") + "])");
    }

    WebEngineView {
        id: view
        anchors.fill: parent
        url: Util.projectUrl(layer.project)
        backgroundColor: "black"
        audioMuted: layer.muted
        // Congelada la página no consume CPU ni GPU: es la «pausa» de un fondo web.
        lifecycleState: layer.playing ? WebEngineView.LifecycleState.Active : WebEngineView.LifecycleState.Frozen

        settings.localContentCanAccessFileUrls: true
        settings.localContentCanAccessRemoteUrls: false
        settings.javascriptCanOpenWindows: false
        settings.playbackRequiresUserGesture: false
        settings.showScrollBars: false
        settings.focusOnNavigationEnabled: false

        userScripts.collection: [
            {
                name: "wallpaperengine-bridge",
                sourceCode: layer.bridge,
                injectionPoint: WebEngineScript.DocumentCreation,
                worldId: WebEngineScript.MainWorld,
                runsOnSubFrames: false
            }
        ]

        onContextMenuRequested: (request) => request.accepted = true
        onNavigationRequested: (request) => {
            // Solo la página propia; nada de salir a internet.
            if (request.url.toString().indexOf("file://") !== 0)
                request.action = WebEngineNavigationRequest.IgnoreRequest;
        }
        onLoadingChanged: (info) => {
            if (info.status === WebEngineView.LoadSucceededStatus) {
                layer.isReady = true;
                layer.pushProps();
                layer.ready();
            } else if (info.status === WebEngineView.LoadFailedStatus) {
                layer.failed(info.errorString);
            }
        }
    }
}
