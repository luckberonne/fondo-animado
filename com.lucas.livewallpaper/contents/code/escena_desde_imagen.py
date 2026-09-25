#!/usr/bin/env python3
"""Crea una escena de Fondo Animado desde una imagen: lo oscuro grande (los personajes) queda quieto y el
resto (esquirlas, explosiones, humo) se mueve con un shader. Sin dependencias (usa ffmpeg).

Uso: escena_desde_imagen.py imagen.jpg [carpeta_salida] [--titulo T] [--fuerza 0.012] [--velocidad 1]
                                       [--umbral 40] [--area-min 0.008] [--quieto x,y]... [--mueve x,y]... [--importar]

Genera en la carpeta: imagen.jpg (1920x1080), mascara.png, poster.jpg, preview.webp y project.json.
Con --importar la agrega a la biblioteca (~/.local/share/livewallpapers).

Cómo se decide qué queda quieto:
1. Baja la imagen a 480x270 y marca los píxeles oscuros (luminancia < umbral).
2. Cierra las rendijas finas del contorno, inunda el «exterior» desde los bordes por los píxeles claros: lo que no
   se alcanza (boca, ojos, brillos dentro del personaje) queda encerrado y cuenta como personaje.
3. Se quedan solo las regiones grandes (área > area-min del cuadro): las esquirlas oscuras sueltas se mueven.
   Con --quieto x,y / --mueve x,y (coordenadas en 1920x1080) se fuerza una región concreta a quedarse quieta o a
   moverse (la salida lista cada región con su centro, para elegir).
4. Se agranda un poco y se suaviza al subir a 1920x1080 (blanco = quieto, negro = se mueve).
"""
import json, os, re, subprocess, sys, unicodedata
from collections import deque

args = [a for a in sys.argv[1:]]
def opt(name, default, cast=str):
    if name in args:
        i = args.index(name); v = cast(args[i + 1]); del args[i:i + 2]; return v
    return default
umbral = opt("--umbral", 40, int); area_min = opt("--area-min", 0.008, float)
titulo = opt("--titulo", None); fuerza = opt("--fuerza", 0.012, float); velocidad = opt("--velocidad", 1.0, float)
def opt_multi(name):
    vals = []
    while name in args:
        i = args.index(name); vals.append(tuple(int(v) for v in args[i + 1].split(","))); del args[i:i + 2]
    return vals
quietos = opt_multi("--quieto"); mueves = opt_multi("--mueve")     # puntos (x,y) en 1920x1080
importar = "--importar" in args
if importar: args.remove("--importar")
if not args:
    sys.exit(__doc__)
src = os.path.abspath(args[0])
titulo = titulo or os.path.splitext(os.path.basename(src))[0].replace("_", " ").replace("-", " ")
slug = re.sub(r"[^a-z0-9]+", "-", unicodedata.normalize("NFKD", titulo).encode("ascii", "ignore").decode().lower()).strip("-")[:50] or "escena"
out = os.path.abspath(args[1]) if len(args) > 1 else os.path.join(os.getcwd(), slug + "-escena")
os.makedirs(out, exist_ok=True)
dst = os.path.join(out, "mascara.png")
W, H = 480, 270

rgb = subprocess.run(["ffmpeg", "-hide_banner", "-loglevel", "error", "-i", src, "-vf", f"scale={W}:{H}:flags=area,format=rgb24",
                      "-frames:v", "1", "-f", "rawvideo", "-"], capture_output=True, check=True).stdout
lum = [(rgb[i * 3] * 299 + rgb[i * 3 + 1] * 587 + rgb[i * 3 + 2] * 114) // 1000 for i in range(W * H)]
dark = [v < umbral for v in lum]

def grow(m, r):
    """Dilatación cuadrada de radio r (separable)."""
    tmp = [False] * (W * H)
    for y in range(H):
        row = y * W
        run = -10**9
        last = [False] * W
        # ventana deslizante: True si hay algún True a distancia <= r en la fila
        idx = [x for x in range(W) if m[row + x]]
        for x in idx:
            for xx in range(max(0, x - r), min(W, x + r + 1)):
                tmp[row + xx] = True
    out = [False] * (W * H)
    for x in range(W):
        idx = [y for y in range(H) if tmp[y * W + x]]
        for y in idx:
            for yy in range(max(0, y - r), min(H, y + r + 1)):
                out[yy * W + x] = True
    return out

def shrink(m, r):
    """Erosión = negar, dilatar, negar."""
    inv = grow([not v for v in m], r)
    return [not v for v in inv]

# Se cierran las rendijas finas del contorno (p. ej. la sonrisa) antes de inundar el exterior:
# se agrandan los oscuros, se inunda, y se vuelve al tamaño original.
CIERRE = 4
dark_grown = grow(dark, CIERRE)
outside = [False] * (W * H)
q = deque()
def push(i):
    if not dark_grown[i] and not outside[i]:
        outside[i] = True
        q.append(i)
for x in range(W):
    push(x); push((H - 1) * W + x)
for y in range(H):
    push(y * W); push(y * W + W - 1)
while q:
    i = q.popleft(); x, y = i % W, i // W
    if x > 0: push(i - 1)
    if x < W - 1: push(i + 1)
    if y > 0: push(i - W)
    if y < H - 1: push(i + W)
static = shrink([not o for o in outside], CIERRE)      # oscuros + encerrados, ya sin el margen añadido

# Lo «encerrado» solo cuenta como personaje si es cálido (boca, ojos, dientes). Los fluidos y esquirlas azules o
# violetas que quedan rodeados de zonas oscuras se siguen moviendo.
filled = [static[i] and not dark[i] for i in range(W * H)]
seen = [False] * (W * H)
for s0 in range(W * H):
    if filled[s0] and not seen[s0]:
        comp = [s0]; seen[s0] = True; k = 0
        while k < len(comp):
            i = comp[k]; k += 1; x, y = i % W, i // W
            for j, ok in ((i - 1, x > 0), (i + 1, x < W - 1), (i - W, y > 0), (i + W, y < H - 1)):
                if ok and filled[j] and not seen[j]:
                    seen[j] = True; comp.append(j)
        n = len(comp)
        r = sum(rgb[i * 3] for i in comp) / n; b = sum(rgb[i * 3 + 2] for i in comp) / n
        warm = r > b + 15
        if not warm:
            for i in comp: static[i] = False
        if n > 0.001 * W * H:
            print(f"relleno {n / (W * H) * 100:.2f} % en ({sum(i % W for i in comp) * 4 // n},{sum(i // W for i in comp) * 4 // n}): "
                  f"{'cálido → quieto' if warm else 'frío → se mueve'}", file=sys.stderr)

# componentes conexos: solo los grandes (más los forzados a mano)
label = [0] * (W * H); comps = {}; n = 0
for s0 in range(W * H):
    if static[s0] and not label[s0]:
        n += 1; comp = [s0]; label[s0] = n; k = 0
        while k < len(comp):
            i = comp[k]; k += 1; x, y = i % W, i // W
            for j, ok in ((i - 1, x > 0), (i + 1, x < W - 1), (i - W, y > 0), (i + W, y < H - 1)):
                if ok and static[j] and not label[j]:
                    label[j] = n; comp.append(j)
        comps[n] = comp

def region_at(px, py, radio=6):
    """Etiqueta de la región en (px,py) de 1920x1080 (o la más cercana dentro de `radio` píxeles de 480x270)."""
    cx, cy = px // 4, py // 4
    for r in range(radio + 1):
        for yy in range(max(0, cy - r), min(H, cy + r + 1)):
            for xx in range(max(0, cx - r), min(W, cx + r + 1)):
                if label[yy * W + xx]:
                    return label[yy * W + xx]
    return 0
forzar_quieto = {region_at(*p) for p in quietos} - {0}
forzar_mueve = {region_at(*p) for p in mueves} - {0}

keep = [False] * (W * H)
for lab, comp in comps.items():
    big = len(comp) > area_min * W * H
    quieta = (big or lab in forzar_quieto) and lab not in forzar_mueve
    if quieta:
        for i in comp: keep[i] = True
    if len(comp) > 0.001 * W * H:
        print(f"región {lab}: {len(comp) / (W * H) * 100:.2f} % del cuadro en ({sum(i % W for i in comp) * 4 // len(comp)},"
              f"{sum(i // W for i in comp) * 4 // len(comp)}) {'(quieta)' if quieta else '(se mueve)'}", file=sys.stderr)

gray = bytes(255 if k else 0 for k in keep)
subprocess.run(["ffmpeg", "-hide_banner", "-loglevel", "error", "-y", "-f", "rawvideo", "-pix_fmt", "gray", "-s", f"{W}x{H}", "-i", "-",
                "-vf", "dilation,dilation,dilation,scale=1920:1080:flags=bicubic,boxblur=7:2", "-frames:v", "1", dst],
               input=gray, check=True)

# ---------- imagen a 1920x1080, póster, miniatura y project.json ----------
def ff(*a):
    subprocess.run(["ffmpeg", "-hide_banner", "-loglevel", "error", "-y", *a], check=True)
ff("-i", src, "-vf", "scale=1920:1080:force_original_aspect_ratio=increase:flags=lanczos,crop=1920:1080", "-q:v", "2", os.path.join(out, "imagen.jpg"))
ff("-i", os.path.join(out, "imagen.jpg"), "-q:v", "3", os.path.join(out, "poster.jpg"))
ff("-i", os.path.join(out, "imagen.jpg"), "-vf", "scale=320:-2", "-quality", "80", os.path.join(out, "preview.webp"))
json.dump({
    "title": titulo, "type": "scene", "file": "project.json", "preview": "preview.webp", "poster": "poster.jpg",
    "general": {"properties": {
        "parallax": {"order": 0, "text": "Movimiento de cámara", "type": "slider", "min": 0, "max": 100, "step": 5, "value": 0},
        "velocidad": {"order": 1, "text": "Velocidad", "type": "slider", "min": 0, "max": 3, "step": 0.1, "value": velocidad},
        "fuerza": {"order": 2, "text": "Intensidad", "type": "slider", "min": 0, "max": 0.03, "step": 0.001, "value": fuerza}
    }},
    "scene": {"layers": [
        {"image": "imagen.jpg", "depth": 0.0,
         "effect": {"shader": "explosion", "mask": "mascara.png", "strength": fuerza, "strengthProp": "fuerza", "speed": 1.0, "cx": 0.55, "cy": 0.5}}
    ]}
}, open(os.path.join(out, "project.json"), "w"), ensure_ascii=False, indent=2)
print(out)
if importar:
    biblioteca = os.path.join(os.path.dirname(os.path.abspath(__file__)), "biblioteca.py")
    print(subprocess.run([sys.executable, biblioteca, "importar", out], capture_output=True, text=True).stdout.strip()[:200])
