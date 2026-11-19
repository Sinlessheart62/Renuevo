extends Node
## Lógica del juego (independiente de los gráficos). Emite señales que el mundo 3D y la interfaz escuchan.

signal tile_changed(i: int, old_t: String)
signal building_changed(i: int, old_b: String)
signal map_rebuilt
signal toast(msg: String)
signal hud_changed
signal phase_changed(ph: int)
signal fx(kind: String, i: int, arg)
signal fauna_changed
signal leaving_started
signal finished(text: String)
signal scanned_animal(i: int, a: Dictionary)

const C := 20
const R := 20
const SKEY := "user://partida.json"
const PKEY := "user://progreso.json"

var region_id := "valle"
var REG: Dictionary = {}
var T: Array[String] = []      # tipo de terreno por casilla
var H := PackedInt32Array()     # altura por casilla
var B: Array[String] = []      # edificio por casilla ("" = ninguno)
var born := PackedFloat32Array()  # momento en que cambió la casilla (para animaciones)
var bborn := PackedFloat32Array()

var POW: Array[bool] = []
var COV: Array[bool] = []
var SRC := PackedInt32Array()
var LOAD := PackedInt32Array()

var seed_v := 1
var leaves := 60
var phase := 1
var b3 := 0
var tool_id := "tur"
var won := false
var started := false
var leaving := false
var leave_t := 0.0
var gtime := D.DAY * .06
var play_s := 0.0
var seen: Dictionary = {}
var scanned: Dictionary = {}
var known: Dictionary = {}
var anim: Array[Dictionary] = []
var CL := {"T":15.0,"H":40.0,"F":20.0}
var wx := {"on":false,"until":0.0,"rain":0.0}
var prog := {"done":{}}
var dirty := false
var last_save := 0.0
var last_warn := -99.0
var tick_acc := 0.0
var fauna_acc := 0.0
var now_s := 0.0
var rng := RandomNumberGenerator.new()
var last_stats: Dictionary = {}
var paused := false

func _ready() -> void:
	rng.randomize()
	REG = D.REGIONS.valle
	_load_prog()

# ---------------------------------------------------------------- utilidades
func idx(x: int, y: int) -> int:
	return y * C + x
func inb(x: int, y: int) -> bool:
	return x >= 0 and y >= 0 and x < C and y < R
func at(x: int, y: int) -> String:
	return T[y * C + x] if inb(x, y) else ""
func nb4(x: int, y: int) -> Array:
	var o := []
	for d in [Vector2i(1,0), Vector2i(-1,0), Vector2i(0,1), Vector2i(0,-1)]:
		if inb(x + d.x, y + d.y): o.append(idx(x + d.x, y + d.y))
	return o
func touches(x: int, y: int, set: Array) -> bool:
	for j in nb4(x, y):
		if T[j] in set: return true
	return false
func pickr(a: Array):
	return a[rng.randi() % a.size()]
func ph_of(t: Dictionary) -> int:
	return REG.climPh if t.get("clim", false) else t.get("ph", 1)
func in_reg(t: Dictionary) -> bool:
	return not t.has("r") or region_id in t.r
func tname(t: Dictionary) -> String:
	return t.n
func reg_tools() -> Array:
	var o := []
	for t in D.TOOLS:
		if in_reg(t): o.append(t)
	return o

class Mulberry:
	var a: int
	func _init(s: int) -> void:
		a = s & 0xffffffff
	func next() -> float:
		a = (a + 0x6D2B79F5) & 0xffffffff
		var t := a
		t = _imul(t ^ (t >> 15), 1 | t)
		t = (t + _imul(t ^ (t >> 7), 61 | t)) & 0xffffffff ^ t
		return float((t ^ (t >> 14)) & 0xffffffff) / 4294967296.0
	func _imul(x: int, y: int) -> int:
		return (x * y) & 0xffffffff

func _noise_grid(r: Mulberry, n: int) -> Callable:
	var g := PackedFloat32Array()
	for i in (n + 1) * (n + 1): g.append(r.next())
	return func(x: float, y: float) -> float:
		var fx := x * n
		var fy := y * n
		var ix := mini(n - 1, int(fx))
		var iy := mini(n - 1, int(fy))
		var u := fx - ix
		var v := fy - iy
		u = u * u * (3 - 2 * u)
		v = v * v * (3 - 2 * v)
		var a := g[iy * (n + 1) + ix]
		var b := g[iy * (n + 1) + ix + 1]
		var c := g[(iy + 1) * (n + 1) + ix]
		var d := g[(iy + 1) * (n + 1) + ix + 1]
		return a + (b - a) * u + (c - a) * v + (a - b - c + d) * u * v

# ---------------------------------------------------------------- generación
func gen(sd: int) -> void:
	var r := Mulberry.new(sd)
	var n1 := _noise_grid(r, 3)
	var n2 := _noise_grid(r, 7)
	var N := func(x: float, y: float) -> float:
		return n1.call(x / (C - 1), y / (R - 1)) * .7 + n2.call(x / (C - 1), y / (R - 1)) * .3
	var base := "ice" if region_id == "polar" else "tox"
	T.clear(); B.clear(); H.resize(C * R); born.resize(C * R); bborn.resize(C * R)
	for y in R:
		for x in C:
			T.append(base); B.append("")
			H[idx(x, y)] = 1 + mini(2, int(floor(N.call(x, y) * 3.3)))
			born[idx(x, y)] = -100.0; bborn[idx(x, y)] = -100.0
	var blob := func(cx: float, cy: float, rad: float, t: String, only: String) -> void:
		for y in R:
			for x in C:
				if (only == "" or T[idx(x, y)] == only) and Vector2(x - cx, y - cy).length() < rad + r.next() * .8:
					T[idx(x, y)] = t
	if region_id == "tropico":
		var th := .5
		var e_at := func(x: int, y: int) -> float:
			return N.call(x, y) - maxf(0, Vector2(x - C / 2.0 + .5, y - R / 2.0 + .5).length() / (C * .5) - .55) * .6
		for tries in 8:
			var n := 0
			for y in R:
				for x in C:
					if e_at.call(x, y) > th: n += 1
			if n > 200: break
			th -= .04
		for y in R:
			for x in C:
				var e: float = e_at.call(x, y)
				if e > th:
					T[idx(x, y)] = "tox"; H[idx(x, y)] = 1 + mini(2, int(floor((e - th) * 7)))
				else:
					T[idx(x, y)] = "sea"; H[idx(x, y)] = 0
		for y in R:
			for x in C:
				if T[idx(x, y)] != "sea" and touches(x, y, ["sea"]):
					T[idx(x, y)] = "sand"; H[idx(x, y)] = 1
		for k in 4: blob.call(3 + r.next() * (C - 6), 3 + r.next() * (R - 6), .6 + r.next() * .8, "rock", "tox")
		for k in 5:
			var cx := int(r.next() * C); var cy := int(r.next() * R)
			for j in [idx(cx, cy)] + nb4(cx, cy):
				if T[j] == "tox" and r.next() < .7: T[j] = "dirt"
		for y in R:
			for x in C:
				if T[idx(x, y)] == "sea" and r.next() < .38:
					var near := false
					for d in [Vector2i(1,0),Vector2i(-1,0),Vector2i(0,1),Vector2i(0,-1),Vector2i(2,0),Vector2i(0,2),Vector2i(-2,0),Vector2i(0,-2)]:
						var q := at(x + d.x, y + d.y)
						if q != "" and q != "sea" and q != "oil": near = true
					if near: T[idx(x, y)] = "oil"
	elif region_id == "volcan":
		var vx := 6 + r.next() * (C - 12); var vy := 6 + r.next() * (R - 12)
		for y in R:
			for x in C:
				var d := Vector2(x - vx, y - vy).length()
				var cone := 5.2 - d * .85
				T[idx(x, y)] = "ash" if N.call(x, y) > .48 else "tox"
				if cone > 2.4:
					H[idx(x, y)] = mini(D.MAXH, int(round(cone)))
					T[idx(x, y)] = "lava" if d < 1.2 else "mnt"
		for k in 4:
			var x := vx; var y := vy; var a := r.next() * 6.28
			for s in 12:
				x += cos(a) + (r.next() - .5) * .9; y += sin(a) + (r.next() - .5) * .9
				var xi := int(round(x)); var yi := int(round(y))
				if not inb(xi, yi): break
				if s > 1: T[idx(xi, yi)] = "lava"
		for k in 4: blob.call(r.next() * C, r.next() * R, .6 + r.next() * .9, "rock", "ash")
		var y := 2 + int(r.next() * (R - 4))
		for x in C:
			if inb(x, y) and T[idx(x, y)] != "lava" and T[idx(x, y)] != "mnt":
				T[idx(x, y)] = "bed"; H[idx(x, y)] = maxi(1, H[idx(x, y)] - 1)
			y = clampi(y + int(round(r.next() * 2 - 1)), 1, R - 2)
		for k in 5:
			var cx := int(r.next() * C); var cy := int(r.next() * R)
			for j in [idx(cx, cy)] + nb4(cx, cy):
				if (T[j] == "tox" or T[j] == "ash") and r.next() < .75: T[j] = "dirt"
	else:
		var mc := 3 + r.next() * (R - 7)
		for y in R:
			for x in C:
				var m: float = 3.6 - x - absf(y - mc) * .22 + (n2.call(x / float(C - 1), y / float(R - 1)) - .5) * 2.4
				if m > .4:
					T[idx(x, y)] = "mnt"; H[idx(x, y)] = mini(D.MAXH, 3 + int(round(m * .8)))
		if region_id == "valle":
			for k in 3: blob.call(4 + r.next() * (C - 8), r.next() * R, 1 + r.next() * 1.3, "ash", "tox")
		else:
			for k in 4: blob.call(4 + r.next() * (C - 8), r.next() * R, 1 + r.next() * 1.4, "tox", "ice")
		for k in 4: blob.call(3 + r.next() * (C - 6), r.next() * R, .6 + r.next() * .9, "rock", base)
		var y := 4 + int(r.next() * (R - 8))
		for x in range(2, C):
			for yy in [y, y + (1 if r.next() < .5 else 0)]:
				if inb(x, yy) and T[idx(x, yy)] != "mnt":
					T[idx(x, yy)] = "bed"; H[idx(x, yy)] = 1
			y = clampi(y + int(round(r.next() * 2 - 1)), 2, R - 3)
		var ph := r.next() * 6
		for yy in R:
			var w := 2 + int(round(sin(yy * .5 + ph) * .9 + .3))
			var sw := 0 if region_id == "polar" else (2 if r.next() < .5 else 1)
			for k in w + sw:
				var j := idx(C - 1 - k, yy)
				if k < w:
					T[j] = "sea"; H[j] = 0
				else:
					T[j] = "sand"; H[j] = 1
		for k in 4:
			var cx := 4 + int(r.next() * (C - 8)); var cy := int(r.next() * R)
			for j in [idx(cx, cy)] + nb4(cx, cy):
				if T[j] == base and r.next() < .75: T[j] = "dirt"
	var bad := ["sea","oil","lava","mnt","bed","sand","rock"]
	for gy in range(2, R, 5):
		for gx in range(2, C, 5):
			var x := clampi(int(round(gx + (r.next() - .5) * 3)), 0, C - 1)
			var y := clampi(int(round(gy + (r.next() - .5) * 3)), 0, R - 1)
			if not (T[idx(x, y)] in bad):
				T[idx(x, y)] = "rock"
				var nn := nb4(x, y)
				if nn.size() and r.next() < .65:
					var q: int = nn[int(floor(r.next() * nn.size()))]
					if not (T[q] in bad):
						T[q] = "rock"; H[q] = H[idx(x, y)]

func set_type(i: int, t: String) -> void:
	var old := T[i]
	T[i] = t
	known[t] = true
	born[i] = now_s
	dirty = true
	tile_changed.emit(i, old)

func set_building(i: int, b: String) -> void:
	var old := B[i]
	B[i] = b
	bborn[i] = now_s
	dirty = true
	building_changed.emit(i, old)

# ---------------------------------------------------------------- energía y clima
func rad(i: int) -> int:
	return 4 if B[i] == "geo" or T[i] == "mnt" else 3
func cheb(s: int, x: int, y: int) -> int:
	return maxi(absi(s % C - x), absi(s / C - y))

func compute_power() -> void:
	POW.resize(C * R); COV.resize(C * R); SRC.resize(C * R); LOAD.resize(C * R)
	POW.fill(false); COV.fill(false); SRC.fill(-1); LOAD.fill(0)
	var srcs := []
	for i in C * R:
		if B[i] != "tur" and B[i] != "geo": continue
		srcs.append(i)
		var r := rad(i); var x0 := i % C; var y0 := i / C
		for y in range(y0 - r, y0 + r + 1):
			for x in range(x0 - r, x0 + r + 1):
				if inb(x, y): COV[idx(x, y)] = true
	for i in C * R:
		if not (B[i] in D.NEEDPOW): continue
		var x := i % C; var y := i / C
		var best := -1; var bd := 1e9
		for s in srcs:
			if cheb(s, x, y) <= rad(s) and LOAD[s] < 6:
				var dd := Vector2(s % C - x, s / C - y).length()
				if dd < bd: bd = dd; best = s
		if best >= 0:
			SRC[i] = best; LOAD[best] += 1; POW[i] = true

func spare(i: int) -> bool:
	var x := i % C; var y := i / C
	for s in C * R:
		if (B[s] == "tur" or B[s] == "geo") and cheb(s, x, y) <= rad(s) and LOAD[s] < 6: return true
	return false

func too_close(x: int, y: int, id: String) -> bool:
	var r0 := 4 if id == "geo" or at(x, y) == "mnt" else 3
	for s in C * R:
		if (B[s] == "tur" or B[s] == "geo") and cheb(s, x, y) <= maxi(rad(s), r0): return true
	return false

func climate(s: Dictionary) -> Dictionary:
	var nS := 0; var nH := 0; var nF := 0; var nG := 0
	for i in C * R:
		if B[i] == "geo": nG += 1
		elif POW.size() and POW[i]:
			if B[i] == "sol": nS += 1
			elif B[i] == "nub": nH += 1
			elif B[i] == "fri": nF += 1
	var gr: float = float(s.green) / s.land
	var rain: float = wx.rain
	CL = {"T": REG.t0 + 3 * nS - 3 * nF + nG - 4 * gr - 1.5 * rain,
		"H": clampf(REG.h0 + 10 * nH + 90.0 * (s.water + s.wet + s.mang) / s.land + 18 * gr + 20 * rain, 0, 100),
		"F": clampf(80 * gr + 25 * (1 - float(s.dirtyN) / s.land), 0, 100)}
	return CL

func req(t: String) -> String:
	if not D.NEED.has(t): return ""
	var n: Dictionary = D.NEED[t]
	if n.has("T") and CL.T < n.T[0]: return "Demasiado frío (mín. %d °C)" % n.T[0]
	if n.has("T") and CL.T > n.T[1]: return "Demasiado calor (máx. %d °C)" % n.T[1]
	if n.has("H") and CL.H < n.H: return "Falta humedad (mín. %d%%)" % n.H
	if n.has("F") and CL.F < n.F: return "Suelo poco fértil (mín. %d%%)" % n.F
	return ""

func need_txt(t: String) -> String:
	if not D.NEED.has(t): return ""
	var n: Dictionary = D.NEED[t]
	var a := []
	if n.has("T"): a.append(("%d–%d °C" % [n.T[0], n.T[1]]) if n.T[1] < 99 else ("≥ %d °C" % n.T[0]))
	if n.has("H"): a.append("humedad ≥ %d%%" % n.H)
	if n.has("F"): a.append("fertilidad ≥ %d%%" % n.F)
	return " · ".join(a)

func pow_chk(i: int) -> String:
	if not COV[i]: return "Necesita energía cerca"
	if not spare(i): return "Las fuentes cercanas ya alimentan 6 edificios"
	return ""

func check(id: String, x: int, y: int) -> String:
	if not inb(x, y): return "Fuera del mapa"
	var i := idx(x, y); var g := T[i]; var t := D.tool(id)
	if id == "rec": return "" if B[i] != "" else "No hay edificio aquí"
	if ph_of(t) > phase: return "Se desbloquea en la fase %d" % ph_of(t)
	if phase == 3 and id in D.NOBUILD3: return "Ya no se construye: registra la fauna y recicla"
	if leaves < t.c: return "Te faltan hojas"
	if id == "hid":
		if B[i] != "asp": return "Se construye sobre un aspersor"
		var near := false
		for dy in range(-3, 4):
			for dx in range(-3, 4):
				var q := at(x + dx, y + dy)
				if q == "water" or q == "wet" or q == "sea": near = true
		return req("wet") if near else "Necesita agua a 3 casillas"
	if B[i] != "": return "Ya hay un edificio"
	if id == "tur":
		if g != "rock" and g != "mnt": return "Las turbinas van sobre roca o montaña"
		return "Muy cerca de otra fuente de energía" if too_close(x, y, "tur") else ""
	if id == "geo":
		if g != "lava": return "Solo sobre lava"
		return "Muy cerca de otra fuente de energía" if too_close(x, y, "geo") else ""
	if id == "pum": return "Solo sobre un cauce seco" if g != "bed" else pow_chk(i)
	if id == "viv":
		if g != "grass": return "Solo sobre pasto"
		var e := pow_chk(i)
		return e if e != "" else req("forest")
	if id == "col":
		if g != "forest": return "Solo sobre un bosque"
		return req("flower")
	if t.get("b", false):
		if g in D.WATERY or g == "bed": return "No sobre el agua ni un cauce"
		if g == "lava": return "Solo la planta geotérmica va sobre lava"
		if g == "mnt": return "Aquí solo caben turbinas"
		return pow_chk(i) if id in D.NEEDPOW else ""
	if id == "can": return "" if g == "dirt" or g == "grass" else "Solo en tierra limpia o pasto"
	if id == "man":
		if g != "sand": return "Solo sobre arena"
		if not touches(x, y, ["sea"]): return "Debe tocar el mar"
		return req("mang")
	return ""

func apply(id: String, x: int, y: int) -> bool:
	var e := check(id, x, y)
	if e != "":
		toast.emit(e); Sfx.play("err"); return false
	var i := idx(x, y)
	if id == "rec":
		var v := int(floor(D.tool(B[i]).c / 2.0))
		leaves += v
		fx.emit("pop", i, "+%d" % v)
		fx.emit("lift", i, B[i])
		set_building(i, "")
		Sfx.play("rec")
	else:
		leaves -= D.tool(id).c
		if D.tool(id).get("b", false):
			if B[i] != "": set_building(i, "")
			set_building(i, id)
			Sfx.play("place"); fx.emit("dust", i, null)
		else:
			set_type(i, "bed" if id == "can" else "mang")
			Sfx.play("water" if id == "can" else "seed"); fx.emit("dust", i, null)
	compute_power(); climate(stats()); dirty = true; hud()
	return true

func grow(i: int, t: String) -> bool:
	if req(t) != "": return false
	set_type(i, t); leaves += 1
	fx.emit("grow", i, t)
	Sfx.play("grow")
	return true

# ---------------------------------------------------------------- simulación
func tick() -> void:
	if not started or won or leaving: return
	var s0 := stats(); climate(s0)
	var boost: float = 1 + wx.rain
	for i in C * R:
		var b := B[i]
		if b == "" or b == "tur" or b == "geo": continue
		var x := i % C; var y := i / C
		if b == "obs":
			for a in anim:
				if scanned.has(a.k) or not (a.k in REG.sp): continue
				if absf(a.x - (x + .5)) <= 3.5 and absf(a.y - (y + .5)) <= 3.5:
					scanned[a.k] = true; discover(a.k, true)
					scanned_animal.emit(i, a)
					toast.emit("Registrado: %s (%d/3)" % [D.SPEC[a.k].n, scanned.size()])
					Sfx.play("scan"); dirty = true
					break
			continue
		if b == "col" or b == "viv" or b == "hid":
			if b != "col" and not POW[i]: continue
			var tt := "flower" if b == "col" else ("forest" if b == "viv" else "wet")
			var rr := 3 if b == "col" else 2
			if req(tt) != "" or rng.randf() > .6: continue
			var c := []
			for dy in range(-rr, rr + 1):
				for dx in range(-rr, rr + 1):
					if inb(x + dx, y + dy):
						var j := idx(x + dx, y + dy)
						if T[j] == "grass" and B[j] == "": c.append(j)
			if c.size(): grow(pickr(c), tt)
			continue
		if b == "pum":
			if not POW[i]: continue
			var n := []
			for j in nb4(x, y):
				if T[j] == "bed" and B[j] == "": n.append(j)
			if n.size():
				var q: int = pickr(n); set_type(q, "water"); fx.emit("ring", q, Color(.75, .9, 1))
			continue
		if not POW[i]: continue
		if b == "sol":
			var c := []
			for dy in range(-3, 4):
				for dx in range(-3, 4):
					if at(x + dx, y + dy) == "ice": c.append(idx(x + dx, y + dy))
			if c.size() and rng.randf() < .7:
				var j: int = pickr(c); set_type(j, "dirt"); fx.emit("ring", j, Color(.92, .96, 1)); Sfx.play("melt")
			continue
		if b != "dep" and b != "asp": continue
		var c := []
		for dy in range(-2, 3):
			for dx in range(-2, 3):
				if not inb(x + dx, y + dy): continue
				var j := idx(x + dx, y + dy)
				if (b == "dep" and T[j] in D.DIRTY) or (b == "asp" and T[j] == "dirt"): c.append(j)
		if c.size():
			var j: int = pickr(c)
			if b == "dep":
				var was := T[j]
				set_type(j, "sea" if was == "oil" else "dirt")
				fx.emit("clean", j, was); Sfx.play("clean")
			elif not grow(j, "grass") and now_s - last_warn > 20:
				last_warn = now_s
				toast.emit("Los aspersores no funcionan: " + req("grass").to_lower() + ". Usa espejos solares")
	# los cauces junto al agua se llenan
	var fl := []
	for i in C * R:
		if T[i] != "bed" or B[i] != "": continue
		for j in nb4(i % C, i / C):
			if T[j] == "water" or T[j] == "sea" or T[j] == "wet":
				fl.append(i); break
	fl.shuffle()
	for k in mini(3, fl.size()):
		set_type(fl[k], "water"); fx.emit("ring", fl[k], Color(.75, .9, 1))
	if fl.size() and rng.randf() < .15: Sfx.play("water")
	# deshielo natural
	if CL.T > 1:
		for k in 20:
			var i := rng.randi() % (C * R)
			if T[i] == "ice" and rng.randf() < minf(.5, CL.T * .03):
				var ok := false
				for j in nb4(i % C, i / C):
					if T[j] != "ice": ok = true
				if ok:
					set_type(i, "dirt"); fx.emit("ring", i, Color(.92, .96, 1))
	# propagación natural
	for k in 30:
		var i := rng.randi() % (C * R)
		var g := T[i]
		if not D.SPR.has(g):
			if g == "grass" and wx.rain > .3 and rng.randf() < .04:
				var n := []
				for j in nb4(i % C, i / C):
					if T[j] == "dirt": n.append(j)
				if n.size(): grow(pickr(n), "grass")
			continue
		var s: Array = D.SPR[g]
		if rng.randf() > s[1] * boost: continue
		var n := []
		for j in nb4(i % C, i / C):
			if T[j] == s[0] and (g == "water" or B[j] == ""): n.append(j)
		if n.size(): grow(pickr(n), "grass" if g == "water" else g)
	if not wx.on and rng.randf() < (.3 + CL.H / 100.0) / 300.0 and phase < 3:
		wx.on = true; wx.until = gtime + 18 + rng.randf() * 12
		toast.emit("Empieza a nevar" if CL.T < 0 else "Empieza a llover: todo crece más rápido")
	if wx.on and gtime > wx.until: wx.on = false
	hud()

func stats() -> Dictionary:
	var s := {"land":0,"green":0,"dirtyN":0,"forest":0,"wet":0,"flower":0,"mang":0,"water":0,"grass":0,"ice":0,"sand":0,"bld":0}
	for i in C * R:
		var t := T[i]
		if B[i] != "": s.bld += 1
		if t == "water": s.water += 1
		if t in D.DIRTY: s.dirtyN += 1
		if t in D.NOLAND: continue
		s.land += 1
		if t in D.GREEN: s.green += 1
		if s.has(t) and t != "water": s[t] += 1
	s.land = maxi(1, s.land)
	return s

func goals_for(ph: int, s: Dictionary) -> Array:
	if ph == 1:
		return [{"n":"Verde","v":float(s.green) / s.land,"g":REG.g1,"long":"Reverdece el %d%% de la tierra" % roundi(REG.g1 * 100)}]
	if ph == 2:
		var o := []
		for e in REG.g2:
			var k: String = e[1]; var g: float = e[2]
			var v: float
			var lg: String
			if k == "clean":
				v = 1 - float(s.dirtyN) / s.land; lg = "Elimina la contaminación (%d%% limpio)" % roundi(g * 100)
			elif k == "melt":
				v = 1 - float(s.ice) / s.land; lg = "Derrite el hielo (%d%% sin hielo)" % roundi(g * 100)
			else:
				v = float(s[k]) / s.land; lg = "%s: %d%% de la tierra" % [e[0], roundi(g * 100)]
			o.append({"n":e[0],"g":g,"v":v,"long":lg})
		return o
	var retire := 1.0 if s.bld == 0 else 1.0 - float(s.bld) / maxi(maxi(b3, s.bld), 1)
	return [{"n":"Especies","v":minf(1, scanned.size() / 3.0),"g":1.0,"txt":"%d/3" % mini(3, scanned.size()),"long":"Registra 3 especies con un observatorio"},
		{"n":"Edificios retirados","v":retire,"g":1.0,"long":"Recicla todos los edificios"}]

func goals() -> Array:
	return goals_for(phase, last_stats if last_stats.size() else stats())

func progress() -> float:
	var gl := goals()
	var p := 0.0
	for o in gl: p += minf(1, o.v / o.g)
	return p / gl.size()

func hud() -> void:
	var s := stats(); last_stats = s; climate(s)
	var gl := goals_for(phase, s)
	var all := true
	for o in gl:
		if o.v < o.g - 1e-9: all = false
	if started and not won and not leaving and all:
		if phase < 3:
			phase += 1
			if phase == 3:
				b3 = s.bld; tool_id = "obs"
			toast.emit("¡Fase 2! Crea ecosistemas: revisa el clima que necesita cada uno" if phase == 2 else "¡Fase 3! Construye un observatorio, registra 3 especies y recicla todo")
			Sfx.play("phase"); dirty = true
			phase_changed.emit(phase)
			save()
		else:
			start_leaving()
	hud_changed.emit()

# ---------------------------------------------------------------- fauna
func hab_tiles(hab: Array) -> Array:
	var o := []
	for i in C * R:
		if T[i] in hab and B[i] == "": o.append(i)
	return o

func new_target(a: Dictionary) -> void:
	var hab: Array = D.HAB[a.k]
	var x0 := int(a.x); var y0 := int(a.y)
	for k in 12:
		var x := x0 + int(round((rng.randf() - .5) * 6)); var y := y0 + int(round((rng.randf() - .5) * 6))
		if inb(x, y) and T[idx(x, y)] in hab:
			a.tx = x + .25 + rng.randf() * .5; a.ty = y + .25 + rng.randf() * .5
			return
	var L := hab_tiles(hab)
	if L.size():
		var i: int = pickr(L); a.tx = i % C + .5; a.ty = i / C + .5

func fauna(silent := false) -> void:
	var s := stats()
	var nr := 0
	for a in anim:
		if a.k == "reindeer": nr += 1
	s["reindeer"] = nr
	var changed := false
	for k in REG.sp:
		var w := D.want(k, s)
		var n := 0
		for a in anim:
			if a.k == k: n += 1
		var L := hab_tiles(D.HAB[k]) if n < w else []
		while n < w and L.size():
			var i: int = pickr(L)
			var a := {"k":k,"x":i % C + .5,"y":i / C + .5,"tx":0.0,"ty":0.0,"walk":false,"graze":false,"idle":rng.randf() * 3,"ph":rng.randf() * 10,"jump":0.0,"id":rng.randi()}
			new_target(a); anim.append(a); n += 1; changed = true
			discover(k, silent)
	var keep: Array[Dictionary] = []
	for a in anim:
		var xi := clampi(int(a.x), 0, C - 1); var yi := clampi(int(a.y), 0, R - 1)
		if T[idx(xi, yi)] in D.HAB[a.k] or a.walk: keep.append(a)
		else: changed = true
	anim = keep
	if changed: fauna_changed.emit()

func discover(k: String, silent: bool) -> void:
	if seen.has(k): return
	seen[k] = true; dirty = true
	if not silent:
		toast.emit("Nueva especie: " + D.SPEC[k].n + (". Regístrala en la fase 3" if phase < 3 else ""))
		Sfx.play("found")

func move_animals(dt: float) -> void:
	for a in anim:
		if a.k == "whale" or a.k == "manta" or a.k == "seal":
			if a.jump > 0: a.jump = maxf(0, a.jump - dt * .35)
			elif rng.randf() < dt * .06: a.jump = 1.0
		if a.idle > 0:
			a.idle -= dt; a.walk = false; continue
		var dx: float = a.tx - a.x; var dy: float = a.ty - a.y
		var d := sqrt(dx * dx + dy * dy)
		if d < .04:
			a.walk = false
			var grazer: bool = a.k in ["deer","reindeer","goat"]
			a.idle = 1 + rng.randf() * (6.0 if grazer else (5.0 if a.k in ["heron","seal"] else 2.5))
			a.graze = grazer and rng.randf() < .7
			new_target(a); continue
		a.walk = true; a.graze = false
		var sp := minf(D.SPD[a.k] * dt, d)
		a.x += dx / d * sp; a.y += dy / d * sp

# ---------------------------------------------------------------- bucle
func _process(dt: float) -> void:
	now_s += dt
	if paused: return
	if started and not won:
		if not leaving:
			gtime += dt; play_s += dt
		tick_acc += dt
		if tick_acc > (.26 if wx.rain > .3 else .35):
			tick_acc = 0; tick()
		fauna_acc += dt
		if fauna_acc > .7:
			fauna_acc = 0; fauna()
		if dirty and now_s - last_save > 8: save()
		if leaving and now_s - leave_t > 16: finish()
	wx.rain += ((1.0 if wx.on else 0.0) - wx.rain) * minf(1, dt * .6)
	move_animals(dt)

func day_clock() -> Dictionary:
	var clock := fmod(gtime / D.DAY, 1.0)
	var day := clampf(sin(clock * TAU) * 1.8 + .55, 0, 1)
	return {"clock":clock,"day":day,"night":1 - day}

func start_leaving() -> void:
	if leaving: return
	leaving = true; leave_t = now_s
	toast.emit("La nave viene a recogerte")
	Sfx.play("ship")
	leaving_started.emit()

func finish() -> void:
	won = true; leaving = false
	var s := stats()
	var m := maxi(1, roundi(play_s / 60.0))
	var first: bool = not prog.done.has(region_id)
	prog.done[region_id] = mini(int(prog.done[region_id]), m) if prog.done.has(region_id) else m
	_save_prog()
	var ni := D.RORDER.find(region_id) + 1
	var nx: String = D.RORDER[ni] if ni < D.RORDER.size() else ""
	var txt := "%s restaurada en %d min: %d%% de tierra verde, %d especies registradas de %d y %d animales en la parcela. No queda ni un edificio." % [REG.n, m, roundi(float(s.green) / s.land * 100), scanned.size(), REG.sp.size(), anim.size()]
	if first and nx != "": txt += " Desbloqueaste: " + D.REGIONS[nx].n + "."
	elif first and nx == "": txt += " ¡Restauraste las cuatro regiones!"
	clear_save()
	Sfx.play("win")
	finished.emit(txt)

# ---------------------------------------------------------------- partidas
func set_region(id: String) -> void:
	region_id = id; REG = D.REGIONS[id]

func reset_run() -> void:
	anim.clear(); won = false; leaving = false
	wx = {"on":false,"until":0.0,"rain":0.0}

func new_game(id: String) -> void:
	set_region(id)
	seed_v = rng.randi() & 0xffffff
	gen(seed_v)
	leaves = 60; phase = 1; b3 = 0; gtime = D.DAY * .06
	seen = {}; scanned = {}; known = {}
	for t in T: known[t] = true
	play_s = 0; reset_run()
	tool_id = "geo" if id == "volcan" else "tur"
	compute_power(); dirty = true
	map_rebuilt.emit()
	hud(); fauna_changed.emit()

func preview(id: String) -> void:
	set_region(id); seed_v = rng.randi() & 0xffffff; gen(seed_v); compute_power(); reset_run()
	map_rebuilt.emit(); hud()

func begin() -> void:
	started = true
	Sfx.play("phase")
	hud()

func snap() -> Dictionary:
	var ts := ""; var bs := ""
	for i in C * R:
		ts += char(97 + D.TY.find(T[i])); bs += char(97 + D.BL.find(B[i]))
	return {"v":3,"ts":Time.get_unix_time_from_system(),"region":region_id,"seed":seed_v,"leaves":leaves,"phase":phase,"b3":b3,
		"gt":roundi(gtime),"seen":seen.keys(),"sc":scanned.keys(),"kn":known.keys(),"ms":roundi(play_s * 1000),"t":ts,"b":bs}

func valid(s) -> bool:
	return s is Dictionary and int(s.get("v", 0)) == 3 and D.REGIONS.has(s.get("region", "")) and str(s.get("t", "")).length() == C * R

func restore(s: Dictionary) -> void:
	set_region(s.region); seed_v = int(s.seed); gen(seed_v)
	var ts: String = s.t; var bs: String = s.b
	for i in C * R:
		var ti := ts.unicode_at(i) - 97
		T[i] = D.TY[ti] if ti >= 0 and ti < D.TY.size() else "tox"
		var ch := bs.substr(i, 1)
		var bi := int(ch) if ch.is_valid_int() else ch.unicode_at(0) - 97
		B[i] = D.BL[bi] if bi >= 0 and bi < D.BL.size() else ""
	leaves = int(s.leaves); phase = int(s.phase); b3 = int(s.get("b3", 0)); gtime = float(s.get("gt", D.DAY * .06))
	seen = {}; scanned = {}; known = {}
	for k in s.get("seen", []): seen[k] = true
	for k in s.get("sc", []): scanned[k] = true
	for k in s.get("kn", []): known[k] = true
	for t in T: known[t] = true
	play_s = float(s.get("ms", 0)) / 1000.0
	reset_run()
	tool_id = "obs" if phase == 3 else ("geo" if region_id == "volcan" else "tur")
	compute_power()
	map_rebuilt.emit(); hud(); fauna(true); fauna_changed.emit()

func save() -> void:
	if not started or won: return
	var f := FileAccess.open(SKEY, FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify(snap())); f.close()
	dirty = false; last_save = now_s

func load_save():
	if not FileAccess.file_exists(SKEY): return null
	var f := FileAccess.open(SKEY, FileAccess.READ)
	if not f: return null
	var s = JSON.parse_string(f.get_as_text())
	return s if valid(s) else null

func clear_save() -> void:
	if FileAccess.file_exists(SKEY): DirAccess.remove_absolute(SKEY)

func _save_prog() -> void:
	var f := FileAccess.open(PKEY, FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify(prog)); f.close()

func _load_prog() -> void:
	if not FileAccess.file_exists(PKEY): return
	var f := FileAccess.open(PKEY, FileAccess.READ)
	if f:
		var p = JSON.parse_string(f.get_as_text())
		if p is Dictionary and p.has("done"): prog = p

func unlocked(id: String) -> bool:
	var i := D.RORDER.find(id)
	return i == 0 or prog.done.has(D.RORDER[i - 1])
