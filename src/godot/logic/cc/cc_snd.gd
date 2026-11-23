extends Node
# CÂU CÁ BỜ KÊNH: âm thanh (01_audio.js). Web tổng hợp bằng WebAudio: tiếng tõm, nước văng, vút cần, tách ống cước,
# dây kêu theo độ căng, đàn tranh Karplus-Strong (có nhấn), nền nước vỗ / mưa / dế / chim / ếch, câu đờn ngắn.
# Ở đây tổng hợp đúng công thức đó ra AudioStreamWAV trong luồng phụ lúc mở game (không khựng), rồi phát lại.

const RATE := 22050
const PENTA := [293.66, 329.63, 392.0, 440.0, 493.88, 587.33, 659.25, 783.99, 880.0]
const PLOP_S := [.4, .6, .8, 1.0, 1.2, 1.4]
const SPLASH_S := [.6, .8, 1.1, 1.3]

var game
var _bank := {}
var _pl: Array = []
var _pi := 0
var _th: Thread
var _ok := false
var _on := false
var _amb := {}
var _amb_t := 0.0
var _mus_t := 2.0
var _creak_v := 0.0

func _init(gm) -> void:
	game = gm

func _ready() -> void:
	for k in 16:
		var p := AudioStreamPlayer.new()
		add_child(p)
		_pl.append(p)
	for nm in ["water", "rain", "crick", "creak"]:
		var p := AudioStreamPlayer.new()
		p.volume_db = -80
		add_child(p)
		_amb[nm] = p
	_th = Thread.new()
	_th.start(_build)

func _exit_tree() -> void:
	if _th != null and _th.is_started():
		_th.wait_to_finish()

# lần chạm đầu: bật nền (như audioInit của web)
func init() -> void:
	if _on or not _ok:
		return
	_on = true
	for nm in ["water", "rain", "crick", "creak"]:
		var p: AudioStreamPlayer = _amb[nm]
		p.stream = _bank.get("amb_" + nm)
		if p.stream != null:
			p.play()
	_amb.water.volume_db = _db(.22 * .5)
	_master()

func _sound_on() -> bool:
	return int(game.S.sound) == 1

func _master() -> void:
	if not _on:
		return
	if not _sound_on():
		for p in _amb.values():
			p.volume_db = -80
	else:
		_amb.water.volume_db = _db(.22 * .5 * .9)

static func _db(v: float) -> float:
	return linear_to_db(maxf(0.00001, v))

# ------------------------------------------------------------ tổng hợp
class Buf:
	var d: PackedFloat32Array
	func _init(sec: float) -> void:
		d = PackedFloat32Array()
		d.resize(int(sec * 22050.0) + 1)

# đường bao như env() của web: lên mũ trong a giây tới peak, xuống mũ trong dec giây
static func _env(t: float, a: float, peak: float, dec: float) -> float:
	if t < 0:
		return 0.0
	if t < a:
		return 0.0001 * pow(peak / 0.0001, t / a)
	var u := (t - a) / dec
	if u > 1:
		return 0.0
	return peak * pow(0.0001 / peak, u)

static func _coef(type: String, f: float, q: float) -> Array:
	f = clampf(f, 10, RATE * 0.49)
	var w0 := TAU * f / RATE
	var cw := cos(w0)
	var sw := sin(w0)
	var b0: float
	var b1: float
	var b2: float
	var al: float
	if type == "bandpass":
		al = sw / (2.0 * maxf(0.0001, q))
		b0 = al
		b1 = 0.0
		b2 = -al
	else:
		var ql := pow(10.0, q / 20.0) if q > 0 else 0.7071
		al = sw / (2.0 * ql)
		if type == "highpass":
			b0 = (1 + cw) / 2
			b1 = -(1 + cw)
			b2 = (1 + cw) / 2
		else:
			b0 = (1 - cw) / 2
			b1 = 1 - cw
			b2 = (1 - cw) / 2
	var a0 := 1 + al
	return [b0 / a0, b1 / a0, b2 / a0, (-2 * cw) / a0, (1 - al) / a0]

# tiếng ồn qua lọc, tần số lọc trượt mũ f0 -> f1 trong ft giây; đường bao (a, peak, dec)
static func nz(B: Buf, t: float, type: String, f0: float, f1: float, ft: float, q: float, a: float, peak: float, dec: float) -> void:
	var n0 := int(t * RATE)
	var n := int((a + dec + 0.02) * RATE)
	var x1 := 0.0
	var x2 := 0.0
	var y1 := 0.0
	var y2 := 0.0
	var c := []
	for k in n:
		var i := n0 + k
		if i >= B.d.size():
			break
		var tt := float(k) / RATE
		if k % 32 == 0:
			c = _coef(type, f0 * pow(f1 / f0, minf(1.0, tt / maxf(.001, ft))), q)
		var x := randf() * 2 - 1
		var y: float = c[0] * x + c[1] * x1 + c[2] * x2 - c[3] * y1 - c[4] * y2
		x2 = x1
		x1 = x
		y2 = y1
		y1 = y
		B.d[i] += y * _env(tt, a, peak, dec)

static func osc(B: Buf, t: float, type: String, f0: float, f1: float, ft: float, a: float, peak: float, dec: float) -> void:
	var n0 := int(t * RATE)
	var n := int((a + dec + 0.02) * RATE)
	var ph := 0.0
	for k in n:
		var i := n0 + k
		if i >= B.d.size():
			break
		var tt := float(k) / RATE
		var f := f0 * pow(f1 / f0, minf(1.0, tt / maxf(.001, ft)))
		ph += f / RATE
		var x := ph - floorf(ph)
		var w := sin(TAU * x)
		if type == "square":
			w = 1.0 if x < .5 else -1.0
		B.d[i] += w * _env(tt, a, peak, dec)

# dây đàn tranh (Karplus-Strong của web: trung bình 2 mẫu * 0.4985), nhấn slide nửa cung từ 0.12 s tới 0.38 s
static func pluck_into(B: Buf, t: float, freq: float, vol: float, slide := 0.0) -> void:
	var p := maxi(2, int(round(RATE / freq)))
	var buf := PackedFloat32Array()
	buf.resize(p)
	for i in p:
		buf[i] = (randf() * 2 - 1) * (1.0 if i < p * .5 else .3)
	var n := int(RATE * 2.2)
	var src := PackedFloat32Array()
	src.resize(n)
	var idx := 0
	for i in n:
		var a := buf[idx]
		var nb := buf[(idx + 1) % p]
		src[i] = a
		buf[idx] = (a + nb) * 0.4985
		idx = (idx + 1) % p
	# lọc thấp 3800 Hz
	var c := _coef("lowpass", 3800, 0)
	var x1 := 0.0
	var x2 := 0.0
	var y1 := 0.0
	var y2 := 0.0
	var pos := 0.0
	var r1 := pow(2.0, slide / 12.0)
	var n0 := int(t * RATE)
	var k := 0
	while pos < n - 1:
		var i := n0 + k
		if i >= B.d.size():
			break
		var ip := int(pos)
		var fr := pos - ip
		var x: float = src[ip] * (1 - fr) + src[ip + 1] * fr
		var y: float = c[0] * x + c[1] * x1 + c[2] * x2 - c[3] * y1 - c[4] * y2
		x2 = x1
		x1 = x
		y2 = y1
		y1 = y
		B.d[i] += y * vol
		var tt := float(k) / RATE
		var rate := 1.0
		if slide != 0.0 and tt > .12:
			rate = lerpf(1.0, r1, clampf((tt - .12) / .26, 0, 1))
		pos += rate
		k += 1

static func _wav(B: Buf, gain := 1.0, loop := false) -> AudioStreamWAV:
	var pcm := PackedByteArray()
	pcm.resize(B.d.size() * 2)
	for i in B.d.size():
		pcm.encode_s16(i * 2, int(clampf(B.d[i] * gain, -1, 1) * 32000))
	var s := AudioStreamWAV.new()
	s.format = AudioStreamWAV.FORMAT_16_BITS
	s.mix_rate = RATE
	s.stereo = false
	s.data = pcm
	if loop:
		s.loop_mode = AudioStreamWAV.LOOP_FORWARD
		s.loop_begin = 0
		s.loop_end = B.d.size() - 1
	return s

static func pkey(freq: float, slide: float) -> String:
	return "p%d_%d" % [int(round(freq * 10)), int(slide)]

func _build() -> void:
	var out := {}
	# tõm: sin trượt 900/√s -> 160/√s + tiếng ồn dải 1800
	for s in PLOP_S:
		var B := Buf.new(.3)
		osc(B, 0, "sine", 900 / sqrt(s), 160 / sqrt(s), .09, .004, .35, .12)
		nz(B, 0, "bandpass", 1800, 1800, 1, 1.2, .003, .18 * s, .16)
		out["plop%s" % s] = _wav(B)
	for s in SPLASH_S:
		var B := Buf.new(.5 * s + .6)
		nz(B, 0, "lowpass", 5000, 700, .5 * s, 0, .006, .5 * minf(1.4, s), .45 * s)
		out["splash%s" % s] = _wav(B)
	var W := Buf.new(.5)
	nz(W, 0, "bandpass", 400, 2600, .25, 2, .08, .25, .25)
	out.whoosh = _wav(W)
	var T := Buf.new(.06)
	nz(T, 0, "highpass", 3000, 3000, 1, 0, .001, 1.0, .03)
	out.tick = _wav(T)
	var N := Buf.new(.12)
	nz(N, 0, "highpass", 20, 20, 1, 0, .001, .3, .08)
	out.snapnz = _wav(N)
	# đàn tranh: các nốt hay dùng
	var notes := []
	for f in PENTA:
		notes.append([f, 0.0])
		notes.append([f, 2.0])
		notes.append([f / 2, 0.0])
		notes.append([f / 2, 1.0])
		notes.append([f / 2, 2.0])
		notes.append([f / 2, -1.0])
	for i in 3:
		notes.append([PENTA[6 + i] * 2, 0.0])
	notes.append_array([[1200.0, -12.0], [220.0, -2.0], [207.0, 0.0]])
	for nt in notes:
		var k := pkey(nt[0], nt[1])
		if out.has(k):
			continue
		var B := Buf.new(2.2)
		pluck_into(B, 0, nt[0], 1.0, nt[1])
		out[k] = _wav(B)
	# chim hót, ếch kêu: vài kiểu sẵn
	for v in 4:
		var B := Buf.new(1.0)
		var n := 2 + randi() % 4
		var base := randf_range(2400, 3600)
		var t := 0.0
		for i in n:
			osc(B, t, "sine", base, base * randf_range(1.2, 1.6), .05, .005, .035, .07)
			t += randf_range(.09, .16)
		out["bird%d" % v] = _wav(B)
	for v in 4:
		var B := Buf.new(.8)
		var n := 2 + randi() % 3
		var f0 := randf_range(180, 300)
		var tmp := Buf.new(.8)
		for i in n:
			osc(tmp, i * .16, "square", f0, f0, 1, .01, .05, .1)
		var c := _coef("bandpass", f0 * 3, 3)
		var x1 := 0.0
		var x2 := 0.0
		var y1 := 0.0
		var y2 := 0.0
		for i in tmp.d.size():
			var x := tmp.d[i]
			var y: float = c[0] * x + c[1] * x1 + c[2] * x2 - c[3] * y1 - c[4] * y2
			x2 = x1
			x1 = x
			y2 = y1
			y1 = y
			B.d[i] = y * 3
		out["frog%d" % v] = _wav(B)
	# nền: nước vỗ (ồn nâu qua lọc thấp 500 ± 260 lắc 0.17 Hz), mưa (ồn trắng lọc cao 900), dế (4400 Hz điều biên 28 Hz)
	var per := 1.0 / .17
	var Wa := Buf.new(per * 2)
	var last := 0.0
	var x1 := 0.0
	var x2 := 0.0
	var y1 := 0.0
	var y2 := 0.0
	var cc := []
	for i in Wa.d.size():
		last = (last + 0.02 * (randf() * 2 - 1)) / 1.02
		var x := last * 3.5
		if i % 64 == 0:
			cc = _coef("lowpass", 500 + 260 * sin(TAU * .17 * i / RATE), 0)
		var y: float = cc[0] * x + cc[1] * x1 + cc[2] * x2 - cc[3] * y1 - cc[4] * y2
		x2 = x1
		x1 = x
		y2 = y1
		y1 = y
		Wa.d[i] = y
	_xfade(Wa)
	out.amb_water = _wav(Wa, 1.0, true)
	var R2 := Buf.new(2.0)
	x1 = 0.0
	x2 = 0.0
	y1 = 0.0
	y2 = 0.0
	var hc := _coef("highpass", 900, 0)
	for i in R2.d.size():
		var x := randf() * 2 - 1
		var y: float = hc[0] * x + hc[1] * x1 + hc[2] * x2 - hc[3] * y1 - hc[4] * y2
		x2 = x1
		x1 = x
		y2 = y1
		y1 = y
		R2.d[i] = y
	_xfade(R2)
	out.amb_rain = _wav(R2, 1.0, true)
	var C := Buf.new(1.0)
	for i in C.d.size() - 1:
		var t := float(i) / RATE
		C.d[i] = sin(TAU * 4400 * t) * (.5 * sin(TAU * 28 * t))
	out.amb_crick = _wav(C, 1.0, true)
	# dây kêu: răng cưa 70 Hz lắc 13 Hz ±25 qua lọc dải 900 Q6
	var K := Buf.new(1.0)
	var ph := 0.0
	var bc := _coef("bandpass", 1100, 6)
	x1 = 0.0
	x2 = 0.0
	y1 = 0.0
	y2 = 0.0
	for i in K.d.size() - 1:
		var t := float(i) / RATE
		ph += (70 + 25 * sin(TAU * 13 * t)) / RATE
		var x := 2.0 * (ph - floorf(ph)) - 1.0
		var y: float = bc[0] * x + bc[1] * x1 + bc[2] * x2 - bc[3] * y1 - bc[4] * y2
		x2 = x1
		x1 = x
		y2 = y1
		y1 = y
		K.d[i] = y * 2.5
	_xfade(K)
	out.amb_creak = _wav(K, 1.0, true)
	call_deferred("_got", out)

static func _xfade(B: Buf) -> void:
	var n := B.d.size()
	var m := mini(int(RATE * .05), n / 4)
	for i in m:
		var a := float(i) / m
		B.d[i] = B.d[i] * a + B.d[n - m + i] * (1 - a)
	B.d.resize(n - m)

func _got(out: Dictionary) -> void:
	_bank = out
	_ok = true

# ------------------------------------------------------------ phát
func _play(key: String, vol: float, bus_mus := false) -> void:
	if not _on or not _sound_on():
		return
	if bus_mus and int(game.S.music) != 1:
		return
	var s = _bank.get(key)
	if s == null:
		return
	var p: AudioStreamPlayer = _pl[_pi]
	_pi = (_pi + 1) % _pl.size()
	p.stream = s
	p.volume_db = _db(vol * .9)
	p.play()

static func _near(arr: Array, v: float) -> float:
	var best: float = arr[0]
	for a in arr:
		if absf(a - v) < absf(best - v):
			best = a
	return best

func plop(sz := 1.0, far := 0.0) -> void:
	_play("plop%s" % _near(PLOP_S, sz), .8 * (1 - far * .6))

func splash(big := 1.0) -> void:
	_play("splash%s" % _near(SPLASH_S, big), .8)
	for i in int(4 + big * 4):
		game.later(.08 + randf() * .5 * big, func(): plop(.35 + randf() * .4, .3))

func whoosh() -> void:
	_play("whoosh", .8)

func tick(vol := .12) -> void:
	_play("tick", .8 * vol)

func creak(v: float) -> void:
	if not _on:
		return
	var k := clampf((v - .6) / .5, 0, 1)
	_creak_v = k
	_amb.creak.volume_db = _db(k * .12 * .8 * .9) if _sound_on() and k > 0 else -80.0

func pluck(freq: float, vol := .3, slide := 0.0, when := 0.0, mus := false) -> void:
	var key := pkey(freq, slide)
	if not _bank.has(key):
		key = pkey(freq, 0)
	var v := vol * (.32 if mus else .8)
	if when > 0:
		game.later(when, func(): _play(key, v, mus))
	else:
		_play(key, v, mus)

func fanfare(rar: int) -> void:
	var seq := [0, 2, 3, 5, 7, 8, 7] if rar >= 3 else ([2, 3, 5, 7] if rar == 2 else [3, 5, 7])
	for i in seq.size():
		pluck(PENTA[seq[i]], .32, 2.0 if i == seq.size() - 1 else 0.0, i * .11)

func snap() -> void:
	pluck(1200, .35, -12)
	_play("snapnz", .8)

func coin(i := 0) -> void:
	pluck(PENTA[6 + (i % 3)] * 2, .16, 0, i * .07)

func ui() -> void:
	pluck(PENTA[5], .14)

func bad() -> void:
	pluck(220, .3, -2)
	pluck(207, .25, 0, .12)

func set_sound(on: bool) -> void:
	game.S.sound = 1 if on else 0
	_master()
	if not on:
		_amb.creak.volume_db = -80

func set_music(on: bool) -> void:
	game.S.music = 1 if on else 0

func ambience(dt: float, tod: Dictionary, rain: float) -> void:
	if not _on:
		init()
		return
	if _sound_on():
		_amb.rain.volume_db = _db(rain * .22 * .5 * .9)
		_amb.crick.volume_db = _db(tod.night * .028 * .5 * .9)
	_amb_t -= dt
	if _amb_t < 0:
		_amb_t = randf_range(1.2, 4)
		if tod.night < .5 and rain <= 0.01:
			_play("bird%d" % (randi() % 4), .5)
		elif tod.night >= .5:
			_play("frog%d" % (randi() % 4), .5)
	_mus_t -= dt
	if _mus_t < 0 and int(game.S.music) == 1:
		_mus_t = randf_range(4, 9)
		_phrase()

# câu đờn ngắn hơi vọng cổ
func _phrase() -> void:
	var k := 2 + randi() % 3
	var t := 0.0
	var n := 3 + randi() % 4
	for i in n:
		k = clampi(k + [-2, -1, -1, 1, 1, 2][randi() % 6], 0, 6)
		var sl := 0.0
		if i == n - 1 and randf() < .6:
			sl = [1.0, 2.0, -1.0][randi() % 3]
		pluck(PENTA[k] / 2, .22, sl, t, true)
		t += [.28, .28, .42, .56][randi() % 4]
