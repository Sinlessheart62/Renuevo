shader_type spatial;
#include "res://shaders/ghibli.gdshaderinc"

// R = tipo, G = tipo anterior, B = avance de la transición, A = capa de ayuda (alcance)
uniform sampler2D biome : filter_nearest, repeat_disable;
uniform vec2 grid = vec2(20.0, 20.0);
uniform float now = 0.0;
uniform vec2 hover = vec2(-10.0);
uniform vec4 hover_col : source_color = vec4(0.4, 1.0, 0.5, 1.0);
uniform float hover_rad = 0.0;
uniform float show_grid = 0.0;
uniform float snow_h = 1.75;
uniform float region = 0.0; // 0 valle, 1 trópico, 2 polar, 3 volcán
uniform float wetness = 0.0;

varying vec3 wpos;
varying vec3 wnorm;

float hash(vec2 p){ p = fract(p * vec2(123.34, 456.21)); p += dot(p, p + 45.32); return fract(p.x * p.y); }
float noise(vec2 p){
	vec2 i = floor(p), f = fract(p);
	vec2 u = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1,0)), u.x), mix(hash(i + vec2(0,1)), hash(i + vec2(1,1)), u.x), u.y);
}
float fbm(vec2 p){ float v = 0.0, a = 0.5; for (int i = 0; i < 4; i++){ v += a * noise(p); p *= 2.03; a *= 0.5; } return v; }

vec3 srgb(vec3 c){ return pow(c, vec3(2.2)); }

vec3 tcol(int t, vec2 p, out float rough, out vec3 emis){
	float n = fbm(p * 1.6), m = noise(p * 5.0), k = noise(p * 9.0);
	rough = 0.92; emis = vec3(0.0);
	vec3 c;
	if (t == 0) { // tóxico
		c = mix(srgb(vec3(0.33,0.26,0.27)), srgb(vec3(0.47,0.36,0.38)), n);
		c = mix(c, srgb(vec3(0.42,0.30,0.40)), smoothstep(0.55, 0.8, fbm(p * 0.8 + 11.0)) * 0.6);
		float pud = smoothstep(0.62, 0.66, fbm(p * 1.7 + 3.0));
		vec3 sl = mix(srgb(vec3(0.45,0.20,0.55)), srgb(vec3(0.62,0.85,0.35)), noise(p * 4.0 + now * 0.05));
		c = mix(c, sl, pud * 0.85); rough = mix(0.9, 0.15, pud);
		c *= 0.85 + 0.3 * k;
	} else if (t == 1) { // tierra
		c = mix(srgb(vec3(0.50,0.37,0.25)), srgb(vec3(0.63,0.48,0.32)), n);
		c = mix(c, srgb(vec3(0.75,0.68,0.58)), step(0.86, k) * 0.7);
	} else if (t == 2 || t == 6) { // pasto / prado
		c = mix(srgb(vec3(0.36,0.62,0.22)), srgb(vec3(0.60,0.78,0.30)), n);
		// pinceladas: vetas alargadas más claras, como fondo pintado a mano
		float br = noise(vec2(p.x * 1.6 + p.y * 0.9, p.y * 7.0 - p.x * 2.0));
		c = mix(c, srgb(vec3(0.78,0.84,0.38)), smoothstep(0.62, 0.9, br) * 0.35);
		c = mix(c, srgb(vec3(0.26,0.48,0.20)), smoothstep(0.65, 0.95, m) * 0.25);
		if (t == 6) c = mix(c, srgb(vec3(0.62,0.78,0.38)), 0.25);
		if (region == 2.0) c = mix(c, srgb(vec3(0.48,0.60,0.38)), 0.35);
	} else if (t == 3) { // bosque
		c = mix(srgb(vec3(0.18,0.36,0.16)), srgb(vec3(0.32,0.50,0.20)), n);
		c = mix(c, srgb(vec3(0.40,0.30,0.18)), step(0.8, k) * 0.4);
	} else if (t == 4 || t == 5 || t == 11) { // fondo de agua dulce / humedal / manglar
		c = mix(srgb(vec3(0.28,0.30,0.18)), srgb(vec3(0.38,0.42,0.24)), n);
	} else if (t == 7) { // roca
		c = mix(srgb(vec3(0.48,0.47,0.45)), srgb(vec3(0.66,0.64,0.60)), n);
		c *= 0.8 + 0.35 * smoothstep(0.3, 0.7, noise(vec2(p.x * 2.0, p.y * 14.0)));
		rough = 0.8;
	} else if (t == 8) { // montaña
		c = mix(srgb(vec3(0.40,0.37,0.34)), srgb(vec3(0.58,0.54,0.49)), n);
		c *= 0.82 + 0.3 * noise(vec2(p.x * 3.0, wpos.y * 9.0));
		if (region == 3.0) c = mix(srgb(vec3(0.20,0.17,0.16)), srgb(vec3(0.33,0.28,0.26)), n);
		rough = 0.85;
	} else if (t == 9) { // fondo marino
		c = mix(srgb(vec3(0.62,0.58,0.45)), srgb(vec3(0.75,0.70,0.55)), n);
	} else if (t == 10) { // arena
		c = mix(srgb(vec3(0.86,0.78,0.58)), srgb(vec3(0.93,0.87,0.70)), n);
		c *= 0.94 + 0.08 * k;
	} else if (t == 12) { // ceniza
		c = mix(srgb(vec3(0.26,0.25,0.25)), srgb(vec3(0.40,0.38,0.37)), n);
		c = mix(c, srgb(vec3(0.62,0.60,0.58)), step(0.82, k) * 0.6);
		float ember = smoothstep(0.88, 0.95, noise(p * 6.0 + vec2(now * 0.02)));
		emis += srgb(vec3(1.0, 0.35, 0.08)) * ember * 0.6;
	} else if (t == 13) { // hielo
		c = mix(srgb(vec3(0.70,0.82,0.91)), srgb(vec3(0.90,0.95,0.99)), n);
		float cr = smoothstep(0.03, 0.0, abs(noise(p * 5.0) - 0.5));
		c = mix(c, srgb(vec3(0.55,0.72,0.86)), cr * 0.7);
		rough = 0.35;
	} else if (t == 14) { // lava
		float flow = fbm(p * 2.0 + vec2(now * 0.06, now * 0.03));
		float crust = smoothstep(0.45, 0.62, flow);
		c = mix(srgb(vec3(0.9, 0.3, 0.05)), srgb(vec3(0.16,0.10,0.08)), crust);
		emis = mix(srgb(vec3(1.0, 0.42, 0.08)) * 3.5, srgb(vec3(0.6, 0.12, 0.02)) * 0.4, crust);
		emis *= 0.85 + 0.25 * sin(now * 2.0 + p.x * 3.0);
		rough = mix(0.3, 0.95, crust);
	} else if (t == 15) { // fondo con petróleo
		c = srgb(vec3(0.16,0.15,0.15));
	} else { // cauce seco
		c = mix(srgb(vec3(0.36,0.27,0.19)), srgb(vec3(0.46,0.36,0.26)), n);
		c = mix(c, srgb(vec3(0.62,0.58,0.52)), step(0.8, k) * 0.7);
		rough = 0.85;
	}
	return c;
}

void vertex(){
	wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	wnorm = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
}

void fragment(){
	vec2 p = wpos.xz + grid * 0.5;
	vec2 warp = vec2(fbm(p * 1.9), fbm(p * 1.9 + 7.3)) - 0.5;
	vec2 q = p + warp * 0.55;
	ivec2 cell = clamp(ivec2(floor(q)), ivec2(0), ivec2(grid) - 1);
	vec4 d = texelFetch(biome, cell, 0);
	int t = int(d.r * 255.0 + 0.5);
	int tp = int(d.g * 255.0 + 0.5);
	float r1, r2; vec3 e1, e2;
	vec3 c = tcol(t, p, r1, e1);
	float rough = r1; vec3 emis = e1;
	if (d.b < 0.999) {
		vec3 c0 = tcol(tp, p, r2, e2);
		float rev = smoothstep(0.0, 0.15, d.b * 1.15 - fbm(p * 4.0) * 0.95);
		c = mix(c0, c, rev); rough = mix(r2, r1, rev); emis = mix(e2, e1, rev);
	}
	// laderas y bordes de terraza: tierra / roca expuesta
	float slope = 1.0 - clamp(wnorm.y, 0.0, 1.0);
	if (t != 8) {
		vec3 soil = mix(srgb(vec3(0.42,0.31,0.22)), srgb(vec3(0.55,0.43,0.31)), noise(vec2(p.x + p.y, wpos.y * 18.0)));
		c = mix(c, soil, smoothstep(0.35, 0.6, slope));
	}
	// nieve en las cumbres
	float snow = smoothstep(snow_h, snow_h + 0.25, wpos.y + fbm(p * 2.0) * 0.5) * smoothstep(0.75, 0.45, slope);
	if (region == 3.0) snow = 0.0;
	if (region == 2.0) snow = max(snow, smoothstep(0.9, 1.2, wpos.y + fbm(p * 2.0) * 0.5) * float(t == 8 || t == 7) * smoothstep(0.7, 0.4, slope));
	c = mix(c, srgb(vec3(0.95,0.97,1.0)), snow);
	// lluvia: suelo más oscuro y brillante
	c *= 1.0 - wetness * 0.18; rough = mix(rough, rough * 0.55, wetness);

	// ayuda visual de herramientas
	float grid_l = 0.0;
	if (show_grid > 0.0) {
		vec2 gfr = abs(fract(p) - 0.5);
		float near = hover.x > -5.0 ? smoothstep(5.5, 2.0, length(p - (hover + 0.5))) : 0.0;
		grid_l = smoothstep(0.475, 0.5, max(gfr.x, gfr.y)) * 0.16 * show_grid * near;
	}
	float cov = d.a;
	vec3 add = vec3(0.0);
	if (cov > 0.01) c = mix(c, c * 0.6 + srgb(vec3(0.95,0.85,0.45)) * 0.4, cov * 0.28 * show_grid);
	c = mix(c, vec3(1.0), grid_l);
	vec2 hc = hover + 0.5;
	if (hover.x > -5.0) {
		vec2 dd = abs(p - hc);
		float inside = step(max(dd.x, dd.y), 0.5);
		float edge = smoothstep(0.38, 0.5, max(dd.x, dd.y)) * inside;
		float pulse = 0.7 + 0.3 * sin(now * 5.0);
		c = mix(c, hover_col.rgb, inside * 0.22 + edge * 0.75 * pulse);
		emis += hover_col.rgb * edge * 0.35;
		if (hover_rad > 0.0) {
			float ring = max(dd.x, dd.y);
			float in_r = step(ring, hover_rad + 0.5);
			float edge_r = smoothstep(hover_rad + 0.42, hover_rad + 0.5, ring) * in_r;
			c = mix(c, c * 1.15 + hover_col.rgb * 0.08, in_r * 0.6);
			c = mix(c, hover_col.rgb, edge_r * 0.5);
		}
	}
	ALBEDO = c;
	ROUGHNESS = rough;
	EMISSION = emis;
}
