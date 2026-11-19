shader_type spatial;
render_mode blend_mix, depth_draw_always, cull_disabled, diffuse_burley, specular_schlick_ggx;

uniform sampler2D depth_tex : hint_depth_texture, filter_linear_mipmap;
uniform sampler2D screen_tex : hint_screen_texture, filter_linear_mipmap;
uniform float now = 0.0;
uniform vec4 sea_col : source_color = vec4(0.18, 0.45, 0.66, 1.0);
uniform vec4 fresh_col : source_color = vec4(0.22, 0.55, 0.62, 1.0);
uniform float rain = 0.0;

varying vec3 wpos;
varying float kind;
varying float age;

float hash(vec2 p){ p = fract(p * vec2(123.34, 456.21)); p += dot(p, p + 45.32); return fract(p.x * p.y); }
float noise(vec2 p){ vec2 i = floor(p), f = fract(p); vec2 u = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1,0)), u.x), mix(hash(i + vec2(0,1)), hash(i + vec2(1,1)), u.x), u.y); }
float waves(vec2 p){
	return noise(p * 2.2 + vec2(now * 0.35, now * 0.2)) * 0.5 + noise(p * 4.7 - vec2(now * 0.25, -now * 0.4)) * 0.3 + noise(p * 9.0 + vec2(now * 0.6, 0.0)) * 0.2;
}

void vertex(){
	kind = INSTANCE_CUSTOM.r;
	age = now - INSTANCE_CUSTOM.g;
	wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	float rise = smoothstep(0.0, 1.6, age);
	VERTEX.y += (waves(wpos.xz) - 0.5) * 0.03 - (1.0 - rise) * 0.25;
	wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment(){
	vec2 p = wpos.xz;
	float e = 0.04;
	float h0 = waves(p), hx = waves(p + vec2(e, 0.0)), hz = waves(p + vec2(0.0, e));
	vec3 nrm_w = normalize(vec3((h0 - hx) * 2.2, 1.0, (h0 - hz) * 2.2));
	// gotas de lluvia
	if (rain > 0.05) {
		vec2 cell = floor(p * 6.0); vec2 f = fract(p * 6.0) - 0.5;
		float t0 = fract(now * 1.3 + hash(cell));
		float ring = smoothstep(0.06, 0.0, abs(length(f) - t0 * 0.45)) * (1.0 - t0);
		nrm_w.xz += f * ring * rain * 1.5;
		nrm_w = normalize(nrm_w);
	}
	NORMAL = normalize((VIEW_MATRIX * vec4(nrm_w, 0.0)).xyz);

	float depth = texture(depth_tex, SCREEN_UV).r;
	vec4 upos = INV_PROJECTION_MATRIX * vec4(SCREEN_UV * 2.0 - 1.0, depth, 1.0);
	upos.xyz /= upos.w;
	float thick = clamp(-upos.z - (-VERTEX.z), 0.0, 10.0);

	vec3 deep, shallow;
	float k = kind;
	if (k < 0.5) { deep = fresh_col.rgb * 0.55; shallow = fresh_col.rgb * 1.25 + vec3(0.03, 0.06, 0.02); }
	else if (k < 1.5) { deep = sea_col.rgb * 0.5; shallow = sea_col.rgb * 1.5 + vec3(0.05, 0.12, 0.08); }
	else if (k < 2.5) { deep = vec3(0.012, 0.012, 0.014); shallow = vec3(0.05, 0.045, 0.05); }
	else { deep = vec3(0.10, 0.16, 0.08); shallow = vec3(0.30, 0.42, 0.20); }

	float dfac = 1.0 - exp(-thick * 2.6);
	vec2 refr_uv = SCREEN_UV + nrm_w.xz * 0.012 * (1.0 - step(1.5, k) * step(k, 2.5));
	vec3 under = texture(screen_tex, refr_uv).rgb;
	vec3 col = mix(under * shallow * 2.2, deep, dfac);
	if (k > 1.5 && k < 2.5) {
		// iridiscencia del petróleo
		float ir = noise(p * 3.0 + vec2(now * 0.05));
		col += (0.5 + 0.5 * cos(6.2831 * (ir * 1.5 + vec3(0.0, 0.33, 0.67)))) * 0.05;
	}
	// espuma en la orilla
	float foam = smoothstep(0.12, 0.0, thick) * (0.6 + 0.4 * noise(p * 14.0 + now));
	foam += smoothstep(0.75, 0.95, waves(p * 1.3)) * 0.15 * step(0.5, k) * step(k, 1.5);
	if (k > 1.5 && k < 2.5) foam *= 0.2;
	col = mix(col, vec3(0.95), clamp(foam, 0.0, 1.0));
	ALBEDO = col;
	float fres = pow(1.0 - clamp(dot(normalize(VIEW), NORMAL), 0.0, 1.0), 4.0);
	ALPHA = clamp(mix(0.55, 0.97, dfac) + foam + fres * 0.3, 0.0, 1.0) * smoothstep(0.0, 0.6, age);
	if (k > 1.5 && k < 2.5) ALPHA = max(ALPHA, 0.92 * smoothstep(0.0, 0.6, age));
	ROUGHNESS = (k > 1.5 && k < 2.5) ? 0.08 : 0.04 + foam * 0.5;
	SPECULAR = 0.6;
	METALLIC = 0.0;
}
