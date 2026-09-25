# Fondo Animado

Fondos de escritorio animados para KDE Plasma 6, al estilo de Wallpaper Engine.

## Qué hace
- **Videos** en bucle como fondo (mp4, webm, mkv, mov, avi, gif).
- **Imágenes animadas**: zoom y paneo lentos, más partículas opcionales (nieve, polvo en el aire, luciérnagas).
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

## Pantalla de bloqueo
Configuración del sistema → Bloqueo de pantalla → Apariencia → Fondo de pantalla → «Fondo Animado». Es la misma
configuración de fondos, pero independiente de la del escritorio. También se puede probar sin bloquear:
`/usr/lib/kscreenlocker_greet --testing`.

El bloqueo lo dibuja otro proceso (`kscreenlocker_greet`) que no hereda el ajuste de GPU de plasmashell: un video
ahí abre la NVIDIA en una laptop híbrida (medido: 28 descriptores en `/dev/nvidia*` y 22 % de CPU). Por eso, en el
bloqueo, un video se muestra como su primer fotograma con el zoom lento de las imágenes (0 descriptores, 4 % de
CPU), y un fondo web como su miniatura si tiene. Las imágenes animadas funcionan igual que en el escritorio.

## Video de prueba
`examples/generar-prueba.sh` genera un degradado animado 1080p60 con ffmpeg.

## Licencia
MIT
