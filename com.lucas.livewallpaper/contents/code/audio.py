#!/usr/bin/env python3
"""Audio del sistema para los fondos web de Fondo Animado (sin dependencias).

Captura lo que suena (monitor de la salida predeterminada, vía parec/PipeWire), calcula 64 bandas de
frecuencia (graves → agudos) y las emite por WebSocket en 127.0.0.1:<puerto> como texto JSON:
un arreglo de 128 valores 0-1, con el mismo formato de Wallpaper Engine (0-63 izquierdo, 64-127 derecho;
la captura es mono, así que ambos canales son iguales). ~30 cuadros por segundo.

Solo trabaja mientras haya clientes conectados; sin clientes durante 30 s, termina.
Uso: audio.py [--puerto 47800]
"""
import asyncio
import base64
import cmath
import hashlib
import json
import math
import struct
import sys

RATE = 22050
N = 512                  # muestras por transformada (23 ms)
HOP = RATE // 30         # muestras nuevas por cuadro (~30 cuadros/s)
BANDS = 64
F_MIN, F_MAX = 40.0, 10000.0
IDLE_EXIT = 30.0         # s sin clientes antes de salir
DB_FLOOR = 60.0          # por debajo de -60 dB relativo a escala completa → 0

PORT = 47800
if "--puerto" in sys.argv:
    PORT = int(sys.argv[sys.argv.index("--puerto") + 1])

# ---------- FFT radix-2 iterativa ----------
_rev = [int(format(i, f"0{N.bit_length() - 1}b")[::-1], 2) for i in range(N)]
_tw = [cmath.exp(-2j * math.pi * k / N) for k in range(N // 2)]
_win = [0.5 - 0.5 * math.cos(2 * math.pi * i / (N - 1)) for i in range(N)]


def fft(x):
    a = [x[_rev[i]] for i in range(N)]
    size = 2
    while size <= N:
        half, step = size // 2, N // size
        for start in range(0, N, size):
            k = 0
            for j in range(start, start + half):
                t = a[j + half] * _tw[k]
                a[j + half] = a[j] - t
                a[j] = a[j] + t
                k += step
        size *= 2
    return a


# Cada banda cubre un rango de bins con escala logarítmica.
def _band_edges():
    edges = []
    for b in range(BANDS + 1):
        f = F_MIN * (F_MAX / F_MIN) ** (b / BANDS)
        edges.append(f * N / RATE)
    out = []
    for b in range(BANDS):
        lo = int(edges[b])
        hi = max(lo + 1, int(edges[b + 1]))
        lo = min(max(1, lo), N // 2)
        out.append((lo, min(N // 2 + 1, max(lo + 1, hi))))
    return out


EDGES = _band_edges()


def bands_from(samples, prev):
    spec = fft([s * w for s, w in zip(samples, _win)])
    mags = [abs(c) for c in spec[: N // 2 + 1]]
    out = []
    for b, (lo, hi) in enumerate(EDGES):
        m = max(mags[lo:hi]) / (N / 4)          # ~1.0 = escala completa
        db = 20 * math.log10(m + 1e-9)
        v = min(1.0, max(0.0, 1 + db / DB_FLOOR))
        # subida rápida, bajada suave
        p = prev[b]
        out.append(v if v > p else p * 0.82 + v * 0.18)
    return out


# ---------- WebSocket mínimo (RFC 6455, solo enviar texto) ----------
GUID = "258EAFA5-E914-47DA-95CA-C5AB0DC85B11"
clients = set()


def frame(text):
    data = text.encode()
    n = len(data)
    head = b"\x81" + (bytes([n]) if n < 126 else b"\x7e" + struct.pack(">H", n))
    return head + data


async def handle(reader, writer):
    try:
        req = await asyncio.wait_for(reader.readuntil(b"\r\n\r\n"), 5)
        key = next((l.split(b":", 1)[1].strip() for l in req.split(b"\r\n") if l.lower().startswith(b"sec-websocket-key")), None)
        if not key:
            writer.close()
            return
        acc = base64.b64encode(hashlib.sha1(key + GUID.encode()).digest()).decode()
        writer.write(("HTTP/1.1 101 Switching Protocols\r\nUpgrade: websocket\r\nConnection: Upgrade\r\n"
                      f"Sec-WebSocket-Accept: {acc}\r\n\r\n").encode())
        await writer.drain()
        clients.add(writer)
        while await reader.read(1024):      # ignora lo que mande el cliente; termina al cerrarse
            pass
    except (asyncio.TimeoutError, asyncio.IncompleteReadError, ConnectionError, OSError):
        pass
    finally:
        clients.discard(writer)
        writer.close()


async def broadcast(values):
    msg = frame(json.dumps([round(v, 3) for v in values] * 2, separators=(",", ":")))
    for w in list(clients):
        try:
            w.write(msg)
            await w.drain()
        except (ConnectionError, OSError):
            clients.discard(w)


# ---------- captura ----------
async def default_sink():
    p = await asyncio.create_subprocess_exec("pactl", "get-default-sink", stdout=asyncio.subprocess.PIPE,
                                             stderr=asyncio.subprocess.DEVNULL)
    out, _ = await p.communicate()
    return out.decode().strip()


async def capture_loop():
    silent_sent = False
    prev = [0.0] * BANDS
    while True:
        sink = await default_sink()
        if not clients or not sink:
            await asyncio.sleep(0.5)
            continue
        proc = await asyncio.create_subprocess_exec(
            "parec", "-d", sink + ".monitor", "--format=s16le", f"--rate={RATE}", "--channels=1",
            "--latency-msec=20", stdout=asyncio.subprocess.PIPE, stderr=asyncio.subprocess.DEVNULL)
        window = [0.0] * N
        chunk = HOP * 2
        last_check = asyncio.get_event_loop().time()
        try:
            while clients:
                data = await asyncio.wait_for(proc.stdout.readexactly(chunk), 3)
                new = [s / 32768 for s in struct.unpack(f"<{HOP}h", data)]
                window = (window + new)[-N:]
                if max(abs(s) for s in new) < 0.0005:           # silencio: no gastar CPU
                    if not silent_sent:
                        await broadcast([0.0] * BANDS)
                        silent_sent = True
                    prev = [0.0] * BANDS
                else:
                    prev = bands_from(window, prev)
                    silent_sent = False
                    await broadcast(prev)
                now = asyncio.get_event_loop().time()
                if now - last_check > 3:                         # ¿cambió la salida predeterminada?
                    last_check = now
                    if await default_sink() != sink:
                        break
        except (asyncio.IncompleteReadError, asyncio.TimeoutError):
            pass
        finally:
            if proc.returncode is None:
                proc.terminate()
            await proc.wait()
        await asyncio.sleep(0.2)


async def idle_watch():
    sin_clientes = 0.0
    while True:
        await asyncio.sleep(1)
        sin_clientes = 0.0 if clients else sin_clientes + 1
        if sin_clientes >= IDLE_EXIT:
            sys.exit(0)


async def main():
    server = await asyncio.start_server(handle, "127.0.0.1", PORT)
    print(f"audio: escuchando en 127.0.0.1:{PORT}", flush=True)
    await asyncio.gather(server.serve_forever(), capture_loop(), idle_watch())


if __name__ == "__main__":
    try:
        asyncio.run(main())
    except KeyboardInterrupt:
        pass
