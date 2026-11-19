# Renuevo 2.0 (Godot 4.3)

Versión de escritorio del juego, reconstruida en Godot con gráficos 3D:
terreno con terrazas y transiciones orgánicas, agua con refracción y espuma,
pasto animado por el viento, árboles y edificios procedurales, fauna,
ciclo de día y noche, lluvia/nieve, nubes, desenfoque de maqueta y sonido.

- `scripts/game.gd` — lógica (energía, clima, crecimiento, fases, fauna, guardado)
- `scripts/world.gd` — mundo 3D · `scripts/factory.gd` — modelos · `scripts/ui.gd` — interfaz
- `shaders/` — terreno, agua, vegetación, cielo, tilt-shift
- `tools/build.sh` — exporta `Renuevo.exe` para Windows

Prueba automática: `godot -- --auto --region=valle --play --out=/tmp/shots`
