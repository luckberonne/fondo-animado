import QtQuick
import QtQuick.Controls as QQC2
import QtQuick.Layouts
import QtQuick.Dialogs
import org.kde.kirigami as Kirigami
import org.kde.kquickcontrols as KQuickControls
import "util.js" as Util

Kirigami.FormLayout {
    id: root
    // parentLayout lo define el diálogo que nos crea; se tolera que falte.
    twinFormLayouts: typeof parentLayout === "undefined" || !parentLayout ? [] : parentLayout

    property var configDialog
    // Los módulos de Bloqueo de pantalla e Inicio de sesión crean este panel con estas propiedades iniciales;
    // si no existen, la creación falla («does not have a property called wallpaperConfiguration»).
    property var wallpaperConfiguration
    property string cfg_PreviewImage
    property string cfg_PreviewImageDefault
    property var cfg_DarkLightScheduleState
    property var cfg_DarkLightScheduleStateDefault
    property alias formLayout: root

    property string cfg_Project
    property string cfg_VideoUrl
    property alias cfg_FillMode: fill.currentIndex
    property alias cfg_Muted: muted.checked
    property alias cfg_Volume: volume.value
    property alias cfg_PauseOnMaximized: pauseMax.checked
    property alias cfg_PauseOnBattery: pauseBattery.checked
    property alias cfg_PauseOnPowerSave: pausePowerSave.checked
    property alias cfg_PauseOnLock: pauseLock.checked
    property string cfg_PropertyOverrides: "{}"
    property int cfg_ImageFps: 20
    property int cfg_WebFps: 20
    property alias cfg_PlaylistEnabled: playlistEnabled.checked
    property alias cfg_PlaylistMinutes: playlistMinutes.value
    property alias cfg_PlaylistRandom: playlistRandom.checked
    property var cfg_PlaylistProjects: []

    readonly property var selected: library.find(cfg_Project)
    readonly property var selectedProps: Util.effectiveProps(selected, cfg_PropertyOverrides)
    readonly property bool isWeb: selected !== null && (selected.type === "web" || selected.type === "scene")
    readonly property var webOverrides: Util.webOverrides(selected, cfg_PropertyOverrides)

    // Propiedades declaradas por un fondo web (formato Wallpaper Engine), en su orden.
    readonly property var webPropList: {
        const d = (selected && selected.properties) || {};
        return Object.keys(d).filter(k => d[k] && d[k].type && d[k].text !== undefined)
                             .sort((a, b) => (d[a].order || 0) - (d[b].order || 0))
                             .map(k => Object.assign({ name: k }, d[k]));
    }
    function webValue(p) { return webOverrides[p.name] !== undefined ? webOverrides[p.name] : p.value }
    function toColor(v) {
        const c = String(v).split(" ").map(Number);
        return Qt.rgba(c[0] || 0, c[1] || 0, c[2] || 0, 1);
    }

    function select(dir) {
        cfg_Project = dir;
        cfg_VideoUrl = "";
    }

    // Guarda una propiedad editada del proyecto elegido en PropertyOverrides.
    function setProp(name, value) {
        if (!selected)
            return;
        let o = {};
        try { o = JSON.parse(cfg_PropertyOverrides || "{}"); } catch (e) {}
        const cur = Object.assign({}, o[selected.dir] || {});
        cur[name] = value;
        o[selected.dir] = cur;
        cfg_PropertyOverrides = JSON.stringify(o);
    }

    // Lista vacía = todos. Al desmarcar el primero se materializa la lista completa menos ese.
    function inPlaylist(dir) {
        return cfg_PlaylistProjects.length === 0 || cfg_PlaylistProjects.indexOf(dir) !== -1;
    }
    function setInPlaylist(dir, on) {
        let list = cfg_PlaylistProjects.length === 0 ? library.projects.map(p => p.dir) : cfg_PlaylistProjects.slice();
        list = list.filter(d => d !== dir);
        if (on)
            list.push(dir);
        cfg_PlaylistProjects = list.length === library.projects.length ? [] : list;
    }

    function forget(dir) {
        if (cfg_Project === dir)
            cfg_Project = "";
        cfg_PlaylistProjects = cfg_PlaylistProjects.filter(d => d !== dir);
        let o = {};
        try { o = JSON.parse(cfg_PropertyOverrides || "{}"); } catch (e) {}
        delete o[dir];
        cfg_PropertyOverrides = JSON.stringify(o);
    }

    // ---------- biblioteca ----------
    Library {
        id: library
        Component.onCompleted: refresh()
        onImported: (project) => {
            root.select(project.dir);
            importer.next();
        }
        onRemoved: (dir) => root.forget(dir)
    }
    Connections {
        target: library
        function onFailed(text) {
            errorMessage.text = text;
            errorMessage.visible = true;
            if (importer.pending.length > 0 || importer.current !== "")
                importer.next();
        }
    }

    QtObject {
        id: importer
        property var pending: []
        property string current: ""
        property int total: 0
        property int done: 0

        function add(urls) {
            pending = pending.concat(urls.map(u => Util.localPath(u.toString())));
            total += urls.length;
            if (current === "")
                next();
        }
        function next() {
            if (current !== "")
                done++;
            if (pending.length === 0) {
                current = "";
                total = 0;
                done = 0;
                return;
            }
            current = pending[0];
            pending = pending.slice(1);
            library.importFile(current);
        }
    }

    Kirigami.InlineMessage {
        id: errorMessage
        Layout.fillWidth: true
        type: Kirigami.MessageType.Warning
        showCloseButton: true
        visible: false
    }

    ColumnLayout {
        Kirigami.FormData.label: "Fondos:"
        Kirigami.FormData.labelAlignment: Qt.AlignTop
        Layout.fillWidth: true
        spacing: Kirigami.Units.smallSpacing

        QQC2.ScrollView {
            Layout.preferredWidth: Kirigami.Units.gridUnit * 32
            Layout.preferredHeight: Kirigami.Units.gridUnit * 17
            Layout.fillWidth: true

            GridView {
                id: grid
                clip: true
                cellWidth: Kirigami.Units.gridUnit * 10.5
                cellHeight: Kirigami.Units.gridUnit * 7.5
                model: library.projects
                currentIndex: -1

                delegate: Item {
                    id: tile
                    required property var modelData
                    readonly property bool isSelected: modelData.dir === root.cfg_Project
                    width: grid.cellWidth
                    height: grid.cellHeight

                    Rectangle {
                        anchors.fill: parent
                        anchors.margins: Kirigami.Units.smallSpacing
                        radius: Kirigami.Units.cornerRadius
                        color: tile.isSelected ? Kirigami.Theme.highlightColor
                             : hover.hovered ? Qt.alpha(Kirigami.Theme.highlightColor, 0.3) : "transparent"

                        ColumnLayout {
                            anchors.fill: parent
                            anchors.margins: Kirigami.Units.smallSpacing
                            spacing: Kirigami.Units.smallSpacing

                            AnimatedImage {
                                Layout.fillWidth: true
                                Layout.fillHeight: true
                                source: Util.assetUrl(tile.modelData, tile.modelData.preview)
                                fillMode: Image.PreserveAspectCrop
                                playing: hover.hovered || tile.isSelected
                                asynchronous: true
                                cache: false

                                // Sin miniatura (p. ej. una página web): ícono grande del tipo.
                                Kirigami.Icon {
                                    anchors.centerIn: parent
                                    visible: !tile.modelData.preview
                                    width: Kirigami.Units.iconSizes.huge; height: width
                                    source: tile.modelData.type === "web" ? "text-html" : "video-x-generic"
                                }
                                Kirigami.Icon {
                                    anchors { left: parent.left; bottom: parent.bottom; margins: Kirigami.Units.smallSpacing }
                                    width: Kirigami.Units.iconSizes.small; height: width
                                    source: tile.modelData.type === "image" ? "image-x-generic"
                                          : tile.modelData.type === "web" ? "text-html" : "video-x-generic"
                                }
                                QQC2.CheckBox {
                                    anchors { right: parent.right; top: parent.top }
                                    visible: root.cfg_PlaylistEnabled
                                    checked: root.inPlaylist(tile.modelData.dir)
                                    onToggled: root.setInPlaylist(tile.modelData.dir, checked)
                                    QQC2.ToolTip.text: "Incluir en la rotación"
                                    QQC2.ToolTip.visible: hovered
                                }
                            }
                            QQC2.Label {
                                Layout.fillWidth: true
                                text: tile.modelData.title
                                elide: Text.ElideRight
                                horizontalAlignment: Text.AlignHCenter
                                color: tile.isSelected ? Kirigami.Theme.highlightedTextColor : Kirigami.Theme.textColor
                            }
                        }
                    }
                    HoverHandler { id: hover }
                    TapHandler { onTapped: root.select(tile.modelData.dir) }
                }

                Kirigami.PlaceholderMessage {
                    anchors.centerIn: parent
                    width: parent.width - Kirigami.Units.gridUnit * 4
                    visible: library.loaded && grid.count === 0
                    icon.name: "video-x-generic"
                    text: "La biblioteca está vacía"
                    explanation: "Importá videos o imágenes, o arrastralos al escritorio."
                }
            }
        }

        RowLayout {
            QQC2.Button {
                icon.name: "list-add"
                text: "Importar…"
                enabled: importer.current === ""
                onClicked: fileDialog.open()
            }
            QQC2.Button {
                icon.name: "edit-delete"
                text: "Quitar"
                enabled: root.selected !== null && importer.current === ""
                onClicked: removeDialog.open()
            }
            QQC2.Button {
                icon.name: "folder-open"
                text: "Abrir carpeta"
                onClicked: Qt.openUrlExternally(Util.fileUrl(library.path || ""))
            }
            QQC2.BusyIndicator {
                Layout.preferredHeight: Kirigami.Units.iconSizes.medium
                visible: importer.current !== ""
                running: visible
            }
            QQC2.Label {
                visible: importer.current !== ""
                text: "Importando " + (importer.done + 1) + " de " + importer.total + "…"
            }
        }
    }

    // ---------- animación de la imagen elegida ----------
    Item {
        Kirigami.FormData.isSection: true
        Kirigami.FormData.label: "Animación de la imagen"
        visible: imageEditor.visible
    }
    ColumnLayout {
        id: imageEditor
        Kirigami.FormData.label: "Zoom:"
        visible: root.selected !== null && root.selected.type === "image"
        RowLayout {
            QQC2.Slider {
                id: zoomSlider
                from: 0; to: 25; stepSize: 1
                value: Number(root.selectedProps.zoom)
                onMoved: root.setProp("zoom", value)
            }
            QQC2.Label { text: zoomSlider.value === 0 ? "Sin movimiento" : zoomSlider.value + " %" }
        }
    }
    RowLayout {
        Kirigami.FormData.label: "Ciclo:"
        visible: imageEditor.visible
        QQC2.Slider {
            id: periodSlider
            from: 10; to: 120; stepSize: 5
            value: Number(root.selectedProps.periodo)
            onMoved: root.setProp("periodo", value)
        }
        QQC2.Label { text: periodSlider.value + " s" }
    }
    QQC2.ComboBox {
        id: particlesBox
        Kirigami.FormData.label: "Partículas:"
        visible: imageEditor.visible
        textRole: "text"
        valueRole: "value"
        model: [
            { text: "Ninguna", value: "ninguna" },
            { text: "Nieve", value: "nieve" },
            { text: "Polvo en el aire", value: "polvo" },
            { text: "Luciérnagas", value: "luciernagas" }
        ]
        currentIndex: Math.max(0, indexOfValue(root.selectedProps.particulas))
        onActivated: root.setProp("particulas", currentValue)
    }
    RowLayout {
        Kirigami.FormData.label: "Cantidad:"
        visible: imageEditor.visible && particlesBox.currentValue !== "ninguna"
        QQC2.Slider {
            id: countSlider
            from: 10; to: 300; stepSize: 10
            value: Number(root.selectedProps.cantidad)
            onMoved: root.setProp("cantidad", value)
        }
        QQC2.Label { text: countSlider.value }
    }

    // ---------- propiedades de un fondo web ----------
    // Filas propias (no un Repeater directo dentro del FormLayout, que le rompe el diseño).
    ColumnLayout {
        Kirigami.FormData.label: "Propiedades:"
        Kirigami.FormData.labelAlignment: Qt.AlignTop
        visible: root.isWeb && root.webPropList.length > 0
        spacing: Kirigami.Units.smallSpacing

        Repeater {
            model: root.isWeb ? root.webPropList : []
            delegate: RowLayout {
                id: prop
                required property var modelData
                readonly property string kind: modelData.type
                spacing: Kirigami.Units.largeSpacing

                QQC2.Label {
                    Layout.preferredWidth: Kirigami.Units.gridUnit * 8
                    text: prop.modelData.text
                    elide: Text.ElideRight
                }
                KQuickControls.ColorButton {
                    visible: prop.kind === "color"
                    color: root.toColor(root.webValue(prop.modelData))
                    showAlphaChannel: false
                    onAccepted: (c) => root.setProp(prop.modelData.name, c.r.toFixed(3) + " " + c.g.toFixed(3) + " " + c.b.toFixed(3))
                }
                QQC2.Slider {
                    visible: prop.kind === "slider"
                    from: Number(prop.modelData.min) || 0
                    to: prop.modelData.max !== undefined ? Number(prop.modelData.max) : 100
                    stepSize: Number(prop.modelData.step) || 0
                    value: Number(root.webValue(prop.modelData))
                    onMoved: root.setProp(prop.modelData.name, value)
                }
                QQC2.Label {
                    visible: prop.kind === "slider"
                    text: Number(root.webValue(prop.modelData)).toFixed(prop.modelData.step && prop.modelData.step < 1 ? 1 : 0)
                }
                QQC2.CheckBox {
                    visible: prop.kind === "bool"
                    checked: !!root.webValue(prop.modelData)
                    onToggled: root.setProp(prop.modelData.name, checked)
                }
                QQC2.ComboBox {
                    visible: prop.kind === "combo"
                    model: prop.modelData.options || []
                    textRole: "label"
                    valueRole: "value"
                    currentIndex: Math.max(0, indexOfValue(root.webValue(prop.modelData)))
                    onActivated: root.setProp(prop.modelData.name, currentValue)
                }
                QQC2.TextField {
                    visible: prop.kind === "textinput"
                    Layout.preferredWidth: Kirigami.Units.gridUnit * 14
                    text: String(root.webValue(prop.modelData))
                    onEditingFinished: root.setProp(prop.modelData.name, text)
                }
            }
        }
    }
    QQC2.ComboBox {
        Kirigami.FormData.label: "Cuadros por segundo:"
        visible: root.selected !== null && root.selected.type === "web"
        textRole: "text"
        valueRole: "value"
        model: [
            { text: "10 (ahorro)", value: 10 },
            { text: "20", value: 20 },
            { text: "30", value: 30 },
            { text: "60 (más fluido, gasta más)", value: 60 }
        ]
        currentIndex: Math.max(0, indexOfValue(root.cfg_WebFps))
        onActivated: root.cfg_WebFps = currentValue
    }

    // ---------- general ----------
    Item { Kirigami.FormData.isSection: true }

    QQC2.ComboBox {
        id: fill
        Kirigami.FormData.label: "Ajuste:"
        model: ["Estirar", "Ajustar", "Rellenar (recortar)"]
    }
    QQC2.ComboBox {
        Kirigami.FormData.label: "Imágenes y escenas:"
        textRole: "text"
        valueRole: "value"
        model: [
            { text: "10 cuadros/s (ahorro)", value: 10 },
            { text: "20 cuadros/s", value: 20 },
            { text: "30 cuadros/s (más fluido)", value: 30 }
        ]
        currentIndex: Math.max(0, indexOfValue(root.cfg_ImageFps))
        onActivated: root.cfg_ImageFps = currentValue
    }
    QQC2.CheckBox {
        id: muted
        Kirigami.FormData.label: "Sonido:"
        text: "Silenciado"
    }
    RowLayout {
        Kirigami.FormData.label: "Volumen:"
        enabled: !muted.checked
        QQC2.Slider {
            id: volume
            from: 0; to: 100; stepSize: 5
        }
        QQC2.Label { text: volume.value + " %" }
    }

    Item { Kirigami.FormData.isSection: true }

    QQC2.CheckBox {
        id: pauseMax
        Kirigami.FormData.label: "Pausar:"
        text: "Con una ventana maximizada o en pantalla completa"
    }
    QQC2.CheckBox {
        id: pauseBattery
        text: "Al usar la batería"
    }
    QQC2.CheckBox {
        id: pausePowerSave
        text: "Con el perfil de ahorro de energía"
    }
    QQC2.CheckBox {
        id: pauseLock
        text: "Con la pantalla bloqueada"
    }

    Item { Kirigami.FormData.isSection: true }

    QQC2.CheckBox {
        id: playlistEnabled
        Kirigami.FormData.label: "Rotación:"
        text: "Cambiar de fondo automáticamente"
    }
    RowLayout {
        enabled: playlistEnabled.checked
        QQC2.Label { text: "Cada" }
        QQC2.SpinBox {
            id: playlistMinutes
            from: 1; to: 1440
        }
        QQC2.Label { text: "minutos a la vista" }
    }
    QQC2.CheckBox {
        id: playlistRandom
        enabled: playlistEnabled.checked
        text: "En orden aleatorio"
    }

    // ---------- diálogos ----------
    FileDialog {
        id: fileDialog
        title: "Importar fondos"
        fileMode: FileDialog.OpenFiles
        nameFilters: [
            "Videos e imágenes (*.mp4 *.webm *.mkv *.mov *.avi *.m4v *.gif *.jpg *.jpeg *.png *.webp *.avif *.jxl *.bmp)",
            "Todos los archivos (*)"
        ]
        onAccepted: importer.add(selectedFiles)
    }

    Kirigami.PromptDialog {
        id: removeDialog
        title: "Quitar de la biblioteca"
        subtitle: root.selected
            ? "Se borra «" + root.selected.title + "» de la biblioteca (el archivo original no se toca)."
            : ""
        standardButtons: Kirigami.Dialog.Ok | Kirigami.Dialog.Cancel
        onAccepted: library.remove(root.selected.dir)
    }
}
