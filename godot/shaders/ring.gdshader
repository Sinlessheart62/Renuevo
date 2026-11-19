shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never, cull_disabled, shadows_disabled;
uniform vec4 col : source_color = vec4(1.0);
uniform float t = 0.0;
void fragment(){
	float r = length(UV - 0.5) * 2.0;
	float ring = smoothstep(0.08, 0.0, abs(r - t)) * (1.0 - t);
	ALBEDO = col.rgb * ring * 1.5;
	ALPHA = ring;
}
