shader_type spatial;
render_mode unshaded, blend_mix, depth_draw_never, cull_disabled, shadows_disabled;
// Mar de nubes bajo la isla.
uniform float now = 0.0;
uniform vec4 top : source_color = vec4(1.0);
uniform vec4 bottom : source_color = vec4(0.7, 0.75, 0.85, 1.0);
float hash(vec2 p){ p = fract(p * vec2(123.34, 456.21)); p += dot(p, p + 45.32); return fract(p.x * p.y); }
float noise(vec2 p){ vec2 i = floor(p), f = fract(p); vec2 u = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1,0)), u.x), mix(hash(i + vec2(0,1)), hash(i + vec2(1,1)), u.x), u.y); }
float fbm(vec2 p){ float v = 0.0, a = 0.5; for (int i = 0; i < 5; i++){ v += a * noise(p); p *= 2.1; a *= 0.5; } return v; }
varying vec3 wp;
void vertex(){ wp = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz; }
void fragment(){
	vec2 p = wp.xz * 0.045 + vec2(now * 0.004, now * 0.002);
	float n = fbm(p * 2.0);
	float n2 = fbm(p * 5.0 + 3.0);
	float d = length(wp.xz) / 160.0;
	float cl = smoothstep(0.35, 0.75, n * 0.75 + n2 * 0.35);
	vec3 c = mix(bottom.rgb, top.rgb, cl);
	ALBEDO = c;
	ALPHA = clamp(cl * 0.95 + 0.25, 0.0, 1.0) * smoothstep(1.0, 0.55, d);
}
