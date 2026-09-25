#!/bin/sh
# Genera un video de prueba 1080p60 (degradado animado, 20 s, bucle continuo) para probar el fondo.
set -e
out="${1:-$(dirname "$0")/degradado-1080p60.mp4}"
ffmpeg -hide_banner -loglevel error -y \
  -f lavfi -i "gradients=s=1920x1080:r=60:d=20:speed=0.01:c0=0x1b1464:c1=0x6a0572:c2=0x0b3d91:c3=0x00a8a8:n=4:type=spiral" \
  -c:v libx264 -preset medium -crf 20 -pix_fmt yuv420p -movflags +faststart "$out"
echo "$out"
