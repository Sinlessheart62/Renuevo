shader_type spatial;
render_mode diffuse_lambert_wrap;
// Paredes del corte del terreno: estratos de suelo.
uniform float top_y = 0.0;
varying vec3 wp;
float hash(float n){ return fract(sin(n) * 43758.5453); }
void vertex(){ wp = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz; }
void fragment(){
	float y = wp.y + sin(wp.x * 1.3 + wp.z * 0.9) * 0.08 + sin(wp.x * 4.1 - wp.z * 3.3) * 0.03;
	float band = floor(y * 3.2);
	vec3 a = vec3(0.42, 0.30, 0.20), b = vec3(0.55, 0.42, 0.30), c2 = vec3(0.36, 0.33, 0.31);
	vec3 c = mix(a, b, hash(band));
	c = mix(c, c2, smoothstep(-0.6, -1.4, y));
	c *= 0.85 + 0.15 * hash(floor(wp.x * 9.0) + floor(wp.z * 9.0) * 7.0 + floor(y * 12.0));
	c *= mix(0.55, 1.0, smoothstep(-2.6, -0.2, y));
	ALBEDO = pow(c, vec3(2.2));
	ROUGHNESS = 0.95;
}
