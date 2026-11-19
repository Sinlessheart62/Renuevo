extends Node
## Efectos de sonido, ambientes en bucle y música.

var muted := false
var vol_master := 1.0
var streams := {}
var players: Array[AudioStreamPlayer] = []
var amb := {}
var amb_target := {}
var music: AudioStreamPlayer
var music_on := true
var last := {}
var gi := 0

const NAMES := ["sel","err","place","rec","seed","water","clean","grow0","grow1","grow2","grow3","melt","found","scan","phase","ship","win"]
const AMB := ["amb_wind","amb_rain","amb_sea","amb_birds","amb_night","amb_lava"]

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	for n in NAMES: streams[n] = load("res://audio/%s.wav" % n)
	for k in 10:
		var p := AudioStreamPlayer.new(); add_child(p); players.append(p)
	for n in AMB:
		var s: AudioStreamWAV = load("res://audio/%s.wav" % n)
		_loop(s)
		var p := AudioStreamPlayer.new(); p.stream = s; p.volume_db = -80; add_child(p)
		amb[n] = p; amb_target[n] = 0.0
	var ms: AudioStreamWAV = load("res://audio/music.wav")
	_loop(ms)
	music = AudioStreamPlayer.new(); music.stream = ms; music.volume_db = -14; add_child(music)

func _loop(s: AudioStreamWAV) -> void:
	s.loop_mode = AudioStreamWAV.LOOP_FORWARD
	s.loop_begin = 0
	s.loop_end = int(s.get_length() * s.mix_rate) - 1

func start_ambience() -> void:
	for n in amb:
		if not amb[n].playing: amb[n].play()
	if music_on and not music.playing: music.play()

func play(n: String) -> void:
	if muted: return
	if n == "grow":
		n = "grow%d" % (randi() % 4)
	var now := Time.get_ticks_msec()
	var key := n.substr(0, 4)
	if last.has(key) and now - int(last[key]) < (90 if key == "grow" else 60): return
	last[key] = now
	if not streams.has(n): return
	var p := players[gi]; gi = (gi + 1) % players.size()
	p.stream = streams[n]
	p.volume_db = -6.0 if key == "grow" else 0.0
	p.pitch_scale = randf_range(.94, 1.06) if key in ["grow", "plac", "clea", "seed"] else 1.0
	p.play()

func set_mute(m: bool) -> void:
	muted = m
	AudioServer.set_bus_mute(0, m)

func set_ambience(levels: Dictionary) -> void:
	for k in levels: amb_target[k] = levels[k]

func _process(dt: float) -> void:
	for n in amb:
		var p: AudioStreamPlayer = amb[n]
		var target: float = amb_target[n]
		var cur := db_to_linear(p.volume_db)
		cur = lerpf(cur, target, minf(1, dt * 1.2))
		p.volume_db = linear_to_db(maxf(cur, .0001))
