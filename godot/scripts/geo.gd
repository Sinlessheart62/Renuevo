class_name Geo
## Construcción de mallas procedurales con colores por vértice.

var st := SurfaceTool.new()
var rng := RandomNumberGenerator.new()
var ctr := Vector3.INF   # punto interior: las normales planas apuntan hacia afuera de él

func _init(sd := 1) -> void:
	rng.seed = sd
	st.begin(Mesh.PRIMITIVE_TRIANGLES)

func tri(a: Vector3, b: Vector3, c: Vector3, ca: Color, cb := Color(0,0,0,0), cc := Color(0,0,0,0)) -> void:
	if cb.a == 0: cb = ca
	if cc.a == 0: cc = ca
	var n := (b - a).cross(c - a).normalized()
	if ctr != Vector3.INF and n.dot((a + b + c) / 3.0 - ctr) < 0: n = -n
	st.set_normal(n); st.set_color(ca); st.add_vertex(a)
	st.set_normal(n); st.set_color(cb); st.add_vertex(b)
	st.set_normal(n); st.set_color(cc); st.add_vertex(c)

func tri_n(a: Vector3, b: Vector3, c: Vector3, na: Vector3, nb: Vector3, nc: Vector3, ca: Color, cb: Color, cc: Color) -> void:
	st.set_normal(na); st.set_color(ca); st.add_vertex(a)
	st.set_normal(nb); st.set_color(cb); st.add_vertex(b)
	st.set_normal(nc); st.set_color(cc); st.add_vertex(c)

func quad(a: Vector3, b: Vector3, c: Vector3, d: Vector3, col: Color, col2 := Color(0,0,0,0)) -> void:
	if col2.a == 0: col2 = col
	tri(a, b, c, col, col, col2); tri(a, c, d, col, col2, col2)

## Cono/cilindro facetado (r0 abajo, r1 arriba). flat=true para aspecto low-poly.
func cyl(p: Vector3, r0: float, r1: float, h: float, seg: int, c0: Color, c1: Color, cap := true, flat := true, jitter := 0.0, rot := 0.0) -> void:
	ctr = p + Vector3(0, h * .35, 0)
	for k in seg:
		var a0 := rot + TAU * k / seg
		var a1 := rot + TAU * (k + 1) / seg
		var j0 := 1.0 + (rng.randf() - .5) * jitter
		var j1 := 1.0 + (rng.randf() - .5) * jitter
		var b0 := p + Vector3(cos(a0) * r0, 0, sin(a0) * r0)
		var b1 := p + Vector3(cos(a1) * r0, 0, sin(a1) * r0)
		var t0 := p + Vector3(cos(a0) * r1 * j0, h, sin(a0) * r1 * j0)
		var t1 := p + Vector3(cos(a1) * r1 * j1, h, sin(a1) * r1 * j1)
		if flat:
			if r1 > 0.0005:
				tri(b0, t0, t1, c0, c1, c1); tri(b0, t1, b1, c0, c1, c0)
			else:
				tri(b0, p + Vector3(0, h, 0), b1, c0, c1, c0)
		else:
			var n0 := Vector3(cos(a0), (r0 - r1) / h, sin(a0)).normalized()
			var n1 := Vector3(cos(a1), (r0 - r1) / h, sin(a1)).normalized()
			tri_n(b0, t0, t1, n0, n0, n1, c0, c1, c1); tri_n(b0, t1, b1, n0, n1, n1, c0, c1, c0)
		if cap:
			tri(p, b0, b1, c0.darkened(.3))
			if r1 > 0.0005: tri(p + Vector3(0, h, 0), t1, t0, c1)

## Esfera irregular (icosfera) con degradado vertical y normales suaves.
## ncen/nblend: normales "esféricas" respecto a un centro común (copas esponjosas).
## grad_fn: si se da, colorea según la posición en el mundo de la malla.
var ncen := Vector3.INF
var nblend := 0.0
var cfn: Callable
func blob(p: Vector3, r: Vector3, c_low: Color, c_high: Color, sub := 1, jit := .12) -> void:
	var verts := _ico(sub)
	var disp := {}
	for k in verts[0].size():
		var v: Vector3 = verts[0][k]
		disp[k] = v * (1.0 + (rng.randf() - .5) * jit * 2)
	for f in verts[1]:
		var pa: Vector3 = disp[f[0]]; var pb: Vector3 = disp[f[1]]; var pc: Vector3 = disp[f[2]]
		var A := p + pa * r; var Bv := p + pb * r; var Cv := p + pc * r
		var na := pa.normalized(); var nb := pb.normalized(); var nc := pc.normalized()
		if ncen != Vector3.INF:
			na = na.lerp((A - ncen).normalized(), nblend).normalized()
			nb = nb.lerp((Bv - ncen).normalized(), nblend).normalized()
			nc = nc.lerp((Cv - ncen).normalized(), nblend).normalized()
		var ca: Color; var cb: Color; var cc: Color
		if cfn.is_valid():
			ca = cfn.call(A, na); cb = cfn.call(Bv, nb); cc = cfn.call(Cv, nc)
		else:
			ca = c_low.lerp(c_high, clampf(pa.y * .5 + .5, 0, 1))
			cb = c_low.lerp(c_high, clampf(pb.y * .5 + .5, 0, 1))
			cc = c_low.lerp(c_high, clampf(pc.y * .5 + .5, 0, 1))
		tri_n(A, Cv, Bv, na, nc, nb, ca, cc, cb)

## Copa de follaje: racimos sobre un elipsoide, con normales y color de volumen único.
func canopy(c: Vector3, r: Vector3, n: int, pal: Array, clump := .42, sub := 1) -> void:
	ncen = c; nblend = .78
	var top := c.y + r.y; var bot := c.y - r.y
	cfn = func(v: Vector3, nn: Vector3) -> Color:
		var h := clampf((v.y - bot) / (top - bot), 0, 1)
		var side := clampf(nn.dot(Vector3(.45, .75, .5).normalized()) * .5 + .5, 0, 1)
		var t := clampf(h * .55 + side * .55 - .1, 0, 1)
		var col: Color
		if t < .5: col = (pal[0] as Color).lerp(pal[1], t * 2)
		else: col = (pal[1] as Color).lerp(pal[2], (t - .5) * 2)
		return col.lerp(pal[3], smoothstep(.82, 1.0, t) * .6)
	# racimo central que tapa huecos
	blob(c, r * .78, pal[0], pal[1], sub, .1)
	for k in n:
		var u := rng.randf() * TAU
		var v := acos(rng.randf_range(-.35, 1.0))
		var dir := Vector3(sin(v) * cos(u), cos(v), sin(v) * sin(u))
		var cr := r.length() / sqrt(3.0) * clump * rng.randf_range(.75, 1.15)
		blob(c + dir * r * .72, Vector3(cr, cr * .82, cr), pal[0], pal[1], sub, .16)
	ncen = Vector3.INF; nblend = 0.0; cfn = Callable()

func box(p: Vector3, s: Vector3, c: Color, ctop := Color(0,0,0,0), rot := 0.0) -> void:
	if ctop.a == 0: ctop = c.lightened(.08)
	ctr = p + Vector3(0, s.y * .5, 0)
	var hx := s.x / 2; var hz := s.z / 2
	var b := Basis(Vector3.UP, rot)
	var P := func(x: float, y: float, z: float) -> Vector3: return p + b * Vector3(x, y, z)
	var c0: Vector3 = P.call(-hx, 0, -hz); var c1: Vector3 = P.call(hx, 0, -hz); var c2: Vector3 = P.call(hx, 0, hz); var c3: Vector3 = P.call(-hx, 0, hz)
	var t0: Vector3 = P.call(-hx, s.y, -hz); var t1: Vector3 = P.call(hx, s.y, -hz); var t2: Vector3 = P.call(hx, s.y, hz); var t3: Vector3 = P.call(-hx, s.y, hz)
	quad(t0, t3, t2, t1, ctop)
	quad(c0, t0, t1, c1, c.darkened(.05), c)
	quad(c1, t1, t2, c2, c.darkened(.12), c.darkened(.06))
	quad(c2, t2, t3, c3, c.darkened(.05), c)
	quad(c3, t3, t0, c0, c.darkened(.12), c.darkened(.06))
	quad(c0, c1, c2, c3, c.darkened(.4))

func leaf_card(p: Vector3, dir: Vector3, w: float, l: float, c0: Color, c1: Color) -> void:
	ctr = Vector3.INF
	var side := dir.cross(Vector3.UP).normalized() * w * .5
	if side.length() < .001: side = Vector3(w * .5, 0, 0)
	var tip := p + dir * l
	var mid := p + dir * l * .45
	# una sola cara: el shader ilumina el reverso (sin duplicados que parpadeen)
	tri(p, mid + side, tip, c0, c1, c1); tri(p, tip, mid - side, c0, c1, c1)

static var last_arrays: Array = []
func commit() -> ArrayMesh:
	st.index()
	if OS.has_feature("editor") or OS.get_cmdline_user_args().has("--nantest"):
		last_arrays = st.commit_to_arrays()
		_scan(last_arrays)
	return st.commit()

static var bad_log := {}
func _scan(a: Array) -> void:
	var bad := 0
	for v in a[Mesh.ARRAY_NORMAL]:
		if not v.is_finite() or v.length() < .5: bad += 1
	for v in a[Mesh.ARRAY_VERTEX]:
		if not v.is_finite(): bad += 1
	if bad > 0:
		print("BADMESH bad=", bad, " verts=", a[Mesh.ARRAY_VERTEX].size(), " stack=", get_stack())

var _ico_cache := {}
func _ico(sub: int) -> Array:
	if _ico_cache.has(sub): return _ico_cache[sub]
	var t := (1.0 + sqrt(5.0)) / 2.0
	var v: Array[Vector3] = []
	for p in [[-1,t,0],[1,t,0],[-1,-t,0],[1,-t,0],[0,-1,t],[0,1,t],[0,-1,-t],[0,1,-t],[t,0,-1],[t,0,1],[-t,0,-1],[-t,0,1]]:
		v.append(Vector3(p[0], p[1], p[2]).normalized())
	var f := [[0,11,5],[0,5,1],[0,1,7],[0,7,10],[0,10,11],[1,5,9],[5,11,4],[11,10,2],[10,7,6],[7,1,8],[3,9,4],[3,4,2],[3,2,6],[3,6,8],[3,8,9],[4,9,5],[2,4,11],[6,2,10],[8,6,7],[9,8,1]]
	for s in sub:
		var nf := []
		var mid := {}
		var gm := func(a: int, b: int) -> int:
			var key := Vector2i(mini(a, b), maxi(a, b))
			if mid.has(key): return mid[key]
			v.append(((v[a] + v[b]) * .5).normalized()); mid[key] = v.size() - 1
			return v.size() - 1
		for tr in f:
			var a: int = gm.call(tr[0], tr[1]); var b: int = gm.call(tr[1], tr[2]); var c: int = gm.call(tr[2], tr[0])
			nf.append([tr[0], a, c]); nf.append([tr[1], b, a]); nf.append([tr[2], c, b]); nf.append([a, b, c])
		f = nf
	_ico_cache[sub] = [v, f]
	return _ico_cache[sub]

# ======================================================================= vegetación (estilo Ghibli)
const LEAF := [Color("#2f5a3c"), Color("#5e9a3f"), Color("#a6cc52"), Color("#e2ec86")]
const LEAF_DARK := [Color("#244a3a"), Color("#3f7a45"), Color("#7fb04f"), Color("#c7e07a")]
const LEAF_JUNGLE := [Color("#1f4d36"), Color("#368a45"), Color("#78c04e"), Color("#cfe878")]
const LEAF_TAIGA := [Color("#22423c"), Color("#3b6d58"), Color("#6f9e7a"), Color("#e9f2f2")]
const BARK := Color("#6b4a36")

static func _trunk(g: Geo, h: float, r: float, lean := Vector3.ZERO) -> Vector3:
	var segs := 4
	var prev := Vector3.ZERO
	for k in segs:
		var f := float(k + 1) / segs
		var p := Vector3(lean.x * f * f, h * f, lean.z * f * f)
		var rr := r * (1.0 - f * .45)
		g.cyl(prev, rr * 1.08, rr, (p - prev).length(), 7, BARK.darkened(.25), BARK.lightened(.05), false, false)
		prev = p
	# raíces que se abren en la base
	for k in 4:
		var a := TAU * k / 4 + g.rng.randf() * .5
		g.leaf_card(Vector3(0, .02, 0), Vector3(cos(a), -.35, sin(a)).normalized(), r * 1.2, r * 2.2, BARK.darkened(.3), BARK.darkened(.1))
	return prev

static func pine(sd: int, dark := false) -> ArrayMesh:
	# conífera de copas escalonadas y redondeadas (como cedros japoneses)
	var g := Geo.new(sd)
	var h := .62 + g.rng.randf() * .22
	var top := _trunk(g, h * .5, .035)
	var pal := LEAF_DARK
	var tiers := 4
	for k in tiers:
		var f := float(k) / tiers
		var y := .12 + f * h * .78
		var r := .2 * (1.0 - f * .62)
		g.ncen = Vector3(0, y - .05, 0); g.nblend = .7
		var bot := .1; var tp := h + .2
		g.cfn = func(v: Vector3, nn: Vector3) -> Color:
			var hh := clampf((v.y - bot) / (tp - bot), 0, 1)
			var side := clampf(nn.dot(Vector3(.45, .75, .5).normalized()) * .5 + .5, 0, 1)
			var t := clampf(hh * .4 + side * .7 - .1, 0, 1)
			return (pal[0] as Color).lerp(pal[1], minf(1, t * 2)) if t < .5 else (pal[1] as Color).lerp(pal[2], (t - .5) * 2)
		var n := 6 + (3 - k)
		for j in n:
			var a := TAU * j / n + g.rng.randf() * .4
			var cr := r * .55
			g.blob(Vector3(cos(a) * r * .7, y + g.rng.randf() * .03, sin(a) * r * .7), Vector3(cr, cr * .7, cr), pal[0], pal[1], 1, .15)
		g.blob(Vector3(0, y + .03, 0), Vector3(r * .75, r * .55, r * .75), pal[0], pal[1], 1, .1)
	g.blob(Vector3(0, h + .1, 0), Vector3(.045, .07, .045), pal[1], pal[2], 1, .1)
	g.ncen = Vector3.INF; g.nblend = 0; g.cfn = Callable()
	return g.commit()

static func spruce(sd: int) -> ArrayMesh:
	var g := Geo.new(sd)
	var h := .7 + g.rng.randf() * .2
	_trunk(g, h * .4, .03)
	var pal := LEAF_TAIGA
	for k in 5:
		var f := k / 5.0
		var y := .08 + f * h * .8
		var r := .17 * (1.0 - f * .7)
		g.ncen = Vector3(0, y - .04, 0); g.nblend = .7
		var bot := .06; var tp := h + .1
		g.cfn = func(v: Vector3, nn: Vector3) -> Color:
			var up := smoothstep(.55, .85, nn.y)
			var hh := clampf((v.y - bot) / (tp - bot), 0, 1)
			var base: Color = (pal[0] as Color).lerp(pal[2], clampf(hh * .5 + nn.dot(Vector3(.45, .75, .5).normalized()) * .4, 0, 1))
			return base.lerp(pal[3], up * .85)   # nieve en lo alto de cada piso
		for j in 7:
			var a := TAU * j / 7 + g.rng.randf() * .4
			var cr := r * .5
			g.blob(Vector3(cos(a) * r * .7, y, sin(a) * r * .7), Vector3(cr, cr * .6, cr), pal[0], pal[1], 1, .12)
		g.blob(Vector3(0, y + .02, 0), Vector3(r * .7, r * .5, r * .7), pal[0], pal[1], 1, .1)
	g.ncen = Vector3.INF; g.nblend = 0; g.cfn = Callable()
	return g.commit()

static func broad(sd: int, tropical := false) -> ArrayMesh:
	# árbol frondoso de copa esponjosa (alcanfor de Totoro)
	var g := Geo.new(sd)
	var h := .26 + g.rng.randf() * .08
	var lean := Vector3((g.rng.randf() - .5) * .08, 0, (g.rng.randf() - .5) * .08)
	var top := _trunk(g, h, .05, lean)
	for k in 2:
		var a := g.rng.randf() * TAU
		g.leaf_card(top - Vector3(0, .06, 0), Vector3(cos(a), .9, sin(a)).normalized(), .035, .14, BARK, BARK.lightened(.1))
	var rx := .23 + g.rng.randf() * .06
	var ry := .17 + g.rng.randf() * .04
	g.canopy(top + Vector3(0, ry * .75, 0), Vector3(rx, ry, rx * .95), 9 + g.rng.randi() % 4, LEAF_JUNGLE if tropical else LEAF, .48)
	return g.commit()
static func palm(sd: int) -> ArrayMesh:
	var g := Geo.new(sd)
	var h := .55 + g.rng.randf() * .2
	var bend := Vector3((g.rng.randf() - .5) * .25, 0, (g.rng.randf() - .5) * .25)
	var segs := 6
	var prev := Vector3.ZERO
	for k in segs:
		var f := float(k + 1) / segs
		var p := Vector3(bend.x * f * f, h * f, bend.z * f * f)
		var c := Color("#8a6a4a") if k % 2 == 0 else Color("#7a5c40")
		g.cyl(prev, .035 - k * .003, .03 - k * .003, (p - prev).length(), 6, c, c.lightened(.1), false, false)
		prev = p
	for k in 7:
		var a := TAU * k / 7 + g.rng.randf() * .3
		var d := Vector3(cos(a), .25 - g.rng.randf() * .4, sin(a)).normalized()
		g.leaf_card(prev, d, .1, .32, Color("#3f8a3a"), Color("#8fcf5a"))
	g.blob(prev + Vector3(0, -.03, 0), Vector3(.035, .035, .035), Color("#5a3f22"), Color("#7a5a32"), 0)
	return g.commit()

static func bush(sd: int, flowers := false) -> ArrayMesh:
	var g := Geo.new(sd)
	var r := .1 + g.rng.randf() * .03
	g.canopy(Vector3(0, r * .65, 0), Vector3(r * 1.2, r * .8, r * 1.1), 5, LEAF, .55, 1)
	if flowers:
		var cols := [Color("#ffe066"), Color("#ff8fb1"), Color("#ffffff"), Color("#c3a6ff"), Color("#ffad5a")]
		var fc: Color = cols[g.rng.randi() % cols.size()]
		for k in 14:
			var u := g.rng.randf() * TAU; var v := g.rng.randf() * 1.2
			var d := Vector3(sin(v) * cos(u), cos(v), sin(v) * sin(u))
			g.blob(Vector3(0, r * .65, 0) + d * Vector3(r * 1.25, r * .85, r * 1.15), Vector3(.016, .013, .016), fc, fc.lightened(.25), 0, 0)
	return g.commit()

static func reed(sd: int) -> ArrayMesh:
	# mata de juncos con espadañas color canela (formas suaves, sin caras planas)
	var g := Geo.new(sd)
	for k in 8:
		var a := g.rng.randf() * TAU; var r := g.rng.randf() * .07
		var p := Vector3(cos(a) * r, 0, sin(a) * r)
		var h := .22 + g.rng.randf() * .16
		var d := Vector3(cos(a) * .25, 1, sin(a) * .25).normalized()
		g.leaf_card(p, d, .045, h, Color("#5d8f3e"), Color("#b8d46a"))
		if k < 2:
			g.blob(p + d * h * .9, Vector3(.02, .045, .02), Color("#a8713c"), Color("#c99052"), 1, 0)
	return g.commit()

static func mangrove(sd: int) -> ArrayMesh:
	var g := Geo.new(sd)
	var root := Color("#6a5440")
	for k in 6:
		var a := TAU * k / 6 + g.rng.randf() * .4
		var foot := Vector3(cos(a) * .17, -.08, sin(a) * .17)
		var top := Vector3(cos(a) * .04, .16, sin(a) * .04)
		var mid := (foot + top) * .5 + Vector3(cos(a) * .05, .07, sin(a) * .05)
		g.cyl(foot, .012, .012, (mid - foot).length(), 4, root, root, false)
		g.cyl(mid, .012, .012, (top - mid).length(), 4, root, root, false)
	g.cyl(Vector3(0, .1, 0), .03, .025, .18, 6, root, root.lightened(.1), false, false)
	g.canopy(Vector3(0, .34, 0), Vector3(.2, .11, .2), 7, LEAF_JUNGLE, .5)
	return g.commit()

static func dead(sd: int) -> ArrayMesh:
	var g := Geo.new(sd)
	var c := Color("#5a4a44")
	g.cyl(Vector3.ZERO, .03, .015, .32, 5, c.darkened(.2), c, true, true, .2)
	for k in 3:
		var a := g.rng.randf() * TAU
		var p := Vector3(0, .15 + k * .05, 0)
		var d := Vector3(cos(a), .8, sin(a)).normalized()
		g.leaf_card(p, d, .02, .14, c, c.lightened(.1))
	return g.commit()

static func boulder(sd: int, col := Color("#8d8a85")) -> ArrayMesh:
	var g := Geo.new(sd)
	var n := 1 + g.rng.randi() % 3
	for k in n:
		var a := g.rng.randf() * TAU
		var r := .06 + g.rng.randf() * .08
		g.blob(Vector3(cos(a) * .08 * k, r * .35, sin(a) * .08 * k), Vector3(r * 1.2, r * .8, r), col.darkened(.25), col.lightened(.12), 0, .35)
	return g.commit()

static func flower_head() -> ArrayMesh:
	var g := Geo.new(3)
	for k in 5:
		var a := TAU * k / 5
		var d := Vector3(cos(a), .25, sin(a)).normalized()
		g.leaf_card(Vector3(0, .0, 0), d, .03, .035, Color.WHITE, Color.WHITE)
	g.blob(Vector3(0, .005, 0), Vector3(.012, .01, .012), Color("#f5c84a"), Color("#ffe27a"), 0, 0)
	g.cyl(Vector3(0, -.09, 0), .004, .004, .09, 4, Color("#4f8a3a"), Color("#6faa4a"), false)
	return g.commit()

static func blade() -> ArrayMesh:
	var g := Geo.new(1)
	var w := .022; var h := 1.0
	var pts := [Vector3(-w, 0, 0), Vector3(w, 0, 0), Vector3(-w * .7, h * .4, 0), Vector3(w * .7, h * .4, 0), Vector3(-w * .35, h * .75, 0), Vector3(w * .35, h * .75, 0), Vector3(0, h, 0)]
	var c := func(y: float) -> Color: return Color(y, y, y, 1)
	for s in [[0,1,3,2],[2,3,5,4]]:
		var a: Vector3 = pts[s[0]]; var b: Vector3 = pts[s[1]]; var cc: Vector3 = pts[s[2]]; var d: Vector3 = pts[s[3]]
		g.tri_n(a, b, cc, Vector3(0, .3, 1), Vector3(0, .3, 1), Vector3(0, .3, 1), c.call(a.y), c.call(b.y), c.call(cc.y))
		g.tri_n(a, cc, d, Vector3(0, .3, 1), Vector3(0, .3, 1), Vector3(0, .3, 1), c.call(a.y), c.call(cc.y), c.call(d.y))
	g.tri_n(pts[4], pts[5], pts[6], Vector3(0, .3, 1), Vector3(0, .3, 1), Vector3(0, .3, 1), c.call(.75), c.call(.75), c.call(1.0))
	return g.commit()

static func cloud(sd: int) -> ArrayMesh:
	# cúmulo esponjoso: base plana, torres redondeadas, normales de volumen
	var g := Geo.new(sd)
	var n := 6 + g.rng.randi() % 4
	var c := Vector3(0, .6, 0)
	g.ncen = c; g.nblend = .65
	g.cfn = func(v: Vector3, nn: Vector3) -> Color:
		var t := clampf(nn.y * .5 + .5, 0, 1)
		return Color("#c9cde6").lerp(Color("#ffffff"), smoothstep(.2, .75, t)).lerp(Color("#fff3e2"), smoothstep(.8, 1.0, t) * .5)
	for k in n:
		var x := (k - n / 2.0) * .5 + (g.rng.randf() - .5) * .3
		var r := .5 + g.rng.randf() * .4 - absf(x) * .15
		g.blob(Vector3(x, r * .55, (g.rng.randf() - .5) * .6), Vector3(r, r * .85, r * .85), Color.WHITE, Color.WHITE, 2, .08)
	for k in 3:
		var x := (g.rng.randf() - .5) * n * .25
		var r := .55 + g.rng.randf() * .3
		g.blob(Vector3(x, r * 1.1 + .3, (g.rng.randf() - .5) * .3), Vector3(r, r * .9, r * .85), Color.WHITE, Color.WHITE, 2, .06)
	g.ncen = Vector3.INF; g.nblend = 0; g.cfn = Callable()
	return g.commit()
