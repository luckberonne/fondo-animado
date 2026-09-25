#!/bin/sh
# Fondo Animado en la pantalla de inicio de sesión (Plasma Login Manager).
#
# Esa pantalla la dibuja otro usuario del sistema (`plasmalogin`), que no ve tu carpeta personal y solo lista los
# fondos instalados en todo el sistema. Este script (correr como root) hace tres cosas:
#   1. instala el plugin en /usr/share/plasma/wallpapers
#   2. copia proyectos de tu biblioteca a la del usuario plasmalogin (/var/lib/plasmalogin/...)
#   3. opcionalmente lo activa en /etc/plasmalogin.conf
#
# Uso:
#   sudo sh instalar-login.sh instalar [proyecto ...]   plugin + copia los proyectos indicados (nombres de carpeta)
#   sudo sh instalar-login.sh activar <proyecto>        lo elige como fondo del inicio de sesión
#   sudo sh instalar-login.sh quitar                    deshace todo (vuelve al fondo que tenías antes)
#   sh instalar-login.sh simular ...                    muestra qué haría sin tocar nada
#
# Solo escenas e imágenes se animan ahí; un video se muestra como su primer fotograma (igual que en el bloqueo).
set -eu

QUIEN="${SUDO_USER:-${USER:-}}"
CASA=$(getent passwd "$QUIEN" | cut -d: -f6)
ORIGEN_PLUGIN="$(cd "$(dirname "$0")/.." && pwd)/com.lucas.livewallpaper"
BIB_USUARIO="$CASA/.local/share/livewallpapers"
BIB_LOGIN=/var/lib/plasmalogin/.local/share/livewallpapers
DESTINO_PLUGIN=/usr/share/plasma/wallpapers/com.lucas.livewallpaper
CONF=/etc/plasmalogin.conf
RESPALDO=/etc/plasmalogin.conf.antes-fondo-animado
SIMULAR=0
[ "${1:-}" = simular ] && { SIMULAR=1; shift; }
ORDEN="${1:-}"; [ $# -gt 0 ] && shift

hacer() { if [ "$SIMULAR" = 1 ]; then echo "[simulación] $*"; else echo "+ $*"; "$@"; fi; }
[ "$SIMULAR" = 1 ] || [ "$(id -u)" -eq 0 ] || { echo "Hay que correrlo como root (sudo)." >&2; exit 1; }
getent passwd plasmalogin >/dev/null || { echo "No existe el usuario plasmalogin: ¿está instalado plasma-login-manager?" >&2; exit 1; }

case "$ORDEN" in
  instalar)
    [ -d "$ORIGEN_PLUGIN" ] || { echo "No encuentro $ORIGEN_PLUGIN" >&2; exit 1; }
    hacer rm -rf "$DESTINO_PLUGIN"
    hacer cp -r "$ORIGEN_PLUGIN" "$DESTINO_PLUGIN"
    hacer chmod -R a+rX "$DESTINO_PLUGIN"
    hacer install -d -o plasmalogin -g plasmalogin "$BIB_LOGIN"
    for p in "$@"; do
      [ -f "$BIB_USUARIO/$p/project.json" ] || { echo "No existe el proyecto '$p' en $BIB_USUARIO" >&2; exit 1; }
      hacer rm -rf "$BIB_LOGIN/$p"
      hacer cp -rL "$BIB_USUARIO/$p" "$BIB_LOGIN/$p"
      hacer chown -R plasmalogin:plasmalogin "$BIB_LOGIN/$p"
      hacer chmod -R u+rwX,go-rwx "$BIB_LOGIN/$p"
    done
    echo "Listo. Ahora: Configuración del sistema → Pantalla de inicio de sesión → Aspecto visual → «Fondo Animado»,"
    echo "o:  sudo sh $0 activar <proyecto>"
    ;;
  activar)
    P="${1:?falta el nombre del proyecto}"
    [ -f "$BIB_LOGIN/$P/project.json" ] || { echo "Primero: sudo sh $0 instalar $P" >&2; exit 1; }
    [ -f "$RESPALDO" ] || hacer cp -p "$CONF" "$RESPALDO"
    hacer kwriteconfig6 --file "$CONF" --group Greeter --key WallpaperPlugin com.lucas.livewallpaper
    hacer kwriteconfig6 --file "$CONF" --group Greeter --group Wallpaper --group com.lucas.livewallpaper --group General --key Project "$BIB_LOGIN/$P"
    echo "Activado. Se ve en el próximo inicio de sesión (o probalo con: /usr/lib/plasma-login-greeter --test)."
    ;;
  quitar)
    if [ -f "$RESPALDO" ]; then hacer cp -p "$RESPALDO" "$CONF"; hacer rm -f "$RESPALDO"; fi
    hacer kwriteconfig6 --file "$CONF" --group Greeter --key WallpaperPlugin --delete
    hacer kwriteconfig6 --file "$CONF" --group Greeter --group Wallpaper --group com.lucas.livewallpaper --group General --key Project --delete
    hacer rm -rf "$DESTINO_PLUGIN" "$BIB_LOGIN"
    echo "Deshecho."
    ;;
  *)
    sed -n '2,17p' "$0"; exit 1 ;;
esac
