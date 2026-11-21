shader_type spatial;
render_mode cull_disabled;
#include "res://shaders/ghibli.gdshaderinc"
// Material de objetos construidos y animales: color por vértice (sRGB).
uniform float now = 0.0;
uniform float emis = 0.0;
void fragment(){
	if (dot(NORMAL, VIEW) < 0.0) NORMAL = -NORMAL;
	vec3 c = pow(max(COLOR.rgb, vec3(0.0)), vec3(2.2));
	ALBEDO = c;
	ROUGHNESS = 0.7;
	EMISSION = c * emis;
}
