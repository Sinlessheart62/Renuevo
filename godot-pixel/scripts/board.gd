extends Node2D
## Mundo 2D en pixel art: casillas con bordes, objetos ordenados por altura, fauna, efectos y clima.

const T := 16
const PRI := ["sea","tsea","oil","water","marsh","bed","lava","ash","tox","dirt","sand","ice","rock","mnt","grass","flower","forest"]
const WAT := ["water","sea","tsea","oil","marsh"]
const DIRS := ["n","e","s","w","ne","se","sw","nw"]

var G: Node
var idx: Dictionary
var atlas: Texture2D
var tex := {}             # sprites cargados
var kinds: Array = []
var anim_kinds: Array = []
var frame := 0
var ftime := 0.0

var ground: Node2D        # dibuja las casillas
var objs: Node2D          # objetos con orden por y
var over: Node2D          # ayudas (selección, alcance) sobre el suelo
var top: Node2D           # anillos, textos
var tile_nodes := []      # por casilla: lista de Sprite2D
var bnodes := {}          # casilla -> Sprite2D de edificio
var anodes := {}          # id -> Sprite2D de animal
var fence_nodes: Array = []

var hover_i := -1
var hover_ok := true
var hover_rad := 0
var cover := PackedByteArray()
var show_cover := false
var rings: Array = []
var pops: Array = []
var lifts: Array = []
var beams: Array = []
var bursts: Array[CPUParticles2D] = []
var bi := 0
var font: Font
var canvas_mod: CanvasModulate
var rain: CPUParticles2D
var snow: CPUParticles2D
var flies: CPUParticles2D
var clouds: Array[Sprite2D] = []
var cam: Camera2D

func _ready() -> void:
	G = Game
	idx = JSON.parse_string(FileAccess.get_file_as_string("res://px/index.json"))
	atlas = load("res://px/tiles.png")
	kinds = idx.tiles.kinds
	anim_kinds = idx.tiles.anim
	for k in idx.sprites: tex[k] = load("res://px/%s.png" % k)
	font = load("res://fonts/VT323.ttf")
	ground = Node2D.new(); add_child(ground); ground.draw.connect(_draw_ground)
	over = Node2D.new(); add_child(over); over.draw.connect(_draw_over)
	objs = Node2D.new(); objs.y_sort_enabled = true; add_child(objs)
	top = Node2D.new(); add_child(top); top.draw.connect(_draw_top)
	canvas_mod = CanvasModulate.new(); add_child(canvas_mod)
	tile_nodes.resize(D.C * D.R)
	for i in D.C * D.R: tile_nodes[i] = []
	cover.resize(D.C * D.R)
	for k in 24:
		var p := CPUParticles2D.new()
		p.one_shot = true; p.emitting = false; p.amount = 10; p.lifetime = .7; p.explosiveness = .9
		p.direction = Vector2(0, -1); p.spread = 70; p.initial_velocity_min = 12; p.initial_velocity_max = 28
		p.gravity = Vector2(0, 40); p.scale_amount_min = 1; p.scale_amount_max = 2
		top.add_child(p); bursts.append(p)
	rain = _weather(false); snow = _weather(true)
	flies = CPUParticles2D.new(); flies.amount = 60; flies.lifetime = 5
	flies.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	flies.emission_rect_extents = Vector2(D.C * T / 2.0, D.R * T / 2.0); flies.position = Vector2(D.C * T / 2.0, D.R * T / 2.0)
	flies.gravity = Vector2.ZERO; flies.spread = 180; flies.initial_velocity_min = 2; flies.initial_velocity_max = 6
	flies.color = Color(1, .95, .5); flies.emitting = false
	var fc := Curve.new(); fc.add_point(Vector2(0, .1)); fc.add_point(Vector2(.3, 1)); fc.add_point(Vector2(.7, 1)); fc.add_point(Vector2(1, .1))
	flies.scale_amount_curve = fc
	top.add_child(flies)
	var cl_img := _cloud_shadow()
	for k in 4:
		var s := Sprite2D.new(); s.texture = cl_img; s.modulate = Color(1, 1, 1, .18)
		s.position = Vector2(randf() * D.C * T, randf() * D.R * T); s.scale = Vector2.ONE * randf_range(1.5, 2.5)
		top.add_child(s); clouds.append(s)
	G.map_rebuilt.connect(rebuild)
	G.tile_changed.connect(_on_tile)
	G.building_changed.connect(_on_building)
	G.fauna_changed.connect(_sync_fauna)
	G.fx.connect(_on_fx)
	G.scanned_animal.connect(func(i, a): beams.append([center(i) + Vector2(0, -18), Vector2(a.x * T, a.y * T), 0.0]))

func _weather(is_snow: bool) -> CPUParticles2D:
	var p := CPUParticles2D.new()
	p.amount = 500
	p.lifetime = 1.0 if not is_snow else 4.0
	p.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	p.emission_rect_extents = Vector2(320, 10)
	p.direction = Vector2(.15, 1); p.spread = 2 if not is_snow else 20
	p.gravity = Vector2(0, 200 if not is_snow else 6)
	p.initial_velocity_min = 220.0 if not is_snow else 14.0; p.initial_velocity_max = 260.0 if not is_snow else 24.0
	p.color = Color(.75, .85, 1, .55) if not is_snow else Color(1, 1, 1, .9)
	p.scale_amount_min = 1; p.scale_amount_max = 1 if not is_snow else 2
	if not is_snow:
		var g := Gradient.new(); g.set_color(0, Color(.75, .85, 1, .6)); g.set_color(1, Color(.75, .85, 1, .6))
		p.color_ramp = g
	p.emitting = false
	add_child(p)
	return p

func _cloud_shadow() -> ImageTexture:
	var img := Image.create(48, 28, false, Image.FORMAT_RGBA8)
	var rr := RandomNumberGenerator.new(); rr.seed = 3
	var blobs := []
	for k in 5: blobs.append([rr.randf_range(10, 38), rr.randf_range(10, 18), rr.randf_range(7, 11), rr.randf_range(5, 8)])
	for y in 28:
		for x in 48:
			for b in blobs:
				if pow((x - b[0]) / b[2], 2) + pow((y - b[1]) / b[3], 2) <= 1:
					img.set_pixel(x, y, Color(.05, .05, .12, 1)); break
	return ImageTexture.create_from_image(img)

# ======================================================================= utilidades
func center(i: int) -> Vector2:
	return Vector2((i % D.C) * T + T / 2.0, (i / D.C) * T + T / 2.0)

func kind_of(t: String) -> String:
	match t:
		"wet", "mang": return "marsh"
		"sea": return "tsea" if G.region_id == "tropico" else "sea"
	return t

func _cell(kind: String, col: int) -> Rect2:
	return Rect2(col * T, kinds.find(kind) * T, T, T)

func tile_at(p: Vector2) -> int:
	var x := int(floor(p.x / T)); var y := int(floor(p.y / T))
	if x < 0 or y < 0 or x >= D.C or y >= D.R: return -1
	return y * D.C + x

# ======================================================================= suelo
func _draw_ground() -> void:
	if G.T.size() != D.C * D.R: return
	var C := D.C; var R := D.R
	# borde exterior: agua/pasto oscuro alrededor de la cerca
	# alrededor de la parcela: bosque oscuro (y mar si la región lo tiene)
	var outer := Color("#1c3016") if G.region_id != "polar" else Color("#c8d6e4")
	if G.region_id == "volcan": outer = Color("#2a2424")
	ground.draw_rect(Rect2(-T * 40, -T * 40, (C + 80) * T, (R + 80) * T), outer)
	if G.region_id in ["valle", "polar"]:
		ground.draw_rect(Rect2(C * T, -T * 40, T * 40, (R + 80) * T), Color("#22496c"))
	elif G.region_id == "tropico":
		ground.draw_rect(Rect2(-T * 40, -T * 40, (C + 80) * T, (R + 80) * T), Color("#1f7480"))
	for y in R:
		for x in C:
			var i := y * C + x
			var k := kind_of(G.T[i])
			var hv := hash(i * 7 + G.seed_v)
			var v := hv & 3
			if k == "tox" and v == 0 and (hv >> 4) % 3 != 0: v = 1
			var f := frame if k in anim_kinds else 0
			ground.draw_texture_rect_region(atlas, Rect2(x * T, y * T, T, T), _cell(k, v * 4 + f))
			var p := PRI.find(k)
			var ov := {}
			var n4 := [[0, -1, "n"], [1, 0, "e"], [0, 1, "s"], [-1, 0, "w"]]
			var same := {}
			for d in n4:
				var nx: int = x + d[0]; var ny: int = y + d[1]
				if nx < 0 or ny < 0 or nx >= C or ny >= R: continue
				var q := kind_of(G.T[ny * C + nx])
				same[d[2]] = q
				if PRI.find(q) > p:
					if not ov.has(q): ov[q] = []
					ov[q].append(d[2])
			for d in [[1, -1, "ne", "n", "e"], [1, 1, "se", "s", "e"], [-1, 1, "sw", "s", "w"], [-1, -1, "nw", "n", "w"]]:
				var nx: int = x + d[0]; var ny: int = y + d[1]
				if nx < 0 or ny < 0 or nx >= C or ny >= R: continue
				var q := kind_of(G.T[ny * C + nx])
				if PRI.find(q) > p and same.get(d[3], "") != q and same.get(d[4], "") != q:
					if not ov.has(q): ov[q] = []
					ov[q].append(d[2])
			if ov.size():
				var ks := ov.keys()
				ks.sort_custom(func(a, b): return PRI.find(a) < PRI.find(b))
				for q in ks:
					var fq := frame if q in anim_kinds else 0
					for d in ov[q]:
						var col := 16 + (32 if k in WAT else 0) + DIRS.find(d) * 4 + fq
						ground.draw_texture_rect_region(atlas, Rect2(x * T, y * T, T, T), _cell(q, col))

# ======================================================================= ayudas sobre el suelo
func _draw_over() -> void:
	if show_cover:
		for i in cover.size():
			if cover[i]:
				over.draw_rect(Rect2((i % D.C) * T, (i / D.C) * T, T, T), Color(1, .9, .4, .13))
	if hover_i >= 0:
		var r := Rect2((hover_i % D.C) * T, (hover_i / D.C) * T, T, T)
		var col := Color("#8ee05a") if hover_ok else Color("#f05a40")
		if hover_rad > 0:
			var rr := Rect2(r.position - Vector2(hover_rad, hover_rad) * T, Vector2(hover_rad * 2 + 1, hover_rad * 2 + 1) * T)
			over.draw_rect(rr, Color(col, .1))
			_dashed(rr, Color(col, .8))
		over.draw_rect(r, Color(col, .25))
		over.draw_rect(r.grow(-.5), col, false, 1.0)
		# esquinas tipo cursor
		for c in [r.position, r.position + Vector2(T - 3, 0), r.position + Vector2(0, T - 3), r.position + Vector2(T - 3, T - 3)]:
			over.draw_rect(Rect2(c, Vector2(3, 3)), Color.WHITE)

func _dashed(r: Rect2, col: Color) -> void:
	var p := r.position; var s := r.size
	for k in range(0, int(s.x), 4):
		over.draw_rect(Rect2(p.x + k, p.y, 2, 1), col); over.draw_rect(Rect2(p.x + k, p.y + s.y - 1, 2, 1), col)
	for k in range(0, int(s.y), 4):
		over.draw_rect(Rect2(p.x, p.y + k, 1, 2), col); over.draw_rect(Rect2(p.x + s.x - 1, p.y + k, 1, 2), col)

func set_hover(i: int, ok: bool, rad: int, cov: bool) -> void:
	hover_i = i; hover_ok = ok; hover_rad = rad
	show_cover = cov
	if cov:
		for k in cover.size(): cover[k] = 1 if (G.COV.size() and G.COV[k]) else 0
	over.queue_redraw()

# ======================================================================= objetos
func _spr(name: String, pos: Vector2, fr := 0) -> Sprite2D:
	var s := Sprite2D.new()
	var info: Dictionary = idx.sprites[name]
	s.texture = tex[name]
	s.hframes = int(info.frames)
	s.frame = fr
	s.centered = false
	s.offset = Vector2(-info.ox, -info.oy)
	s.position = pos
	objs.add_child(s)
	return s

func _rnd(i: int, salt: int) -> RandomNumberGenerator:
	var r := RandomNumberGenerator.new(); r.seed = hash(Vector3i(G.seed_v, i, salt)); return r

func _gen_tile_objs(i: int) -> void:
	for s in tile_nodes[i]: s.queue_free()
	tile_nodes[i] = []
	var t: String = G.T[i]
	var r := _rnd(i, D.TY.find(t))
	var c := center(i)
	var occupied: bool = G.B[i] != ""
	var list := []
	var add := func(name: String, m: float) -> void:
		var p := c + Vector2(r.randf_range(-8 + m, 8 - m), r.randf_range(-8 + m, 8 - m))
		if occupied and p.distance_to(c) < 7: return
		list.append([name, p.round()])
	var reg: String = G.region_id
	match t:
		"forest":
			var n := 1 + (1 if r.randf() < .45 else 0)
			for k in n:
				var nm := ""
				if reg == "tropico": nm = ("palm%d" % (r.randi() % 2)) if r.randf() < .4 else ("jungle%d" % (r.randi() % 2))
				elif reg == "polar": nm = "spruce%d" % (r.randi() % 2)
				else: nm = ("pine%d" % (r.randi() % 3)) if r.randf() < .45 else ("broad%d" % (r.randi() % 3))
				add.call(nm, 4.0)
			if r.randf() < .3: add.call("bush%d" % (r.randi() % 2), 3.0)
		"flower":
			if r.randf() < .55: add.call("fbush%d" % (r.randi() % 3), 4.0)
		"grass":
			if r.randf() < .1: add.call("bush%d" % (r.randi() % 2), 4.0)
		"wet":
			add.call("reed%d" % (r.randi() % 2), 4.0)
		"mang":
			add.call("mang0", 5.0)
		"sand":
			if reg == "tropico" and r.randf() < .12: add.call("palm%d" % (r.randi() % 2), 6.0)
		"tox", "dirt", "ash", "ice":
			if r.randf() < .05: add.call("dead%d" % (r.randi() % 2), 4.0)
			elif r.randf() < .07: add.call("rock%d" % (r.randi() % 3), 4.0)
		"rock":
			add.call("rock%d" % (r.randi() % 3), 3.0)
			if r.randf() < .4: add.call("rock%d" % (r.randi() % 3), 3.0)
		"mnt":
			var snowy: bool = (reg == "polar") or (reg == "valle" and G.H[i] >= 4)
			var nm: String = "peakdark%d" if reg == "volcan" else ("peaksnow%d" if snowy else "peak%d")
			add.call(nm % (r.randi() % 2), 6.0)
	for e in list:
		var s := _spr(e[0], e[1])
		if G.born[i] > G.now_s - .5 and G.born[i] > -50:
			s.scale = Vector2(.2, .2)
			var tw := s.create_tween()
			tw.tween_property(s, "scale", Vector2(1.15, 1.15), .25).set_trans(Tween.TRANS_BACK)
			tw.tween_property(s, "scale", Vector2.ONE, .12)
		tile_nodes[i].append(s)

func _place_building(i: int, anim_in: bool) -> void:
	var s := _spr("b_" + G.B[i], center(i) + Vector2(0, 6))
	s.set_meta("id", G.B[i]); s.set_meta("tile", i)
	bnodes[i] = s
	if anim_in:
		s.scale = Vector2(.3, .3)
		var tw := s.create_tween()
		tw.tween_property(s, "scale", Vector2(1.1, 1.1), .22).set_trans(Tween.TRANS_BACK)
		tw.tween_property(s, "scale", Vector2.ONE, .12)

func _build_fence() -> void:
	for n in fence_nodes: n.queue_free()
	fence_nodes.clear()
	var C := D.C; var R := D.R
	for x in C:
		for side in [-1, R]:
			var yi := 0 if side == -1 else R - 1
			if G.T[yi * C + x] in ["sea", "oil", "mnt"]: continue
			var s := _spr("fence_h", Vector2(x * T + 8, (side + (1 if side == -1 else 0)) * T + (10 if side == -1 else 6)))
			fence_nodes.append(s)
	for y in R:
		for side in [-1, C]:
			var xi := 0 if side == -1 else C - 1
			if G.T[y * C + xi] in ["sea", "oil", "mnt"]: continue
			var s := _spr("fence_v", Vector2((0 if side == -1 else C) * T + (-1 if side == -1 else 1), y * T + 16))
			fence_nodes.append(s)

func rebuild() -> void:
	for i in D.C * D.R: _gen_tile_objs(i)
	for k in bnodes: bnodes[k].queue_free()
	bnodes.clear()
	for i in D.C * D.R:
		if G.B[i] != "": _place_building(i, false)
	_build_fence()
	_sync_fauna()
	ground.queue_redraw(); over.queue_redraw()

func _on_tile(i: int, _old: String) -> void:
	_gen_tile_objs(i)
	ground.queue_redraw()

func _on_building(i: int, _old: String) -> void:
	if bnodes.has(i):
		bnodes[i].queue_free(); bnodes.erase(i)
	if G.B[i] != "": _place_building(i, true)
	_gen_tile_objs(i)

# ======================================================================= fauna
func _sync_fauna() -> void:
	var ids := {}
	for a in G.anim:
		ids[a.id] = true
		if not anodes.has(a.id):
			var s := _spr("a_" + a.k, Vector2(a.x * T, a.y * T))
			if a.k == "manta": s.z_index = -1
			s.scale = Vector2(.2, .2)
			s.create_tween().tween_property(s, "scale", Vector2.ONE, .3).set_trans(Tween.TRANS_BACK)
			anodes[a.id] = s
	for k in anodes.keys():
		if not ids.has(k):
			anodes[k].queue_free(); anodes.erase(k)

func _update_fauna() -> void:
	var t: float = G.now_s
	for a in G.anim:
		if not anodes.has(a.id): continue
		var s: Sprite2D = anodes[a.id]
		var p := Vector2(a.x * T, a.y * T)
		var k: String = a.k
		var fly: bool = k in ["bee", "butterfly", "parrot"]
		if fly:
			s.offset.y = -float(idx.sprites["a_" + k].oy) - (14.0 if k == "parrot" else 6.0) - round(sin(t * 3 + a.ph) * 2)
		s.position = p.round()
		var dx: float = a.tx - a.x
		if absf(dx) > .02: s.flip_h = dx < 0
		var nf := s.hframes
		if fly or k in ["manta", "whale"]:
			s.frame = int(t * (8.0 if fly else 1.5) + a.ph) % nf if k != "whale" else (2 if a.jump > .3 else int(t + a.ph) % 2)
		elif a.walk:
			s.frame = 1 + int(t * 6 + a.ph) % 2
		elif a.graze and nf > 3:
			s.frame = 3
		else:
			s.frame = 0

# ======================================================================= efectos
func _on_fx(kind: String, i: int, arg) -> void:
	var p := center(i)
	match kind:
		"dust": burst(p, Color("#c8a878"), 14)
		"grow":
			var col := Color("#8db84a")
			if arg == "flower": col = Color("#f0d040")
			elif arg in ["wet", "mang"]: col = Color("#6ab0a0")
			burst(p, col, 6)
		"ring": rings.append([p, 0.0, arg])
		"clean":
			var col := Color("#d8a8e0")
			if arg == "ash": col = Color("#d0d0d0")
			elif arg == "oil": col = Color("#80d0c0")
			rings.append([p, 0.0, col]); burst(p, col, 8)
		"pop": pops.append([p + Vector2(0, -14), 0.0, str(arg)])
		"lift":
			var b := _spr("b_" + str(arg), p + Vector2(0, 6))
			var d := _spr("drone", p + Vector2(0, -60))
			b.z_index = 2; d.z_index = 3
			lifts.append([d, b, 0.0, p])

func burst(p: Vector2, col: Color, n: int) -> void:
	var b := bursts[bi]; bi = (bi + 1) % bursts.size()
	b.position = p; b.color = col; b.amount = n; b.restart()

func _draw_top() -> void:
	for r in rings:
		var rad: float = 2 + r[1] * 12
		top.draw_arc(r[0], rad, 0, TAU, 24, Color(r[2], 1.0 - r[1]), 1.0, false)
	for b in beams:
		top.draw_line(b[0], b[1], Color(.6, 1, .9, 1.0 - b[2] / 1.2), 1.0)
		top.draw_circle(b[1], 3 + b[2] * 6, Color(.6, 1, .9, .4 * (1.0 - b[2] / 1.2)))
	for p in pops:
		var a: float = clampf(1.6 - p[1], 0, 1)
		var pos: Vector2 = p[0] + Vector2(-6, -p[1] * 10)
		top.draw_string_outline(font, pos.round(), p[2], HORIZONTAL_ALIGNMENT_LEFT, -1, 16, 3, Color(.12, .08, .05, a))
		top.draw_string(font, pos.round(), p[2], HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color(1, .95, .7, a))

func _process(dt: float) -> void:
	ftime += dt
	if ftime > .25:
		ftime = 0; frame = (frame + 1) % 4
		ground.queue_redraw()
		_anim_buildings()
	_update_fauna()
	for r in rings.duplicate():
		r[1] += dt * 1.2
		if r[1] > 1: rings.erase(r)
	for p in pops.duplicate():
		p[1] += dt
		if p[1] > 1.6: pops.erase(p)
	for b in beams.duplicate():
		b[2] += dt
		if b[2] > 1.2: beams.erase(b)
	for L in lifts.duplicate():
		L[2] += dt
		var t: float = L[2]
		var d: Sprite2D = L[0]; var b: Sprite2D = L[1]; var p: Vector2 = L[3]
		if t < 1.0: d.position = p + Vector2(0, lerpf(-60, -16, t))
		elif t > 1.4:
			var k := t - 1.4
			d.position = p + Vector2(k * 20, -16 - k * k * 40 - k * 10)
			b.position = d.position + Vector2(0, 22)
			b.modulate.a = clampf(1.0 - (k - 1.0), 0, 1)
		d.frame = 0
		if t > 4.5:
			d.queue_free(); b.queue_free(); lifts.erase(L)
	top.queue_redraw()
	for c in clouds:
		c.position.x += dt * 6
		if c.position.x > D.C * T + 80: c.position = Vector2(-80, randf() * D.R * T)
	_sky(dt)

func _anim_buildings() -> void:
	for i in bnodes:
		var s: Sprite2D = bnodes[i]
		var id: String = s.get_meta("id")
		var powered: bool = G.POW.size() > i and (G.POW[i] or id in ["tur", "geo", "col", "obs"])
		if s.hframes > 1:
			if powered or id == "tur": s.frame = (s.frame + 1) % s.hframes
		s.modulate = Color.WHITE if powered else Color(.82, .78, .78)
		if powered and id in ["geo", "nub", "fri", "dep"] and randf() < .35:
			var col := Color(1, 1, 1, .8) if id != "fri" else Color(.8, .95, 1, .8)
			burst(s.position + Vector2(0, -24 if id == "nub" else -16), col, 2)

func _sky(_dt: float) -> void:
	var dc: Dictionary = G.day_clock()
	var night: float = dc.night
	var dusk := 1.0 - absf(dc.day - .5) * 2.0 if dc.day > 0 and dc.day < 1 else 0.0
	var col := Color.WHITE.lerp(Color(1, .82, .66), dusk * .55).lerp(Color(.42, .48, .78), night * .85)
	var r: float = G.wx.rain
	col = col.lerp(Color(.72, .76, .84), r * .5)
	canvas_mod.color = col
	var cold: bool = G.CL.T < 0
	if cam:
		var vis := get_viewport_rect().size / cam.zoom
		for p in [rain, snow]:
			p.position = cam.get_screen_center_position() - Vector2(0, vis.y / 2 + 10)
			p.emission_rect_extents = Vector2(vis.x / 2 + 30, 4)
	rain.emitting = r > .25 and not cold and G.started
	snow.emitting = r > .25 and cold and G.started
	flies.emitting = night > .6 and G.last_stats.size() and G.last_stats.green > 30 and not cold
