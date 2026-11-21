extends CanvasLayer
## Interfaz: HUD, herramientas, bitácora, menús y mensajes.

signal tool_selected(id: String)
signal start_region(id: String)
signal continue_game
signal to_menu
signal quit_game
signal fx_toggled(on: bool)

const PAPER := Color("#f2e2c0")
const PAPER2 := Color("#dcc396")
const INK := Color("#3a2416")
const INK2 := Color("#7a5634")
const GREEN := Color("#4f7a26")
const WOOD := Color("#6b4428")
const RED := Color("#c0533a")
const GOLD := Color("#d9a441")

var F500: Font
var F600: Font
var F700: Font
var SERIF: Font
var SERIFB: Font

var root: Control
var hud: Control
var ring: Control
var pct_l: Label
var phase_l: Label
var phase_n: Label
var goals_box: VBoxContainer
var leaves_l: Label
var clim_box: HBoxContainer
var time_l: Label
var toolbar: HBoxContainer
var tool_btns := {}
var info_l: RichTextLabel
var hover_l: Label
var toast_p: PanelContainer
var toast_l: Label
var toast_t := 0.0
var journal: Control
var j_tabs: TabContainer
var menu: Control
var menu_box: VBoxContainer
var regions: Control
var reg_grid: HBoxContainer
var pause: Control
var win: Control
var win_l: Label
var help_l: Label
var thumbs := {}
var ring_p := 0.0
var fx_on := true

func _ready() -> void:
	layer = 5
	# fuentes pixel sin suavizado
	var pix: FontFile = load("res://fonts/PixelifySans.ttf")
	var silk: FontFile = load("res://fonts/Silkscreen.ttf")
	silk.antialiasing = TextServer.FONT_ANTIALIASING_NONE
	silk.hinting = TextServer.HINTING_NONE
	silk.subpixel_positioning = TextServer.SUBPIXEL_POSITIONING_DISABLED
	pix.hinting = TextServer.HINTING_NONE
	var vt: FontFile = load("res://fonts/VT323.ttf")
	vt.hinting = TextServer.HINTING_NONE
	F500 = vt
	var v7 := FontVariation.new(); v7.base_font = vt; v7.variation_embolden = .6; F600 = v7; F700 = v7
	SERIF = vt
	SERIFB = silk
	root = Control.new(); root.set_anchors_preset(Control.PRESET_FULL_RECT); root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.theme = _theme()
	add_child(root)
	_build_hud()
	_build_toast()
	_build_journal()
	_build_menu()
	_build_regions()
	_build_pause()
	_build_win()
	Game.toast.connect(say)
	Game.hud_changed.connect(refresh)
	Game.phase_changed.connect(func(_p): build_toolbar())
	Game.finished.connect(show_win)
	hud.visible = false

# ======================================================================= tema
func _theme() -> Theme:
	var t := Theme.new()
	t.default_font = F500
	t.default_font_size = 24
	t.set_color("font_color", "Label", INK)
	var sb := _box(PAPER, 18, 0)
	t.set_stylebox("panel", "PanelContainer", sb)
	t.set_stylebox("panel", "Panel", sb)
	var bn := _box(Color("#ead2a2"), 14, 3, Color("#8c5a32"))
	var bh := _box(Color("#f6e3ba"), 14, 3, Color("#b07a45"))
	var bp := _box(Color("#cfe2a0"), 14, 3, GREEN)
	var bd := _box(Color("#d9c7a3"), 14, 3, Color("#a88a64"))
	for s in [["normal", bn], ["hover", bh], ["pressed", bp], ["disabled", bd], ["focus", StyleBoxEmpty.new()]]:
		t.set_stylebox(s[0], "Button", s[1])
	t.set_color("font_color", "Button", INK)
	t.set_color("font_hover_color", "Button", INK)
	t.set_color("font_pressed_color", "Button", INK)
	t.set_color("font_disabled_color", "Button", INK2.lightened(.3))
	t.set_font("font", "Button", F600)
	t.set_font_size("font_size", "Button", 24)
	t.set_stylebox("panel", "TabContainer", _box(PAPER, 0, 0))
	t.set_stylebox("tab_selected", "TabContainer", _box(Color("#fffaf0"), 12, 2, GREEN))
	t.set_stylebox("tab_unselected", "TabContainer", _box(PAPER2, 12, 0))
	t.set_stylebox("tab_hovered", "TabContainer", _box(Color("#f8f1e2"), 12, 0))
	t.set_color("font_selected_color", "TabContainer", INK)
	t.set_color("font_unselected_color", "TabContainer", INK2)
	t.set_color("font_hovered_color", "TabContainer", INK)
	t.set_font("font", "TabContainer", F600)
	t.set_color("default_color", "RichTextLabel", INK)
	t.set_font("normal_font", "RichTextLabel", F500)
	t.set_font("bold_font", "RichTextLabel", F700)
	t.set_font_size("normal_font_size", "RichTextLabel", 24)
	t.set_font_size("bold_font_size", "RichTextLabel", 24)
	t.set_stylebox("normal", "RichTextLabel", StyleBoxEmpty.new())
	var sc := _box(Color("#d8cbb0"), 6, 0)
	t.set_stylebox("grabber", "VScrollBar", sc)
	t.set_stylebox("grabber_highlight", "VScrollBar", _box(GREEN, 6, 0))
	t.set_stylebox("scroll", "VScrollBar", _box(PAPER2, 6, 0))
	return t

func _box(c: Color, r: int, bw: int, bc := Color.TRANSPARENT, pad := 12) -> StyleBoxFlat:
	# estilo madera de granja: esquinas rectas y marco grueso
	var s := StyleBoxFlat.new()
	s.bg_color = c
	s.set_corner_radius_all(0)
	if pad > 0:
		if bw == 0 or bc.a == 0:
			bw = 4 if r >= 16 else 3; bc = WOOD
		else:
			bw = maxi(bw, 3)
	s.set_border_width_all(bw); s.border_color = bc
	s.anti_aliasing = false
	s.content_margin_left = pad; s.content_margin_right = pad; s.content_margin_top = pad * .7; s.content_margin_bottom = pad * .7
	s.shadow_color = Color(.1, .06, .03, .45) if r >= 16 else Color(0, 0, 0, 0)
	s.shadow_size = 0
	s.shadow_offset = Vector2(4, 4)
	return s

const FS := 1.35   # la fuente pixel es más pequeña: escalar tamaños
func _lbl(txt: String, size := 18, font: Font = null, col := INK) -> Label:
	var l := Label.new(); l.text = txt
	l.add_theme_font_size_override("font_size", size if font == SERIFB else int(size * FS))
	if font: l.add_theme_font_override("font", font)
	l.add_theme_color_override("font_color", col)
	return l

func _btn(txt: String, cb: Callable, w := 0) -> Button:
	var b := Button.new(); b.text = txt
	b.pressed.connect(func(): Sfx.play("sel"); cb.call())
	if w > 0: b.custom_minimum_size.x = w
	b.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	return b

func _panel(alpha := 1.0) -> PanelContainer:
	var p := PanelContainer.new()
	var sb := _box(Color(PAPER, alpha), 18, 0)
	p.add_theme_stylebox_override("panel", sb)
	return p

# ======================================================================= HUD
func _build_hud() -> void:
	hud = Control.new(); hud.set_anchors_preset(Control.PRESET_FULL_RECT); hud.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(hud)
	# — progreso de fase (arriba izquierda)
	var tl := _panel(.94)
	tl.position = Vector2(18, 16)
	hud.add_child(tl)
	var h := HBoxContainer.new(); h.add_theme_constant_override("separation", 14); tl.add_child(h)
	ring = Control.new(); ring.custom_minimum_size = Vector2(76, 76); ring.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	ring.draw.connect(_draw_ring)
	h.add_child(ring)
	pct_l = _lbl("0%", 20, F700); pct_l.set_anchors_preset(Control.PRESET_FULL_RECT)
	pct_l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER; pct_l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	ring.add_child(pct_l)
	var v := VBoxContainer.new(); v.add_theme_constant_override("separation", 2); h.add_child(v)
	var hh := HBoxContainer.new(); v.add_child(hh)
	phase_l = _lbl("Fase 1", 15, F600, GREEN); hh.add_child(phase_l)
	phase_n = _lbl("Sanar el suelo", 24, SERIFB); v.add_child(phase_n)
	goals_box = VBoxContainer.new(); goals_box.add_theme_constant_override("separation", 3); v.add_child(goals_box)
	# — recursos y clima (arriba derecha)
	var tr := _panel(.94)
	tr.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	tr.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	tr.position = Vector2(-18, 16)
	tr.anchor_left = 1; tr.anchor_right = 1; tr.offset_right = -18; tr.offset_left = -18
	hud.add_child(tr)
	var rv := VBoxContainer.new(); rv.add_theme_constant_override("separation", 8); tr.add_child(rv)
	var r1 := HBoxContainer.new(); r1.add_theme_constant_override("separation", 10); r1.alignment = BoxContainer.ALIGNMENT_END; rv.add_child(r1)
	var leaf := _icon("leaf", 28, GREEN); r1.add_child(leaf)
	leaves_l = _lbl("60", 28, F700); r1.add_child(leaves_l)
	var sp := Control.new(); sp.custom_minimum_size.x = 8; r1.add_child(sp)
	r1.add_child(_small_btn("Bitácora  B", func(): toggle_journal()))
	r1.add_child(_small_btn("Menú  Esc", func(): toggle_pause()))
	clim_box = HBoxContainer.new(); clim_box.add_theme_constant_override("separation", 8); clim_box.alignment = BoxContainer.ALIGNMENT_END
	rv.add_child(clim_box)
	time_l = _lbl("", 15, F500, INK2); time_l.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT; rv.add_child(time_l)
	# — barra de herramientas (abajo)
	var bottom := VBoxContainer.new()
	bottom.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	bottom.anchor_left = .5; bottom.anchor_right = .5; bottom.anchor_top = 1; bottom.anchor_bottom = 1
	bottom.grow_horizontal = Control.GROW_DIRECTION_BOTH; bottom.grow_vertical = Control.GROW_DIRECTION_BEGIN
	bottom.offset_bottom = -14
	bottom.alignment = BoxContainer.ALIGNMENT_END
	bottom.add_theme_constant_override("separation", 8)
	bottom.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hud.add_child(bottom)
	var ip := _panel(.9)
	ip.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	ip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var iv := VBoxContainer.new(); iv.add_theme_constant_override("separation", 0); ip.add_child(iv)
	info_l = RichTextLabel.new(); info_l.bbcode_enabled = true; info_l.fit_content = true; info_l.scroll_active = false
	info_l.custom_minimum_size = Vector2(760, 0); info_l.autowrap_mode = TextServer.AUTOWRAP_OFF
	info_l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	iv.add_child(info_l)
	hover_l = _lbl("", 16, F500, INK2); hover_l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	iv.add_child(hover_l)
	bottom.add_child(ip)
	var tp := _panel(.94)
	tp.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	toolbar = HBoxContainer.new(); toolbar.add_theme_constant_override("separation", 8)
	tp.add_child(toolbar)
	bottom.add_child(tp)
	# — ayuda de controles
	help_l = _lbl("WASD mover · Q/E girar · R/F inclinar · Rueda/Z/X zoom · Clic derecho arrastrar: girar · H ocultar", 14, F500, Color(1, 1, 1, .85))
	help_l.add_theme_color_override("font_shadow_color", Color(0, 0, 0, .6))
	help_l.add_theme_constant_override("shadow_offset_x", 1); help_l.add_theme_constant_override("shadow_offset_y", 1)
	help_l.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	help_l.anchor_top = 1; help_l.anchor_bottom = 1
	help_l.offset_left = 18; help_l.offset_top = -30; help_l.offset_bottom = -10
	help_l.visible = false
	hud.add_child(help_l)

func _small_btn(t: String, cb: Callable) -> Button:
	var b := _btn(t, cb)
	b.add_theme_font_size_override("font_size", 20)
	var sb := _box(Color("#fbf5e8"), 10, 2, Color("#d8cbb0"), 8)
	b.add_theme_stylebox_override("normal", sb)
	return b

func _icon(kind: String, s: int, col: Color) -> Control:
	var c := Control.new(); c.custom_minimum_size = Vector2(s, s)
	c.draw.connect(func():
		var w := float(s)
		match kind:
			"leaf":
				var pts := PackedVector2Array()
				for k in 21:
					var t := float(k) / 20.0
					var a := t * PI
					pts.append(Vector2(w * .5 + cos(a + PI * .75) * w * .0 + (t - .5) * w * .75, w * .5 - sin(a) * w * .32 + (t - .5) * -w * .5))
				for k in 21:
					var t := 1.0 - float(k) / 20.0
					var a := t * PI
					pts.append(Vector2(w * .5 + (t - .5) * w * .75, w * .5 + sin(a) * w * .32 + (t - .5) * -w * .5))
				c.draw_colored_polygon(pts, col)
				c.draw_line(Vector2(w * .12, w * .88), Vector2(w * .82, w * .18), col.darkened(.35), 2.0, true)
			"t":
				c.draw_circle(Vector2(w * .5, w * .74), w * .2, col)
				c.draw_rect(Rect2(w * .4, w * .1, w * .2, w * .6), col)
			"h":
				var pts := PackedVector2Array()
				for k in 25:
					var a := float(k) / 24.0 * TAU
					var r := w * .3
					var p := Vector2(sin(a) * r, -cos(a) * r)
					if cos(a) > .3: p.y -= (cos(a) - .3) * w * .45
					pts.append(Vector2(w * .5, w * .62) + p)
				c.draw_colored_polygon(pts, col)
			"f":
				c.draw_line(Vector2(w * .5, w * .95), Vector2(w * .5, w * .45), col, 2.5, true)
				c.draw_circle(Vector2(w * .32, w * .4), w * .17, col)
				c.draw_circle(Vector2(w * .68, w * .32), w * .17, col)
		)
	return c

func _draw_ring() -> void:
	var c := ring.size / 2
	ring.draw_arc(c, 32, 0, TAU, 64, Color(PAPER2), 8, true)
	if ring_p > 0.001:
		ring.draw_arc(c, 32, -PI / 2, -PI / 2 + TAU * ring_p, 64, GREEN, 8, true)

func refresh() -> void:
	if not hud.visible: return
	var gl: Array = Game.goals()
	ring_p = Game.progress(); ring.queue_redraw()
	pct_l.text = "%d%%" % int(ring_p * 100)
	phase_l.text = "FASE %d  ·  %s" % [Game.phase, Game.REG.n.to_upper()]
	phase_n.text = D.PHN[Game.phase]
	for c in goals_box.get_children(): c.queue_free()
	for o in gl:
		var row := HBoxContainer.new(); row.add_theme_constant_override("separation", 8)
		var ok: bool = o.v >= o.g - 1e-9
		var nl := _lbl(("✓ " if ok else "") + o.n, 15, F600, GREEN if ok else INK)
		nl.custom_minimum_size.x = 150
		row.add_child(nl)
		var bar := ProgressBar.new(); bar.show_percentage = false
		bar.custom_minimum_size = Vector2(120, 10); bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		bar.max_value = 1.0; bar.value = clampf(o.v / o.g, 0, 1)
		bar.add_theme_stylebox_override("background", _box(PAPER2, 5, 0, Color.TRANSPARENT, 0))
		bar.add_theme_stylebox_override("fill", _box(GREEN if ok else GOLD, 5, 0, Color.TRANSPARENT, 0))
		row.add_child(bar)
		var vt := ""
		if o.has("txt"): vt = o.txt
		elif o.g < 1: vt = "%d/%d%%" % [int(o.v * 100), roundi(o.g * 100)]
		else: vt = "%d%%" % int(o.v * 100)
		row.add_child(_lbl(vt, 14, F500, INK2))
		goals_box.add_child(row)
	leaves_l.text = str(Game.leaves)
	for c in clim_box.get_children(): c.queue_free()
	var CL: Dictionary = Game.CL
	var chips := [["t", "%d °C" % roundi(CL.T), CL.T < 0 or CL.T > 28, "Temperatura"], ["h", "%d%%" % roundi(CL.H), CL.H < 40, "Humedad"], ["f", "%d%%" % roundi(CL.F), CL.F < 30, "Fertilidad"]]
	for ch in chips:
		var p := PanelContainer.new()
		var bad: bool = ch[2]
		p.add_theme_stylebox_override("panel", _box(Color("#fbe3da") if bad else Color("#fbf5e8"), 10, 2, RED.lightened(.3) if bad else Color("#e2d6bd"), 7))
		p.tooltip_text = ch[3]
		var hb := HBoxContainer.new(); hb.add_theme_constant_override("separation", 4); p.add_child(hb)
		hb.add_child(_icon(ch[0], 16, RED if bad else INK2))
		hb.add_child(_lbl(ch[1], 16, F600, RED if bad else INK))
		clim_box.add_child(p)
	for id in tool_btns:
		var b: Button = tool_btns[id]
		var t := D.tool(id)
		var lock: bool = Game.ph_of(t) > Game.phase
		var no3: bool = Game.phase == 3 and id in D.NOBUILD3
		b.disabled = lock or no3
		b.modulate = Color(1, 1, 1, .45) if (lock or no3) else Color.WHITE
		b.button_pressed = id == Game.tool_id
		var cl: Label = b.get_node("v/c")
		cl.add_theme_color_override("font_color", RED if Game.leaves < t.c else INK2)
		(b.get_node("v/lock") as Label).visible = lock
	update_info()

func update_info() -> void:
	var t := D.tool(Game.tool_id)
	if t.is_empty():
		info_l.text = ""; return
	var need := ""
	match Game.tool_id:
		"asp": need = Game.need_txt("grass")
		"viv": need = Game.need_txt("forest")
		"col": need = Game.need_txt("flower")
		"hid": need = Game.need_txt("wet")
		"man": need = Game.need_txt("mang")
	var cost := ("  ·  [color=#5f8f3a]%d hojas[/color]" % t.c) if t.c > 0 else ""
	info_l.text = "[center][b]%s[/b]%s  —  %s%s[/center]" % [Game.tname(t), cost, t.d, ("  ·  [color=#7a6b55]clima: %s[/color]" % need) if need != "" else ""]

func set_hover(txt: String, err: String) -> void:
	if txt == "":
		hover_l.text = ""; return
	hover_l.text = txt + (("   ✕ " + err) if err != "" else "   ✓ Se puede construir aquí")
	hover_l.add_theme_color_override("font_color", RED if err != "" else GREEN)

func build_toolbar() -> void:
	for c in toolbar.get_children(): c.queue_free()
	tool_btns.clear()
	var k := 0
	for t in Game.reg_tools():
		k += 1
		var b := Button.new()
		b.toggle_mode = true
		b.custom_minimum_size = Vector2(92, 112)
		b.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		b.tooltip_text = t.d
		var v := VBoxContainer.new(); v.name = "v"; v.set_anchors_preset(Control.PRESET_FULL_RECT)
		v.mouse_filter = Control.MOUSE_FILTER_IGNORE; v.add_theme_constant_override("separation", 0)
		v.offset_top = 4; v.offset_bottom = -4
		b.add_child(v)
		var key := _lbl(str(k % 10) if k <= 10 else "", 12, F600, INK2.lightened(.2))
		key.position = Vector2(8, 4); key.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var tr := TextureRect.new(); tr.custom_minimum_size = Vector2(84, 64)
		tr.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE; tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		tr.mouse_filter = Control.MOUSE_FILTER_IGNORE
		if thumbs.has(t.id): tr.texture = thumbs[t.id]
		v.add_child(tr)
		var nl := _lbl(Game.tname(t), 14, F600); nl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		nl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		v.add_child(nl)
		var cl := _lbl(("%d" % t.c) if t.c > 0 else "+50%", 13, F500, INK2); cl.name = "c"
		cl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER; cl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		v.add_child(cl)
		var lk := _lbl("Fase %d" % Game.ph_of(t), 12, F600, INK2); lk.name = "lock"
		lk.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER; lk.visible = false; lk.mouse_filter = Control.MOUSE_FILTER_IGNORE
		v.add_child(lk)
		b.add_child(key)
		var id: String = t.id
		b.pressed.connect(func(): select_tool(id))
		toolbar.add_child(b)
		tool_btns[id] = b
	refresh()

func select_tool(id: String) -> void:
	var t := D.tool(id)
	if t.is_empty(): return
	if Game.ph_of(t) > Game.phase:
		say("Se desbloquea en la fase %d" % Game.ph_of(t)); Sfx.play("err"); refresh(); return
	Game.tool_id = id
	Sfx.play("sel")
	tool_selected.emit(id)
	refresh()

func select_index(k: int) -> void:
	var list := Game.reg_tools()
	if k >= 0 and k < list.size(): select_tool(list[k].id)

func set_time(day_n: int, night: float, rain: float, cold: bool) -> void:
	var w := "Noche" if night > .6 else ("Atardecer" if night > .25 else "Día")
	if rain > .3: w += (" · nieva" if cold else " · llueve")
	time_l.text = "Día %d · %s" % [day_n, w]

# ======================================================================= mensajes
func _build_toast() -> void:
	toast_p = _panel(.96)
	toast_p.set_anchors_preset(Control.PRESET_CENTER_TOP)
	toast_p.anchor_left = .5; toast_p.anchor_right = .5
	toast_p.grow_horizontal = Control.GROW_DIRECTION_BOTH
	toast_p.offset_top = 132
	toast_p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	toast_l = _lbl("", 19, F600); toast_l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	toast_p.add_child(toast_l)
	toast_p.modulate.a = 0
	root.add_child(toast_p)

func say(m: String) -> void:
	toast_l.text = m
	toast_t = 3.2

func _process(dt: float) -> void:
	toast_t -= dt
	toast_p.modulate.a = clampf(toast_t * 3, 0, 1)
	if toast_p.modulate.a > 0:
		toast_p.offset_left = -toast_p.size.x / 2; toast_p.offset_right = toast_p.size.x / 2

# ======================================================================= bitácora
func _build_journal() -> void:
	journal = _overlay()
	var p := _panel(); p.custom_minimum_size = Vector2(980, 640)
	_center(journal, p)
	var v := VBoxContainer.new(); v.add_theme_constant_override("separation", 10); p.add_child(v)
	var top := HBoxContainer.new(); v.add_child(top)
	var tt := _lbl("Bitácora de restauración", 32, SERIFB); tt.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(tt)
	top.add_child(_btn("Cerrar  ✕", func(): toggle_journal()))
	j_tabs = TabContainer.new(); j_tabs.size_flags_vertical = Control.SIZE_EXPAND_FILL
	v.add_child(j_tabs)
	for name in ["Objetivos", "Ecosistemas", "Fauna", "Edificios"]:
		var sc := ScrollContainer.new(); sc.name = name
		sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
		var rt := RichTextLabel.new(); rt.name = "t"; rt.bbcode_enabled = true; rt.fit_content = true
		rt.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		rt.add_theme_constant_override("line_separation", 4)
		sc.add_child(rt)
		j_tabs.add_child(sc)

func toggle_journal() -> void:
	if journal.visible:
		journal.visible = false; return
	_fill_journal()
	journal.visible = true

func _fill_journal() -> void:
	var s: Dictionary = Game.stats()
	var t := ""
	t += "[font_size=32][b]%s[/b][/font_size]\n[color=#7a6b55]%s[/color]\n\n" % [Game.REG.n, Game.REG.d]
	for ph in [1, 2, 3]:
		var cur: bool = ph == Game.phase
		var done: bool = ph < Game.phase
		t += "[b]%s Fase %d · %s[/b]\n" % ["✓" if done else ("▶" if cur else "○"), ph, D.PHN[ph]]
		if ph <= Game.phase:
			for o in Game.goals_for(ph, s):
				var ok: bool = done or o.v >= o.g - 1e-9
				t += "    %s %s — %s\n" % ["[color=#5f8f3a]✓[/color]" if ok else "·", o.long, ("listo" if ok else "%d%%" % int(minf(1, o.v / o.g) * 100))]
		else:
			t += "    [color=#7a6b55]Se revela al completar la fase anterior.[/color]\n"
		t += "\n"
	t += "[b]Clima actual[/b]\n    Temperatura %d °C · Humedad %d%% · Fertilidad %d%%\n" % [roundi(Game.CL.T), roundi(Game.CL.H), roundi(Game.CL.F)]
	t += "    [color=#7a6b55]Los espejos solares calientan, los enfriadores enfrían y las torres de nubes humedecen (todos necesitan energía). El agua y el verde suben la humedad; el verde y la limpieza suben la fertilidad.[/color]\n"
	_set_tab("Objetivos", t)
	t = "[color=#7a6b55]Cada ecosistema necesita un clima concreto. Los que ya viste aparecen con su descripción.[/color]\n\n"
	for ty in D.TY:
		var k: bool = Game.known.has(ty)
		if k:
			var need: String = Game.need_txt(ty)
			var bad: String = Game.req(ty)
			t += "[b]%s[/b]%s\n    %s%s\n" % [D.TNAME[ty], "  ·  [color=#c0533a]%s[/color]" % bad if bad != "" else "", D.TDESC[ty], ("\n    [color=#5f8f3a]Clima: %s[/color]" % need) if need != "" else ""]
		else:
			t += "[color=#b0a48c][b]???[/b]  — aún no descubierto[/color]\n"
	_set_tab("Ecosistemas", t)
	t = "[color=#7a6b55]Especies de esta región. En la fase 3 regístralas con un observatorio (radio 3).[/color]\n\n"
	for sp in Game.REG.sp:
		var spec: Dictionary = D.SPEC[sp]
		var sn: bool = Game.seen.has(sp); var sc: bool = Game.scanned.has(sp)
		var n := 0
		for a in Game.anim:
			if a.k == sp: n += 1
		if sn:
			t += "[b]%s[/b]  %s\n    %s\n    [color=#7a6b55]%s · en la parcela: %d[/color]\n" % [spec.n, "[color=#5f8f3a]● registrada[/color]" if sc else "[color=#d9a441]○ sin registrar[/color]", spec.d, spec.req, n]
		else:
			t += "[color=#b0a48c][b]???[/b][/color]\n    [color=#7a6b55]Pista: %s[/color]\n" % spec.req
	_set_tab("Fauna", t)
	t = ""
	for tl in Game.reg_tools():
		var ph: int = Game.ph_of(tl)
		t += "[b]%s[/b]  [color=#5f8f3a]%s[/color]  [color=#7a6b55]· fase %d%s[/color]\n    %s\n" % [Game.tname(tl), ("%d hojas" % tl.c) if tl.c else "devuelve 50%", ph, "  · necesita energía" if tl.id in D.NEEDPOW else "", tl.d]
	_set_tab("Edificios", t)

func _set_tab(name: String, txt: String) -> void:
	var rt: RichTextLabel = j_tabs.get_node(name + "/t")
	rt.text = txt

# ======================================================================= menús
func _overlay(dim := .45) -> Control:
	var o := ColorRect.new(); o.color = Color(.08, .07, .05, dim)
	o.set_anchors_preset(Control.PRESET_FULL_RECT)
	o.visible = false
	root.add_child(o)
	return o

func _center(parent: Control, child: Control) -> void:
	var cc := CenterContainer.new(); cc.set_anchors_preset(Control.PRESET_FULL_RECT)
	parent.add_child(cc); cc.add_child(child)

func _build_menu() -> void:
	menu = Control.new(); menu.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.add_child(menu)
	var grad := TextureRect.new(); grad.set_anchors_preset(Control.PRESET_FULL_RECT)
	var gt := GradientTexture2D.new(); var g := Gradient.new()
	g.set_color(0, Color(.05, .04, .03, .7)); g.set_color(1, Color(.05, .04, .03, 0))
	gt.gradient = g; gt.fill_from = Vector2(0, 0); gt.fill_to = Vector2(.7, 0)
	grad.texture = gt; grad.mouse_filter = Control.MOUSE_FILTER_IGNORE
	menu.add_child(grad)
	menu_box = VBoxContainer.new()
	menu_box.position = Vector2(110, 0)
	menu_box.anchor_top = .5; menu_box.anchor_bottom = .5
	menu_box.offset_top = -230
	menu_box.add_theme_constant_override("separation", 12)
	menu.add_child(menu_box)
	var title := _lbl("RENUEVO", 88, SERIFB, Color("#fff3dc"))
	title.add_theme_color_override("font_shadow_color", Color(0, 0, 0, .45))
	title.add_theme_constant_override("shadow_offset_y", 4); title.add_theme_constant_override("shadow_outline_size", 8)
	menu_box.add_child(title)
	var sub := _lbl("Edición pixel  ·  Restaura la tierra y vete sin dejar rastro.", 22, SERIF, Color("#f0e6d0"))
	sub.add_theme_color_override("font_shadow_color", Color(0, 0, 0, .5)); sub.add_theme_constant_override("shadow_offset_y", 2)
	menu_box.add_child(sub)
	var gap := Control.new(); gap.custom_minimum_size.y = 26; menu_box.add_child(gap)

func show_menu(has_save: bool, save_name: String) -> void:
	hud.visible = false; regions.visible = false; pause.visible = false; win.visible = false; journal.visible = false
	for c in menu_box.get_children().slice(3): c.queue_free()
	if has_save:
		var b := _btn("Continuar  ·  " + save_name, func(): continue_game.emit(), 360)
		b.add_theme_font_size_override("font_size", 30); menu_box.add_child(b)
	var nb := _btn("Nueva partida", func(): open_regions(), 360); nb.add_theme_font_size_override("font_size", 30)
	menu_box.add_child(nb)
	var cb := _btn("Cómo se juega", func(): _how_to(), 360); menu_box.add_child(cb)
	var fb := _btn("Pantalla completa  ·  F11", func(): _toggle_fs(), 360); menu_box.add_child(fb)
	var qb := _btn("Salir", func(): quit_game.emit(), 360); menu_box.add_child(qb)
	menu.visible = true

func _toggle_fs() -> void:
	var m := DisplayServer.window_get_mode()
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_MAXIMIZED if m == DisplayServer.WINDOW_MODE_FULLSCREEN else DisplayServer.WINDOW_MODE_FULLSCREEN)

var howto: Control
func _how_to() -> void:
	if howto == null:
		howto = _overlay(.55)
		var p := _panel(); p.custom_minimum_size = Vector2(820, 0)
		_center(howto, p)
		var v := VBoxContainer.new(); v.add_theme_constant_override("separation", 10); p.add_child(v)
		v.add_child(_lbl("Cómo se juega", 32, SERIFB))
		var rt := RichTextLabel.new(); rt.bbcode_enabled = true; rt.fit_content = true; rt.custom_minimum_size.x = 780
		rt.text = "[b]1. Sanar el suelo.[/b] Pon [b]turbinas[/b] sobre roca para tener energía. Los [b]depuradores[/b] limpian la tierra tóxica y los [b]aspersores[/b] la convierten en pasto. Canales y bombas traen agua.\n\n[b]2. Devolver la vida.[/b] Crea bosques (viveros), flores (colmenas), humedales (hidropónicos) y manglares. Cada uno pide un clima: ajústalo con espejos solares, enfriadores y torres de nubes.\n\n[b]3. Registrar y partir.[/b] Construye observatorios para registrar 3 especies y recicla todos los edificios. Una nave te recoge: no queda rastro.\n\n[b]Controles[/b]\n· Clic izquierdo: construir · arrastrar: mover el mapa\n· Clic derecho o rueda presionada + arrastrar: girar e inclinar\n· WASD / flechas: mover · Q/E: girar · R/F: inclinar · Rueda, Z/X: zoom\n· 1–9, 0: herramientas · B: bitácora · M: sonido · G: efectos visuales · H: ocultar interfaz · F11: pantalla completa · Esc: menú"
		v.add_child(rt)
		v.add_child(_btn("Entendido", func(): howto.visible = false))
	howto.visible = true

func _build_regions() -> void:
	regions = _overlay(.5)
	var p := _panel(); p.custom_minimum_size = Vector2(1180, 0)
	_center(regions, p)
	var v := VBoxContainer.new(); v.add_theme_constant_override("separation", 14); p.add_child(v)
	var top := HBoxContainer.new(); v.add_child(top)
	var tt := _lbl("Elige una región", 32, SERIFB); tt.size_flags_horizontal = Control.SIZE_EXPAND_FILL; top.add_child(tt)
	top.add_child(_btn("Volver", func(): regions.visible = false; menu.visible = true))
	v.add_child(_lbl("Cada región se desbloquea al restaurar la anterior.", 17, F500, INK2))
	reg_grid = HBoxContainer.new(); reg_grid.add_theme_constant_override("separation", 14); v.add_child(reg_grid)

func open_regions() -> void:
	menu.visible = false; win.visible = false
	for c in reg_grid.get_children(): c.queue_free()
	for id in D.RORDER:
		var r: Dictionary = D.REGIONS[id]
		var ok: bool = Game.unlocked(id)
		var card := PanelContainer.new()
		card.custom_minimum_size = Vector2(275, 330)
		card.add_theme_stylebox_override("panel", _box(Color("#fffaf0") if ok else PAPER2, 16, 2, Color(r.col, .8) if ok else Color("#d8cbb0"), 14))
		var cv := VBoxContainer.new(); cv.add_theme_constant_override("separation", 8); card.add_child(cv)
		var sw := ColorRect.new(); sw.custom_minimum_size = Vector2(0, 70); sw.color = r.col if ok else Color("#cfc5b0")
		cv.add_child(sw)
		cv.add_child(_lbl(r.n, 16, SERIFB, INK if ok else INK2))
		var d := Label.new(); d.text = r.d; d.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		d.add_theme_font_size_override("font_size", 15); d.add_theme_color_override("font_color", INK2)
		d.custom_minimum_size = Vector2(240, 110)
		cv.add_child(d)
		var st := "Clima inicial: %d °C · %d%% humedad" % [r.t0, r.h0]
		cv.add_child(_lbl(st, 13, F500, INK2))
		var done: bool = Game.prog.done.has(id)
		if done: cv.add_child(_lbl("✓ Restaurada en %d min" % int(Game.prog.done[id]), 15, F600, GREEN))
		var sp := Control.new(); sp.size_flags_vertical = Control.SIZE_EXPAND_FILL; cv.add_child(sp)
		if ok:
			var rid: String = id
			cv.add_child(_btn("Jugar" if not done else "Jugar de nuevo", func(): start_region.emit(rid)))
		else:
			cv.add_child(_lbl("Bloqueada: restaura la anterior", 15, F600, INK2))
		reg_grid.add_child(card)
	regions.visible = true

func _build_pause() -> void:
	pause = _overlay(.5)
	var p := _panel(); p.custom_minimum_size = Vector2(420, 0)
	_center(pause, p)
	var v := VBoxContainer.new(); v.add_theme_constant_override("separation", 10); p.add_child(v)
	v.add_child(_lbl("Pausa", 32, SERIFB))
	v.add_child(_btn("Continuar", func(): toggle_pause()))
	v.add_child(_btn("Bitácora", func(): pause.visible = false; toggle_journal()))
	var fxb := _btn("Efectos visuales: activados", func(): pass)
	fxb.pressed.connect(func():
		fx_on = not fx_on
		fxb.text = "Efectos visuales: " + ("activados" if fx_on else "básicos")
		fx_toggled.emit(fx_on))
	fxb.name = "fxb"
	v.add_child(fxb)
	var mb := _btn("Música: activada", func(): pass)
	mb.pressed.connect(func():
		Sfx.music_on = not Sfx.music_on
		if Sfx.music_on: Sfx.music.play()
		else: Sfx.music.stop()
		mb.text = "Música: " + ("activada" if Sfx.music_on else "apagada"))
	v.add_child(mb)
	var sb := _btn("Sonido: activado", func(): pass)
	sb.pressed.connect(func():
		Sfx.set_mute(not Sfx.muted)
		sb.text = "Sonido: " + ("apagado" if Sfx.muted else "activado"))
	sb.name = "sb"
	v.add_child(sb)
	v.add_child(_btn("Guardar y volver al menú", func(): to_menu.emit()))
	v.add_child(_btn("Salir del juego", func(): quit_game.emit()))

func toggle_pause() -> void:
	if journal.visible:
		journal.visible = false; return
	pause.visible = not pause.visible
	(pause.find_child("sb", true, false) as Button).text = "Sonido: " + ("apagado" if Sfx.muted else "activado")

func _build_win() -> void:
	win = _overlay(.35)
	var p := _panel(); p.custom_minimum_size = Vector2(640, 0)
	_center(win, p)
	var v := VBoxContainer.new(); v.add_theme_constant_override("separation", 14); p.add_child(v)
	v.add_child(_lbl("Tierra restaurada", 40, SERIFB, GREEN.darkened(.1)))
	win_l = Label.new(); win_l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART; win_l.custom_minimum_size.x = 600
	win_l.add_theme_font_size_override("font_size", 19)
	v.add_child(win_l)
	var h := HBoxContainer.new(); h.add_theme_constant_override("separation", 10); v.add_child(h)
	h.add_child(_btn("Elegir otra región", func(): open_regions()))
	h.add_child(_btn("Seguir mirando", func(): win.visible = false))

func show_win(txt: String) -> void:
	win_l.text = txt
	hud.visible = false
	win.visible = true

func any_modal() -> bool:
	return journal.visible or pause.visible or regions.visible or menu.visible or win.visible or (howto != null and howto.visible)

# ======================================================================= miniaturas (sprites)
func make_thumbs_2d(board: Node) -> void:
	for t in D.TOOLS:
		var name: String = "b_" + t.id
		if t.id == "man": name = "mang0"
		elif t.id == "rec": name = "drone"
		elif t.id == "can": name = ""
		var at := AtlasTexture.new()
		if name == "":
			at.atlas = board.atlas
			at.region = Rect2(0, board.kinds.find("water") * 16, 16, 16)
		else:
			var info: Dictionary = board.idx.sprites[name]
			at.atlas = board.tex[name]
			at.region = Rect2(0, 0, info.w, info.h)
		thumbs[t.id] = at
