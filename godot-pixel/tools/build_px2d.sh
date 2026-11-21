#!/bin/bash
# Exporta Renuevo para Windows, pone el icono y comprime.
set -e
cd /home/claude/gd/px2d
G=/tmp/godot/Godot_v4.3-stable_linux.x86_64
OUT=/home/claude/gd/buildpx/RenuevoPixel
rm -rf /home/claude/gd/buildpx && mkdir -p $OUT
timeout 600 $G --headless --export-release "Windows Desktop" $OUT/RenuevoPixel.exe 2>&1 | grep -E "ERROR|error|Export" | grep -v "mesh_storage\|Parameter \"m\"" | head -20 || true
ls -la $OUT
echo "listo"
cat > $OUT/LEEME.txt <<'T'
RENUEVO PIXEL — edición pixel art

Cómo jugar
1. Abre RenuevoPixel.exe (puedes crear un acceso directo en el escritorio).
2. Si Windows muestra "Windows protegió tu PC": Más información → Ejecutar de todas formas.

Controles
- Clic izquierdo: construir · arrastrar: mover el mapa
- Clic derecho (o rueda presionada) + arrastrar: girar e inclinar la cámara
- WASD / flechas: mover · Q/E: girar 45° · R/F: inclinar · Rueda o Z/X: zoom
- 1–9 y 0: herramientas · B: bitácora · M: sonido · G: efectos visuales
- H: ocultar interfaz (para capturas) · F11: pantalla completa · Esc: pausa

Las partidas se guardan solas en:
%APPDATA%\Renuevo
T
cd /home/claude/gd/buildpx && zip -q -9 -r RenuevoPixel-Windows.zip RenuevoPixel && ls -la RenuevoPixel-Windows.zip
