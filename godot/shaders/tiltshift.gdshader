shader_type canvas_item;
// Desenfoque de maqueta (tilt-shift) por altura en pantalla + viñeta suave.
uniform sampler2D screen_tex : hint_screen_texture, filter_linear_mipmap;
uniform float strength = 1.0;
uniform float band = 0.22;
uniform float center = 0.52;
uniform float vignette = 0.28;
void fragment(){
	vec2 uv = SCREEN_UV;
	float d = abs(uv.y - center);
	float b = smoothstep(band, band + 0.38, d) * strength;
	vec3 c;
	if (b < 0.01) {
		c = texture(screen_tex, uv).rgb;
	} else {
		float lod = b * 3.2;
		vec2 px = SCREEN_PIXEL_SIZE * (1.0 + b * 7.0);
		c = vec3(0.0);
		float w = 0.0;
		for (int i = 0; i < 12; i++) {
			float a = float(i) * 2.39996;
			float r = sqrt(float(i) + 0.5) / sqrt(12.0);
			vec2 o = vec2(cos(a), sin(a)) * r * px * 6.0;
			c += textureLod(screen_tex, uv + o, lod).rgb;
			w += 1.0;
		}
		c /= w;
	}
	vec2 q = uv - 0.5;
	float v = 1.0 - dot(q, q) * vignette * 2.2;
	COLOR = vec4(c * v, 1.0);
}
