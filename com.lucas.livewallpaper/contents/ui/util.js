.pragma library

// Comilla un argumento para sh.
function quote(s) {
    return "'" + String(s).replace(/'/g, "'\\''") + "'";
}

// file:// de una ruta local, con cada tramo codificado (espacios, #, ?, etc.).
function fileUrl(path) {
    if (!path)
        return "";
    return "file://" + String(path).split("/").map(encodeURIComponent).join("/");
}

// Ruta local a partir de una URL file:// (lo inverso de fileUrl).
function localPath(url) {
    const s = String(url);
    return s.startsWith("file://") ? decodeURIComponent(s.slice(7)) : s;
}

// Archivo principal de un proyecto como URL. Los proyectos «sueltos» (VideoUrl) traen `url`.
function projectUrl(p) {
    if (!p)
        return "";
    return p.url ? p.url : fileUrl(p.dir + "/" + p.file);
}

function assetUrl(p, name) {
    return p && p.dir && name ? fileUrl(p.dir + "/" + name) : "";
}

// Propiedades efectivas: las del project.json pisadas por las editadas en la configuración.
function effectiveProps(p, overridesJson) {
    const base = Object.assign({ zoom: 8, periodo: 40, particulas: "ninguna", cantidad: 60 }, (p && p.properties) || {});
    let over = {};
    try { over = JSON.parse(overridesJson || "{}"); } catch (e) { over = {}; }
    return Object.assign(base, (p && over[p.dir]) || {});
}

// Valores editados de un proyecto web: {nombre: valor} (los defaults viven en el project.json).
function webOverrides(p, overridesJson) {
    let over = {};
    try { over = JSON.parse(overridesJson || "{}"); } catch (e) { over = {}; }
    return (p && over[p.dir]) || {};
}
