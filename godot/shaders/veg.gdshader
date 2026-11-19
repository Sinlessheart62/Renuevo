shader_type spatial;
render_mode diffuse_lambert_wrap, specular_schlick_ggx, cull_disabled;

uniform float now = 0.0;
uniform float wind = 1.0;
uniform float is_grass = 0.0;
uniform float sway = 0.04;
uniform vec4 tip_tint : source_color = vec4(1.0);
uniform float snow = 0.0;

varying float hgt;
varying vec3 icol;
varying float aofac;

void vertex(){
	vec3 wp = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	float age = now - INSTANCE_CUSTOM.r;
	float grow = INSTANCE_CUSTOM.r < -50.0 ? 1.0 : smoothstep(0.0, 1.0, age * 0.9);
	grow = grow * grow * (3.0 - 2.0 * grow);
	float pop = 1.0 + 0.18 * sin(clamp(age * 0.9, 0.0, 1.0) * 3.14159);
	if (INSTANCE_CUSTOM.r < -50.0) pop = 1.0;
	icol = INSTANCE_CUSTOM.r < -50.0 ? COLOR.rgb : COLOR.rgb;
	if (is_grass > 0.5) {
		hgt = VERTEX.y;
		icol = INSTANCE_CUSTOM.gba;
		float w = sin(now * 1.7 + wp.x * 1.3 + wp.z * 0.9) * 0.5 + sin(now * 3.1 + wp.x * 3.0) * 0.2;
		VERTEX.x += w * sway * hgt * hgt * wind;
		VERTEX.z += cos(now * 1.3 + wp.z * 1.1) * sway * 0.5 * hgt * hgt * wind;
		VERTEX *= vec3(1.0, max(grow, 0.001), 1.0);
		aofac = mix(0.45, 1.0, hgt);
	} else {
		hgt = VERTEX.y;
		float ph = INSTANCE_CUSTOM.g * 6.28;
		float s = (sin(now * 1.2 + ph + wp.x * 0.5) * 0.6 + sin(now * 2.3 + ph * 1.7) * 0.4) * sway * wind;
		VERTEX.x += s * max(VERTEX.y, 0.0) * max(VERTEX.y, 0.0) * 6.0;
		VERTEX.z += s * 0.6 * max(VERTEX.y, 0.0) * max(VERTEX.y, 0.0) * 6.0;
		VERTEX *= max(grow * pop, 0.001);
		aofac = clamp(0.55 + VERTEX.y * 1.4, 0.55, 1.0);
	}
}

void fragment(){
	vec3 c;
	if (is_grass > 0.5) {
		c = mix(icol * 0.45, icol * 1.12 * tip_tint.rgb, smoothstep(0.0, 1.0, hgt));
	} else {
		c = COLOR.rgb;
		c = pow(c, vec3(2.2));
	}
	c = mix(c, vec3(0.92, 0.95, 1.0), snow * smoothstep(0.2, 0.9, NORMAL.y));
	ALBEDO = c * aofac;
	ROUGHNESS = 0.85;
	SPECULAR = 0.25;
	BACKLIGHT = c * 0.35;
}
