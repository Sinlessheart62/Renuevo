shader_type spatial;
render_mode cull_disabled;
#include "res://shaders/ghibli.gdshaderinc"
// Modelos del Stylized Nature MegaKit (Quaternius, CC0) con luz pintada, viento y aparición.
uniform sampler2D albedo_tex : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform vec4 base_col : source_color = vec4(1.0);
uniform vec4 tint : source_color = vec4(1.0);
uniform float cutoff = 0.3;
uniform float sway = 0.0;
uniform float model_h = 1.0;
uniform float now = 0.0;
uniform float wind = 1.0;
uniform float snow = 0.0;
uniform float use_vcol = 1.0;
uniform float mask_mode = 0.0;   // la textura es una máscara: colorear con mask_col
uniform vec4 mask_col : source_color = vec4(0.4, 0.62, 0.25, 1.0);
varying float hgt;
void vertex(){
	vec3 wp = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	float age = now - INSTANCE_CUSTOM.r;
	float grow = INSTANCE_CUSTOM.r < -50.0 ? 1.0 : smoothstep(0.0, 1.0, age * 0.9);
	float pop = INSTANCE_CUSTOM.r < -50.0 ? 1.0 : 1.0 + 0.15 * sin(clamp(age * 0.9, 0.0, 1.0) * 3.14159);
	hgt = clamp(VERTEX.y / model_h, 0.0, 1.0);
	float ph = INSTANCE_CUSTOM.g * 6.28;
	float s = (sin(now * 1.3 + ph + wp.x * 0.6) * 0.6 + sin(now * 2.4 + ph * 1.7 + wp.z) * 0.4) * sway * wind * model_h;
	VERTEX.x += s * hgt * hgt;
	VERTEX.z += s * 0.6 * hgt * hgt;
	VERTEX *= max(grow * pop, 0.001);
}
void fragment(){
	vec4 t = texture(albedo_tex, UV);
	if (t.a < cutoff) discard;
	if (dot(NORMAL, VIEW) < 0.0) NORMAL = -NORMAL;
	vec3 c = t.rgb * base_col.rgb * tint.rgb * (use_vcol > 0.5 ? COLOR.rgb : vec3(1.0));
	if (mask_mode > 0.5) c = mask_col.rgb * (0.75 + 0.5 * t.r);
	c = mix(c, vec3(0.92, 0.95, 1.0), snow * smoothstep(0.35, 0.9, NORMAL.y) * smoothstep(0.3, 0.7, hgt));
	ALBEDO = c * mix(0.75, 1.0, hgt);
	ROUGHNESS = 0.85;
	SPECULAR = 0.2;
}
