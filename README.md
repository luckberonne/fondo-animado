# Fondo Animado

Fondos de escritorio animados para KDE Plasma 6, al estilo de Wallpaper Engine.

## Qué hace
- **Videos** en bucle como fondo (mp4, webm, mkv, mov, avi, gif).
- **Imágenes animadas**: zoom y paneo lentos, más partículas opcionales (nieve, polvo en el aire, luciérnagas).
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

Hace falta `python3` y `ffmpeg` (para importar a la biblioteca).

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

## Video de prueba
`examples/generar-prueba.sh` genera un degradado animado 1080p60 con ffmpeg.

## Licencia
MIT
