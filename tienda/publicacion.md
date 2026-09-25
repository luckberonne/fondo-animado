# Ficha para la KDE Store (store.kde.org)

Subir: `dist/com.lucas.livewallpaper-1.0.0.tar.gz` (se genera con `tienda/empaquetar.sh`).
Categoría: la de fondos de escritorio para Plasma 6 («Wallpaper Plugins» / plugins de fondo de pantalla; comprobar el
nombre exacto en el formulario de subida). Licencia: MIT. Versión: 1.0.0.
Enlaces: <https://github.com/luckberonne/fondo-animado> · incidencias: <https://github.com/luckberonne/fondo-animado/issues>
Capturas (en `screenshots/`): `escena-lago.png`, `panel-configuracion.png`, `fondo-web-audio.png`. Icono: `tienda/icono-256.png`.

## Título
Animated Wallpaper (Fondo Animado)

## Descripción corta (EN)
Animated wallpapers for Plasma 6: videos, animated images, shader scenes and web wallpapers, with a library and smart pausing.

## Descripción (EN)
Live wallpapers for KDE Plasma 6 (Wayland), inspired by Wallpaper Engine.

* **Videos** in a loop, optimized on import (≤30 fps, ≤1080p, hardware H.264).
* **Animated images**: slow zoom and pan plus optional particles (snow, dust, fireflies).
* **Scenes**: stacked image layers with camera drift, shader effects (water, shine, wind, "explosion" masks, neon glow) and particles.
  A helper script turns any illustration into a scene: the dark characters stay still, shards and fluids move.
* **Web wallpapers** (HTML/JS/canvas) with the Wallpaper Engine web API: user properties and system-audio reactive visualizers.
* **Library** with animated thumbnails: import, pick, remove, rotate wallpapers every N minutes.
* **Low overhead**: pauses when a window is maximized or fullscreen, when the screen is locked and, optionally, on battery.
  Animations run at a capped frame rate; particles are computed by hand instead of using QtQuick.Particles (which redraws at
  the display refresh rate).
* Works on the lock screen too (images and scenes animate; videos and web wallpapers show a still frame).

Requirements: Plasma 6 with Qt 6 (Multimedia; WebEngine and WebSockets for web wallpapers), `python3` and `ffmpeg` (importing to the
library), `parec` (audio-reactive web wallpapers). Optional, for hybrid-GPU laptops: a systemd drop-in that keeps video decoding on
the integrated GPU (see the README).

Known limits: Plasma Login Manager (the login screen before you sign in) only accepts a fixed list of wallpapers, so it is not
supported there. Web wallpapers render in software inside plasmashell (about 6% of a core at 2 fps, 22% at 30 fps).
Tested on Plasma 6.7, Wayland, Arch-based system only.

## Descripción (ES)
Fondos animados para KDE Plasma 6 (Wayland), al estilo de Wallpaper Engine.

* **Videos** en bucle, optimizados al importar (≤30 fps, ≤1080p, H.264 por hardware).
* **Imágenes animadas**: zoom y paneo lentos y partículas opcionales (nieve, polvo, luciérnagas).
* **Escenas**: capas de imagen con movimiento de cámara, efectos de shader (agua, brillo, viento, máscaras de «explosión», neón) y
  partículas. Un script convierte cualquier ilustración en una escena: los personajes oscuros quedan quietos y las esquirlas y
  fluidos se mueven.
* **Fondos web** (HTML/JS/canvas) con la API web de Wallpaper Engine: propiedades editables y visualizadores que reaccionan al audio.
* **Biblioteca** con miniaturas animadas: importar, elegir, quitar y rotar fondos cada N minutos.
* **Gasta poco**: se pausa con una ventana maximizada o en pantalla completa, con la pantalla bloqueada y, si se quiere, con batería.
* También en la pantalla de bloqueo (imágenes y escenas animadas; videos y fondos web como imagen fija).

Límites conocidos: la pantalla de inicio de sesión de Plasma solo acepta una lista fija de fondos, así que no se soporta ahí.
Los fondos web se dibujan por software dentro de plasmashell. Probado solo en Plasma 6.7, Wayland, sistema basado en Arch.

## Registro de cambios (1.0.0)
Primera versión pública.
