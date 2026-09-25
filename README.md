# Fondo Animado

Fondos de escritorio animados para KDE Plasma 6, al estilo de Wallpaper Engine.

## Qué hace
- **Videos** en bucle como fondo (mp4, webm, mkv, mov, avi, gif).
- **Imágenes animadas**: zoom y paneo lentos, más partículas opcionales (nieve, polvo en el aire, luciérnagas).
- **Escenas**: capas de imagen con movimiento de cámara (paralaje), efectos de shader (agua, brillo, viento) y
  partículas (nieve, polvo, luciérnagas).
- **Fondos web** (HTML/JS/canvas) con la API de Wallpaper Engine: propiedades editables y visualizadores que
  reaccionan al audio del sistema.
- **Biblioteca** con miniaturas animadas: importar, elegir, quitar y rotar fondos cada N minutos.
- **Gasta poco**: se pausa solo con una ventana maximizada o en pantalla completa, con la pantalla bloqueada y,
  si se activa, con batería. Los videos se optimizan al importarlos (≤30 fps, ≤1080p, H.264 por hardware).
- Arrastrar un video o una imagen al escritorio lo importa y lo aplica. Clic derecho en el escritorio:
  «Pausar fondo animado» y «Siguiente fondo».
- El color de acento de Plasma se toma del fondo.

## Instalación
```sh
cp -r com.lucas.livewallpaper ~/.local/share/plasma/wallpapers/
systemctl --user restart plasma-plasmashell
```
Después: clic derecho en el escritorio → Configurar escritorio y fondo → Tipo de fondo: «Fondo Animado».

Hace falta `python3` y `ffmpeg` (para importar a la biblioteca), y `qt6-webengine` y `qt6-websockets` para los
fondos web. El audio usa `parec` (PipeWire/PulseAudio).

### Laptops con GPU híbrida (AMD/Intel + NVIDIA)
FFmpeg decodifica por VAAPI en `/dev/dri/renderD128`, y en muchas laptops ese nodo es la NVIDIA: la despierta y
los fotogramas tienen que copiarse entre placas. `sistema/plasmashell-livewallpaper.conf` hace que, **solo para
plasmashell**, `renderD128` sea la GPU integrada; así el video se decodifica ahí y se dibuja sin copias.
Revisá que los números de nodo coincidan con tu equipo (`ls -l /dev/dri/by-path/`).
```sh
mkdir -p ~/.config/systemd/user/plasma-plasmashell.service.d
cp sistema/plasmashell-livewallpaper.conf ~/.config/systemd/user/plasma-plasmashell.service.d/livewallpaper.conf
systemctl --user daemon-reload && systemctl --user restart plasma-plasmashell
```
Para deshacerlo, borrar ese archivo y repetir la última línea.

## Biblioteca
Los fondos viven en `~/.local/share/livewallpapers/<nombre>/`, cada uno con un `project.json`
(`title`, `type`: `video` | `image`, `file`, `preview`, `poster`, `properties`).
También se maneja desde la terminal:
```sh
com.lucas.livewallpaper/contents/code/biblioteca.py importar video.mp4          # optimiza si hace falta
com.lucas.livewallpaper/contents/code/biblioteca.py importar foto.jpg
com.lucas.livewallpaper/contents/code/biblioteca.py importar video.mp4 --original
com.lucas.livewallpaper/contents/code/biblioteca.py listar
```
Las carpetas de Wallpaper Engine (Steam Workshop) de tipo video también se pueden importar.

## Fondos web
Un fondo web es una carpeta con `index.html` y un `project.json` con el formato de Wallpaper Engine
(<https://docs.wallpaperengine.io/en/web/first/gettingstarted.html>). Se importa desde la configuración
(o `biblioteca.py importar carpeta/`) y se pueden importar también los de tipo web del Workshop de Steam.

Lo que implementa de esa API:
- `window.wallpaperPropertyListener.applyUserProperties(props)` con las propiedades declaradas en
  `general.properties` (`color`, `slider`, `bool`, `combo`, `textinput`); se editan en la configuración.
- `window.wallpaperRegisterAudioListener(cb)`: 128 valores 0-1 (0-63 izquierdo, 64-127 derecho), ~30 veces por
  segundo, si el proyecto declara `"supportsaudioprocessing": true`. Los calcula `contents/code/audio.py`
  (FFT sin dependencias sobre el monitor de la salida predeterminada) y solo corre mientras el fondo web se ve.
- Tope de cuadros por segundo (por defecto 20): se aplica a `requestAnimationFrame`.
- Pausa: la página se congela y el servicio de audio se detiene con las mismas reglas que el video.

Sin implementar todavía: propiedades `file`/`directory`, `applyGeneralProperties` y el resto de la API.
`examples/ondas-web/` es un fondo de ejemplo.

**Costo:** dentro de plasmashell, QtWebEngine dibuja por software (Qt no puede compartir contexto de GPU ahí).
Medido con un canvas a pantalla completa: ~6 % de un núcleo a 2 fps, ~14 % a 15, ~22 % a 30 y ~38 % a 60,
más ~100 MB de memoria. Por eso el tope por defecto es 20 y se pausan sin verse.

## Escenas
Formato propio: una carpeta con imágenes y un `project.json` con `"type": "scene"` y una lista de capas
(de atrás hacia adelante). `examples/lago-escena/` es un ejemplo completo (`examples/generar-escena.py` lo genera).
```json
"scene": { "layers": [
  { "image": "cielo.png",    "depth": 0.0 },
  { "particles": "luciernagas", "count": 22, "depth": 0.15 },
  { "image": "lago.png",     "depth": 0.55,
    "effect": { "shader": "agua", "strength": 0.006, "speed": 1.0, "horizon": 0.58 } }
] }
```
- `depth` (0 = lejano, 1 = primer plano): cuánto se mueve la capa con la cámara, que hace una deriva lenta.
  La amplitud y la velocidad se editan en la configuración (`general.properties`: `parallax`, `velocidad`).
- Shaders (`contents/shaders/*.frag`, compilar con `qsb --qt6 -o x.frag.qsb x.frag`): `agua` (ondas que crecen con la
  distancia al horizonte `horizon` + destellos), `brillo` (franja de luz que barre la capa), `viento` (balanceo),
  `explosion` (mueve solo lo que una máscara `mask` marca como libre y hace titilar los brillos).
  Uniformes comunes: `strength`, `speed`, `horizon`.
- Partículas: `nieve`, `polvo`, `luciernagas`.
- Todo avanza con un reloj limitado (cuadros/s, «Imágenes y escenas» en la configuración; 20 por defecto) y se pausa
  con las mismas reglas que el video.
- Un `poster` (imagen completa) sirve de fondo en la pantalla de bloqueo.

### Animar una imagen: personajes quietos, explosiones en movimiento
`contents/code/escena_desde_imagen.py` arma una escena desde cualquier ilustración: lo oscuro y grande (los
personajes) queda quieto y el resto (esquirlas, fluidos, salpicaduras) se mueve con el shader `explosion`.
```sh
contents/code/escena_desde_imagen.py ilustracion.jpg --titulo "Gengar explosiones" --importar
# afinar: --umbral 40 (más bajo = solo lo más oscuro queda quieto), --fuerza 0.012, --velocidad 1
# forzar regiones concretas (coordenadas en 1920x1080; la salida lista cada región con su centro):
#   --quieto 503,278   --mueve 1719,806
```
Detecta los personajes por luminancia, rellena lo que encierran (boca, ojos) solo si es cálido (los fluidos
azules o violetas rodeados de sombra se siguen moviendo) y usa una máscara suave. Con el Gengar de ejemplo: 0 % de
los píxeles de la cara y la sonrisa cambian, y entre el 14 % y el 39 % de los de los fluidos y esquirlas.
La intensidad y la velocidad se editan en la configuración. Costo a 1080p y 20 cuadros/s: ~2,6 % de CPU y ~13 % de GPU.

El paralaje **no sigue al puntero**: el motor `mouse` de Plasma usa X11 y tumba plasmashell en Wayland.

**Costo** (escena de ejemplo, 1080p, 20 cuadros/s): ~4 % de un núcleo y ~7 % de la GPU integrada. Las partículas de
`QtQuick.Particles` costaban ~8 % de CPU y ~14 % de GPU con 50 partículas porque se redibujan a la frecuencia de la
pantalla sin tope; por eso las partículas se calculan a mano con el reloj limitado.

## Pantalla de bloqueo
Configuración del sistema → Bloqueo de pantalla → Apariencia → Fondo de pantalla → «Fondo Animado». Es la misma
configuración de fondos, pero independiente de la del escritorio. También se puede probar sin bloquear:
`/usr/lib/kscreenlocker_greet --testing`.

El bloqueo lo dibuja otro proceso (`kscreenlocker_greet`) que no hereda el ajuste de GPU de plasmashell: un video
ahí abre la NVIDIA en una laptop híbrida (medido: 28 descriptores en `/dev/nvidia*` y 22 % de CPU). Por eso, en el
bloqueo, un video se muestra como su primer fotograma con el zoom lento de las imágenes (0 descriptores, 4 % de
CPU), un fondo web como su miniatura si tiene, y una escena como su `poster`. Las imágenes animadas funcionan igual que en el escritorio.

## Video de prueba
`examples/generar-prueba.sh` genera un degradado animado 1080p60 con ffmpeg.

## Licencia
MIT
