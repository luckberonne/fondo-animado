import QtQuick
import QtWebSockets
import org.kde.plasma.plasma5support as P5Support
import "util.js" as Util

// Recibe el audio del sistema (audio.py) y lo entrega como `frame` (128 valores 0-1).
// El servicio se arranca solo mientras `active` sea verdadero, y se detiene al terminar.
Item {
    id: feed

    property bool active: false
    property int port: 47800
    property var frame: []

    readonly property string script: Util.localPath(Qt.resolvedUrl("../code/audio.py"))
    readonly property string unit: "livewallpaper-audio"

    // systemd-run: sin archivos de unidad que instalar. Si ya está corriendo, falla sin consecuencias.
    readonly property string startCmd: "systemd-run --user --quiet --collect --unit=" + unit
                                       + " python3 " + Util.quote(script) + " --puerto " + port
    readonly property string stopCmd: "systemctl --user stop " + unit

    property bool serverUp: false

    onActiveChanged: {
        if (active) {
            serverUp = false;
            run(startCmd);
            connectTimer.restart();
        } else {
            connectTimer.stop();
            socket.active = false;
            frame = [];
            run(stopCmd);
        }
    }
    Component.onDestruction: if (active) run(stopCmd)

    property int _seq: 0
    function run(cmd) { exec.connectSource(cmd + " # " + (++_seq)) }
    P5Support.DataSource {
        id: exec
        engine: "executable"
        onNewData: (source, data) => disconnectSource(source)
    }

    // Reintenta la conexión mientras el servicio arranca o si se cae.
    Timer {
        id: connectTimer
        interval: 800
        repeat: true
        onTriggered: if (feed.active && !socket.active) socket.active = true
    }

    WebSocket {
        id: socket
        url: "ws://127.0.0.1:" + feed.port
        onTextMessageReceived: (message) => {
            try { feed.frame = JSON.parse(message); } catch (e) {}
        }
        onStatusChanged: (status) => {
            if (status === WebSocket.Error || status === WebSocket.Closed)
                active = false;   // connectTimer volverá a intentarlo
        }
    }
}
