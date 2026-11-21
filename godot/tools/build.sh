#!/bin/bash
# Exporta Renuevo para Windows, pone el icono y comprime.
set -e
cd /home/claude/gd/renuevo
G=/tmp/godot/Godot_v4.3-stable_linux.x86_64
OUT=/home/claude/gd/build/Renuevo
rm -rf /home/claude/gd/build && mkdir -p $OUT
timeout 600 $G --headless --export-release "Windows Desktop" $OUT/Renuevo.exe 2>&1 | grep -E "ERROR|error|Export" | grep -v "mesh_storage\|Parameter \"m\"" | head -20 || true
ls -la $OUT
echo "listo"
cat > $OUT/LEEME.txt <<'T'
RENUEVO — versión 2.0 (Godot)

Cómo jugar
1. Abre Renuevo.exe (puedes crear un acceso directo en el escritorio).
2. Si Windows muestra "Windows protegió tu PC": Más información → Ejecutar de todas formas.

Controles
- Clic izquierdo: construir · arrastrar: mover el mapa
- Clic derecho (o rueda presionada) + arrastrar: girar e inclinar la cámara
- WASD / flechas: mover · Q/E: girar · R/F: inclinar · Rueda o Z/X: zoom
- 1–9 y 0: herramientas · B: bitácora · M: sonido · G: efectos visuales
- H: ocultar interfaz (para capturas) · F11: pantalla completa · Esc: pausa

Árboles, arbustos, flores, helechos y rocas: Stylized Nature MegaKit de Quaternius (CC0, dominio público).

Las partidas se guardan solas en:
%APPDATA%\Renuevo
T
cd /home/claude/gd/build && rm -f Renuevo-Godot-Windows.zip && zip -q -9 -r Renuevo-Godot-Windows.zip Renuevo && ls -la Renuevo-Godot-Windows.zip
