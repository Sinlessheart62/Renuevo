// Iluminación pintada estilo Ghibli: dos tonos con borde suave, sombras frescas,
// luz cálida, rebote y borde iluminado.
uniform vec4 shade_tint : source_color = vec4(0.62, 0.70, 0.95, 1.0);
uniform vec4 light_tint : source_color = vec4(1.0, 0.96, 0.86, 1.0);
uniform float toon_soft = 0.18;
uniform float rim_amt = 0.25;

void light(){
	float ndl = dot(NORMAL, LIGHT);
	float wrap = (ndl + 0.3) / 1.3;
	float lit = smoothstep(0.32 - toon_soft, 0.32 + toon_soft, wrap) * ATTENUATION;
	// banda cálida en la frontera luz/sombra (como pintura)
	float edge = smoothstep(0.0, 0.25, wrap) * (1.0 - smoothstep(0.25, 0.6, wrap)) * ATTENUATION;
	vec3 c = LIGHT_COLOR / PI;
	DIFFUSE_LIGHT += c * light_tint.rgb * lit * 1.05;
	DIFFUSE_LIGHT += c * shade_tint.rgb * (1.0 - lit) * 0.16;
	DIFFUSE_LIGHT += c * vec3(1.0, 0.75, 0.55) * edge * 0.12;
	float rim = pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), 3.0);
	SPECULAR_LIGHT += c * rim * rim_amt * lit * light_tint.rgb;
}
