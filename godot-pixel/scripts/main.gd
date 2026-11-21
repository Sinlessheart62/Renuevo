extends Node3D
## Escena principal: cámara, entrada de teclado/ratón, selección de casillas y flujo de partida.

var world: Node3D
var ui: CanvasLayer
var rig: Node3D
var cam: Camera3D
var target := Vector3.ZERO
var yaw := deg_to_rad(45.0)
var pitch := deg_to_rad(52.0)
var dist := 36.0
var t_target := Vector3.ZERO
var t_yaw := yaw
var t_pitch := pitch
var t_dist := dist
var hover_i := -1
var drag_btn := 0
var drag_start := Vector2.ZERO
var drag_moved := false
var last_mouse := Vector2.ZERO
var ghost: Node3D
var ghost_key := ""
var ghost_ok_mat: StandardMaterial3D
var ghost_bad_mat: StandardMaterial3D
var ship: Node3D
var ship_t := 0.0
var menu_orbit := true
var fx_on := true
var hud_hidden := false
var args := {}
var auto_t := 0.0
var svp: SubViewport
var screen: TextureRect
var outline: MeshInstance3D
var pix := 3

func _ready() -> void:
	for a in OS.get_cmdline_user_args():
		var kv := a.trim_prefix("--").split("=")
		args[kv[0]] = kv[1] if kv.size() > 1 else "1"
	# el mundo 3D se dibuja en una vista de baja resolución que luego se amplía sin suavizado
	svp = SubViewport.new()
	svp.msaa_3d = Viewport.MSAA_DISABLED
	svp.screen_space_aa = Viewport.SCREEN_SPACE_AA_DISABLED
	svp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	svp.audio_listener_enable_3d = false
	add_child(svp)
	world = preload("res://scripts/world.gd").new(); world.name = "World"; svp.add_child(world)
	rig = Node3D.new(); svp.add_child(rig)
	cam = Camera3D.new(); cam.near = .1; cam.far = 300
	cam.projection = Camera3D.PROJECTION_ORTHOGONAL
	rig.add_child(cam)
	world.cam_attr = CameraAttributesPractical.new()
	cam.attributes = world.cam_attr
	# contorno de 1 píxel
	var oq := MeshInstance3D.new()
	var qm := QuadMesh.new(); qm.size = Vector2(2, 2); oq.mesh = qm
	var om := ShaderMaterial.new(); om.shader = load("res://shaders/outline.gdshader")
	oq.material_override = om
	oq.extra_cull_margin = 16384
	oq.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	outline = oq
	cam.add_child(oq)
	var tl := CanvasLayer.new(); tl.layer = -1; add_child(tl)
	screen = TextureRect.new()
	screen.texture = svp.get_texture()
	screen.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	screen.stretch_mode = TextureRect.STRETCH_SCALE
	screen.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	screen.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var pm := ShaderMaterial.new(); pm.shader = load("res://shaders/palette.gdshader")
	screen.material = pm
	tl.add_child(screen)
	get_viewport().size_changed.connect(_resize)
	_resize()
	ui = preload("res://scripts/ui.gd").new(); ui.name = "UI"; add_child(ui)
	ui.tool_selected.connect(func(_id): ghost_key = "")
	ui.start_region.connect(_start)
	ui.continue_game.connect(_continue)
	ui.to_menu.connect(_to_menu)
	ui.quit_game.connect(_quit)
	ui.fx_toggled.connect(_set_fx)
	Game.leaving_started.connect(_ship_in)
	Game.phase_changed.connect(func(_p): ghost_key = "")
	ghost_ok_mat = _ghost_mat(Color(.5, 1, .6, .45))
	ghost_bad_mat = _ghost_mat(Color(1, .4, .3, .45))
	var holder := Node.new(); add_child(holder)
	ui.make_thumbs(world.factory, holder)
	get_window().min_size = Vector2i(1100, 650)
	Game.preview("valle")
	Sfx.start_ambience()
	_menu()
	if args.has("auto"): _auto_setup()
	if args.has("nantest"): _nan_test()

func _ghost_mat(c: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.albedo_color = c; m.emission_enabled = true; m.emission = Color(c.r, c.g, c.b); m.emission_energy_multiplier = .4
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	return m

# ======================================================================= flujo
func _menu() -> void:
	var s = Game.load_save()
	var nm := ""
	if s: nm = "%s, fase %d" % [D.REGIONS[s.region].n, int(s.phase)]
	menu_orbit = true
	t_dist = 42; t_pitch = deg_to_rad(40)
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
	menu_orbit = false
	ui.menu.visible = false; ui.regions.visible = false; ui.win.visible = false
	ui.hud.visible = true
	ui.build_toolbar()
	Game.begin()
	t_target = Vector3.ZERO; t_dist = 26; t_pitch = deg_to_rad(52); t_yaw = snappedf(t_yaw, PI / 4)
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
	world.env.ssao_enabled = on; world.env.ssil_enabled = on; world.env.volumetric_fog_enabled = on
	outline.visible = on
	(screen.material as ShaderMaterial).set_shader_parameter("amount", 1.0 if on else 0.0)
	world.sun.shadow_blur = 1.5 if on else .5
	ui.say("Efectos visuales: " + ("completos" if on else "básicos (más rápido)"))

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
			KEY_Q: t_yaw = snappedf(t_yaw + PI / 4, PI / 4)
			KEY_E: t_yaw = snappedf(t_yaw - PI / 4, PI / 4)
		if k >= KEY_0 and k <= KEY_9 and not ui.any_modal():
			ui.select_index((k - KEY_1) if k != KEY_0 else 9)
	if ui.any_modal() and not menu_orbit: return
	if e is InputEventMouseButton:
		var mb := e as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_WHEEL_UP and mb.pressed: t_dist = clampf(t_dist * .9, 6, 60)
		elif mb.button_index == MOUSE_BUTTON_WHEEL_DOWN and mb.pressed: t_dist = clampf(t_dist * 1.1, 6, 60)
		elif mb.pressed:
			drag_btn = mb.button_index; drag_start = mb.position; last_mouse = mb.position; drag_moved = false
		else:
			if mb.button_index == MOUSE_BUTTON_LEFT and drag_btn == MOUSE_BUTTON_LEFT and not drag_moved and Game.started and not menu_orbit:
				_click(mb.position)
			if drag_btn == MOUSE_BUTTON_RIGHT or drag_btn == MOUSE_BUTTON_MIDDLE: t_yaw = snappedf(t_yaw, PI / 4)
			drag_btn = 0
	elif e is InputEventMouseMotion:
		var mm := e as InputEventMouseMotion
		if drag_btn != 0:
			if mm.position.distance_to(drag_start) > 6: drag_moved = true
			var d := mm.position - last_mouse
			last_mouse = mm.position
			if not drag_moved: return
			if drag_btn == MOUSE_BUTTON_LEFT:
				_pan(-d.x * t_dist * .0016, -d.y * t_dist * .0016 / maxf(.5, sin(pitch)))
			elif drag_btn == MOUSE_BUTTON_RIGHT or drag_btn == MOUSE_BUTTON_MIDDLE:
				t_yaw -= d.x * .006
				t_pitch = clampf(t_pitch + d.y * .004, deg_to_rad(22), deg_to_rad(82))

func _pan(dx: float, dz: float) -> void:
	var right := Vector3(cos(t_yaw), 0, -sin(t_yaw))
	var fwd := Vector3(-sin(t_yaw), 0, -cos(t_yaw))
	t_target += right * dx - fwd * dz
	t_target.x = clampf(t_target.x, -16, 16); t_target.z = clampf(t_target.z, -16, 16)

func _click(pos: Vector2) -> void:
	var i := _pick(pos)
	if i < 0: return
	Game.apply(Game.tool_id, i % D.C, i / D.C)
	ghost_key = ""

func _pick(pos: Vector2) -> int:
	var vp := pos / float(pix)
	var o := cam.project_ray_origin(vp)
	var d := cam.project_ray_normal(vp)
	var t := 0.0
	var prev_above := true
	t = 40.0
	for k in 2400:
		var p := o + d * t
		if p.y < -3 and t > 60: break
		var h: float = world.surface_at(p.x, p.z)
		if p.y <= h and absf(p.x) < 15 and absf(p.z) < 15:
			# refinar
			var a := t - .08; var b := t
			for j in 8:
				var m := (a + b) * .5
				var q := o + d * m
				if q.y <= world.surface_at(q.x, q.z): b = m
				else: a = m
			var hit := o + d * b
			var tx := int(floor(hit.x + 15)); var tz := int(floor(hit.z + 15))
			if tx >= 0 and tz >= 0 and tx < D.C and tz < D.R: return tz * D.C + tx
			return -1
		t += .08
	return -1

# ======================================================================= bucle
func _process(dt: float) -> void:
	var playing: bool = Game.started and not menu_orbit and not ui.any_modal()
	Game.paused = Game.started and not menu_orbit and (ui.pause.visible or ui.journal.visible)
	# teclado continuo
	if playing or (Game.started and not menu_orbit):
		var sp := t_dist * dt * .9
		if Input.is_key_pressed(KEY_A) or Input.is_key_pressed(KEY_LEFT): _pan(-sp, 0)
		if Input.is_key_pressed(KEY_D) or Input.is_key_pressed(KEY_RIGHT): _pan(sp, 0)
		if Input.is_key_pressed(KEY_W) or Input.is_key_pressed(KEY_UP): _pan(0, -sp)
		if Input.is_key_pressed(KEY_S) or Input.is_key_pressed(KEY_DOWN): _pan(0, sp)

		if Input.is_key_pressed(KEY_R): t_pitch = clampf(t_pitch + dt * 1.0, deg_to_rad(22), deg_to_rad(82))
		if Input.is_key_pressed(KEY_F): t_pitch = clampf(t_pitch - dt * 1.0, deg_to_rad(22), deg_to_rad(82))
		if Input.is_key_pressed(KEY_Z) or Input.is_key_pressed(KEY_EQUAL) or Input.is_key_pressed(KEY_KP_ADD): t_dist = clampf(t_dist * (1 - dt * 1.2), 6, 60)
		if Input.is_key_pressed(KEY_X) or Input.is_key_pressed(KEY_MINUS) or Input.is_key_pressed(KEY_KP_SUBTRACT): t_dist = clampf(t_dist * (1 + dt * 1.2), 6, 60)
	if menu_orbit:
		t_yaw += dt * .05
		t_target = Vector3.ZERO
	if ship and ship_t < 16:
		_ship_update(dt)
	var k := minf(1, dt * 8)
	target = target.lerp(t_target, k)
	yaw = lerp_angle(yaw, t_yaw, k)
	pitch = lerpf(pitch, t_pitch, k)
	dist = lerpf(dist, t_dist, k)
	var off := Vector3(sin(yaw) * cos(pitch), sin(pitch), cos(yaw) * cos(pitch)) * 80.0
	var tgt := target + Vector3(0, .6, 0)
	cam.size = dist * .62
	# ajustar el punto de mira a la rejilla de píxeles de la cámara (evita el "temblor")
	var bas := Basis.looking_at(-off.normalized(), Vector3.UP)
	var texel: float = cam.size / float(svp.size.y)
	var lx := bas.x.dot(tgt); var ly := bas.y.dot(tgt); var lz := bas.z.dot(tgt)
	lx = round(lx / texel) * texel; ly = round(ly / texel) * texel
	tgt = bas.x * lx + bas.y * ly + bas.z * lz
	cam.global_transform = Transform3D(bas, tgt + off)
	# casilla bajo el ratón
	if playing and drag_btn == 0:
		var i := _pick(get_viewport().get_mouse_position())
		if i != hover_i or ghost_key != "%s:%d:%d" % [Game.tool_id, i, Game.leaves]:
			hover_i = i
			_update_hover()
	elif not playing and hover_i != -2:
		hover_i = -2
		world.show_tool_help("", -1, false)
		_clear_ghost()
		ui.set_hover("", "")
	# reloj y sonido ambiente
	if Game.started:
		var dc: Dictionary = Game.day_clock()
		ui.set_time(int(Game.gtime / D.DAY) + 1, dc.night, Game.wx.rain, Game.CL.T < 0)
	_ambience(dt)
	if args.has("auto"): _auto_step(dt)

func _update_hover() -> void:
	var id: String = Game.tool_id
	if hover_i < 0:
		world.show_tool_help(id, -1, false); _clear_ghost(); ui.set_hover("", ""); ghost_key = ""
		return
	var x := hover_i % D.C; var y := hover_i / D.C
	var err: String = Game.check(id, x, y)
	world.show_tool_help(id, hover_i, err == "")
	var tn: String = D.TNAME[Game.T[hover_i]]
	if Game.B[hover_i] != "": tn += " · " + D.tool(Game.B[hover_i]).n + (" (sin energía)" if Game.B[hover_i] in D.NEEDPOW and not Game.POW[hover_i] else "")
	ui.set_hover(tn, err)
	var key := "%s:%d:%d" % [id, hover_i, Game.leaves]
	if key == ghost_key: return
	ghost_key = key
	_clear_ghost()
	var t := D.tool(id)
	if t.get("b", false) and (Game.B[hover_i] == "" or id == "hid"):
		ghost = world.factory.make(id, hover_i)
		var m := ghost_ok_mat if err == "" else ghost_bad_mat
		for c in ghost.find_children("*", "GeometryInstance3D", true, false):
			if c is MeshInstance3D: (c as MeshInstance3D).material_override = m
			elif c is CPUParticles3D: c.queue_free()
		var p: Vector3 = world.tile_center(hover_i); p.y = world.height_at(p.x, p.z) + .02
		ghost.position = p
		world.add_child(ghost)

func _clear_ghost() -> void:
	if ghost:
		ghost.queue_free(); ghost = null

func _ambience(_dt: float) -> void:
	var s: Dictionary = Game.last_stats
	if s.is_empty(): return
	var dc: Dictionary = Game.day_clock()
	var night: float = dc.night
	var gr: float = float(s.green) / s.land
	var sea := 0.0
	for t in ["sea", "oil"]:
		pass
	var rain: float = Game.wx.rain
	var cold: bool = Game.CL.T < 0
	var lava := 0.25 if Game.region_id == "volcan" else 0.0
	var zoom := clampf(1.3 - dist / 60.0, .3, 1.0)
	Sfx.set_ambience({
		"amb_wind": .25 + (1 - gr) * .25 + (.2 if cold else 0.0),
		"amb_rain": rain * (.0 if cold else .7),
		"amb_sea": (0.0 if Game.region_id == "volcan" else .28) * zoom,
		"amb_birds": clampf(gr * 1.6, 0, .8) * (1 - night) * zoom,
		"amb_night": clampf(gr * 1.4, 0, .5) * night * (0.0 if cold else 1.0),
		"amb_lava": lava * zoom})

# ======================================================================= nave de salida
func _ship_in() -> void:
	ship = world.factory.airship()
	ship.scale = Vector3.ONE * .8
	world.add_child(ship)
	ship_t = 0
	_clear_ghost()
	ui.hud.visible = false

func _ship_update(dt: float) -> void:
	ship_t += dt
	var t := ship_t
	var pos: Vector3
	if t < 6:
		var k := ease(t / 6.0, -2.0)
		pos = Vector3(lerpf(-30, 0, k), lerpf(9, 3.2, k), lerpf(-14, 0, k))
		ship.rotation.y = lerpf(ship.rotation.y, atan2(30, 14), .05)
	elif t < 10:
		pos = Vector3(0, 3.2 + sin((t - 6) * 1.5) * .1, 0)
	else:
		var k := (t - 10) / 6.0
		pos = Vector3(k * k * 30, 3.2 + k * k * 12, k * 18)
	ship.position = pos
	for p in ["prop0", "prop2"]:
		var pn := ship.get_node_or_null(p) as Node3D
		if pn: pn.rotation.z += dt * 14
	t_target = t_target.lerp(Vector3(pos.x * .5, 0, pos.z * .5), dt * .8)
	t_dist = lerpf(t_dist, 30, dt * .3)
	t_pitch = lerpf(t_pitch, deg_to_rad(30), dt * .3)
	if ship_t >= 16:
		ship.queue_free(); ship = null

# ======================================================================= pruebas automáticas
# Uso: godot -- --auto --region=valle --out=/tmp/shots --shots=8 --speed=4
var auto_t0 := 0.0
var auto_next_shot := 0.0
var auto_shot_n := 0
var auto_started := false
var auto_act := 0.0
var auto_done_t := -1.0
var zoo_nodes := []
func _auto_setup() -> void:
	DirAccess.make_dir_recursive_absolute(args.get("out", "/tmp/shots"))

func _shot(tag: String) -> void:
	var cnt := 0
	for id in world.anodes:
		var n: Node3D = world.anodes[id]
		var mi = n.find_children("*", "MeshInstance3D", true, false)
		if cnt < 4: print("ANODE ", n.name, " pos=", n.global_position, " born=", mi[0].get_instance_shader_parameter("born") if mi.size() else -1, " now=", Game.now_s, " sc=", n.scale, " body=", n.get_node("body").transform)
		cnt += 1
	var img := get_viewport().get_texture().get_image()
	if img == null: return
	var path := "%s/%02d_%s.png" % [args.get("out", "/tmp/shots"), auto_shot_n, tag]
	img.save_png(path)
	print("SHOT ", path, " fase=", Game.phase, " stats=", Game.last_stats, " CL=", Game.CL, " anim=", Game.anim.size(), " scanned=", Game.scanned.size())
	auto_shot_n += 1

func _auto_step(dt: float) -> void:
	auto_t0 += dt
	if args.has("menu") and auto_t0 > 2.5 and auto_shot_n == 0:
		_shot("menu")
		if args.has("regions"): ui.open_regions()
	if args.has("menu") and args.has("regions") and auto_t0 > 3.5 and auto_shot_n == 1:
		_shot("regiones"); get_tree().quit(); return
	if args.has("menu") and auto_t0 > 3.5 and not args.has("regions"):
		get_tree().quit(); return
	if args.has("menu"): return
	if args.has("zoo"):
		for zn in zoo_nodes:
			if args.has("anim"): world.factory.animate_animal(zn[0], zn[1], Game.now_s, false, false, 0.0)
		if auto_t0 > 1.0 and not auto_started:
			auto_started = true
			_start("valle")
			var ks := ["deer","reindeer","goat","bear","wolf","fox","rabbit","hare","beaver","frog","lizard","heron","flamingo","duck","seal","turtle","manta","whale","bee","butterfly","parrot"]
			if args.zoo == "fly": ks = ["bee","butterfly","parrot","bee","butterfly","parrot","heron"]
			if args.zoo == "real":
				for k in ks.size():
					var x := 3.0 + (k % 7) * 1.6; var z := 8.0 + (k / 7) * 1.6
					Game.anim.append({"k":ks[k],"x":x,"y":z,"tx":x,"ty":z,"walk":false,"graze":false,"idle":999.0,"ph":0.0,"jump":0.0,"id":k + 1000})
				Game.fauna_changed.emit()
				ks = []
			for k in ks.size():
				var n: Node3D = world.factory.animal(ks[k])
				var x := -5.0 + (k % 7) * 1.6; var z := -2.0 + (k / 7) * 1.6
				n.position = Vector3(x, world.surface_at(x, z) + .02, z)
				n.scale = Vector3.ONE * 2.5
				world.add_child(n)
				if args.zoo == "fly":
					n.position.y += 1.0
					zoo_nodes.append([n, ks[k]])
					if k >= 3: world.factory.set_born(n, Game.now_s)
					for mi in n.find_children("*", "MeshInstance3D", true, false): print("FLY ", ks[k], " ", mi.get_aabb(), " born=", mi.get_instance_shader_parameter("born"))

			t_dist = 22; t_pitch = deg_to_rad(50); t_yaw = 0; t_target = Vector3(0, 0, 0)
			auto_next_shot = auto_t0 + 3
		if auto_started and auto_t0 > auto_next_shot:
			for id in world.anodes:
				var n: Node3D = world.anodes[id]
				var mi = n.find_children("*", "MeshInstance3D", true, false)
				print("ANODE ", n.name, " pos=", n.global_position, " vis=", n.is_visible_in_tree(), " born=", mi[0].get_instance_shader_parameter("born") if mi.size() else -1, " now=", Game.now_s, " sc=", n.scale)
				break
			_shot("zoo_fx" if fx_on else "zoo_nofx")
			if not fx_on: get_tree().quit()
			_set_fx(false); world.env.glow_enabled = false
			auto_next_shot = auto_t0 + 2
		return
	if not auto_started and auto_t0 > 1.0:
		auto_started = true
		_start(args.get("region", "valle"))
		if args.has("lush"): _lush()
		if args.has("nofx"): _set_fx(false); world.env.glow_enabled = false
		if args.has("noglow"): world.env.glow_enabled = false
		if args.has("nossil"): world.env.ssil_enabled = false
		if args.has("nossao"): world.env.ssao_enabled = false
		if args.has("novol"): world.env.volumetric_fog_enabled = false
		if args.has("noreeds"):
			for k in world.veg_variants:
				if k.begins_with("reed"): world.veg_variants[k].visible = false
		if args.has("nowater"): world.water_mm.visible = false
		if args.has("nofauna"): Game.anim.clear(); Game.fauna_changed.emit()

		if args.has("cam"):
			var c: PackedStringArray = args.cam.split(",")
			t_dist = float(c[0]); t_pitch = deg_to_rad(float(c[1])); t_yaw = deg_to_rad(float(c[2]))
			if c.size() > 4: t_target = Vector3(float(c[3]), 0, float(c[4]))
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
	if args.has("rain"): Game.wx.on = true; Game.wx.until = Game.gtime + 100
	if auto_t0 >= auto_next_shot:
		_shot("f%d" % Game.phase)
		auto_next_shot = auto_t0 + float(args.get("every", "6"))
		if auto_shot_n >= int(args.get("shots", "3")): get_tree().quit()
	if Game.won and auto_done_t < 0: auto_done_t = auto_t0
	if auto_done_t > 0 and auto_t0 - auto_done_t > 2.0:
		_shot("fin"); print("WIN"); get_tree().quit()
	if auto_t0 > float(args.get("limit", "600")): print("TIMEOUT"); get_tree().quit()

func _auto_action() -> void:
	var G := Game
	var cands := []
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
				if s.water > 18: continue
			if id == "tur" or id == "geo": sc += 5
			if id == "rec" and G.B[i] == "obs" and G.scanned.size() < 3: continue
			if sc > bs: bs = sc; best = i
		if best >= 0:
			G.apply(id, best % D.C, best / D.C)
			return

func _nan_test() -> void:
	var F = world.factory
	var ks := ["deer","reindeer","goat","bear","wolf","fox","rabbit","hare","beaver","frog","lizard","heron","flamingo","duck","seal","turtle","manta","whale","bee","butterfly","parrot"]
	var nodes := []
	for k in ks: nodes.append([k, F.animal(k)])
	for id in ["tur","geo","dep","asp","pum","sol","nub","fri","viv","col","hid","obs"]: nodes.append([id, F.make(id, 0)])
	for v in world.veg_variants: 
		var n := Node3D.new(); var mi := MeshInstance3D.new(); mi.mesh = world.veg_variants[v].multimesh.mesh; n.add_child(mi); nodes.append([v, n])
	for e in nodes:
		var bad := 0; var tot := 0
		for mi in e[1].find_children("*","MeshInstance3D",true,false):
			var m: Mesh = mi.mesh
			if not (m is ArrayMesh): continue
			for s in m.get_surface_count():
				var a = m.surface_get_arrays(s)
				for v in a[Mesh.ARRAY_NORMAL]:
					tot += 1
					if not v.is_finite() or v.length() < .5: bad += 1
		if bad: print("NAN ", e[0], " bad=", bad, "/", tot)
	print("NANTEST DONE")
	get_tree().quit()

func _lush() -> void:
	var G := Game
	for i in D.C * D.R:
		var t: String = G.T[i]
		if t in ["tox", "ash", "dirt", "ice"]:
			var r := G.rng.randf()
			G.T[i] = "forest" if r < .35 else ("flower" if r < .55 else "grass")
		elif t == "bed": G.T[i] = "water"
	for i in D.C * D.R:
		if G.T[i] in ["grass", "flower"] and G.touches(i % D.C, i / D.C, ["water"]) and G.rng.randf() < .7: G.T[i] = "wet"
		if G.T[i] == "sand" and G.touches(i % D.C, i / D.C, ["sea"]) and G.rng.randf() < .5 and G.region_id in ["valle", "tropico"]: G.T[i] = "mang"
	G.compute_power()
	G.map_rebuilt.emit()
	G.hud()
	G.fauna(true)
	G.fauna_changed.emit()

func _resize() -> void:
	var ws := get_viewport().get_visible_rect().size
	pix = maxi(2, int(round(ws.y / 300.0)))
	svp.size = Vector2i(ceili(ws.x / pix), ceili(ws.y / pix))
	screen.position = Vector2.ZERO
	screen.size = Vector2(svp.size) * pix
