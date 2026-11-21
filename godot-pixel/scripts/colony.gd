extends Node2D
## Nave colonia: aterriza al empezar, sus colonos construyen todo, se desarma pieza a pieza
## mientras haya edificios en pie, se rearma al reciclarlos y al final despega.

const T := 16
const NW := 6

var board: Node2D
var G: Node
var ship: Sprite2D
var flames: Array[Sprite2D] = []
var shader: ShaderMaterial
var under: Node2D          # pista y sombra (bajo los objetos)
var fly: Node2D            # piezas volando (encima de todo)
var workers: Array = []    # {s, p, tgt, st, t, home, spd}
var parts: Array = []      # [desde, hasta, t, dur, frame, delay]
var mode := "idle"         # idle | intro | play | leave | gone
var mt := 0.0
var alt := 0.0             # altura de la nave sobre el suelo (px)
var keep_shown := 1.0
var shake := 0.0
var ftime := 0.0
var fr := 0
var rng := RandomNumberGenerator.new()

func setup(b: Node2D) -> void:
	board = b; G = Game
	under = Node2D.new(); under.draw.connect(_draw_under)
	board.add_child(under); board.move_child(under, board.objs.get_index())
	fly = Node2D.new(); fly.z_index = 6; fly.draw.connect(_draw_fly)
	board.add_child(fly)
	shader = ShaderMaterial.new()
	shader.shader = load("res://shaders/dissolve.gdshader")
	G.building_changed.connect(_on_building)

func base_pos() -> Vector2:
	var i: int = G.ship_i
	return Vector2((i % D.C + .5) * T, (i / D.C + 1) * T - 2)

func hatch() -> Vector2:
	return base_pos() + Vector2(0, -12)

func ramp_end() -> Vector2:
	return base_pos() + Vector2(0, -2)

# ---------------------------------------------------------------- ciclo
func clear() -> void:
	if ship: ship.queue_free(); ship = null
	flames.clear()
	for w in workers: w.s.queue_free()
	workers.clear(); parts.clear()
	mode = "idle"; shake = 0
	under.queue_redraw(); fly.queue_redraw()

func _make_ship() -> void:
	ship = board._spr("lander", base_pos())
	ship.material = shader
	shader.set_shader_parameter("keep", 1.0)
	for dx in [-9, 9]:
		var f := Sprite2D.new(); f.texture = board.tex["flame"]; f.hframes = 4
		f.centered = false; f.offset = Vector2(-4, 0); f.position = Vector2(dx, -8)
		f.visible = false; f.show_behind_parent = true
		ship.add_child(f); flames.append(f)

func _make_worker(p: Vector2, st: String) -> Dictionary:
	var s: Sprite2D = board._spr("worker", p)
	var tints := [Color(1, 1, 1), Color(1, .9, .8), Color(.9, 1, .95), Color(1, .95, 1), Color(.95, .95, 1), Color(1, 1, .9)]
	s.self_modulate = tints[workers.size() % tints.size()]
	var w := {"s": s, "p": p, "tgt": p, "st": st, "t": 0.0, "home": p, "spd": 14.0}
	workers.append(w)
	return w

## Partida nueva: la nave baja del cielo.
func start_intro() -> void:
	clear()
	_make_ship()
	mode = "intro"; mt = 0; alt = 260
	keep_shown = 1.0
	ship.frame = 2

## Partida recuperada: la nave ya está en tierra, en el estado que corresponde.
func start_static() -> void:
	clear()
	_make_ship()
	mode = "play"; alt = 0; ship.frame = 0
	keep_shown = G.ship_keep()
	for k in NW:
		var a := TAU * k / NW + rng.randf() * .4
		var p := base_pos() + Vector2(cos(a) * 40, sin(a) * 22 + 10)
		_make_worker(p, "idle")
	# colonos repartidos entre los edificios existentes
	var L: Array = board.building_tiles()
	for k in mini(L.size(), NW):
		var w: Dictionary = workers[k]
		w.p = board.center(L[(k * 7) % L.size()]) + Vector2(rng.randf_range(-8, 8), rng.randf_range(4, 9))
		w.home = w.p; w.tgt = w.p

func skip_intro() -> void:
	if mode != "intro": return
	alt = 0; ship.frame = 0
	for f in flames: f.visible = false
	while workers.size() < NW: _make_worker(ramp_end(), "idle")
	for k in workers.size():
		var w: Dictionary = workers[k]
		var a := TAU * k / NW + .3
		w.p = base_pos() + Vector2(cos(a) * 40, sin(a) * 22 + 10)
		w.home = w.p; w.tgt = w.p; w.st = "idle"
	mode = "play"; shake = 0

func intro_done() -> bool:
	return mode != "intro"

func start_leave() -> void:
	if not ship: _make_ship()
	mode = "leave"; mt = 0
	for w in workers:
		w.st = "back"; w.tgt = ramp_end() + Vector2(rng.randf_range(-3, 3), 0)
		w.spd = maxf(20.0, w.p.distance_to(w.tgt) / 5.0)

# ---------------------------------------------------------------- eventos de juego
func _on_building(i: int, old: String) -> void:
	if mode != "play" or not ship: return
	var p: Vector2 = board.center(i)
	if G.B[i] != "":
		# piezas de la nave viajan al nuevo edificio y un colono va a montarlo
		for k in 3: parts.append([hatch() + Vector2(rng.randf_range(-14, 14), rng.randf_range(-10, 4)), p + Vector2(rng.randf_range(-4, 4), 0), 0.0, .9 + k * .12, rng.randi() % 3, k * .08])
		var best: Dictionary = {}; var bd := 1e9
		for w in workers:
			var d: float = w.p.distance_to(p) + (200.0 if w.st in ["go", "work"] else 0.0)
			if d < bd: bd = d; best = w
		if not best.is_empty():
			best.st = "go"; best.tgt = p + Vector2(rng.randf_range(-7, 7), rng.randf_range(5, 9))
			best.spd = maxf(22.0, best.p.distance_to(best.tgt) / 5.0)
	elif old != "":
		# reciclaje: el dron se lleva el edificio y sus piezas regresan a la nave
		for k in 3: parts.append([p + Vector2(rng.randf_range(-4, 4), -20), hatch() + Vector2(rng.randf_range(-14, 14), rng.randf_range(-10, 4)), 0.0, 1.1 + k * .12, rng.randi() % 3, 1.4 + k * .1])

# ---------------------------------------------------------------- cuadro a cuadro
func _process(dt: float) -> void:
	if mode == "idle" or not ship: return
	mt += dt
	ftime += dt
	if ftime > .1:
		ftime = 0; fr = (fr + 1) % 4
		for f in flames: f.frame = fr
	match mode:
		"intro": _intro(dt)
		"play": _play(dt)
		"leave": _leave(dt)
	shake = maxf(0, shake - dt * 2.5)
	# armado/desarmado progresivo
	var target_keep: float = 1.0 if mode in ["intro", "leave"] else G.ship_keep()
	keep_shown = move_toward(keep_shown, target_keep, dt * .35)
	shader.set_shader_parameter("keep", keep_shown)
	shader.set_shader_parameter("weld", 1.0 if absf(keep_shown - target_keep) > .005 else 0.0)
	ship.position = (base_pos() + Vector2(0, -alt)).round()
	# la nave no se ve "por encima" de los árboles cuando vuela: z alto en el aire
	ship.z_index = 5 if alt > 4 else 0
	_update_workers(dt)
	for P in parts.duplicate():
		P[2] += dt
		if P[2] > P[5] + P[3]:
			parts.erase(P)
			board.burst(P[1], Color("#e0e4e8"), 4)
	under.queue_redraw(); fly.queue_redraw()

func _intro(_dt: float) -> void:
	if mt < 3.4:
		var k := mt / 3.4
		alt = 260.0 * pow(1.0 - k, 2.2)
		ship.frame = 2
		for f in flames:
			f.visible = true
			f.scale = Vector2(1, 1.0 + (1.0 - k) * .6)
		if alt < 30: shake = maxf(shake, .5)
	elif mt < 4.2:
		if alt > 0:
			alt = 0; shake = 1.2
			for j in G.ship_tiles: board.burst(board.center(j), Color("#c8a878"), 14)
			Sfx.play("place")
		for f in flames: f.visible = false
		ship.frame = 0
	else:
		ship.frame = 1
		# colonos bajan por la rampa uno a uno
		var n := int((mt - 4.4) / .4) + 1
		while workers.size() < mini(n, NW):
			var w := _make_worker(hatch(), "out")
			var a := TAU * (workers.size() - 1) / NW + .3
			w.tgt = base_pos() + Vector2(cos(a) * 40, sin(a) * 22 + 10)
			w.home = w.tgt; w.spd = 16
		if mt > 4.4 + NW * .4 + 1.6:
			ship.frame = 0
			for w in workers:
				if w.st == "out": w.st = "idle"
			mode = "play"

func _play(_dt: float) -> void:
	ship.frame = 0

func _leave(dt: float) -> void:
	# 0-8 s: los colonos regresan; 8-9 cierra; 9-15 despega y se va
	var aboard := true
	for w in workers:
		if w.st != "in": aboard = false
	if mt < 8.5:
		ship.frame = 1 if mt > .5 else 0
		if mt > 7.5 and not aboard:
			for w in workers: w.st = "in"; w.s.visible = false
	elif mt < 9.4:
		ship.frame = 0
	else:
		ship.frame = 2
		var k := mt - 9.4
		for f in flames:
			f.visible = true; f.scale = Vector2(1, 1.0 + minf(k, 1.5) * .5)
		if k < 1.2:
			shake = maxf(shake, .8)
			alt = k * 4
			if fmod(k, .3) < dt:
				for j in G.ship_tiles: board.burst(board.center(j), Color("#d8d0c0"), 10)
		else:
			var q := k - 1.2
			alt = 5 + q * q * 38
			ship.position.x = base_pos().x + q * q * 6
		if k > 0 and k < dt * 1.5: Sfx.play("ship")

func _update_workers(dt: float) -> void:
	for w in workers:
		var s: Sprite2D = w.s
		if w.st == "in":
			s.visible = false; continue
		w.t += dt
		var d: Vector2 = w.tgt - w.p
		var moving := d.length() > 1.0
		if moving:
			var stp := minf(d.length(), w.spd * dt)
			w.p += d.normalized() * stp
			s.flip_h = d.x < 0
			s.frame = int(w.t * 8) % 2
		else:
			match w.st:
				"go":
					w.st = "work"; w.t = 0
				"work":
					s.frame = 3 + int(w.t * 6) % 2
					if int(w.t * 6) % 2 == 1 and fmod(w.t, 1.0 / 3.0) < dt:
						board.burst(w.p + Vector2(4 if not s.flip_h else -4, -6), Color("#ffe080"), 2)
					if w.t > 2.6:
						w.st = "idle"; w.home = w.p; w.t = 0
				"back":
					w.st = "in"; s.visible = false
				"out":
					w.st = "idle"; w.t = 0
				_:
					s.frame = 2
					if w.t > 2.0 + rng.randf() * 3.0:
						w.t = 0
						w.tgt = w.home + Vector2(rng.randf_range(-18, 18), rng.randf_range(-12, 12))
						w.spd = 12
		s.position = w.p.round()

# ---------------------------------------------------------------- dibujo
func _draw_under() -> void:
	if G.ship_i < 0 or mode == "idle": return
	var c := base_pos() + Vector2(0, -4)
	# pista de aterrizaje: queda marcada aunque la nave se desarme
	var a := .35 if mode != "gone" else .2
	_ellipse(under, c, Vector2(26, 9), Color(.85, .85, .8, a * .5))
	_ellipse_line(under, c, Vector2(26, 9), Color(.95, .7, .3, a))
	_ellipse_line(under, c, Vector2(17, 6), Color(.95, .95, .9, a * .7))
	# sombra mientras vuela
	if alt > 2:
		var k := clampf(1.0 - alt / 260.0, .15, 1.0)
		_ellipse(under, base_pos() + Vector2(ship.position.x - base_pos().x, 0), Vector2(26, 5) * k, Color(0, 0, 0, .35 * k))

func _ellipse(n: CanvasItem, c: Vector2, r: Vector2, col: Color) -> void:
	var pts := PackedVector2Array()
	for k in 24: pts.append(c + Vector2(cos(TAU * k / 24) * r.x, sin(TAU * k / 24) * r.y))
	n.draw_colored_polygon(pts, col)

func _ellipse_line(n: CanvasItem, c: Vector2, r: Vector2, col: Color) -> void:
	var pts := PackedVector2Array()
	for k in 25: pts.append(c + Vector2(cos(TAU * k / 24) * r.x, sin(TAU * k / 24) * r.y))
	n.draw_polyline(pts, col, 1.0)

func _draw_fly() -> void:
	var tx: Texture2D = board.tex["part"]
	for P in parts:
		var t: float = (P[2] - P[5]) / P[3]
		if t < 0: continue
		var a: Vector2 = P[0]; var b: Vector2 = P[1]
		var p := a.lerp(b, t) + Vector2(0, -sin(t * PI) * (30 + a.distance_to(b) * .15))
		fly.draw_texture_rect_region(tx, Rect2((p - Vector2(3, 2)).round(), Vector2(6, 5)), Rect2(P[4] * 6, 0, 6, 5))
