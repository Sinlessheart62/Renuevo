#!/bin/bash
# Ejecuta el juego con Vulkan por software en una pantalla virtual. Args extra = args del juego.
cd /home/claude/gd/${PROJ:-renuevo}
G=/tmp/godot/Godot_v4.3-stable_linux.x86_64
export VK_ICD_FILENAMES=/usr/share/vulkan/icd.d/lvp_icd.json
W=${W:-1600}; H=${H:-900}
xvfb-run -a -s "-screen 0 ${W}x${H}x24" timeout ${TO:-500} $G --rendering-driver vulkan --resolution ${W}x${H} --position 0,0 -- "$@" 2>&1 | grep -E "SHOT|WIN|TIMEOUT|SCRIPT ERROR|ERROR|at: " | grep -v "at: \(load\|_load\)" | awk '!seen[$0]++' | head -40
