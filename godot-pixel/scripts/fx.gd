extends Node3D
## Efectos breves: polvo, brotes, anillos, textos flotantes, dron y rayo del observatorio.

var world: Node
var bursts: Array[CPUParticles3D] = []
var sprouts: Array[CPUParticles3D] = []
var rings: Array = []      # [MeshInstance3D, t]
var pops: Array = []       # [Label3D, t]
var lifts: Array = []      # [Node3D drone, Node3D model, t, pos]
var beams: Array = []
var bi := 0
var si := 0
var ring_shader: Shader = preload("res://shaders/ring.gdshader")
var font: Font

func _ready() -> void:
	font = load("res://fonts/VT323.ttf")
	for k in 20:
		var p := CPUParticles3D.new()
		p.one_shot = true; p.emitting = false; p.amount = 18; p.lifetime = .9; p.explosiveness = .95
		p.direction = Vector3(0, 1, 0); p.spread = 75
		p.initial_velocity_min = .5; p.initial_velocity_max = 1.1
		p.gravity = Vector3(0, -1.5, 0)
		p.damping_min = 1.0; p.damping_max = 2.0
		var m := SphereMesh.new(); m.radius = .035; m.height = .06; m.radial_segments = 6; m.rings = 3
		var mm := StandardMaterial3D.new(); mm.vertex_color_use_as_albedo = true
		mm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA; mm.roughness = 1
		m.material = mm
		p.mesh = m
		var c := Curve.new(); c.add_point(Vector2(0, 1)); c.add_point(Vector2(1, .02))
		p.scale_amount_curve = c
		add_child(p); bursts.append(p)
	for k in 30:
		var p := CPUParticles3D.new()
		p.one_shot = true; p.emitting = false; p.amount = 7; p.lifetime = 1.3; p.explosiveness = .8
		p.direction = Vector3(0, 1, 0); p.spread = 30
		p.initial_velocity_min = .3; p.initial_velocity_max = .6
		p.gravity = Vector3(0, .1, 0)
		p.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX; p.emission_box_extents = Vector3(.35, .05, .35)
		var m := QuadMesh.new(); m.size = Vector2(.05, .05)
		var mm := StandardMaterial3D.new(); mm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		mm.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED; mm.vertex_color_use_as_albedo = true
		mm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		mm.emission_enabled = true; mm.emission_energy_multiplier = 1.5
		m.material = mm
		p.mesh = m
		var c := Curve.new(); c.add_point(Vector2(0, .02)); c.add_point(Vector2(.2, 1)); c.add_point(Vector2(1, .02))
		p.scale_amount_curve = c
		add_child(p); sprouts.append(p)

func burst(pos: Vector3, col: Color, n: int, spd: float) -> void:
	var p := bursts[bi]; bi = (bi + 1) % bursts.size()
	p.position = pos + Vector3(0, .05, 0)
	p.amount = n; p.color = col
	p.initial_velocity_max = spd * 1.2
	p.restart()

func grow(pos: Vector3, t: String) -> void:
	var p := sprouts[si]; si = (si + 1) % sprouts.size()
	p.position = pos + Vector3(0, .1, 0)
	var col := Color(.7, 1, .4)
	match t:
		"flower": col = Color(1, .85, .4)
		"forest": col = Color(.5, .95, .45)
		"wet", "mang": col = Color(.55, .95, .85)
	p.color = col
	p.restart()

func ring(pos: Vector3, col: Color) -> void:
	var mi := MeshInstance3D.new()
	var q := PlaneMesh.new(); q.size = Vector2(1.6, 1.6)
	mi.mesh = q
	var m := ShaderMaterial.new(); m.shader = ring_shader
	m.set_shader_parameter("col", col)
	mi.material_override = m
	mi.position = pos + Vector3(0, .04, 0)
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mi)
	rings.append([mi, 0.0])

func pop(pos: Vector3, txt: String) -> void:
	var l := Label3D.new()
	l.text = txt
	l.font = font
	l.font_size = 72
	l.outline_size = 14
	l.modulate = Color("#fff6d8")
	l.outline_modulate = Color(.2, .3, .15, .9)
	l.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	l.pixel_size = .004
	l.no_depth_test = true
	l.position = pos
	add_child(l)
	pops.append([l, 0.0])

func lift(pos: Vector3, id: String, factory: Node) -> void:
	var model: Node3D = factory.lift_model(id)
	model.position = pos
	add_child(model)
	var d: Node3D = factory.drone()
	d.position = pos + Vector3(0, 3, 0)
	add_child(d)
	lifts.append([d, model, 0.0, pos])

func beam(pos: Vector3, a: Dictionary) -> void:
	var target: Vector3 = Vector3(a.x - D.C / 2.0, 0, a.y - D.R / 2.0)
	target.y = world.surface_at(target.x, target.z) + .1
	var mi := MeshInstance3D.new()
	var cm := CylinderMesh.new(); cm.top_radius = .02; cm.bottom_radius = .02; cm.height = 1.0; cm.radial_segments = 6
	mi.mesh = cm
	var m := StandardMaterial3D.new(); m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.albedo_color = Color(.6, 1, .9, .7); m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.emission_enabled = true; m.emission = Color(.5, 1, .85); m.emission_energy_multiplier = 3
	mi.material_override = m
	add_child(mi)
	var mid := (pos + target) * .5
	var dir := target - pos
	mi.position = mid
	mi.basis = Basis.looking_at(dir.normalized(), Vector3.UP if absf(dir.normalized().y) < .99 else Vector3.RIGHT) * Basis(Vector3.RIGHT, PI / 2)
	mi.scale = Vector3(1, dir.length(), 1)
	beams.append([mi, 0.0, m])
	ring(target, Color(.5, 1, .85))

func _process(dt: float) -> void:
	for r in rings.duplicate():
		r[1] += dt * .9
		(r[0].material_override as ShaderMaterial).set_shader_parameter("t", r[1])
		if r[1] >= 1.0:
			r[0].queue_free(); rings.erase(r)
	for p in pops.duplicate():
		p[1] += dt
		var l: Label3D = p[0]
		l.position.y += dt * .5
		l.modulate.a = clampf(1.6 - p[1], 0, 1)
		l.outline_modulate.a = l.modulate.a * .9
		if p[1] > 1.6:
			l.queue_free(); pops.erase(p)
	for L in lifts.duplicate():
		L[2] += dt
		var t: float = L[2]
		var d: Node3D = L[0]; var m: Node3D = L[1]; var pos: Vector3 = L[3]
		if t < 1.2:
			d.position = pos + Vector3(0, lerpf(3.0, .95, ease(t / 1.2, .4)), 0)
		elif t < 1.6:
			pass
		else:
			var k := t - 1.6
			d.position = pos + Vector3(k * 1.2, .95 + k * k * 1.6 + k, 0)
			m.position = d.position - Vector3(0, .95, 0)
			m.scale = Vector3.ONE * clampf(1.0 - (k - 1.5) * .5, .02, 1)
		d.rotation.y += dt * 2
		if t > 5:
			d.queue_free(); m.queue_free(); lifts.erase(L)
	for b in beams.duplicate():
		b[1] += dt
		(b[2] as StandardMaterial3D).albedo_color.a = clampf(1.0 - b[1] / 1.2, 0, 1) * .7
		if b[1] > 1.2:
			b[0].queue_free(); beams.erase(b)
