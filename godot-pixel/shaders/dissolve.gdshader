shader_type canvas_item;
// Desarme de la nave colonia en bloques de 3 px: lo de arriba se desmonta primero.
uniform float keep = 1.0;
uniform float weld = 0.0;
uniform float hf = 3.0;
uniform vec2 fsize = vec2(64.0, 54.0);

float h(vec2 p) { return fract(sin(dot(p, vec2(12.9898, 78.233))) * 43758.5453); }

void fragment() {
	vec4 c = texture(TEXTURE, UV);
	vec2 lp = vec2(fract(UV.x * hf), UV.y) * fsize;
	vec2 blk = floor(lp / 3.0);
	float th = h(blk) * 0.65 + (1.0 - UV.y) * 0.35;
	th = th * 0.98 + 0.01;
	if (th > keep) {
		c.a = 0.0;
	} else if (weld > 0.5 && th > keep - 0.05 && c.a > 0.5) {
		c.rgb = mix(c.rgb, vec3(1.0, 0.85, 0.4), 0.7);
	}
	COLOR = c * COLOR;
}
