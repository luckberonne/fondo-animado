#!/bin/sh
# Genera dist/com.lucas.livewallpaper-<versión>.tar.gz listo para subir a la KDE Store (o instalar con kpackagetool6).
set -eu
cd "$(dirname "$0")/.."
V=$(python3 -c "import json;print(json.load(open('com.lucas.livewallpaper/metadata.json'))['KPlugin']['Version'])")
mkdir -p dist
find com.lucas.livewallpaper -name __pycache__ -prune -exec rm -rf {} \;
tar --owner=0 --group=0 --numeric-owner --sort=name --mtime='2026-01-01' -czf "dist/com.lucas.livewallpaper-$V.tar.gz" com.lucas.livewallpaper
echo "dist/com.lucas.livewallpaper-$V.tar.gz"
echo "Probar: kpackagetool6 --type Plasma/Wallpaper --install dist/com.lucas.livewallpaper-$V.tar.gz"
