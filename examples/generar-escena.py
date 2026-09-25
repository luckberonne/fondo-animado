#!/usr/bin/env python3
"""Genera la escena de ejemplo `lago-escena/`: cielo, montañas y lago con reflejo (PNG puros, sin dependencias)
más su project.json. Uso: generar-escena.py [carpeta_de_salida]"""
import json, math, os, random, struct, subprocess, sys, zlib

W, H = 1600, 900
HORIZON = 522                                   # y del horizonte (el lago empieza aquí)
out = sys.argv[1] if len(sys.argv) > 1 else os.path.join(os.path.dirname(os.path.abspath(__file__)), "lago-escena")
os.makedirs(out, exist_ok=True)
random.seed(7)

def png(path, rows, alpha):
    raw = b"".join(b"\x00" + bytes(r) for r in rows)
    def chunk(t, d):
        c = struct.pack(">I", len(d)) + t + d
        return c + struct.pack(">I", zlib.crc32(t + d) & 0xFFFFFFFF)
    data = b"\x89PNG\r\n\x1a\n" + chunk(b"IHDR", struct.pack(">IIBBBBB", W, H, 8, 6 if alpha else 2, 0, 0, 0)) \
        + chunk(b"IDAT", zlib.compress(raw, 6)) + chunk(b"IEND", b"")
    open(path, "wb").write(data)

def mix(a, b, t):
    return tuple(a[i] + (b[i] - a[i]) * t for i in range(3))

# ---------- cielo ----------
TOP, MID, LOW = (6, 8, 26), (34, 22, 74), (214, 108, 96)
def sky_color(y):
    t = min(1.0, y / HORIZON)
    return mix(TOP, MID, t / 0.6) if t < 0.6 else mix(MID, LOW, ((t - 0.6) / 0.4) ** 1.8)

sky = [[0] * (W * 3) for _ in range(HORIZON + 1)]
for y in range(HORIZON + 1):
    r, g, b = sky_color(y)
    row = sky[y]
    for x in range(W):
        row[x * 3], row[x * 3 + 1], row[x * 3 + 2] = int(r), int(g), int(b)
for _ in range(420):                            # estrellas
    x, y = random.randrange(W), random.randrange(int(HORIZON * 0.8))
    v = random.randint(120, 255)
    for dx, dy, k in ((0, 0, 1), (1, 0, .4), (-1, 0, .4), (0, 1, .4), (0, -1, .4)):
        if 0 <= x + dx < W and 0 <= y + dy < HORIZON:
            for c in range(3):
                i = (x + dx) * 3 + c
                sky[y + dy][i] = min(255, int(sky[y + dy][i] + v * k))
MX, MY, MR = 1120, 190, 40                      # luna
for y in range(MY - 150, MY + 150):
    for x in range(MX - 150, MX + 150):
        if 0 <= x < W and 0 <= y < HORIZON:
            d = math.hypot(x - MX, y - MY)
            k = 1.0 if d < MR else max(0.0, 1 - (d - MR) / 110) ** 2.2 * 0.55
            if k > 0:
                for c, v in enumerate((250, 246, 224)):
                    i = x * 3 + c
                    sky[y][i] = int(sky[y][i] + (v - sky[y][i]) * min(1.0, k))
png(os.path.join(out, "cielo.png"), [[*sky[min(y, HORIZON)]] for y in range(H)], False)

# ---------- montañas (RGBA) ----------
def ridge(base, amp, seed):
    ph = [random.Random(seed + i).uniform(0, 6.28) for i in range(5)]
    return [int(base - amp * (0.5 + 0.5 * sum(math.sin(x / (W / (2 + 3 * i)) * 6.28 * 0.6 + ph[i]) / (i + 1) for i in range(5)) / 2.3))
            for x in range(W)]
far, near = ridge(430, 130, 1), ridge(490, 110, 9)
FAR_C, NEAR_C = (44, 34, 96), (8, 10, 24)
def mount_pixel(x, y):
    if y >= near[x]:
        return mix(NEAR_C, (16, 14, 36), min(1, (y - near[x]) / 80)), 255
    if y >= far[x]:
        return mix(FAR_C, (150, 84, 110), min(1, (y - far[x]) / 220) ** 1.5), 255
    return None, 0
rows = []
for y in range(H):
    row = bytearray(W * 4)
    if y <= HORIZON + 6:
        for x in range(W):
            c, a = mount_pixel(x, y)
            if a:
                row[x * 4:x * 4 + 4] = bytes((int(c[0]), int(c[1]), int(c[2]), 255))
    rows.append(row)
png(os.path.join(out, "montanas.png"), rows, True)

# ---------- lago con reflejo (RGBA) ----------
def scene_pixel(x, y):
    y = max(0, min(HORIZON, int(y)))
    c, a = mount_pixel(x, y)
    if a:
        return c
    return tuple(sky[y][x * 3:x * 3 + 3])
rows = []
for y in range(H):
    row = bytearray(W * 4)
    if y >= HORIZON:
        d = y - HORIZON
        for x in range(W):
            r, g, b = scene_pixel(x, HORIZON - d * 0.9)
            k = 0.5 - 0.22 * min(1, d / 380)
            r, g, b = r * k * 0.8, g * k * 0.9, b * k * 1.2 + 8
            m = abs(x - MX) / (24 + d * 0.32)               # columna de reflejo de la luna
            if m < 1:
                s = (1 - m) ** 2 * (0.9 - 0.5 * min(1, d / 380))
                r, g, b = r + (250 - r) * s, g + (240 - g) * s, b + (215 - b) * s
            row[x * 4:x * 4 + 4] = bytes((min(255, int(r)), min(255, int(g)), min(255, int(b)), 255))
    rows.append(row)
png(os.path.join(out, "lago.png"), rows, True)

# ---------- project.json ----------
json.dump({
    "title": "Lago nocturno (escena)",
    "type": "scene",
    "file": "project.json",
    "preview": "preview.webp",
    "poster": "poster.jpg",                     # imagen completa: la pantalla de bloqueo muestra esta
    "general": {"properties": {
        "parallax": {"order": 0, "text": "Movimiento de cámara", "type": "slider", "min": 0, "max": 100, "step": 5, "value": 50},
        "velocidad": {"order": 1, "text": "Velocidad", "type": "slider", "min": 0, "max": 3, "step": 0.1, "value": 1}
    }},
    "scene": {"layers": [
        {"image": "cielo.png", "depth": 0.0},
        {"particles": "luciernagas", "count": 22, "depth": 0.15},
        {"image": "montanas.png", "depth": 0.35},
        {"image": "lago.png", "depth": 0.55,
         "effect": {"shader": "agua", "strength": 0.006, "speed": 1.0, "horizon": HORIZON / H}},
        {"particles": "luciernagas", "count": 30, "depth": 1.0}
    ]}
}, open(os.path.join(out, "project.json"), "w"), ensure_ascii=False, indent=2)

# Las capas se dibujaron a 1600x900; se llevan a 1920x1080 con lanczos para que los bordes no se vean escalonados.
for n in ("cielo", "montanas", "lago"):
    f = os.path.join(out, n + ".png")
    subprocess.run(["ffmpeg", "-hide_banner", "-loglevel", "error", "-y", "-i", f, "-vf", "scale=1920:1080:flags=lanczos",
                    f + ".tmp.png"], check=True)
    os.replace(f + ".tmp.png", f)

# póster (composición completa a resolución de pantalla) y miniatura
subprocess.run(["ffmpeg", "-hide_banner", "-loglevel", "error", "-y", "-i", f"{out}/cielo.png", "-i", f"{out}/montanas.png",
                "-i", f"{out}/lago.png", "-filter_complex", "[0][1]overlay[a];[a][2]overlay",
                "-frames:v", "1", "-q:v", "3", f"{out}/poster.jpg"], check=True)
# miniatura
subprocess.run(["ffmpeg", "-hide_banner", "-loglevel", "error", "-y", "-i", f"{out}/cielo.png", "-i", f"{out}/montanas.png",
                "-i", f"{out}/lago.png", "-filter_complex", "[0][1]overlay[a];[a][2]overlay,scale=320:-2",
                "-frames:v", "1", f"{out}/preview.webp"], check=False)
print(out)
