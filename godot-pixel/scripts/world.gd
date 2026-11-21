extends Node3D
## Todo lo visual: terreno, agua, vegetación, edificios, fauna, cielo, clima y efectos.

const C := 30
const R := 30
const S := 5                 # subdivisiones por casilla del terreno
const NV := C * S + 1
const BAND := 0.3
const GRASSY := ["grass","forest","flower","wet"]

var G: Node
var HM := PackedFloat32Array()   # mapa de alturas del terreno (NV x NV)
var biome_img: Image
var biome_tex: ImageTexture
var blend := PackedFloat32Array()  # progreso de transición por casilla
var prev_t := PackedByteArray()
var cover := PackedByteArray()
var gborn := PackedFloat32Array()  # momento en que la casilla tuvo pasto
var noise := FastNoiseLite.new()

var terrain_mi: MeshInstance3D
var skirt_mi: MeshInstance3D
var wall_mi: MeshInstance3D
var island_mi: MeshInstance3D
var terrain_mat: ShaderMaterial
var water_mm: MultiMeshInstance3D
var water_mat: ShaderMaterial
var veg_mat: ShaderMaterial
var grass_mat: ShaderMaterial
var flower_mat: ShaderMaterial
var flat_mat: ShaderMaterial
var mats_now: Array[ShaderMaterial] = []

var grass_chunks: Array[MultiMeshInstance3D] = []
var grass_dirty := {}
var veg_variants := {}   # nombre -> {mesh, mmi}
var veg_dirty := false
var tile_objs := []      # por casilla: lista de [variante, Transform3D, fase]
var height_dirty := false
var water_dirty := false

var bnodes := {}         # casilla -> Node3D del edificio
var anodes := {}         # id animal -> Node3D
var factory: Node

var sun: DirectionalLight3D
var moon: DirectionalLight3D
var env: Environment
var sky_mat: ShaderMaterial
var cam_attr: CameraAttributesPractical
var cloud_sea: MeshInstance3D
var clouds: Array[Node3D] = []
var cloud_mat: ShaderMaterial
var rain_p: CPUParticles3D
var snow_p: CPUParticles3D
var fireflies: CPUParticles3D
var fx: Node

func _ready() -> void:
	G = Game
	noise.seed = 7
	noise.frequency = 0.35
	noise.fractal_octaves = 3
	biome_img = Image.create(C, R, false, Image.FORMAT_RGBA8)
	biome_tex = ImageTexture.create_from_image(biome_img)
	blend.resize(C * R); prev_t.resize(C * R); cover.resize(C * R); gborn.resize(C * R)
	tile_objs.resize(C * R)
	factory = preload("res://scripts/factory.gd").new()
	add_child(factory)
	_make_materials()
	mats_now.append(factory.mat)
	_make_env()
	_make_nodes()
	fx = preload("res://scripts/fx.gd").new()
	fx.world = self
	add_child(fx)
	G.map_rebuilt.connect(rebuild_all)
	G.tile_changed.connect(_on_tile)
	G.building_changed.connect(_on_building)
	G.fauna_changed.connect(_sync_fauna)
	G.fx.connect(_on_fx)
	G.scanned_animal.connect(func(i, a): fx.beam(tile_top(i) + Vector3(0, .9, 0), a))

# ======================================================================= materiales
func _make_materials() -> void:
	terrain_mat = ShaderMaterial.new(); terrain_mat.shader = load("res://shaders/terrain.gdshader")
	terrain_mat.set_shader_parameter("biome", biome_tex)
	water_mat = ShaderMaterial.new(); water_mat.shader = load("res://shaders/water.gdshader")
	var vs: Shader = load("res://shaders/veg.gdshader")
	veg_mat = ShaderMaterial.new(); veg_mat.shader = vs; veg_mat.set_shader_parameter("sway", .012)
	grass_mat = ShaderMaterial.new(); grass_mat.shader = vs
	grass_mat.set_shader_parameter("is_grass", 1.0); grass_mat.set_shader_parameter("sway", .05)
	flower_mat = ShaderMaterial.new(); flower_mat.shader = vs; flower_mat.set_shader_parameter("sway", .02)
	flat_mat = ShaderMaterial.new(); flat_mat.shader = load("res://shaders/flat.gdshader")
	terrain_mat.set_shader_parameter("toon_soft", .12); terrain_mat.set_shader_parameter("rim_amt", 0.0)
	grass_mat.set_shader_parameter("toon_soft", .08); grass_mat.set_shader_parameter("rim_amt", 0.0)
	grass_mat.set_shader_parameter("light_tint", Color(.92, .92, .82))
	veg_mat.set_shader_parameter("toon_soft", .05); veg_mat.set_shader_parameter("rim_amt", .35)
	mats_now = [terrain_mat, water_mat, veg_mat, grass_mat, flower_mat, flat_mat]

func _make_env() -> void:
	var we := WorldEnvironment.new()
	env = Environment.new()
	env.background_mode = Environment.BG_SKY
	var sky := Sky.new()
	sky_mat = ShaderMaterial.new(); sky_mat.shader = load("res://shaders/sky.gdshader")
	sky.sky_material = sky_mat
	sky.radiance_size = Sky.RADIANCE_SIZE_128
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	env.ambient_light_sky_contribution = .55
	env.ambient_light_energy = 1.0
	env.reflected_light_source = Environment.REFLECTION_SOURCE_SKY
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.tonemap_exposure = 1.0
	env.tonemap_white = 6.0
	env.ssao_enabled = true
	env.ssao_radius = .8
	env.ssao_intensity = 1.0
	env.ssao_power = 1.4
	env.ssao_detail = .6
	env.ssil_enabled = false
	env.ssil_radius = 2.0
	env.ssil_intensity = .6
	env.glow_enabled = true
	env.glow_intensity = .3
	env.glow_strength = 1.0
	env.glow_bloom = .06
	env.glow_hdr_threshold = 1.1
	env.glow_blend_mode = Environment.GLOW_BLEND_MODE_SOFTLIGHT
	env.set_glow_level(0, 0.0); env.set_glow_level(1, 0.6); env.set_glow_level(2, 1.0); env.set_glow_level(3, 0.8); env.set_glow_level(4, 0.6)
	env.fog_enabled = true
	env.fog_light_color = Color(.78, .84, .92)
	env.fog_density = .0004
	env.fog_aerial_perspective = .2
	env.fog_sky_affect = .0
	env.volumetric_fog_enabled = false
	env.volumetric_fog_density = .006
	env.volumetric_fog_albedo = Color(.95, .95, 1)
	env.volumetric_fog_anisotropy = .55
	env.volumetric_fog_length = 70.0
	env.volumetric_fog_ambient_inject = .15
	env.adjustment_enabled = true
	env.adjustment_saturation = 1.16
	env.adjustment_contrast = 1.04
	we.environment = env
	add_child(we)
	sun = DirectionalLight3D.new()
	sun.shadow_enabled = true
	sun.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_2_SPLITS
	sun.directional_shadow_max_distance = 95.0
	sun.shadow_blur = 1.5
	sun.shadow_bias = .04
	sun.shadow_normal_bias = 1.2
	sun.light_angular_distance = 1.2
	sun.light_volumetric_fog_energy = 1.4
	add_child(sun)
	moon = DirectionalLight3D.new()
	moon.light_color = Color(.55, .65, 1.0)
	moon.light_energy = 0.0
	moon.shadow_enabled = false
	moon.sky_mode = DirectionalLight3D.SKY_MODE_LIGHT_ONLY
	add_child(moon)

func _make_nodes() -> void:
	terrain_mi = MeshInstance3D.new(); terrain_mi.material_override = terrain_mat; add_child(terrain_mi)
	skirt_mi = MeshInstance3D.new(); add_child(skirt_mi)
	var sm := ShaderMaterial.new(); sm.shader = load("res://shaders/skirt.gdshader"); skirt_mi.material_override = sm
	wall_mi = MeshInstance3D.new(); add_child(wall_mi)
	var wm := StandardMaterial3D.new()
	wm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	wm.albedo_color = Color(.2, .45, .62, .78); wm.roughness = .1
	wm.cull_mode = BaseMaterial3D.CULL_DISABLED
	wall_mi.material_override = wm
	island_mi = MeshInstance3D.new(); add_child(island_mi)
	island_mi.mesh = _island_mesh()
	var im := ShaderMaterial.new(); im.shader = load("res://shaders/skirt.gdshader"); island_mi.material_override = im
	water_mm = MultiMeshInstance3D.new(); water_mm.material_override = water_mat
	water_mm.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(water_mm)
	# pasto en trozos de 5x5 casillas
	var bl := Geo.blade()
	for k in 36:
		var mmi := MultiMeshInstance3D.new()
		var mm := MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		mm.use_custom_data = true
		mm.mesh = bl
		mmi.multimesh = mm
		mmi.material_override = grass_mat
		mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(mmi)
		grass_chunks.append(mmi)
	# variantes de vegetación
	var defs := {
		"pine0":Geo.pine(1),"pine1":Geo.pine(2),"pine2":Geo.pine(3),
		"spruce0":Geo.spruce(4),"spruce1":Geo.spruce(5),"spruce2":Geo.spruce(6),
		"broad0":Geo.broad(7),"broad1":Geo.broad(8),"broad2":Geo.broad(9),
		"jungle0":Geo.broad(10, true),"jungle1":Geo.broad(11, true),
		"palm0":Geo.palm(12),"palm1":Geo.palm(13),"palm2":Geo.palm(14),
		"bush0":Geo.bush(15),"bush1":Geo.bush(16),
		"fbush0":Geo.bush(17, true),"fbush1":Geo.bush(18, true),"fbush2":Geo.bush(19, true),
		"reed0":Geo.reed(20),"reed1":Geo.reed(21),
		"mang0":Geo.mangrove(22),"mang1":Geo.mangrove(23),
		"dead0":Geo.dead(24),"dead1":Geo.dead(25),
		"rock0":Geo.boulder(26),"rock1":Geo.boulder(27),"rock2":Geo.boulder(28),
		"drock0":Geo.boulder(29, Color("#5d5550")),"drock1":Geo.boulder(30, Color("#6b625a")),
		"flower":Geo.flower_head()}
	for k in defs:
		var mmi := MultiMeshInstance3D.new()
		var mm := MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		mm.use_custom_data = true
		mm.use_colors = k == "flower"
		mm.mesh = defs[k]
		mmi.multimesh = mm
		mmi.material_override = flower_mat if k == "flower" else veg_mat
		if k == "flower" or k.begins_with("reed"): mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(mmi)
		veg_variants[k] = mmi
	# mar de nubes
	cloud_sea = MeshInstance3D.new()
	var pm := PlaneMesh.new(); pm.size = Vector2(400, 400)
	cloud_sea.mesh = pm
	cloud_sea.position = Vector3(0, -9, 0)
	var cm := ShaderMaterial.new(); cm.shader = load("res://shaders/clouds.gdshader"); cloud_sea.material_override = cm
	cloud_sea.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mats_now.append(cm)
	add_child(cloud_sea)
	# cúmulos alrededor de la isla (visibles) y nubes altas que solo proyectan sombra
	cloud_mat = ShaderMaterial.new(); cloud_mat.shader = load("res://shaders/flat.gdshader")
	cloud_mat.set_shader_parameter("toon_soft", .3); cloud_mat.set_shader_parameter("rim_amt", .6)
	cloud_mat.set_shader_parameter("shade_tint", Color(.75, .78, 1.0))
	cloud_mat.set_shader_parameter("emis", .32)
	mats_now.append(cloud_mat)
	for k in 14:
		var mi := MeshInstance3D.new()
		mi.mesh = Geo.cloud(40 + k)
		mi.material_override = cloud_mat
		var a := TAU * k / 14 + randf() * .3
		var d := randf_range(34, 60)
		var s := randf_range(3.5, 7.0)
		mi.scale = Vector3(s, s * randf_range(.8, 1.1), s)
		mi.position = Vector3(cos(a) * d, randf_range(-8, -1.5), sin(a) * d)
		mi.rotation.y = randf() * TAU
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		mi.set_meta("ring", true)
		add_child(mi); clouds.append(mi)
	for k in 5:
		var mi := MeshInstance3D.new()
		mi.mesh = Geo.cloud(60 + k)
		mi.material_override = cloud_mat
		var s := 2.0 + randf() * 1.4
		mi.scale = Vector3(s, s, s)
		mi.position = Vector3(randf_range(-40, 40), 18 + randf() * 3, randf_range(-40, 40))
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_SHADOWS_ONLY
		add_child(mi); clouds.append(mi)
	# clima
	rain_p = _weather(false); snow_p = _weather(true)
	fireflies = CPUParticles3D.new()
	fireflies.amount = 180; fireflies.lifetime = 6.0
	fireflies.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	fireflies.emission_box_extents = Vector3(15, .6, 15)
	fireflies.position = Vector3(0, 1.2, 0)
	fireflies.gravity = Vector3(0, .02, 0)
	fireflies.direction = Vector3(0, 1, 0); fireflies.spread = 180; fireflies.initial_velocity_min = .03; fireflies.initial_velocity_max = .12
	var fm := QuadMesh.new(); fm.size = Vector2(.05, .05)
	var ffm := StandardMaterial3D.new(); ffm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	ffm.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED; ffm.albedo_color = Color(1, .95, .5)
	ffm.emission_enabled = true; ffm.emission = Color(1, .9, .4); ffm.emission_energy_multiplier = 6
	ffm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	fm.material = ffm
	fireflies.mesh = fm
	var fc := Curve.new(); fc.add_point(Vector2(0, .02)); fc.add_point(Vector2(.3, 1)); fc.add_point(Vector2(.7, 1)); fc.add_point(Vector2(1, .02))
	fireflies.scale_amount_curve = fc
	fireflies.emitting = false
	add_child(fireflies)

func _weather(is_snow: bool) -> CPUParticles3D:
	var p := CPUParticles3D.new()
	p.amount = 3000 if not is_snow else 2200
	p.lifetime = 1.4 if not is_snow else 6.0
	p.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	p.emission_box_extents = Vector3(18, .5, 18)
	p.position = Vector3(0, 9, 0)
	p.direction = Vector3(.1, -1, 0); p.spread = 3 if not is_snow else 25
	p.gravity = Vector3(0, -9.8, 0) if not is_snow else Vector3(0, -.6, 0)
	p.initial_velocity_min = 6.0 if not is_snow else .4
	p.initial_velocity_max = 8.0 if not is_snow else .9
	var m := QuadMesh.new()
	m.size = Vector2(.012, .28) if not is_snow else Vector2(.05, .05)
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.albedo_color = Color(.8, .88, 1, .35) if not is_snow else Color(1, 1, 1, .9)
	mat.billboard_mode = BaseMaterial3D.BILLBOARD_FIXED_Y if not is_snow else BaseMaterial3D.BILLBOARD_ENABLED
	m.material = mat
	p.mesh = m
	p.emitting = false
	add_child(p)
	return p

func _island_mesh() -> ArrayMesh:
	# roca flotante bajo la parcela (estilo isla flotante)
	var g := Geo.new(77)
	var top := -2.4
	var n := 28
	var pts := []
	for k in n:
		var a := TAU * k / n
		var rr := 15.02 / maxf(absf(cos(a)), absf(sin(a)))
		pts.append(Vector3(cos(a) * rr, top, sin(a) * rr))
	var rings := [[1.0, 0.0], [.86, -1.4], [.62, -3.0], [.38, -4.8], [.16, -6.6]]
	var prev := pts
	for ri in range(1, rings.size()):
		var cur := []
		for k in n:
			var p: Vector3 = pts[k]
			var j := 1.0 + (g.rng.randf() - .5) * .25
			cur.append(Vector3(p.x * rings[ri][0] * j, top + rings[ri][1] + (g.rng.randf() - .5) * .6, p.z * rings[ri][0] * j))
		g.ctr = Vector3(0, top + rings[ri][1] * .5, 0)
		for k in n:
			var a: Vector3 = prev[k]; var b: Vector3 = prev[(k + 1) % n]; var c: Vector3 = cur[(k + 1) % n]; var d: Vector3 = cur[k]
			g.quad(a, b, c, d, Color(.5, .4, .3), Color(.42, .38, .36))
		prev = cur
	g.ctr = Vector3(0, 0, 0)
	for k in n:
		g.tri(prev[k], prev[(k + 1) % n], Vector3(0, top - 9.0, 0), Color(.35, .32, .3))
	return g.commit()

# ======================================================================= alturas
func ground_h(i: int) -> float:
	var t: String = G.T[i]
	var h: float = G.H[i] * D.HS
	if t == "sea" or t == "oil": return -0.55
	if t in D.SUNK: return h - 0.3
	return h

func water_h(i: int) -> float:
	var t: String = G.T[i]
	if t == "sea" or t == "oil": return -0.1
	return G.H[i] * D.HS - 0.09

func tile_center(i: int) -> Vector3:
	return Vector3(i % C - C / 2.0 + .5, 0, i / C - R / 2.0 + .5)

func tile_top(i: int) -> Vector3:
	var p := tile_center(i)
	var t: String = G.T[i]
	p.y = water_h(i) if t in D.WATERY else height_at(p.x, p.z)
	return p

func _compute_hm() -> void:
	HM.resize(NV * NV)
	var gh := PackedFloat32Array(); gh.resize(C * R)
	for i in C * R: gh[i] = ground_h(i)
	for vy in NV:
		for vx in NV:
			var u := float(vx) / S; var v := float(vy) / S
			var tx := clampi(int(u), 0, C - 1); var tyy := clampi(int(v), 0, R - 1)
			var ws := 0.0; var hs := 0.0; var mnt := 0.0
			for dy in range(-1, 2):
				for dx in range(-1, 2):
					var nx := tx + dx; var ny := tyy + dy
					if nx < 0 or ny < 0 or nx >= C or ny >= R: continue
					var ddx := maxf(maxf(nx - u, 0.0), u - (nx + 1))
					var ddy := maxf(maxf(ny - v, 0.0), v - (ny + 1))
					var d := sqrt(ddx * ddx + ddy * ddy)
					if d >= BAND: continue
					var w := 1.0 - d / BAND
					w = w * w * (3 - 2 * w)
					var j := ny * C + nx
					ws += w; hs += w * gh[j]
					if G.T[j] == "mnt": mnt += w
			var h := hs / maxf(ws, 1e-4)
			if mnt > 0:
				var m := mnt / ws
				h += (noise.get_noise_2d(u * 1.0, v * 1.0) * .5 + .45) * .9 * m * m
			h += noise.get_noise_2d(u * 3.0 + 50, v * 3.0) * .025
			HM[vy * NV + vx] = h

func height_at(x: float, z: float) -> float:
	var u := clampf((x + C / 2.0) * S, 0, NV - 1.001); var v := clampf((z + R / 2.0) * S, 0, NV - 1.001)
	var ix := int(u); var iy := int(v); var fx := u - ix; var fy := v - iy
	var a := HM[iy * NV + ix]; var b := HM[iy * NV + ix + 1]; var c := HM[(iy + 1) * NV + ix]; var d := HM[(iy + 1) * NV + ix + 1]
	return lerpf(lerpf(a, b, fx), lerpf(c, d, fx), fy)

func surface_at(x: float, z: float) -> float:
	var tx := int(floor(x + C / 2.0)); var tz := int(floor(z + R / 2.0))
	var h := height_at(x, z)
	if tx >= 0 and tz >= 0 and tx < C and tz < R:
		var i := tz * C + tx
		if G.T[i] in D.WATERY: h = maxf(h, water_h(i))
	return h

func _build_terrain() -> void:
	_compute_hm()
	var verts := PackedVector3Array(); verts.resize(NV * NV)
	var norms := PackedVector3Array(); norms.resize(NV * NV)
	var step := 1.0 / S
	for vy in NV:
		for vx in NV:
			verts[vy * NV + vx] = Vector3(vx * step - C / 2.0, HM[vy * NV + vx], vy * step - R / 2.0)
	for vy in NV:
		for vx in NV:
			var hl := HM[vy * NV + maxi(vx - 1, 0)]; var hr := HM[vy * NV + mini(vx + 1, NV - 1)]
			var hd := HM[maxi(vy - 1, 0) * NV + vx]; var hu := HM[mini(vy + 1, NV - 1) * NV + vx]
			norms[vy * NV + vx] = Vector3(hl - hr, 2 * step, hd - hu).normalized()
	var idx := PackedInt32Array()
	for vy in NV - 1:
		for vx in NV - 1:
			var a := vy * NV + vx
			idx.append_array([a, a + 1, a + NV, a + 1, a + NV + 1, a + NV])
	var arr := []; arr.resize(Mesh.ARRAY_MAX)
	arr[Mesh.ARRAY_VERTEX] = verts; arr[Mesh.ARRAY_NORMAL] = norms; arr[Mesh.ARRAY_INDEX] = idx
	var m := ArrayMesh.new(); m.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)
	terrain_mi.mesh = m
	# corte lateral (estratos) y paredes de agua del borde
	var sg := Geo.new(1); var wg := Geo.new(2)
	var bottom := -2.5
	var edges := [[Vector2i(0, 0), Vector2i(1, 0), Vector3(0, 0, -1)], [Vector2i(NV - 1, 0), Vector2i(0, 1), Vector3(1, 0, 0)],
		[Vector2i(NV - 1, NV - 1), Vector2i(-1, 0), Vector3(0, 0, 1)], [Vector2i(0, NV - 1), Vector2i(0, -1), Vector3(-1, 0, 0)]]
	for e in edges:
		var p0: Vector2i = e[0]; var dir: Vector2i = e[1]; var out: Vector3 = e[2]
		for k in NV - 1:
			var a := p0 + dir * k; var b := p0 + dir * (k + 1)
			var va := verts[a.y * NV + a.x]; var vb := verts[b.y * NV + b.x]
			sg.ctr = (va + vb) * .5 - out
			sg.quad(va, vb, Vector3(vb.x, bottom, vb.z), Vector3(va.x, bottom, va.z), Color.WHITE)
			# agua del borde
			var ta := _tile_of_vert(a); var tb := _tile_of_vert(b)
			if G.T[ta] in D.WATERY and G.T[tb] in D.WATERY:
				var wa := water_h(ta); var wb := water_h(tb)
				if wa > va.y or wb > vb.y:
					wg.ctr = (va + vb) * .5 - out
					wg.quad(Vector3(va.x, wa, va.z) + out * .002, Vector3(vb.x, wb, vb.z) + out * .002, vb + out * .002, va + out * .002, Color.WHITE)
	skirt_mi.mesh = sg.commit()
	_build_fence(verts)
	wall_mi.mesh = wg.commit()

func _tile_of_vert(v: Vector2i) -> int:
	var tx := clampi(v.x / S - (1 if v.x % S == 0 and v.x == NV - 1 else 0), 0, C - 1)
	var tz := clampi(v.y / S - (1 if v.y % S == 0 and v.y == NV - 1 else 0), 0, R - 1)
	return tz * C + tx

# ======================================================================= textura de biomas
func _write_biome(i: int) -> void:
	var t := D.TY.find(G.T[i])
	var b := clampf(blend[i], 0, 1)
	biome_img.set_pixel(i % C, i / C, Color8(t, prev_t[i], int(b * 255), cover[i]))

func set_cover(arr: PackedByteArray) -> void:
	cover = arr
	for i in C * R: _write_biome(i)
	biome_tex.update(biome_img)

# ======================================================================= agua
func _build_water() -> void:
	var list := []
	for i in C * R:
		if G.T[i] in D.WATERY: list.append(i)
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_custom_data = true
	var pm := PlaneMesh.new(); pm.size = Vector2(1.002, 1.002); pm.subdivide_width = 3; pm.subdivide_depth = 3
	mm.mesh = pm
	mm.instance_count = list.size()
	for k in list.size():
		var i: int = list[k]
		var p := tile_center(i); p.y = water_h(i)
		mm.set_instance_transform(k, Transform3D(Basis(), p))
		var t: String = G.T[i]
		var kind := 0.0
		if t == "sea": kind = 1.0
		elif t == "oil": kind = 2.0
		elif t == "wet" or t == "mang": kind = 3.0
		var bt: float = G.born[i]
		mm.set_instance_custom_data(k, Color(kind, bt if bt > -50 else -100.0, 0, 0))
	water_mm.multimesh = mm

# ======================================================================= vegetación
func _rnd(i: int, salt: int) -> RandomNumberGenerator:
	var r := RandomNumberGenerator.new()
	r.seed = hash(Vector3i(G.seed_v, i, salt))
	return r

func _gen_objs(i: int) -> void:
	var o := []
	var t: String = G.T[i]
	var r := _rnd(i, D.TY.find(t))
	var c := tile_center(i)
	var occupied: bool = G.B[i] != ""
	var add := func(v: String, m: float, s: float) -> void:
		var x := c.x + r.randf_range(-.5 + m, .5 - m); var z := c.z + r.randf_range(-.5 + m, .5 - m)
		if occupied and Vector2(x - c.x, z - c.z).length() < .42: return
		var y := height_at(x, z)
		if t in ["wet", "mang"]: y = maxf(y, water_h(i) - .04)
		var sc := s * r.randf_range(.8, 1.2)
		var bs := Basis(Vector3.UP, r.randf() * TAU).scaled(Vector3(sc, sc, sc))
		o.append([v, Transform3D(bs, Vector3(x, y, z)), r.randf()])
	var reg: String = G.region_id
	match t:
		"forest":
			var n := 2 + (1 if r.randf() < .6 else 0) + (1 if r.randf() < .3 else 0)
			for k in n:
				var v := r.randi() % 3
				var kind := ""
				if reg == "tropico": kind = ("palm%d" % v) if r.randf() < .45 else ("jungle%d" % (v % 2))
				elif reg == "polar": kind = "spruce%d" % v
				else: kind = ("pine%d" % v) if r.randf() < .55 else ("broad%d" % v)
				add.call(kind, .14, 1.0)
			if r.randf() < .6: add.call("bush%d" % (r.randi() % 2), .1, 1.0)
		"flower":
			for k in 1 + (1 if r.randf() < .5 else 0): add.call("fbush%d" % (r.randi() % 3), .12, 1.0)
		"grass":
			if r.randf() < .16: add.call("bush%d" % (r.randi() % 2), .15, .9)
		"wet":
			add.call("reed%d" % (r.randi() % 2), .15, 1.0)
			if r.randf() < .6: add.call("reed%d" % (r.randi() % 2), .15, 1.0)
		"mang":
			add.call("mang%d" % (r.randi() % 2), .22, 1.0)
			if r.randf() < .6: add.call("mang%d" % (r.randi() % 2), .22, .85)
		"sand":
			if reg == "tropico" and r.randf() < .14: add.call("palm%d" % (r.randi() % 3), .3, 1.0)
		"tox", "dirt", "ash", "ice":
			if r.randf() < .07: add.call("dead%d" % (r.randi() % 2), .3, 1.0)
			if r.randf() < .12: add.call("rock%d" % (r.randi() % 3), .2, .6)
		"rock":
			for k in 1 + r.randi() % 2: add.call("rock%d" % (r.randi() % 3), .15, 1.1)
		"mnt":
			if r.randf() < .35: add.call("drock%d" % (r.randi() % 2), .2, 1.2)
		"bed":
			if r.randf() < .3: add.call("rock%d" % (r.randi() % 3), .2, .5)
	# flores sueltas
	if t == "flower":
		var cols := [Color("#f2d24b"), Color("#ef7fa8"), Color("#ffffff"), Color("#b79af2"), Color("#ff9a4d"), Color("#e8473f")]
		var fc: Color = cols[r.randi() % cols.size()]
		var fc2: Color = cols[r.randi() % cols.size()]
		for k in 9:
			var x := c.x + r.randf_range(-.48, .48); var z := c.z + r.randf_range(-.48, .48)
			var y := height_at(x, z) + r.randf_range(.07, .13)
			var sc := r.randf_range(1.5, 2.1)
			o.append(["flower", Transform3D(Basis(Vector3.UP, r.randf() * TAU).scaled(Vector3(sc, sc, sc)), Vector3(x, y, z)), r.randf(), fc if r.randf() < .6 else fc2])
	tile_objs[i] = o

func _build_veg() -> void:
	var lists := {}
	for k in veg_variants: lists[k] = []
	for i in C * R:
		for o in tile_objs[i]:
			lists[o[0]].append([o, i])
	for k in lists:
		var mm: MultiMesh = veg_variants[k].multimesh
		var L: Array = lists[k]
		mm.instance_count = L.size()
		for n in L.size():
			var o: Array = L[n][0]; var i: int = L[n][1]
			mm.set_instance_transform(n, o[1])
			var bt: float = G.born[i]
			mm.set_instance_custom_data(n, Color(bt + o[2] * .6 if bt > -50 else -100.0, o[2], 0, 0))
			if mm.use_colors: mm.set_instance_color(n, o[3])

func _build_grass_chunk(ch: int) -> void:
	var cx0 := (ch % 6) * 5; var cy0 := (ch / 6) * 5
	var buf := PackedFloat32Array()
	var cnt := 0
	var reg: String = G.region_id
	for ty in range(cy0, cy0 + 5):
		for tx in range(cx0, cx0 + 5):
			var i := ty * C + tx
			var t: String = G.T[i]
			if not (t in GRASSY): continue
			var n := 0; var hgt := .14
			var base := Color(.40, .68, .22)
			match t:
				"grass": n = 12; hgt = .17
				"flower": n = 9; hgt = .15; base = Color(.48, .72, .26)
				"forest": n = 5; hgt = .14; base = Color(.28, .54, .2)
				"wet": n = 10; hgt = .22; base = Color(.36, .58, .28)
			if reg == "polar": base = base.lerp(Color(.48, .58, .36), .4)
			if reg == "tropico": base = base.lerp(Color(.2, .62, .25), .25)
			if G.B[i] != "": n /= 3
			var r := _rnd(i, 99)
			var c := tile_center(i)
			var bt: float = gborn[i]
			for k in n:
				var x := c.x + r.randf_range(-.5, .5); var z := c.z + r.randf_range(-.5, .5)
				var y := height_at(x, z)
				if t == "wet" and y < water_h(i) - .2: continue
				var h := hgt * r.randf_range(.6, 1.35)
				var a := r.randf() * TAU
				var lean := r.randf_range(-.25, .25)
				var bs := Basis(Vector3.UP, a) * Basis(Vector3.RIGHT, lean)
				bs = bs.scaled(Vector3(r.randf_range(2.2, 3.2), h, 1.0))
				var vcol := base * r.randf_range(.85, 1.15)
				vcol = vcol.lerp(Color(.78, .82, .32), pow(r.randf(), 2.0) * .2)
				buf.append_array([bs.x.x, bs.y.x, bs.z.x, x, bs.x.y, bs.y.y, bs.z.y, y, bs.x.z, bs.y.z, bs.z.z, z,
					(bt + r.randf() * .5) if bt > -50 else -100.0, vcol.r, vcol.g, vcol.b])
				cnt += 1
	var mm: MultiMesh = grass_chunks[ch].multimesh
	mm.instance_count = cnt
	if cnt > 0: mm.buffer = buf

# ======================================================================= reconstrucción
func rebuild_all() -> void:
	for i in C * R:
		blend[i] = 1.0; prev_t[i] = D.TY.find(G.T[i]); cover[i] = 0
		gborn[i] = -100.0
		_write_biome(i)
	biome_tex.update(biome_img)
	var reg_i := D.RORDER.find(G.region_id)
	terrain_mat.set_shader_parameter("region", float(reg_i))
	terrain_mat.set_shader_parameter("snow_h", 2.25 if G.region_id == "valle" else 1.7)
	var sea: Variant = G.REG.sea
	if sea != null: water_mat.set_shader_parameter("sea_col", sea)
	veg_mat.set_shader_parameter("snow", .35 if G.region_id == "polar" else 0.0)
	_build_terrain()
	_build_water()
	for i in C * R: _gen_objs(i)
	_build_veg()
	for ch in 36: _build_grass_chunk(ch)
	for k in bnodes: bnodes[k].queue_free()
	bnodes.clear()
	for i in C * R:
		if G.B[i] != "": _place_building(i, false)
	_sync_fauna()

func _on_tile(i: int, old: String) -> void:
	var t: String = G.T[i]
	prev_t[i] = D.TY.find(old); blend[i] = 0.0
	_write_biome(i)
	if (t in D.SUNK) != (old in D.SUNK) or t == "mang" or old == "mang": height_dirty = true
	if (t in D.WATERY) != (old in D.WATERY) or t in D.WATERY: water_dirty = true
	if (t in GRASSY) and not (old in GRASSY): gborn[i] = G.now_s
	grass_dirty[(i / C / 5) * 6 + (i % C) / 5] = true
	_gen_objs(i)
	veg_dirty = true

func _on_building(i: int, old: String) -> void:
	if bnodes.has(i):
		var n: Node3D = bnodes[i]
		bnodes.erase(i)
		n.queue_free()
	if G.B[i] != "": _place_building(i, true)
	_gen_objs(i); veg_dirty = true
	grass_dirty[(i / C / 5) * 6 + (i % C) / 5] = true

func _place_building(i: int, anim_in: bool) -> void:
	var n: Node3D = factory.make(G.B[i], i)
	var p := tile_center(i); p.y = height_at(p.x, p.z)
	n.position = p
	n.set_meta("born", G.now_s if anim_in else -100.0)
	n.set_meta("tile", i)
	add_child(n)
	bnodes[i] = n
	factory.set_born(n, G.now_s if anim_in else -100.0)

# ======================================================================= fauna
func _sync_fauna() -> void:
	var ids := {}
	for a in G.anim:
		ids[a.id] = true
		if not anodes.has(a.id):
			var n: Node3D = factory.animal(a.k)
			var big: float = 2.8 if a.k in ["frog", "butterfly", "bee", "lizard", "duck"] else (2.2 if a.k in ["rabbit", "hare", "beaver", "fox", "turtle", "parrot"] else 1.7)
			n.scale = Vector3.ONE * big
			anodes[a.id] = n
			add_child(n)
			factory.set_born(n, G.now_s)
			n.position = _apos(a)
	for k in anodes.keys():
		if not ids.has(k):
			anodes[k].queue_free(); anodes.erase(k)

func _apos(a: Dictionary) -> Vector3:
	var x: float = a.x - C / 2.0; var z: float = a.y - R / 2.0
	return Vector3(x, surface_at(x, z), z)

func _update_fauna(dt: float) -> void:
	var t: float = G.now_s
	for a in G.anim:
		if not anodes.has(a.id): continue
		var n: Node3D = anodes[a.id]
		var p := _apos(a)
		var k: String = a.k
		var fly: bool = k in ["bee", "butterfly", "parrot"]
		var swim: bool = k in ["duck", "beaver", "seal", "manta", "whale"]
		var ph: float = a.ph
		if fly:
			p.y += (1.4 if k == "parrot" else .35) + sin(t * 3 + ph) * .08
		elif swim:
			if k == "manta": p.y -= .12
			if k == "whale": p.y -= .25 - a.jump * .35 * sin(a.jump * PI)
			if k == "seal" or k == "duck" or k == "beaver": p.y -= .02
		elif a.walk:
			var hop := 0.0
			if k in ["rabbit", "hare", "frog"]: hop = absf(sin(t * 10 + ph)) * .07
			else: hop = absf(sin(t * 9 + ph)) * .012
			p.y += hop
		n.position = n.position.lerp(p, minf(1, dt * 12))
		var dx: float = a.tx - a.x; var dz: float = a.ty - a.y
		if a.walk and (absf(dx) + absf(dz)) > .01:
			var ang := atan2(dx, dz)
			n.rotation.y = lerp_angle(n.rotation.y, ang, minf(1, dt * 6))
		factory.animate_animal(n, k, t + ph, a.walk, a.graze, a.jump)

# ======================================================================= efectos
func _on_fx(kind: String, i: int, arg) -> void:
	var p := tile_top(i)
	match kind:
		"dust": fx.burst(p, Color(.78, .7, .58), 18, .9)
		"grow": fx.grow(p, arg)
		"ring": fx.ring(p, arg)
		"clean":
			var col := Color(.85, .7, .95)
			if arg == "ash": col = Color(.85, .85, .85)
			elif arg == "oil": col = Color(.5, .85, .8)
			fx.ring(p, col); fx.burst(p + Vector3(0, .1, 0), col, 8, .6)
		"pop": fx.pop(p + Vector3(0, .6, 0), arg)
		"lift":
			if bnodes.has(i): pass
			fx.lift(p, arg, factory)

func show_tool_help(tool: String, hover_i: int, ok: bool) -> void:
	var arr := PackedByteArray(); arr.resize(C * R); arr.fill(0)
	var grid := 0.0
	if tool in ["tur", "geo"] or tool in D.NEEDPOW:
		grid = 1.0
		for i in C * R:
			if G.COV.size() and G.COV[i]: arr[i] = 255
	elif tool != "":
		grid = .6
	set_cover(arr)
	terrain_mat.set_shader_parameter("show_grid", grid)
	if hover_i >= 0:
		terrain_mat.set_shader_parameter("hover", Vector2(hover_i % C, hover_i / C))
		terrain_mat.set_shader_parameter("hover_col", Color(.45, 1, .55) if ok else Color(1, .38, .3))
		var rr := 0.0
		match tool:
			"tur": rr = 4.0 if G.T[hover_i] == "mnt" else 3.0
			"geo": rr = 4.0
			"dep", "asp", "viv": rr = 2.0
			"sol", "col", "obs": rr = 3.0
			"hid": rr = 3.0
		terrain_mat.set_shader_parameter("hover_rad", rr)
	else:
		terrain_mat.set_shader_parameter("hover", Vector2(-10, -10))

# ======================================================================= cielo y bucle
func _process(dt: float) -> void:
	var now: float = G.now_s
	for m in mats_now: m.set_shader_parameter("now", now)
	# transiciones de color del suelo
	var changed := false
	for i in C * R:
		if blend[i] < 1.0:
			blend[i] = minf(1.0, blend[i] + dt * .7)
			_write_biome(i); changed = true
	if changed: biome_tex.update(biome_img)
	if height_dirty:
		height_dirty = false
		_build_terrain()
		for i in C * R: _gen_objs(i)
		veg_dirty = true
		for ch in 36: grass_dirty[ch] = true
		for i in bnodes:
			var p := tile_center(i); bnodes[i].position.y = height_at(p.x, p.z)
	if water_dirty:
		water_dirty = false; _build_water()
	if veg_dirty:
		veg_dirty = false; _build_veg()
	if grass_dirty.size():
		for ch in grass_dirty: _build_grass_chunk(ch)
		grass_dirty.clear()
	_update_sky(dt)
	_update_fauna(dt)
	factory.animate_buildings(bnodes, now, dt)
	for cl in clouds:
		if cl.has_meta("ring"):
			var p := cl.position
			var ang := atan2(p.z, p.x) + dt * .006
			var d := Vector2(p.x, p.z).length()
			cl.position = Vector3(cos(ang) * d, p.y, sin(ang) * d)
		else:
			cl.position.x += dt * .35
			if cl.position.x > 46: cl.position.x = -46; cl.position.z = randf_range(-36, 36)

var _rain_vis := 0.0
func _update_sky(dt: float) -> void:
	var dc: Dictionary = G.day_clock()
	var day: float = dc.day; var night: float = dc.night; var clock: float = dc.clock
	var rain: float = G.wx.rain
	var cold: bool = G.CL.T < 0
	# sol: amanece al este, cruza y se pone
	var el := lerpf(-.2, 1.0, day)
	var az := clock * TAU * .5 + 2.2
	sun.rotation = Vector3(-maxf(el, .06) * .72 - .18, az, 0)
	var dusk := 1.0 - absf(day - .5) * 2.0 if day > 0 and day < 1 else 0.0
	var sc := Color(1.0, .95, .86).lerp(Color(1.0, .6, .35), dusk * .7)
	sun.light_color = sc
	sun.light_energy = lerpf(0.0, 1.55, smoothstep(0.0, .35, day)) * (1.0 - rain * .55)
	moon.light_energy = night * .38
	moon.rotation = Vector3(-.9, az + PI, 0)
	var zen := Color(.13, .42, .88).lerp(Color(.04, .06, .16), night)
	var hor := Color(.80, .90, .97).lerp(Color(1.0, .68, .45), dusk * .65).lerp(Color(.10, .13, .25), night)
	var grey := Color(.58, .62, .68).lerp(Color(.08, .09, .12), night)
	zen = zen.lerp(grey, rain * .75); hor = hor.lerp(grey.lightened(.15), rain * .7)
	sky_mat.set_shader_parameter("zenith", zen)
	sky_mat.set_shader_parameter("horizon", hor)
	sky_mat.set_shader_parameter("ground", hor.darkened(.08))
	sky_mat.set_shader_parameter("sun_col", sc)
	sky_mat.set_shader_parameter("night", night)
	sky_mat.set_shader_parameter("now", G.now_s)
	env.ambient_light_energy = lerpf(.35, 1.0, day)
	env.fog_light_color = hor
	env.volumetric_fog_density = .006 + rain * .008
	env.volumetric_fog_albedo = Color(.95, .95, 1).lerp(Color(.6, .65, .8), night)
	var cm: ShaderMaterial = cloud_sea.material_override
	cm.set_shader_parameter("top", Color(1, 1, 1).lerp(Color(1, .82, .7), dusk * .5).lerp(Color(.22, .26, .38), night).lerp(Color(.7, .72, .76), rain * .5))
	cm.set_shader_parameter("bottom", hor.darkened(.15))
	terrain_mat.set_shader_parameter("wetness", rain * (0.0 if cold else 1.0))
	water_mat.set_shader_parameter("rain", rain if not cold else 0.0)
	_rain_vis = rain
	rain_p.emitting = rain > .25 and not cold and G.started
	snow_p.emitting = rain > .25 and cold and G.started
	var wind := 1.0 + rain * 1.5
	veg_mat.set_shader_parameter("wind", wind); grass_mat.set_shader_parameter("wind", wind)
	fireflies.emitting = night > .6 and G.last_stats.size() and G.last_stats.green > 30 and not cold
	for b in bnodes.values(): factory.night_lights(b, night)

var fence_mi: MeshInstance3D
func _build_fence(verts: PackedVector3Array) -> void:
	if fence_mi == null:
		fence_mi = MeshInstance3D.new()
		fence_mi.material_override = factory.mat
		add_child(fence_mi)
	var g := Geo.new(5)
	var wood := Color("#8a5a32"); var light := Color("#b07a45")
	var edges := [[Vector2i(0, 0), Vector2i(1, 0)], [Vector2i(NV - 1, 0), Vector2i(0, 1)], [Vector2i(NV - 1, NV - 1), Vector2i(-1, 0)], [Vector2i(0, NV - 1), Vector2i(0, -1)]]
	var inset := .12
	for e in edges:
		var p0: Vector2i = e[0]; var dir: Vector2i = e[1]
		var prev := Vector3.INF
		for k in range(0, NV, S):
			var a := p0 + dir * k
			var v := verts[a.y * NV + a.x]
			var tile := _tile_of_vert(a)
			if G.T[tile] in ["sea", "oil", "mnt", "lava"]:
				prev = Vector3.INF; continue
			var c := v
			c.x = clampf(c.x, -C / 2.0 + inset, C / 2.0 - inset); c.z = clampf(c.z, -R / 2.0 + inset, R / 2.0 - inset)
			c.y = height_at(c.x, c.z)
			g.box(c + Vector3(0, -.05, 0), Vector3(.09, .36, .09), wood.darkened(.15), light)
			if prev != Vector3.INF:
				for h in [.13, .25]:
					var mid := (prev + c) * .5
					var dd := c - prev
					var ang := atan2(dd.x, dd.z)
					g.box(mid + Vector3(0, h - .03, 0), Vector3(.035, .05, dd.length()), wood, light, ang)
			prev = c
	fence_mi.mesh = g.commit()
