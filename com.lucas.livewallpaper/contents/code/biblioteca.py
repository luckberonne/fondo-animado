#!/usr/bin/env python3
"""Biblioteca de proyectos de Fondo Animado.

Cada proyecto es una carpeta en ~/.local/share/livewallpapers/<slug>/ con:
  project.json  {"title", "type": "video" | "image", "file", "preview", "poster", "source"}
  preview.webp  miniatura (animada para videos, ~3 s; fija para imágenes), 320 px
  poster.jpg    primer fotograma a resolución completa (solo videos; se muestra mientras carga)
  <video o imagen>

Uso (toda la salida es JSON en una línea, para leerla desde QML):
  biblioteca.py listar
  biblioteca.py importar <video | imagen | carpeta de Wallpaper Engine> [--enlazar] [--original]

Al importar un video se optimiza para usarlo de fondo (salvo --original o --enlazar): si pasa de
30 fps o de 1080p, o está en un códec que la GPU no decodifica, se recodifica a H.264 ≤30 fps con
la GPU integrada (VAAPI) o, si no se puede, con libx264.
  biblioteca.py quitar <carpeta del proyecto>
"""
import json
import os
import re
import shutil
import subprocess
import sys
import unicodedata

VIDEO_EXT = {".mp4", ".webm", ".mkv", ".mov", ".avi", ".m4v", ".gif"}
IMAGE_EXT = {".jpg", ".jpeg", ".png", ".webp", ".avif", ".jxl", ".bmp"}
LIB = os.path.join(os.environ.get("XDG_DATA_HOME") or os.path.expanduser("~/.local/share"), "livewallpapers")


def salir(obj, codigo=0):
    print(json.dumps(obj, ensure_ascii=False))
    sys.exit(codigo)


def error(msg):
    salir({"ok": False, "error": msg}, 1)


def slug(texto):
    t = unicodedata.normalize("NFKD", texto).encode("ascii", "ignore").decode()
    t = re.sub(r"[^a-zA-Z0-9]+", "-", t).strip("-").lower()
    return t[:60] or "fondo"


def carpeta_libre(nombre):
    base = os.path.join(LIB, nombre)
    ruta, n = base, 2
    while os.path.exists(ruta):
        ruta, n = f"{base}-{n}", n + 1
    return ruta


def duracion(video):
    try:
        out = subprocess.run(
            ["ffprobe", "-v", "error", "-show_entries", "format=duration", "-of", "csv=p=0", video],
            capture_output=True, text=True, timeout=30).stdout.strip()
        return float(out)
    except (ValueError, subprocess.SubprocessError):
        return 0.0


FPS_MAX = 30
ALTO_MAX = 1080
CODECS_HW = {"h264", "hevc", "vp9", "av1"}


def info_video(video):
    """(códec, fps, alto) del primer flujo de video."""
    try:
        out = subprocess.run(
            ["ffprobe", "-v", "error", "-select_streams", "v:0", "-show_entries",
             "stream=codec_name,avg_frame_rate,r_frame_rate,height", "-of", "json", video],
            capture_output=True, text=True, timeout=30).stdout
        st = json.loads(out)["streams"][0]
    except (ValueError, KeyError, IndexError, subprocess.SubprocessError):
        return None, 0.0, 0

    def fps(txt):
        try:
            n, d = txt.split("/")
            return float(n) / float(d) if float(d) else 0.0
        except (ValueError, AttributeError):
            return 0.0
    return st.get("codec_name"), fps(st.get("avg_frame_rate")) or fps(st.get("r_frame_rate")), int(st.get("height") or 0)


def nodo_render_integrado():
    """Nodo /dev/dri/renderD* de una GPU que no sea NVIDIA (la integrada en laptops híbridas)."""
    base = "/sys/class/drm"
    for nombre in sorted(os.listdir(base)):
        if not nombre.startswith("renderD"):
            continue
        try:
            with open(os.path.join(base, nombre, "device", "vendor")) as f:
                vendor = f.read().strip()
        except OSError:
            continue
        if vendor != "0x10de":
            return "/dev/dri/" + nombre
    return None


def necesita_optimizar(video):
    codec, fps, alto = info_video(video)
    return codec not in CODECS_HW or fps > FPS_MAX + 0.5 or alto > ALTO_MAX


def optimizar(video, salida):
    ff = ["ffmpeg", "-hide_banner", "-loglevel", "error", "-y"]
    filtro = f"fps='min(source_fps,{FPS_MAX})',scale=-2:'min({ALTO_MAX},ih)':flags=lanczos"
    audio = ["-c:a", "aac", "-b:a", "160k"]
    nodo = nodo_render_integrado()
    if nodo:
        r = subprocess.run(ff + ["-vaapi_device", nodo, "-i", video,
                                 "-vf", filtro + ",format=nv12,hwupload",
                                 "-c:v", "h264_vaapi", "-qp", "20"] + audio + ["-movflags", "+faststart", salida],
                           timeout=3600)
        if r.returncode == 0:
            return
    subprocess.run(ff + ["-i", video, "-vf", filtro + ",format=yuv420p",
                         "-c:v", "libx264", "-preset", "veryfast", "-crf", "20"] + audio + ["-movflags", "+faststart", salida],
                   check=True, timeout=3600)


def generar_previa_imagen(imagen, destino):
    subprocess.run(["ffmpeg", "-hide_banner", "-loglevel", "error", "-y", "-i", imagen,
                    "-vf", "scale=320:-2:flags=lanczos", "-frames:v", "1", "-c:v", "libwebp", "-quality", "80",
                    os.path.join(destino, "preview.webp")], check=True, timeout=120)


def generar_previas(video, destino):
    dur = duracion(video)
    inicio = min(1.0, dur / 3) if dur else 0
    ff = ["ffmpeg", "-hide_banner", "-loglevel", "error", "-y"]
    subprocess.run(ff + ["-ss", f"{inicio:.2f}", "-t", "3", "-i", video,
                         "-vf", "fps=12,scale=320:-2:flags=lanczos", "-an",
                         "-c:v", "libwebp_anim", "-loop", "0", "-quality", "70",
                         os.path.join(destino, "preview.webp")], check=True, timeout=300)
    subprocess.run(ff + ["-i", video, "-frames:v", "1", "-q:v", "3",
                         os.path.join(destino, "poster.jpg")], check=True, timeout=120)


def leer_proyecto(carpeta):
    try:
        with open(os.path.join(carpeta, "project.json"), encoding="utf-8") as f:
            p = json.load(f)
    except (OSError, ValueError):
        return None
    tipo = str(p.get("type", "")).lower()
    archivo = p.get("file", "")
    if not archivo or not os.path.exists(os.path.join(carpeta, archivo)):
        return None
    return {
        "dir": carpeta,
        "title": p.get("title") or os.path.basename(carpeta),
        "type": tipo,
        "file": archivo,
        "preview": p.get("preview", ""),
        "poster": p.get("poster", ""),
        "properties": p.get("properties", {}),
    }


def listar():
    proyectos = []
    if os.path.isdir(LIB):
        for nombre in sorted(os.listdir(LIB), key=str.lower):
            p = leer_proyecto(os.path.join(LIB, nombre))
            if p:
                proyectos.append(p)
    salir({"ok": True, "biblioteca": LIB, "proyectos": proyectos})


def importar(origen, enlazar, original):
    origen = os.path.abspath(os.path.expanduser(origen))
    titulo = None
    if os.path.isdir(origen):
        # Carpeta de Wallpaper Engine (Steam Workshop): solo el tipo video por ahora.
        try:
            with open(os.path.join(origen, "project.json"), encoding="utf-8") as f:
                we = json.load(f)
        except (OSError, ValueError):
            error("La carpeta no tiene un project.json válido")
        if str(we.get("type", "")).lower() != "video":
            error(f"Tipo «{we.get('type')}» de Wallpaper Engine no soportado (solo video)")
        video = os.path.join(origen, we.get("file", ""))
        titulo = we.get("title")
    else:
        video = origen
    if not os.path.isfile(video):
        error(f"No existe el archivo: {video}")
    ext = os.path.splitext(video)[1].lower()
    if ext in VIDEO_EXT:
        tipo = "video"
    elif ext in IMAGE_EXT:
        tipo = "image"
    else:
        error(f"Formato no soportado: {ext or 'sin extensión'}")

    titulo = titulo or os.path.splitext(os.path.basename(video))[0].replace("_", " ")
    os.makedirs(LIB, exist_ok=True)
    destino = carpeta_libre(slug(titulo))
    os.makedirs(destino)
    archivo = ("video" if tipo == "video" else "imagen") + ext
    try:
        if tipo == "video" and not (enlazar or original) and necesita_optimizar(video):
            archivo = "video.mp4"
            optimizar(video, os.path.join(destino, archivo))
        elif enlazar:
            os.symlink(video, os.path.join(destino, archivo))
        else:
            shutil.copy2(video, os.path.join(destino, archivo))
        if tipo == "video":
            generar_previas(os.path.join(destino, archivo), destino)
        else:
            generar_previa_imagen(video, destino)
    except (OSError, subprocess.SubprocessError) as e:
        shutil.rmtree(destino, ignore_errors=True)
        error(f"No se pudo importar: {e}")

    proyecto = {"title": titulo, "type": tipo, "file": archivo, "preview": "preview.webp",
                "poster": "poster.jpg" if tipo == "video" else "", "source": video}
    if tipo == "image":
        # Animación por defecto de una imagen fija; se edita desde la configuración.
        proyecto["properties"] = {"zoom": 8, "periodo": 40, "particulas": "ninguna", "cantidad": 60}
    with open(os.path.join(destino, "project.json"), "w", encoding="utf-8") as f:
        json.dump(proyecto, f, ensure_ascii=False, indent=2)
    salir({"ok": True, "proyecto": leer_proyecto(destino)})


def quitar(carpeta):
    carpeta = os.path.realpath(carpeta)
    # Solo se borra lo que está directamente dentro de la biblioteca.
    if os.path.dirname(carpeta) != os.path.realpath(LIB) or not os.path.isfile(os.path.join(carpeta, "project.json")):
        error("Esa carpeta no es un proyecto de la biblioteca")
    shutil.rmtree(carpeta)
    salir({"ok": True, "quitado": carpeta})


if __name__ == "__main__":
    args = sys.argv[1:]
    if not args:
        error(__doc__.strip())
    cmd, resto = args[0], args[1:]
    if cmd == "listar":
        listar()
    elif cmd == "importar" and resto:
        importar(resto[0], "--enlazar" in resto[1:], "--original" in resto[1:])
    elif cmd == "quitar" and len(resto) == 1:
        quitar(resto[0])
    else:
        error(f"Comando desconocido: {' '.join(args)}")
