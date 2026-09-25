# Fondo Animado

Fondos de escritorio animados para KDE Plasma 6, al estilo de Wallpaper Engine.

## Qué hace
- Video en bucle como fondo (mp4, webm, mkv, mov, gif).
- Pausa sola con una ventana maximizada o en pantalla completa, con la pantalla bloqueada y, si se activa, con batería.
- Arrastrar un video al escritorio lo aplica como fondo; clic derecho → «Pausar fondo animado».
- El color de acento de Plasma se toma del video.

## Instalación
```sh
cp -r com.lucas.livewallpaper ~/.local/share/plasma/wallpapers/
systemctl --user restart plasma-plasmashell
```
Después: clic derecho en el escritorio → Configurar escritorio → Tipo de fondo: «Fondo Animado».

### Laptops con GPU híbrida (AMD + NVIDIA)
FFmpeg usa el primer dispositivo de video (`/dev/dri/renderD128`), que puede ser la NVIDIA, y la despierta.
`sistema/plasmashell-livewallpaper.conf` hace que plasmashell decodifique por Vulkan en la AMD:
```sh
mkdir -p ~/.config/systemd/user/plasma-plasmashell.service.d
cp sistema/plasmashell-livewallpaper.conf ~/.config/systemd/user/plasma-plasmashell.service.d/livewallpaper.conf
systemctl --user daemon-reload && systemctl --user restart plasma-plasmashell
```

## Video de prueba
`examples/generar-prueba.sh` genera un degradado animado 1080p60 con ffmpeg.

## Licencia
MIT
