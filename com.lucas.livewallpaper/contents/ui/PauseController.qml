import QtQuick
import QtQuick.Window
import org.kde.taskmanager as TaskManager
import org.kde.plasma.plasma5support as P5Support

// Decide si el fondo debe reproducirse. Todo desemboca en `shouldPlay`.
Item {
    id: ctl

    property bool pauseOnMaximized: true
    property bool pauseOnBattery: false
    property bool pauseOnLock: true
    property bool pauseOnPowerSave: false
    property bool manualPause: false

    readonly property bool coveredByWindow: pauseOnMaximized && coveringCount > 0
    readonly property bool onBattery: pauseOnBattery && !power.pluggedIn
    readonly property bool powerSaving: pauseOnPowerSave && profile.saving
    readonly property bool locked: pauseOnLock && lock.active

    readonly property bool wantPlay: !manualPause && !coveredByWindow && !onBattery && !powerSaving && !locked
    // Con histéresis: al pasar entre ventanas con Alt+Tab no se pausa/reanuda en falso.
    property bool shouldPlay: wantPlay

    onWantPlayChanged: hysteresis.restart()
    Timer {
        id: hysteresis
        interval: 300
        onTriggered: ctl.shouldPlay = ctl.wantPlay
    }

    // ---------- ventanas maximizadas / pantalla completa en esta pantalla ----------
    property int coveringCount: 0

    TaskManager.VirtualDesktopInfo { id: virtualDesktopInfo }
    TaskManager.ActivityInfo { id: activityInfo }

    TaskManager.TasksModel {
        id: tasksModel
        virtualDesktop: virtualDesktopInfo.currentDesktop
        activity: activityInfo.currentActivity
        screenGeometry: Qt.rect(ctl.Screen.virtualX, ctl.Screen.virtualY, ctl.Screen.width, ctl.Screen.height)
        filterByVirtualDesktop: true
        filterByActivity: true
        filterByScreen: true
        filterMinimized: true
        filterHidden: true
        groupMode: TaskManager.TasksModel.GroupDisabled
    }

    // Se cuenta siempre (es barato), así al activar la opción el número ya está al día.
    Connections {
        target: tasksModel
        function onCountChanged() { ctl.recount() }
        function onDataChanged() { ctl.recount() }
        function onModelReset() { ctl.recount() }
    }
    Component.onCompleted: recount()
    function recount() {
        let n = 0;
        const A = TaskManager.AbstractTasksModel;
        for (let i = 0; i < tasksModel.count; i++) {
            const idx = tasksModel.index(i, 0);
            if (tasksModel.data(idx, A.IsMaximized) === true || tasksModel.data(idx, A.IsFullScreen) === true)
                n++;
        }
        coveringCount = n;
    }

    // ---------- batería ----------
    P5Support.DataSource {
        id: power
        engine: "powermanagement"
        connectedSources: ctl.pauseOnBattery ? ["AC Adapter"] : []
        readonly property bool pluggedIn: {
            const d = data["AC Adapter"];
            return !d || d["Plugged in"] !== false;
        }
    }

    // ---------- perfil de energía (power-profiles-daemon) ----------
    P5Support.DataSource {
        id: profile
        engine: "executable"
        property bool saving: false
        interval: 5000
        connectedSources: ctl.pauseOnPowerSave ? ["powerprofilesctl get"] : []
        onNewData: (source, data) => saving = (data["stdout"] || "").trim() === "power-saver"
    }

    // ---------- pantalla bloqueada ----------
    P5Support.DataSource {
        id: lock
        engine: "executable"
        readonly property string cmd: "qdbus6 org.freedesktop.ScreenSaver /ScreenSaver org.freedesktop.ScreenSaver.GetActive"
        property bool active: false
        interval: 4000
        connectedSources: ctl.pauseOnLock ? [cmd] : []
        onNewData: (source, data) => active = (data["stdout"] || "").trim() === "true"
    }
}
