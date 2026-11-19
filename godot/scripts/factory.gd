extends Node
## Modelos de edificios y animales (procedurales) y su animación.

var flat_shader: Shader = preload("res://shaders/flat.gdshader")
var mat: ShaderMaterial
var glass: StandardMaterial3D
var mirror: StandardMaterial3D
var lamp_on: StandardMaterial3D
var lamp_off: StandardMaterial3D
var win_mat: StandardMaterial3D
var cache := {}

const WHITE := Color("#eeeae2")
const STEEL := Color("#9aa3a8")
const DARK := Color("#4a4f55")
const WOOD := Color("#9a6b44")
const RUST := Color("#c2683c")
const CONC := Color("#c9c2b4")
const ACC := Color("#e3b23c")

func _init() -> void:
	mat = ShaderMaterial.new(); mat.shader = flat_shader
	glass = StandardMaterial3D.new()
	glass.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	glass.albedo_color = Color(.75, .92, .95, .35); glass.roughness = .05; glass.metallic = .2
	glass.cull_mode = BaseMaterial3D.CULL_DISABLED
	mirror = StandardMaterial3D.new()
	mirror.albedo_color = Color(.75, .85, .95); mirror.metallic = .95; mirror.roughness = .08
	lamp_on = StandardMaterial3D.new(); lamp_on.emission_enabled = true; lamp_on.albedo_color = Color(.5, 1, .55)
	lamp_on.emission = Color(.4, 1, .5); lamp_on.emission_energy_multiplier = 3.0
	lamp_off = StandardMaterial3D.new(); lamp_off.emission_enabled = true; lamp_off.albedo_color = Color(1, .45, .3)
	lamp_off.emission = Color(1, .35, .2); lamp_off.emission_energy_multiplier = 3.0
	win_mat = StandardMaterial3D.new(); win_mat.emission_enabled = true; win_mat.albedo_color = Color(1, .85, .5)
	win_mat.emission = Color(1, .75, .4); win_mat.emission_energy_multiplier = 0.0

func _mi(m: Mesh, parent: Node3D, material: Material = null, pos := Vector3.ZERO) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = m
	mi.material_override = material if material else mat
	mi.position = pos
	parent.add_child(mi)
	return mi

func _pad(g: Geo, r := .36) -> void:
	g.cyl(Vector3(0, -.15, 0), r, r * .96, .19, 10, CONC.darkened(.15), CONC)

func _lamp(n: Node3D, p: Vector3) -> void:
	var s := SphereMesh.new(); s.radius = .028; s.height = .056; s.radial_segments = 8; s.rings = 4
	var mi := _mi(s, n, lamp_off, p)
	mi.name = "lamp"
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF

# ======================================================================= edificios
func make(id: String, i: int) -> Node3D:
	var n := Node3D.new()
	n.name = "b_" + id
	n.set_meta("id", id)
	match id:
		"tur": _turbine(n)
		"geo": _geo(n)
		"dep": _scrubber(n)
		"asp": _sprinkler(n)
		"pum": _pump(n)
		"sol": _solar(n)
		"nub": _cloud_tower(n)
		"fri": _cooler(n)
		"viv": _nursery(n)
		"col": _hive(n)
		"hid": _hydro(n)
		"obs": _observatory(n)
	n.rotation.y = (hash(i) % 4) * PI / 2 if id != "sol" else 0.0
	return n

func set_born(n: Node3D, t: float) -> void:
	# animación de aparición: crece con un pequeño rebote
	if t < -50: return
	var target := n.scale
	n.scale = target * .01
	var tw := n.create_tween()
	tw.tween_property(n, "scale", target * 1.12, .35).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tw.tween_property(n, "scale", target, .2).set_trans(Tween.TRANS_SINE)

func _turbine(n: Node3D) -> void:
	var g := Geo.new(1)
	_pad(g, .26)
	g.cyl(Vector3(0, .03, 0), .07, .035, 1.35, 10, WHITE.darkened(.08), WHITE, true, false)
	g.box(Vector3(0, 1.36, -.04), Vector3(.12, .11, .26), WHITE, WHITE.lightened(.1))
	_mi(g.commit(), n)
	var rotor := Node3D.new(); rotor.name = "rotor"; rotor.position = Vector3(0, 1.415, .1); n.add_child(rotor)
	var rg := Geo.new(2)
	rg.blob(Vector3.ZERO, Vector3(.05, .05, .07), WHITE.darkened(.1), WHITE, 1, 0)
	for k in 3:
		var a := TAU * k / 3
		var d := Vector3(cos(a), sin(a), 0)
		var side := Vector3(-sin(a), cos(a), 0) * .035
		var tip := d * .62
		var c0 := WHITE; var c1 := WHITE
		rg.ctr = Vector3(0, 0, -1)
		rg.quad(d * .04 + side, tip + side * .25, tip - side * .3, d * .04 - side * .6, c0, c1)
		rg.ctr = Vector3(0, 0, 1)
		rg.quad(d * .04 + side, tip + side * .25, tip - side * .3, d * .04 - side * .6, c0, c1)
		rg.ctr = Vector3(0, 0, -1)
		rg.quad(tip * .85 + side * .3, tip + side * .25, tip - side * .3, tip * .85 - side * .4, RUST, RUST)
	_mi(rg.commit(), rotor)
	_lamp(n, Vector3(0, 1.46, -.12))

func _geo(n: Node3D) -> void:
	var g := Geo.new(3)
	_pad(g, .44)
	for k in 2:
		var x := -.16 + k * .3
		var p := Vector3(x, .03, 0)
		g.cyl(p, .15, .1, .32, 14, CONC, CONC.lightened(.05), false, false)
		g.cyl(p + Vector3(0, .32, 0), .1, .12, .22, 14, CONC.lightened(.05), CONC.lightened(.1), false, false)
		g.cyl(p + Vector3(0, .51, 0), .121, .121, .02, 14, RUST, RUST, false)
	g.box(Vector3(.0, .03, .26), Vector3(.5, .14, .14), STEEL, STEEL.lightened(.1))
	g.cyl(Vector3(-.25, .1, .15), .025, .025, .4, 6, RUST, RUST)
	_mi(g.commit(), n)
	for k in 2:
		var st := _steam(Vector3(-.16 + k * .3, .55, 0), Color(1, 1, 1, .5), 1.0)
		n.add_child(st)
	_lamp(n, Vector3(.24, .2, .33))

func _scrubber(n: Node3D) -> void:
	var g := Geo.new(4)
	_pad(g, .34)
	g.cyl(Vector3(0, .03, 0), .2, .2, .42, 14, Color("#7c8a7e"), Color("#93a294"), false, false)
	g.cyl(Vector3(0, .45, 0), .2, .07, .14, 14, Color("#93a294"), STEEL, true, false)
	for k in 4:
		var a := TAU * k / 4 + .4
		g.box(Vector3(cos(a) * .2, .12, sin(a) * .2), Vector3(.07, .2, .07), DARK, DARK.lightened(.2), -a)
	g.cyl(Vector3(0, .2, 0), .205, .205, .03, 14, ACC, ACC, false)
	_mi(g.commit(), n)
	var fan := Node3D.new(); fan.name = "fan"; fan.position = Vector3(0, .6, 0); n.add_child(fan)
	var fg := Geo.new(5)
	for k in 4:
		var a := TAU * k / 4
		fg.box(Vector3(cos(a) * .06, 0, sin(a) * .06), Vector3(.12, .012, .035), DARK.lightened(.3), DARK.lightened(.4), -a)
	_mi(fg.commit(), fan)
	var p := _steam(Vector3(0, .62, 0), Color(.85, .75, 1, .35), .6)
	p.name = "puff"; n.add_child(p)
	_lamp(n, Vector3(.15, .45, .15))

func _sprinkler(n: Node3D) -> void:
	var g := Geo.new(6)
	_pad(g, .22)
	g.cyl(Vector3(0, .03, 0), .05, .035, .55, 8, STEEL.darkened(.1), STEEL, true, false)
	g.box(Vector3(0, .03, 0), Vector3(.16, .1, .16), Color("#5a8fb0"), Color("#6ea6c8"))
	_mi(g.commit(), n)
	var arm := Node3D.new(); arm.name = "arm"; arm.position = Vector3(0, .58, 0); n.add_child(arm)
	var ag := Geo.new(7)
	ag.box(Vector3(0, -.015, 0), Vector3(.9, .03, .035), STEEL, STEEL.lightened(.15))
	ag.cyl(Vector3(0, -.03, 0), .045, .045, .06, 8, ACC, ACC)
	for s in [-1, 1]:
		ag.cyl(Vector3(s * .44, -.05, 0), .02, .02, .05, 6, DARK, DARK)
	_mi(ag.commit(), arm)
	for s in [-1, 1]:
		var sp := _spray(); sp.position = Vector3(s * .44, -.05, 0); sp.name = "spray%d" % (s + 1)
		arm.add_child(sp)
	_lamp(n, Vector3(.07, .14, .07))

func _pump(n: Node3D) -> void:
	var g := Geo.new(8)
	_pad(g, .3)
	g.box(Vector3(-.05, .03, 0), Vector3(.32, .26, .3), Color("#b5654a"), Color("#c87a5c"))
	g.cyl(Vector3(-.05, .29, 0), .22, 0.0, .14, 4, Color("#6d4a3a"), Color("#7d5a48"), true, true, 0, PI / 4)
	g.cyl(Vector3(.15, .05, 0), .04, .04, .2, 8, STEEL, STEEL)
	_mi(g.commit(), n)
	var wheel := Node3D.new(); wheel.name = "wheel"; wheel.position = Vector3(.2, .16, 0); n.add_child(wheel)
	var wg := Geo.new(9)
	for k in 6:
		var a := TAU * k / 6
		wg.box(Vector3(0, cos(a) * .07, sin(a) * .07), Vector3(.03, .02, .1), WOOD, WOOD.lightened(.1), 0)
	_mi(wg.commit(), wheel)
	_lamp(n, Vector3(-.2, .25, .16))

func _solar(n: Node3D) -> void:
	var g := Geo.new(10)
	_pad(g, .3)
	g.cyl(Vector3(0, .03, 0), .05, .04, .32, 8, STEEL, STEEL.lightened(.1), true, false)
	_mi(g.commit(), n)
	var head := Node3D.new(); head.name = "head"; head.position = Vector3(0, .36, 0); n.add_child(head)
	var bm := BoxMesh.new(); bm.size = Vector3(.62, .025, .5)
	_mi(bm, head, mirror)
	var fm := BoxMesh.new(); fm.size = Vector3(.66, .02, .54)
	var fr := _mi(fm, head, null, Vector3(0, -.02, 0))
	var frm := StandardMaterial3D.new(); frm.albedo_color = DARK; fr.material_override = frm
	_lamp(n, Vector3(.08, .2, .08))

func _cloud_tower(n: Node3D) -> void:
	var g := Geo.new(11)
	_pad(g, .26)
	g.cyl(Vector3(0, .03, 0), .12, .06, 1.0, 10, WHITE.darkened(.05), WHITE, true, false)
	g.cyl(Vector3(0, .55, 0), .14, .14, .05, 12, Color("#5a8fb0"), Color("#6ea6c8"))
	g.cyl(Vector3(0, 1.0, 0), .1, .13, .1, 12, Color("#6ea6c8"), Color("#8cc0de"))
	_mi(g.commit(), n)
	var p := _steam(Vector3(0, 1.12, 0), Color(1, 1, 1, .8), 1.6)
	p.name = "puff"; n.add_child(p)
	_lamp(n, Vector3(.13, .58, 0))

func _cooler(n: Node3D) -> void:
	var g := Geo.new(12)
	_pad(g, .32)
	g.box(Vector3(0, .03, 0), Vector3(.48, .3, .42), Color("#8fb4c4"), Color("#a8cad8"))
	for k in 5:
		g.box(Vector3(-.2 + k * .1, .08, .212), Vector3(.05, .18, .01), Color("#5f7d8c"), Color("#5f7d8c"))
	g.cyl(Vector3(0, .33, 0), .17, .17, .03, 14, DARK, DARK.lightened(.15))
	_mi(g.commit(), n)
	var fan := Node3D.new(); fan.name = "fan"; fan.position = Vector3(0, .37, 0); n.add_child(fan)
	var fg := Geo.new(13)
	for k in 5:
		var a := TAU * k / 5
		fg.box(Vector3(cos(a) * .075, 0, sin(a) * .075), Vector3(.15, .01, .05), WHITE, WHITE, -a)
	_mi(fg.commit(), fan)
	var p := _steam(Vector3(0, .4, 0), Color(.8, .95, 1, .45), .7)
	p.name = "puff"; n.add_child(p)
	_lamp(n, Vector3(.2, .3, .2))

func _nursery(n: Node3D) -> void:
	var g := Geo.new(14)
	_pad(g, .38)
	g.box(Vector3(0, .03, 0), Vector3(.6, .05, .44), WOOD, WOOD.lightened(.1))
	for k in 4:
		var a := (k - 1.5) * .14
		var tg := Geo.new(20 + k)
		g.blob(Vector3(a, .12, -.08), Vector3(.05, .06, .05), Color("#3d7a32"), Color("#8cc657"), 0)
		g.blob(Vector3(a + .05, .11, .09), Vector3(.045, .05, .045), Color("#3d7a32"), Color("#8cc657"), 0)
	_mi(g.commit(), n)
	# invernadero de vidrio (medio cilindro)
	var cm := CylinderMesh.new(); cm.top_radius = .23; cm.bottom_radius = .23; cm.height = .62; cm.radial_segments = 16
	var gl := _mi(cm, n, glass, Vector3(0, .07, 0))
	gl.rotation = Vector3(0, 0, PI / 2)
	gl.scale = Vector3(1, 1, 1)
	var frame := Geo.new(15)
	for k in 5:
		var x := -.3 + k * .15
		for s in 8:
			var a0 := PI * s / 8; var a1 := PI * (s + 1) / 8
			frame.box(Vector3(x, .07 + sin(a0) * .23, cos(a0) * .23), Vector3(.012, .012, .1), WHITE, WHITE, 0)
	_mi(frame.commit(), n)
	_lamp(n, Vector3(.32, .1, .2))

func _hive(n: Node3D) -> void:
	var g := Geo.new(16)
	g.cyl(Vector3(0, -.12, 0), .3, .28, .14, 10, WOOD.darkened(.3), WOOD.darkened(.2))
	for k in 3:
		var x := -.14 + k * .14
		var hgt := .14 + (k % 2) * .06
		g.box(Vector3(x, .02, 0), Vector3(.11, hgt, .14), Color("#e8c46a").darkened(k * .06), Color("#f0d27e"))
		g.box(Vector3(x, .02 + hgt, 0), Vector3(.13, .02, .16), Color("#c28a4a"), Color("#d49a58"))
	_mi(g.commit(), n)
	var bees := CPUParticles3D.new()
	bees.name = "bees"
	bees.amount = 14; bees.lifetime = 3.0
	bees.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE; bees.emission_sphere_radius = .35
	bees.position = Vector3(0, .35, 0)
	bees.gravity = Vector3.ZERO; bees.spread = 180; bees.initial_velocity_min = .1; bees.initial_velocity_max = .3
	bees.orbit_velocity_min = .2; bees.orbit_velocity_max = .5
	var bm := SphereMesh.new(); bm.radius = .012; bm.height = .02; bm.radial_segments = 4; bm.rings = 2
	var bmat := StandardMaterial3D.new(); bmat.albedo_color = Color(.95, .78, .2)
	bm.material = bmat
	bees.mesh = bm
	n.add_child(bees)

func _hydro(n: Node3D) -> void:
	var g := Geo.new(17)
	_pad(g, .4)
	g.cyl(Vector3(0, .03, 0), .3, .3, .12, 18, STEEL, STEEL.lightened(.1), false, false)
	g.cyl(Vector3(0, .02, 0), .26, .26, .125, 18, Color("#3d8a6a"), Color("#57b48a"))
	g.cyl(Vector3(0, .03, 0), .05, .04, .62, 8, STEEL.darkened(.1), STEEL, true, false)
	for k in 6:
		var a := TAU * k / 6
		g.blob(Vector3(cos(a) * .17, .17, sin(a) * .17), Vector3(.05, .04, .05), Color("#4f8a3a"), Color("#a6d86a"), 0)
	_mi(g.commit(), n)
	var arm := Node3D.new(); arm.name = "arm"; arm.position = Vector3(0, .64, 0); n.add_child(arm)
	var ag := Geo.new(18)
	ag.box(Vector3(0, -.015, 0), Vector3(.8, .03, .035), STEEL, STEEL.lightened(.15))
	_mi(ag.commit(), arm)
	for s in [-1, 1]:
		var sp := _spray(); sp.position = Vector3(s * .4, -.05, 0); sp.name = "spray%d" % (s + 1)
		arm.add_child(sp)
	_lamp(n, Vector3(.08, .2, .08))

func _observatory(n: Node3D) -> void:
	var g := Geo.new(19)
	_pad(g, .36)
	g.cyl(Vector3(0, .03, 0), .27, .25, .3, 16, WHITE.darkened(.08), WHITE, true, false)
	g.cyl(Vector3(0, .3, 0), .275, .275, .025, 16, ACC, ACC)
	g.box(Vector3(0, .03, .25), Vector3(.1, .16, .04), DARK, DARK)
	_mi(g.commit(), n)
	var dome := Node3D.new(); dome.name = "dome"; dome.position = Vector3(0, .32, 0); n.add_child(dome)
	var dg := Geo.new(20)
	dg.blob(Vector3.ZERO, Vector3(.26, .24, .26), Color("#b9c4cc"), Color("#e6edf2"), 2, 0)
	dg.box(Vector3(0, .05, .2), Vector3(.07, .22, .12), DARK, DARK, 0)
	_mi(dg.commit(), dome)
	var scope := CylinderMesh.new(); scope.top_radius = .03; scope.bottom_radius = .04; scope.height = .25
	var sc := _mi(scope, dome, null, Vector3(0, .18, .22))
	var smat := StandardMaterial3D.new(); smat.albedo_color = DARK; sc.material_override = smat
	sc.rotation = Vector3(-.9, 0, 0)
	_lamp(n, Vector3(.2, .28, .2))

func _steam(p: Vector3, col: Color, size: float) -> CPUParticles3D:
	var s := CPUParticles3D.new()
	s.amount = 16; s.lifetime = 3.2
	s.position = p
	s.direction = Vector3(0, 1, 0); s.spread = 12
	s.gravity = Vector3(.12, .2, 0)
	s.initial_velocity_min = .18; s.initial_velocity_max = .32
	s.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE; s.emission_sphere_radius = .05
	var m := SphereMesh.new(); m.radius = .07 * size; m.height = .12 * size; m.radial_segments = 8; m.rings = 4
	var mm := StandardMaterial3D.new()
	mm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mm.albedo_color = col; mm.vertex_color_use_as_albedo = true
	mm.diffuse_mode = BaseMaterial3D.DIFFUSE_LAMBERT_WRAP
	mm.roughness = 1.0
	m.material = mm
	s.mesh = m
	var c := Curve.new(); c.add_point(Vector2(0, .3)); c.add_point(Vector2(.4, 1)); c.add_point(Vector2(1, 1.6))
	s.scale_amount_curve = c
	var gr := Gradient.new(); gr.set_color(0, Color(1, 1, 1, 0)); gr.add_point(.15, Color(1, 1, 1, 1)); gr.set_color(gr.get_point_count() - 1, Color(1, 1, 1, 0))
	s.color_ramp = gr
	return s

func _spray() -> CPUParticles3D:
	var s := CPUParticles3D.new()
	s.amount = 30; s.lifetime = .9
	s.direction = Vector3(0, .3, 1); s.spread = 25
	s.gravity = Vector3(0, -2.2, 0)
	s.initial_velocity_min = .5; s.initial_velocity_max = .8
	var m := SphereMesh.new(); m.radius = .012; m.height = .024; m.radial_segments = 4; m.rings = 2
	var mm := StandardMaterial3D.new()
	mm.albedo_color = Color(.8, .92, 1, .7); mm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mm.emission_enabled = true; mm.emission = Color(.5, .7, .9); mm.emission_energy_multiplier = .4
	m.material = mm
	s.mesh = m
	s.local_coords = false
	return s

func animate_buildings(nodes: Dictionary, t: float, dt: float) -> void:
	for i in nodes:
		var n: Node3D = nodes[i]
		var id: String = n.get_meta("id")
		var powered: bool = Game.POW.size() > i and (Game.POW[i] or id in ["tur", "geo", "col", "obs"])
		var lamp := n.get_node_or_null("lamp") as MeshInstance3D
		if lamp: lamp.material_override = lamp_on if powered else lamp_off
		var sp := 1.0 if powered else 0.0
		match id:
			"tur":
				var r := n.get_node("rotor") as Node3D
				r.rotation.z += dt * (2.2 + Game.wx.rain * 1.5)
			"dep", "fri":
				(n.get_node("fan") as Node3D).rotation.y += dt * 9 * sp
				(n.get_node("puff") as CPUParticles3D).emitting = powered
			"asp", "hid":
				(n.get_node("arm") as Node3D).rotation.y += dt * 1.4 * sp
				for k in [0, 2]:
					var s := n.get_node("arm/spray%d" % k) as CPUParticles3D
					if s: s.emitting = powered
			"pum":
				(n.get_node("wheel") as Node3D).rotation.x += dt * 4 * sp
			"sol":
				var h := n.get_node("head") as Node3D
				var dc: Dictionary = Game.day_clock()
				h.rotation.x = lerp_angle(h.rotation.x, -.5 + sin(t * .1) * .1, dt)
				h.rotation.y = fmod(dc.clock * TAU + .6 + PI, TAU)
			"nub":
				(n.get_node("puff") as CPUParticles3D).emitting = powered
			"obs":
				(n.get_node("dome") as Node3D).rotation.y += dt * .4

func night_lights(n: Node3D, night: float) -> void:
	pass

# ======================================================================= animales
func animal(k: String) -> Node3D:
	var n := Node3D.new()
	n.name = "a_" + k
	var body := Node3D.new(); body.name = "body"; n.add_child(body)
	var g := Geo.new(hash(k))
	var wings := false
	match k:
		"deer": _quad(g, .26, .2, Color("#a86e3e"), Color("#efe0c8"), true, false, .06)
		"reindeer": _quad(g, .27, .2, Color("#8a7260"), Color("#e8e2d8"), true, true, .06)
		"goat": _quad(g, .2, .15, Color("#e8e2d6"), Color("#cfc6b6"), false, false, .04, true)
		"bear": _quad(g, .32, .2, Color("#5a3e2c"), Color("#4a3224"), false, false, .1)
		"wolf": _quad(g, .24, .16, Color("#8d8f94"), Color("#d8d8d8"), false, false, .05)
		"fox": _quad(g, .18, .11, Color("#f2f2f2"), Color("#ffffff"), false, false, .05)
		"rabbit": _small(g, .1, Color("#b89a7a"), Color("#f2ece0"), true)
		"hare": _small(g, .12, Color("#eeeeea"), Color("#ffffff"), true)
		"beaver": _small(g, .13, Color("#7a5236"), Color("#5a3a26"), false)
		"frog": _small(g, .06, Color("#5aa83c"), Color("#b6e07a"), false)
		"lizard": _lizard(g)
		"heron": _wader(g, Color("#9fb0bf"), Color("#e8eef2"), .3)
		"flamingo": _wader(g, Color("#f08aa0"), Color("#ffb0c0"), .32)
		"duck": _floater(g, Color("#7a5a3a"), Color("#2f7a4a"))
		"seal": _seal(g)
		"turtle": _turtle(g)
		"fish": _fish(g, .1, Color("#f2a63c"))
		"manta": _manta(g)
		"whale": _whale(g)
		"bee", "butterfly", "parrot": wings = true
	if not wings:
		_mi(g.commit(), body)
	else:
		_flyer(n, body, k)
	return n

func _quad(g: Geo, L: float, H: float, c: Color, belly: Color, antlers: bool, big_antlers: bool, girth: float, horns := false) -> void:
	var leg := H * .55
	var w := L * .28 + girth * .3
	# cuerpo
	g.blob(Vector3(0, leg + w * .55, 0), Vector3(w * .85, w * .75, L * .55), c.darkened(.05), c.lightened(.08), 1, .05)
	g.blob(Vector3(0, leg + w * .3, 0), Vector3(w * .7, w * .45, L * .42), belly.darkened(.1), belly, 0, .05)
	# patas
	for sx in [-1, 1]:
		for sz in [-1, 1]:
			g.cyl(Vector3(sx * w * .45, 0, sz * L * .32), .018 + girth * .15, .022 + girth * .15, leg + w * .3, 5, c.darkened(.35), c.darkened(.1), false)
	# cuello y cabeza
	var hp := Vector3(0, leg + w * 1.25 + H * .2, L * .52)
	g.cyl(Vector3(0, leg + w * .6, L * .4), w * .38, w * .3, H * .5, 6, c, c, false, false)
	g.blob(hp, Vector3(w * .42, w * .42, w * .6), c.darkened(.05), c.lightened(.1), 1, .05)
	g.blob(hp + Vector3(0, -.01, w * .5), Vector3(w * .22, w * .2, w * .3), c.darkened(.25), c.darkened(.15), 0, 0)
	for sx in [-1, 1]:
		g.leaf_card(hp + Vector3(sx * w * .25, w * .3, -.01), Vector3(sx * .7, .7, -.2).normalized(), .035, .06, c, belly)
		if antlers:
			var base := hp + Vector3(sx * w * .15, w * .35, 0)
			var tip := base + Vector3(sx * .06, .12 if big_antlers else .09, -.02)
			g.cyl(base, .008, .006, (tip - base).length(), 4, Color("#d8c8a8"), Color("#efe6d2"), false)
			for b in 2:
				var bb := base + (tip - base) * (.4 + b * .3)
				g.cyl(bb, .006, .004, .05, 4, Color("#d8c8a8"), Color("#efe6d2"), false)
		if horns:
			g.cyl(hp + Vector3(sx * w * .15, w * .35, -.02), .012, .004, .07, 5, Color("#6a5a4a"), Color("#8a7a6a"), false)
	# cola
	g.blob(Vector3(0, leg + w * .8, -L * .55), Vector3(w * .18, w * .18, w * .3), belly, belly, 0, 0)

func _small(g: Geo, L: float, c: Color, belly: Color, ears: bool) -> void:
	g.blob(Vector3(0, L * .45, 0), Vector3(L * .4, L * .38, L * .55), c.darkened(.05), c.lightened(.1), 1, .05)
	g.blob(Vector3(0, L * .7, L * .45), Vector3(L * .28, L * .26, L * .3), c, c.lightened(.1), 1, .05)
	g.blob(Vector3(0, L * .35, -L * .5), Vector3(L * .12, L * .12, L * .12), belly, belly, 0, 0)
	if ears:
		for sx in [-1, 1]:
			g.leaf_card(Vector3(sx * L * .1, L * .9, L * .4), Vector3(sx * .2, 1, -.25).normalized(), L * .16, L * .5, c, belly)

func _lizard(g: Geo) -> void:
	var c := Color("#6a9a4a")
	g.blob(Vector3(0, .03, 0), Vector3(.03, .02, .07), c, c.lightened(.2), 0, 0)
	g.blob(Vector3(0, .035, .08), Vector3(.022, .018, .03), c, c.lightened(.2), 0, 0)
	g.cyl(Vector3(0, .03, -.07), .015, .003, .1, 4, c, c, false)

func _wader(g: Geo, c: Color, c2: Color, H: float) -> void:
	for sx in [-1, 1]:
		g.cyl(Vector3(sx * .02, 0, 0), .006, .006, H * .5, 4, Color("#d0705a") if c.r > .9 else Color("#c8a040"), Color("#c06040"), false)
	g.blob(Vector3(0, H * .58, 0), Vector3(.05, .045, .09), c, c2, 1, .05)
	g.cyl(Vector3(0, H * .62, .06), .012, .01, H * .35, 5, c, c2, false)
	g.blob(Vector3(0, H * .98, .07), Vector3(.025, .022, .03), c, c2, 0, 0)
	g.cyl(Vector3(0, H * .98, .09), .006, .001, .07, 4, Color("#e8c040"), Color("#303030"), false)

func _floater(g: Geo, c: Color, head: Color) -> void:
	g.blob(Vector3(0, .03, 0), Vector3(.05, .035, .08), c, c.lightened(.2), 1, .05)
	g.blob(Vector3(0, .085, .055), Vector3(.026, .026, .026), head, head.lightened(.2), 0, 0)
	g.blob(Vector3(0, .08, .085), Vector3(.012, .007, .02), Color("#e8a030"), Color("#f0b040"), 0, 0)

func _seal(g: Geo) -> void:
	var c := Color("#6f7680")
	g.blob(Vector3(0, .03, 0), Vector3(.07, .05, .16), c, c.lightened(.2), 1, .05)
	g.blob(Vector3(0, .07, .13), Vector3(.045, .045, .05), c, c.lightened(.25), 1, .03)

func _turtle(g: Geo) -> void:
	var c := Color("#4f6a3a")
	g.blob(Vector3(0, .04, 0), Vector3(.09, .045, .11), Color("#5a4a30"), Color("#8a7448"), 1, .05)
	g.blob(Vector3(0, .03, .12), Vector3(.03, .025, .035), c, c.lightened(.2), 0, 0)
	for sx in [-1, 1]:
		g.leaf_card(Vector3(sx * .07, .02, .05), Vector3(sx, -.1, .4).normalized(), .05, .08, c, c)

func _fish(g: Geo, L: float, c: Color) -> void:
	g.blob(Vector3(0, 0, 0), Vector3(L * .2, L * .3, L * .5), c, c.lightened(.2), 1, .05)

func _manta(g: Geo) -> void:
	var c := Color("#2e3c4a")
	g.ctr = Vector3(0, -1, 0)
	g.tri(Vector3(0, 0, .2), Vector3(.28, 0, -.05), Vector3(0, 0, -.12), c, c.lightened(.1))
	g.tri(Vector3(0, 0, .2), Vector3(0, 0, -.12), Vector3(-.28, 0, -.05), c, c.lightened(.1))
	g.blob(Vector3(0, .01, .03), Vector3(.06, .02, .12), c, c.lightened(.1), 0, 0)
	g.cyl(Vector3(0, 0, -.12), .006, .002, .2, 3, c, c, false)

func _whale(g: Geo) -> void:
	var c := Color("#3c4f66")
	g.blob(Vector3(0, 0, 0), Vector3(.22, .18, .6), c, c.lightened(.15), 1, .04)
	g.blob(Vector3(0, -.05, .1), Vector3(.17, .1, .5), Color("#d8dde2"), Color("#e8ecef"), 1, .04)
	g.ctr = Vector3(0, 1, -.55)
	g.tri(Vector3(0, .04, -.58), Vector3(.25, .06, -.8), Vector3(0, .04, -.72), c)
	g.tri(Vector3(0, .04, -.58), Vector3(0, .04, -.72), Vector3(-.25, .06, -.8), c)

func _flyer(n: Node3D, body: Node3D, k: String) -> void:
	var g := Geo.new(hash(k))
	var c := Color("#e8473f"); var wc := Color("#2f7ad0"); var s := .05
	match k:
		"bee": c = Color("#f0c030"); wc = Color(.9, .95, 1, .6); s = .025
		"butterfly": c = Color("#3a2a20"); wc = [Color("#f29a3a"), Color("#6ab0f2"), Color("#f2e05a")][randi() % 3]; s = .035
		"parrot": c = Color("#e0402f"); wc = Color("#2f6ad0"); s = .07
	g.blob(Vector3.ZERO, Vector3(s * .35, s * .35, s), c, c.lightened(.2), 0, 0)
	if k == "parrot":
		g.blob(Vector3(0, s * .2, s * .9), Vector3(s * .35, s * .35, s * .35), c, c.lightened(.2), 0, 0)
		g.cyl(Vector3(0, -s * .1, -s), s * .15, s * .05, s * 1.4, 4, Color("#2f6ad0"), Color("#f2d24b"), false)
	_mi(g.commit(), body)
	for side in [-1, 1]:
		var wn := Node3D.new(); wn.name = "w%d" % (side + 1); body.add_child(wn)
		var wg := Geo.new(3)
		var span := s * (2.4 if k == "butterfly" else 2.0)
		wg.ctr = Vector3(0, -1, 0)
		wg.tri(Vector3.ZERO, Vector3(side * span, 0, s * .6), Vector3(side * span * .8, 0, -s * .9), wc, wc.lightened(.2))
		wg.ctr = Vector3(0, 1, 0)
		wg.tri(Vector3.ZERO, Vector3(side * span, 0, s * .6), Vector3(side * span * .8, 0, -s * .9), wc, wc.lightened(.2))
		_mi(wg.commit(), wn)

func animate_animal(n: Node3D, k: String, t: float, walk: bool, graze: bool, jump: float) -> void:
	var body := n.get_node("body") as Node3D
	match k:
		"bee", "butterfly", "parrot":
			var f := 30.0 if k == "bee" else (9.0 if k == "butterfly" else 12.0)
			var a := sin(t * f) * (1.1 if k == "butterfly" else .8)
			var w0 := body.get_node("w0") as Node3D; var w2 := body.get_node("w2") as Node3D
			w0.rotation.z = -a; w2.rotation.z = a
		"whale", "manta":
			body.rotation.x = sin(t * .8) * .06 - jump * .4 * sin(jump * PI)
		_:
			if walk:
				body.rotation.x = sin(t * 9) * .04
				body.position.y = 0
			elif graze:
				body.rotation.x = lerpf(body.rotation.x, .32, .05)
			else:
				body.rotation.x = lerpf(body.rotation.x, 0, .1)
				body.scale.y = 1.0 + sin(t * 2.2) * .015

# ======================================================================= dron de reciclaje
func lift_model(id: String) -> Node3D:
	var n := make(id, 0)
	n.rotation.y = 0
	return n

func drone() -> Node3D:
	var n := Node3D.new()
	var g := Geo.new(5)
	g.box(Vector3(0, 0, 0), Vector3(.22, .06, .22), Color("#3a4048"), Color("#e3b23c"))
	for sx in [-1, 1]:
		for sz in [-1, 1]:
			g.cyl(Vector3(sx * .16, .03, sz * .16), .012, .012, .04, 5, DARK, DARK)
			g.cyl(Vector3(sx * .16, .07, sz * .16), .09, .09, .006, 12, Color(.8, .85, .9, 1), Color(.9, .95, 1, 1), false)
	g.cyl(Vector3(0, -.3, 0), .004, .004, .3, 4, DARK, DARK, false)
	_mi(g.commit(), n)
	return n

func airship() -> Node3D:
	var n := Node3D.new()
	var g := Geo.new(9)
	g.blob(Vector3(0, 1.0, 0), Vector3(.9, .75, 2.1), Color("#c9b48a"), Color("#f2e6c8"), 2, .02)
	for k in 5:
		var z := -1.4 + k * .7
		g.cyl(Vector3(0, .25 + absf(z) * .1, z), .9 - absf(z) * .18, .9 - absf(z) * .18, .05, 18, Color("#8a5a3a"), Color("#9a6a48"), false)
	g.box(Vector3(0, 0, 0), Vector3(.5, .32, 1.1), Color("#8a5a3a"), Color("#b0805a"))
	g.box(Vector3(0, .32, 0), Vector3(.58, .05, 1.2), Color("#5a3a26"), Color("#6a4a32"))
	for sx in [-1, 1]:
		g.ctr = Vector3(sx * -1, 1, -2)
		g.tri(Vector3(sx * .3, 1.0, -1.7), Vector3(sx * 1.0, 1.0, -2.5), Vector3(sx * .2, 1.0, -2.4), Color("#a8483a"))
	g.ctr = Vector3(1, 1, -2)
	g.tri(Vector3(0, 1.4, -1.6), Vector3(0, 2.0, -2.5), Vector3(0, 1.3, -2.4), Color("#a8483a"))
	for k in 4:
		g.box(Vector3(-.18 + k * .12, .12, .56), Vector3(.07, .07, .01), Color("#ffe6a0"), Color("#ffe6a0"))
	var mi := _mi(g.commit(), n)
	for sx in [-1, 1]:
		var p := Node3D.new(); p.name = "prop%d" % (sx + 1); p.position = Vector3(sx * .55, .2, -.6); n.add_child(p)
		var pg := Geo.new(4)
		for k in 3:
			var a := TAU * k / 3
			pg.box(Vector3(cos(a) * .12, sin(a) * .12, 0), Vector3(.24, .04, .01), WOOD, WOOD, 0)
		_mi(pg.commit(), p)
	return n
