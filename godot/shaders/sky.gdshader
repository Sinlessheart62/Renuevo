shader_type sky;
// Cielo pintado (degradados suaves, sol con halo, estrellas de noche).
uniform vec4 zenith : source_color = vec4(0.30, 0.55, 0.85, 1.0);
uniform vec4 horizon : source_color = vec4(0.85, 0.90, 0.95, 1.0);
uniform vec4 ground : source_color = vec4(0.75, 0.80, 0.88, 1.0);
uniform vec4 sun_col : source_color = vec4(1.0, 0.93, 0.8, 1.0);
uniform float night = 0.0;
uniform float now = 0.0;
float hash(vec3 p){ p = fract(p * 0.3183099 + 0.1); p *= 17.0; return fract(p.x * p.y * p.z * (p.x + p.y + p.z)); }
void sky(){
	float y = EYEDIR.y;
	vec3 c = mix(horizon.rgb, zenith.rgb, pow(smoothstep(-0.02, 0.9, y), 0.6));
	c = mix(c, ground.rgb, smoothstep(0.0, -0.25, y));
	float sd = dot(EYEDIR, LIGHT0_DIRECTION);
	if (LIGHT0_ENABLED) {
		c += sun_col.rgb * (pow(max(sd, 0.0), 8.0) * 0.25 + pow(max(sd, 0.0), 120.0) * 1.2 + smoothstep(0.9995, 0.9998, sd) * 8.0) * (1.0 - night);
	}
	if (night > 0.01 && y > 0.0) {
		vec3 d = EYEDIR * 220.0;
		float s = step(0.9965, hash(floor(d)));
		c += vec3(s) * night * (0.6 + 0.4 * sin(now * 3.0 + hash(floor(d) + 3.0) * 20.0)) * smoothstep(0.0, 0.3, y);
	}
	COLOR = c;
}
