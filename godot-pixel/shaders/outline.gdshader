shader_type spatial;
// Contorno de 1 píxel (baja resolución) por saltos de profundidad y de normales.
render_mode unshaded, blend_mix, depth_draw_never, depth_test_disabled, cull_disabled, shadows_disabled;
uniform sampler2D depth_tex : hint_depth_texture, filter_nearest;
uniform sampler2D nrm_tex : hint_normal_roughness_texture, filter_nearest;
uniform vec4 line_col : source_color = vec4(0.13, 0.08, 0.06, 1.0);
uniform float depth_thr = 0.12;
uniform float normal_thr = 0.55;
uniform float strength = 0.9;

void vertex(){ POSITION = vec4(VERTEX.xy, 1.0, 1.0); }

float lin(vec2 uv, mat4 ip){
	float d = texture(depth_tex, uv).r;
	vec4 v = ip * vec4(uv * 2.0 - 1.0, d, 1.0);
	return -v.z / v.w;
}
vec3 nrm(vec2 uv){ return texture(nrm_tex, uv).xyz * 2.0 - 1.0; }

void fragment(){
	vec2 px = 1.0 / VIEWPORT_SIZE;
	vec2 uv = SCREEN_UV;
	float d0 = lin(uv, INV_PROJECTION_MATRIX);
	float far_c = 0.0;
	float edge = 0.0;
	vec3 n0 = nrm(uv);
	vec2 offs[4] = vec2[](vec2(px.x, 0.0), vec2(-px.x, 0.0), vec2(0.0, px.y), vec2(0.0, -px.y));
	for (int i = 0; i < 4; i++){
		float d = lin(uv + offs[i], INV_PROJECTION_MATRIX);
		// solo el píxel más cercano dibuja la línea (silueta por dentro del objeto)
		if (d - d0 > depth_thr) edge = 1.0;
		vec3 n = nrm(uv + offs[i]);
		if (dot(n, n0) < normal_thr && d >= d0 - 0.02) edge = max(edge, 0.5);
	}
	if (d0 > 900.0) edge = 0.0;
	ALBEDO = line_col.rgb;
	ALPHA = edge * strength;
}
