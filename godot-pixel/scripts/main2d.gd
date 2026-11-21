extends Node2D
## Escena principal 2D: cámara con zoom entero, entrada, selección y flujo de partida.

var board: Node2D
var ui: CanvasLayer
var cam: Camera2D
var zoom_lvl := 3.0
var t_pos := Vector2.ZERO
var hover_i := -1
var drag_btn := 0
var drag_start := Vector2.ZERO
var drag_moved := false
var last_mouse := Vector2.ZERO
var ghost: Sprite2D
var ghost_key := ""
var ship: Sprite2D
var ship_t := 0.0
var menu_mode := true
var fx_on := true
var hud_hidden := false
var args := {}
var menu_t := 0.0
var hl_user := false
var next_b := 0

func _ready() -> void:
	for a in OS.get_cmdline_user_args():
		var kv := a.trim_prefix("--").split("=")
		args[kv[0]] = kv[1] if kv.size() > 1 else "1"
	board = preload("res://scripts/board.gd").new(); board.name = "Board"; add_child(board)
	cam = Camera2D.new(); add_child(cam)
	cam.position_smoothing_enabled = false
	board.cam = cam
	ui = preload("res://scripts/ui.gd").new(); ui.name = "UI"; add_child(ui)
	ui.tool_selected.connect(func(_id): ghost_key = "")
	ui.start_region.connect(_start)
	ui.continue_game.connect(_continue)
	ui.to_menu.connect(_to_menu)
	ui.quit_game.connect(_quit)
	ui.fx_toggled.connect(_set_fx)
	ui.highlight_pressed.connect(toggle_highlight)
	ui.next_building_pressed.connect(goto_next_building)
	Game.leaving_started.connect(_ship_in)
	Game.phase_changed.connect(func(_p): ghost_key = "")
	ui.make_thumbs_2d(board)
	get_window().min_size = Vector2i(1100, 650)
	Game.preview("valle")
	t_pos = Vector2(D.C, D.R) * 8
	Sfx.start_ambience()
	_menu()
	if args.has("auto"): _auto_setup()

# ======================================================================= flujo
func _menu() -> void:
	var s = Game.load_save()
	var nm := ""
	if s: nm = "%s, fase %d" % [D.REGIONS[s.region].n, int(s.phase)]
	menu_mode = true
	zoom_lvl = 3
	ui.show_menu(s != null, nm)

func _start(id: String) -> void:
	Game.new_game(id)
	_begin()
	ui.say(Game.REG.n + ": " + ("pon turbinas sobre roca para empezar" if id != "volcan" else "pon una geotérmica sobre la lava para empezar"))

func _continue() -> void:
	var s = Game.load_save()
	if s == null: return
	Game.restore(s)
	_begin()
	ui.say("Partida recuperada: " + Game.REG.n)

func _begin() -> void:
	menu_mode = false
	ui.menu.visible = false; ui.regions.visible = false; ui.win.visible = false
	ui.hud.visible = true
	ui.build_toolbar()
	Game.begin()
	t_pos = Vector2(D.C, D.R) * 8
	zoom_lvl = 3
	if ship: ship.queue_free(); ship = null

func _to_menu() -> void:
	if Game.started and not Game.won: Game.save()
	Game.started = false
	_clear_ghost()
	_menu()

func _quit() -> void:
	if Game.started and not Game.won: Game.save()
	get_tree().quit()

func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		if Game.started and not Game.won: Game.save()

func _set_fx(on: bool) -> void:
	fx_on = on
	for c in board.clouds: c.visible = on
	ui.say("Efectos: " + ("activados" if on else "básicos"))

# ======================================================================= entrada
func _unhandled_input(e: InputEvent) -> void:
	if e is InputEventKey and e.pressed and not e.echo:
		var k: int = e.keycode
		if k == KEY_F11:
			ui._toggle_fs(); return
		if k == KEY_ESCAPE:
			if ui.howto and ui.howto.visible: ui.howto.visible = false
			elif ui.regions.visible: ui.regions.visible = false; ui.menu.visible = true
			elif Game.started: ui.toggle_pause()
			return
		if not Game.started: return
		match k:
			KEY_B: ui.toggle_journal()
			KEY_M: Sfx.set_mute(not Sfx.muted); ui.say("Sonido " + ("apagado" if Sfx.muted else "activado"))
			KEY_G: ui.fx_on = not fx_on; _set_fx(not fx_on)
			KEY_H:
				hud_hidden = not hud_hidden
				ui.hud.visible = not hud_hidden
			KEY_F1: ui.help_l.visible = not ui.help_l.visible
			KEY_V: toggle_highlight()
			KEY_N: goto_next_building()
			KEY_Z, KEY_EQUAL, KEY_KP_ADD: zoom_lvl = minf(zoom_lvl + 1, 7)
			KEY_X, KEY_MINUS, KEY_KP_SUBTRACT: zoom_lvl = maxf(zoom_lvl - 1, 2)
		if k >= KEY_0 and k <= KEY_9 and not ui.any_modal():
			ui.select_index((k - KEY_1) if k != KEY_0 else 9)
	if ui.any_modal() and not menu_mode: return
	if e is InputEventMouseButton:
		var mb := e as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_WHEEL_UP and mb.pressed: zoom_lvl = minf(zoom_lvl + 1, 7)
		elif mb.button_index == MOUSE_BUTTON_WHEEL_DOWN and mb.pressed: zoom_lvl = maxf(zoom_lvl - 1, 2)
		elif mb.pressed:
			drag_btn = mb.button_index; drag_start = mb.position; last_mouse = mb.position; drag_moved = false
		else:
			if mb.button_index == MOUSE_BUTTON_LEFT and drag_btn == MOUSE_BUTTON_LEFT and not drag_moved and Game.started and not menu_mode:
				_click()
			drag_btn = 0
	elif e is InputEventMouseMotion:
		var mm := e as InputEventMouseMotion
		if drag_btn != 0:
			if mm.position.distance_to(drag_start) > 6: drag_moved = true
			var d := mm.position - last_mouse
			last_mouse = mm.position
			if drag_moved: t_pos -= d / _scale()

func _scale() -> float:
	return get_viewport().get_canvas_transform().get_scale().x if false else cam.zoom.x * get_tree().root.get_final_transform().get_scale().x

func _click() -> void:
	var i := _pick()
	if i < 0: return
	Game.apply(Game.tool_id, i % D.C, i / D.C)
	ghost_key = ""

func _pick() -> int:
	return board.tile_at(board.get_global_mouse_position())

# ======================================================================= bucle
func _process(dt: float) -> void:
	var playing: bool = Game.started and not menu_mode and not ui.any_modal()
	Game.paused = Game.started and not menu_mode and (ui.pause.visible or ui.journal.visible)
	if Game.started and not menu_mode:
		var sp := 260.0 * dt / zoom_lvl
		if Input.is_key_pressed(KEY_A) or Input.is_key_pressed(KEY_LEFT): t_pos.x -= sp
		if Input.is_key_pressed(KEY_D) or Input.is_key_pressed(KEY_RIGHT): t_pos.x += sp
		if Input.is_key_pressed(KEY_W) or Input.is_key_pressed(KEY_UP): t_pos.y -= sp
		if Input.is_key_pressed(KEY_S) or Input.is_key_pressed(KEY_DOWN): t_pos.y += sp
	if menu_mode:
		menu_t += dt
		t_pos = Vector2(D.C, D.R) * 8 + Vector2(cos(menu_t * .05) * 60, sin(menu_t * .07) * 40)
	t_pos = t_pos.clamp(Vector2(-24, -24), Vector2(D.C * 16 + 24, D.R * 16 + 24))
	if ship and ship_t < 14: _ship_update(dt)
	# zoom entero en píxeles de pantalla (para que el pixel art quede nítido)
	var root_s: float = get_tree().root.get_final_transform().get_scale().x
	var z := maxf(1.0, round(zoom_lvl * root_s)) / root_s
	cam.zoom = Vector2(z, z)
	cam.position = cam.position.lerp(t_pos, minf(1, dt * 10))
	var px := 1.0 / (z * root_s)
	cam.position = (cam.position / px).round() * px
	# casilla bajo el ratón
	if playing and drag_btn == 0:
		var i := _pick()
		if i != hover_i or ghost_key != "%s:%d:%d" % [Game.tool_id, i, Game.leaves]:
			hover_i = i
			_update_hover()
	elif not playing and hover_i != -2:
		hover_i = -2
		board.set_hover(-1, true, 0, false)
		_clear_ghost()
		ui.set_hover("", "")
	board.set_highlight(Game.started and not menu_mode and (hl_user or Game.tool_id == "rec"))
	if Game.started:
		ui.set_buildings_left(board.bnodes.size(), Game.phase == 3, board.highlight)
		var dc: Dictionary = Game.day_clock()
		ui.set_time(int(Game.gtime / D.DAY) + 1, dc.night, Game.wx.rain, Game.CL.T < 0)
	_ambience()
	if args.has("auto"): _auto_step(dt)

func _update_hover() -> void:
	var id: String = Game.tool_id
	var cov: bool = id in ["tur", "geo"] or id in D.NEEDPOW
	if hover_i < 0:
		board.set_hover(-1, true, 0, cov); _clear_ghost(); ui.set_hover("", ""); ghost_key = ""
		return
	var x := hover_i % D.C; var y := hover_i / D.C
	var err: String = Game.check(id, x, y)
	var rr := 0
	match id:
		"tur": rr = 4 if Game.T[hover_i] == "mnt" else 3
		"geo": rr = 4
		"dep", "asp", "viv": rr = 2
		"sol", "col", "obs", "hid": rr = 3
	board.set_hover(hover_i, err == "", rr, cov)
	var tn: String = D.TNAME[Game.T[hover_i]]
	if Game.B[hover_i] != "": tn += " · " + D.tool(Game.B[hover_i]).n + (" (sin energía)" if Game.B[hover_i] in D.NEEDPOW and not Game.POW[hover_i] else "")
	ui.set_hover(tn, err)
	var key := "%s:%d:%d" % [id, hover_i, Game.leaves]
	if key == ghost_key: return
	ghost_key = key
	_clear_ghost()
	var t := D.tool(id)
	if t.get("b", false) and (Game.B[hover_i] == "" or id == "hid"):
		ghost = board._spr("b_" + id, board.center(hover_i) + Vector2(0, 6))
		ghost.modulate = Color(.6, 1, .6, .7) if err == "" else Color(1, .45, .4, .7)
		ghost.z_index = 1

func _clear_ghost() -> void:
	if ghost:
		ghost.queue_free(); ghost = null

func _ambience() -> void:
	var s: Dictionary = Game.last_stats
	if s.is_empty(): return
	var dc: Dictionary = Game.day_clock()
	var night: float = dc.night
	var gr: float = float(s.green) / s.land
	var rain: float = Game.wx.rain
	var cold: bool = Game.CL.T < 0
	Sfx.set_ambience({
		"amb_wind": .2 + (1 - gr) * .25 + (.2 if cold else 0.0),
		"amb_rain": rain * (.0 if cold else .7),
		"amb_sea": 0.0 if Game.region_id == "volcan" else .25,
		"amb_birds": clampf(gr * 1.6, 0, .8) * (1 - night),
		"amb_night": clampf(gr * 1.4, 0, .5) * night * (0.0 if cold else 1.0),
		"amb_lava": .25 if Game.region_id == "volcan" else 0.0})

# ======================================================================= nave de salida
func _ship_in() -> void:
	ship = Sprite2D.new(); ship.texture = board.tex["airship"]; ship.z_index = 5
	board.add_child(ship)
	ship_t = 0
	_clear_ghost()
	ui.hud.visible = false

func _ship_update(dt: float) -> void:
	ship_t += dt
	var c := Vector2(D.C, D.R) * 8
	var p: Vector2
	if ship_t < 5: p = c + Vector2(lerpf(-300, 0, ease(ship_t / 5.0, .4)), -40)
	elif ship_t < 9: p = c + Vector2(0, -40 + sin((ship_t - 5) * 2) * 2)
	else:
		var k := (ship_t - 9) / 5.0
		p = c + Vector2(k * k * 400, -40 - k * k * 200)
	ship.position = p.round()
	t_pos = t_pos.lerp(p + Vector2(0, 40), dt * 1.5)
	if ship_t >= 14:
		ship.queue_free(); ship = null

# ======================================================================= pruebas automáticas
var auto_t0 := 0.0
var auto_next_shot := 0.0
var auto_shot_n := 0
var auto_started := false
var auto_act := 0.0
var auto_done_t := -1.0
func _auto_setup() -> void:
	DirAccess.make_dir_recursive_absolute(args.get("out", "/tmp/shots"))

func _shot(tag: String) -> void:
	var img := get_viewport().get_texture().get_image()
	if img == null: return
	var path := "%s/%02d_%s.png" % [args.get("out", "/tmp/shots"), auto_shot_n, tag]
	img.save_png(path)
	print("SHOT ", path, " fase=", Game.phase, " anim=", Game.anim.size(), " scanned=", Game.scanned.size())
	auto_shot_n += 1

func _auto_step(dt: float) -> void:
	auto_t0 += dt
	if args.has("menu"):
		if auto_t0 > 2.5 and auto_shot_n == 0:
			_shot("menu")
			if args.has("regions"): ui.open_regions()
		if auto_t0 > 3.5 and auto_shot_n == 1 and args.has("regions"): _shot("regiones")
		if auto_t0 > 4: get_tree().quit()
		return
	if not auto_started and auto_t0 > 1.0:
		auto_started = true
		_start(args.get("region", "valle"))
		if args.has("lush"): _lush()
		if args.has("hl"): hl_user = true
		if args.has("zoom"): zoom_lvl = float(args.zoom)
		if args.has("at"):
			var c: PackedStringArray = args.at.split(",")
			t_pos = Vector2(float(c[0]), float(c[1])) * 16
		auto_next_shot = auto_t0 + 2.0
		return
	if not auto_started: return
	Game.leaves = maxi(Game.leaves, 400)
	var speed := int(args.get("speed", "3"))
	if not Game.won and not Game.leaving and args.has("play"):
		for k in speed: Game.tick()
		Game.gtime += dt * (speed - 1)
		auto_act += dt
		if auto_act > .15:
			auto_act = 0
			for k in 3: _auto_action()
	if args.has("time"): Game.gtime = D.DAY * float(args.time)
	if auto_t0 >= auto_next_shot:
		_shot("f%d" % Game.phase)
		auto_next_shot = auto_t0 + float(args.get("every", "6"))
		if auto_shot_n >= int(args.get("shots", "3")): get_tree().quit()
	if Game.won and auto_done_t < 0: auto_done_t = auto_t0
	if auto_done_t > 0 and auto_t0 - auto_done_t > 2.0:
		_shot("fin"); print("WIN"); get_tree().quit()
	if auto_t0 > float(args.get("limit", "900")): print("TIMEOUT"); get_tree().quit()

func _auto_action() -> void:
	var G := Game
	var s: Dictionary = G.last_stats
	if s.is_empty(): return
	var tries := []
	if G.phase < 3:
		tries = ["geo", "tur", "dep", "asp", "pum", "can"]
		var ph2 := G.phase == 2
		if G.ph_of(D.tool("sol")) <= G.phase:
			if G.CL.T < (12 if ph2 else 2) or s.ice > 0: tries.append("sol")
			if G.CL.T > 26: tries.append("fri")
			if G.CL.H < (55 if ph2 else 40): tries.append("nub")
		if ph2: tries += ["viv", "col", "hid", "man", "asp", "dep"]
	else:
		if G.scanned.size() < 3:
			var nobs := 0
			for i in D.C * D.R:
				if G.B[i] == "obs": nobs += 1
			if nobs < 4: tries = ["obs"]
		else:
			tries = ["rec"]
	tries.shuffle()
	for id in tries:
		var t := D.tool(id)
		if t.is_empty() or not G.in_reg(t): continue
		var best := -1; var bs := -1.0
		for k in 160:
			var i := G.rng.randi() % (D.C * D.R)
			var x := i % D.C; var y := i / D.C
			if G.check(id, x, y) != "": continue
			var sc := G.rng.randf()
			if id == "dep" or id == "asp":
				var n := 0
				for dy in range(-2, 3):
					for dx in range(-2, 3):
						var q := G.at(x + dx, y + dy)
						if (id == "dep" and q in D.DIRTY) or (id == "asp" and q == "dirt"): n += 1
				if n < 3: continue
				sc += n
			if id == "can":
				if not G.touches(x, y, ["water", "sea", "bed"]): continue
				if s.water > 30: continue
			if id == "tur" or id == "geo": sc += 5
			if id == "rec" and G.B[i] == "obs" and G.scanned.size() < 3: continue
			if sc > bs: bs = sc; best = i
		if best >= 0:
			G.apply(id, best % D.C, best / D.C)
			return

func _lush() -> void:
	var G := Game
	for i in D.C * D.R:
		var t: String = G.T[i]
		if t in ["tox", "ash", "dirt", "ice"]:
			var r := G.rng.randf()
			G.T[i] = "forest" if r < .3 else ("flower" if r < .5 else "grass")
		elif t == "bed": G.T[i] = "water"
	for i in D.C * D.R:
		if G.T[i] in ["grass", "flower"] and G.touches(i % D.C, i / D.C, ["water"]) and G.rng.randf() < .6: G.T[i] = "wet"
		if G.T[i] == "sand" and G.touches(i % D.C, i / D.C, ["sea"]) and G.rng.randf() < .4 and G.region_id in ["valle", "tropico"]: G.T[i] = "mang"
	G.compute_power()
	G.map_rebuilt.emit()
	G.hud()
	G.fauna(true)
	G.fauna_changed.emit()

func toggle_highlight() -> void:
	hl_user = not hl_user
	ui.say("Resaltar edificios: " + ("activado" if hl_user else "desactivado") + "  (V)")

func goto_next_building() -> void:
	var L: Array = board.building_tiles()
	if L.is_empty():
		ui.say("No queda ningún edificio en la parcela"); return
	next_b = next_b % L.size()
	var i: int = L[next_b]
	next_b += 1
	t_pos = board.center(i)
	zoom_lvl = maxf(zoom_lvl, 4)
	hl_user = true
	ui.say("%s  ·  %d de %d" % [D.tool(Game.B[i]).n, next_b, L.size()])
