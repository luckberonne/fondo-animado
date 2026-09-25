import QtQuick
import org.kde.plasma.plasma5support as P5Support
import "util.js" as Util

// Acceso a la biblioteca (~/.local/share/livewallpapers) a través de contents/code/biblioteca.py.
QtObject {
    id: lib

    property var projects: []
    property string path: ""
    property bool loaded: false
    property int busy: 0            // comandos en curso

    signal imported(var project)
    signal removed(string dir)
    signal failed(string message)

    readonly property string script: Util.localPath(Qt.resolvedUrl("../code/biblioteca.py"))

    function refresh() { run("listar", []) }
    function importFile(filePath) { run("importar", [filePath]) }
    function remove(dir) { run("quitar", [dir]) }

    function find(dir) {
        for (let i = 0; i < projects.length; i++)
            if (projects[i].dir === dir)
                return projects[i];
        // Si la ruta guardada no existe para este usuario (p. ej. la pantalla de inicio de sesión corre como
        // otro usuario y no ve tu carpeta personal), se busca un proyecto con el mismo nombre en su propia biblioteca.
        const base = String(dir).split("/").pop();
        if (base) {
            for (let i = 0; i < projects.length; i++)
                if (projects[i].dir.split("/").pop() === base)
                    return projects[i];
        }
        return null;
    }

    property int _seq: 0
    property var _pending: ({})

    function run(cmd, args) {
        // El número al final hace única cada orden: el motor executable no repite una fuente conectada.
        const line = "python3 " + Util.quote(script) + " " + cmd + " "
                   + args.map(Util.quote).join(" ") + " # " + (++_seq);
        _pending[line] = cmd;
        busy++;
        exec.connectSource(line);
    }

    property P5Support.DataSource exec: P5Support.DataSource {
        engine: "executable"
        onNewData: (source, data) => {
            const cmd = lib._pending[source];
            delete lib._pending[source];
            disconnectSource(source);
            lib.busy = Math.max(0, lib.busy - 1);

            let res;
            try {
                res = JSON.parse((data["stdout"] || "").trim().split("\n").pop());
            } catch (e) {
                lib.failed("Respuesta inválida de biblioteca.py: " + (data["stderr"] || data["stdout"] || ""));
                return;
            }
            if (!res.ok) {
                lib.failed(res.error || "Error desconocido");
                return;
            }
            if (cmd === "listar") {
                lib.projects = res.proyectos;
                lib.path = res.biblioteca;
                lib.loaded = true;
            } else if (cmd === "importar") {
                lib.imported(res.proyecto);
                lib.refresh();
            } else if (cmd === "quitar") {
                lib.removed(res.quitado);
                lib.refresh();
            }
        }
    }
}
