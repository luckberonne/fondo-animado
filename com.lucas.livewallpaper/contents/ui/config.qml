import QtQuick
import QtQuick.Controls as QQC2
import QtQuick.Layouts
import QtQuick.Dialogs
import org.kde.kirigami as Kirigami

Kirigami.FormLayout {
    id: root
    twinFormLayouts: parentLayout

    property var configDialog
    property alias formLayout: root

    property alias cfg_VideoUrl: pathField.text
    property alias cfg_FillMode: fill.currentIndex
    property alias cfg_Muted: muted.checked
    property alias cfg_Volume: volume.value
    property alias cfg_PauseOnMaximized: pauseMax.checked
    property alias cfg_PauseOnBattery: pauseBattery.checked
    property alias cfg_PauseOnLock: pauseLock.checked

    RowLayout {
        Kirigami.FormData.label: "Video:"
        QQC2.TextField {
            id: pathField
            Layout.preferredWidth: Kirigami.Units.gridUnit * 20
            placeholderText: "Elegí un video o arrastralo al escritorio"
        }
        QQC2.Button {
            icon.name: "document-open"
            text: "Elegir…"
            onClicked: dialog.open()
        }
    }

    QQC2.ComboBox {
        id: fill
        Kirigami.FormData.label: "Ajuste:"
        model: ["Estirar", "Ajustar", "Rellenar (recortar)"]
    }

    Item { Kirigami.FormData.isSection: true }

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
            Layout.preferredWidth: Kirigami.Units.gridUnit * 12
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
        id: pauseLock
        text: "Con la pantalla bloqueada"
    }

    FileDialog {
        id: dialog
        title: "Elegir video"
        nameFilters: ["Videos (*.mp4 *.webm *.mkv *.mov *.avi *.m4v *.gif)", "Todos los archivos (*)"]
        onAccepted: pathField.text = selectedFile.toString()
    }
}
