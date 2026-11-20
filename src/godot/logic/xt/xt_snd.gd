extends Node
# XẾP TRÁI: âm thanh (01_audio.js). Web tổng hợp hết bằng WebAudio (dây đàn tranh Karplus-Strong, song lang,
# tiếng thú qua lọc formant). Ở đây tổng hợp y công thức đó thành AudioStreamWAV, làm trong luồng phụ lúc mở game
# để không khựng; bản nhạc vọng cổ 64 nhịp được dựng sẵn thành một vòng lặp liền.

const RATE := 22050
const PENTA := [0, 2, 5, 7, 9]
const MEL := "5-7-8-.75-4-2-..4-5-7-8-9---8-..7-8-9-a-9-8-7-..5-7-5-4-2-------"
const BASS := [0, 0, 3, 3, 0, 0, 4, 4, 2, 2, 3, 3, 0, 0, 0, 0]

var game
var _bank := {}
var _pl: Array = []
var _pi := 0
var _mus: AudioStreamPlayer
var _th: Thread
var _last := {}
var _plk := {}
var _ready_ok := false

func _init(gm) -> void:
	game = gm

func _ready() -> void:
	for k in 10:
		var p := AudioStreamPlayer.new()
		add_child(p)
		_pl.append(p)
	_mus = AudioStreamPlayer.new()
	add_child(_mus)
	_th = Thread.new()
	_th.start(_build)

func _exit_tree() -> void:
	if _th != null and _th.is_started():
		_th.wait_to_finish()

func init() -> void:
	pass

static func mtof(m: float) -> float:
	return 440.0 * pow(2.0, (m - 69) / 12.0)

static func note_of(i: int) -> int:
	return 60 + PENTA[((i % 5) + 5) % 5] + 12 * int(floor(i / 5.0))

# ------------------------------------------------------------ bộ đệm: khô + gửi vang
class Buf:
	var d: PackedFloat32Array
	var r: PackedFloat32Array
	func _init(sec: float) -> void:
		d = PackedFloat32Array()
		d.resize(int(sec * 22050.0) + 1)
		r = PackedFloat32Array()
		r.resize(d.size())

func _pluck_buf(m: int, bright := 0.55, ln := 2.2) -> PackedFloat32Array:
	var key := "%d|%s" % [m, bright]
	if _plk.has(key):
		return _plk[key]
	var f := mtof(m)
	var L := maxi(4, int(round(RATE / f)))
	var N := int(RATE * ln)
	var o := PackedFloat32Array()
	o.resize(N)
	var dl := PackedFloat32Array()
	dl.resize(L)
	var lp := 0.0
	for i in L:
		lp += ((randf() * 2 - 1) - lp) * bright
		dl[i] = lp
	var decay := pow(0.001, 1.0 / (f * ln * 0.9))
	var p := 0
	var prev := 0.0
	for i in N:
		var v := dl[p]
		dl[p] = (v + prev) * 0.5 * decay
		prev = v
		o[i] = v
		p += 1
		if p == L:
			p = 0
	_plk[key] = o
	return o

func pluck(B: Buf, m: float, t: float, vol := 0.5, bend := 0.0) -> void:
	var src := _pluck_buf(int(round(m)))
	var n0 := int(t * RATE)
	var pos := 0.0
	var rate1 := pow(2.0, bend / 12.0)
	var k := 0
	while pos < src.size() - 1 and k < int(2.2 * RATE):
		var i := n0 + k
		if i >= B.d.size():
			break
		var ip := int(pos)
		var fr := pos - ip
		var v: float = (src[ip] * (1 - fr) + src[ip + 1] * fr) * vol
		B.d[i] += v
		B.r[i] += v
		var tt := float(k) / RATE
		var rate := 1.0
		if bend != 0.0 and tt > 0.08:
			rate = lerpf(1.0, rate1, clampf((tt - 0.08) / 0.14, 0, 1))
		pos += rate
		k += 1

static func _env(t: float, a: float, peak: float, d: float) -> float:
	if t < 0:
		return 0.0
	if t < a:
		return peak * t / a
	var u := (t - a) / d
	return peak * pow(0.0008 / peak, minf(u, 1.0)) * (1.0 if u <= 1.0 else 0.0)

static func tone(B: Buf, type: String, f0: float, f1: float, dur: float, vol: float, t: float) -> void:
	f1 = maxf(20, f1)
	var n0 := int(t * RATE)
	var n := int((dur + 0.05) * RATE)
	var ph := 0.0
	for k in n:
		var i := n0 + k
		if i >= B.d.size():
			break
		var tt := float(k) / RATE
		var f := f0 * pow(f1 / f0, minf(1.0, tt / dur))
		ph += f / RATE
		var x := ph - floorf(ph)
		var w := 0.0
		match type:
			"triangle": w = 4.0 * absf(x - 0.5) - 1.0
			"square": w = 1.0 if x < 0.5 else -1.0
			"sawtooth": w = 2.0 * x - 1.0
			_: w = sin(TAU * x)
		B.d[i] += w * _env(tt, 0.006, vol, dur)

# RBJ biquad như BiquadFilterNode (Q của lowpass/highpass tính theo dB)
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
		var ql := pow(10.0, q / 20.0)
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

static func nz(B: Buf, dur: float, vol: float, type: String, f0: float, f1: float, t: float, q := 1.0) -> void:
	var n0 := int(t * RATE)
	var n := int((dur + 0.05) * RATE)
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
			c = _coef(type, f0 * pow(f1 / f0, minf(1.0, tt / dur)), q)
		var x := randf() * 2 - 1
		var y: float = c[0] * x + c[1] * x1 + c[2] * x2 - c[3] * y1 - c[4] * y2
		x2 = x1
		x1 = x
		y2 = y1
		y1 = y
		B.d[i] += y * _env(tt, 0.005, vol, dur)

static func voice(B: Buf, t: float, pts: Array, dur: float, formants: Array, vol: float) -> void:
	var n0 := int(t * RATE)
	var n := int((dur + 0.05) * RATE)
	var src := PackedFloat32Array()
	src.resize(n)
	var ph := 0.0
	var segs := pts.size() - 1
	for k in n:
		var tt := float(k) / RATE
		var u := clampf(tt / dur, 0, 1) * segs
		var j := mini(int(u), segs - 1)
		var f: float = lerpf(pts[j], pts[j + 1], u - j)
		ph += f / RATE
		var x := ph - floorf(ph)
		var g := 0.0
		if tt < 0.04:
			g = vol * tt / 0.04
		elif tt < dur * 0.75:
			g = vol
		elif tt < dur:
			g = vol * (1 - (tt - dur * 0.75) / (dur * 0.25))
		src[k] = (2.0 * x - 1.0) * g
	for fm in formants:
		var c := _coef("bandpass", fm[0], fm[1])
		var a: float = fm[2]
		var x1 := 0.0
		var x2 := 0.0
		var y1 := 0.0
		var y2 := 0.0
		for k in n:
			var i := n0 + k
			if i >= B.d.size():
				break
			var x := src[k]
			var y: float = c[0] * x + c[1] * x1 + c[2] * x2 - c[3] * y1 - c[4] * y2
			x2 = x1
			x1 = x
			y2 = y1
			y1 = y
			B.d[i] += y * a

# vang phòng nhỏ (thay cho convolver 1.6 s): 4 comb + 2 allpass, trộn 0.28
static func _reverb(B: Buf) -> void:
	var n := B.d.size()
	var wet := PackedFloat32Array()
	wet.resize(n)
	var combs := [[1116, 0.84], [1188, 0.83], [1277, 0.82], [1356, 0.81]]
	for cb in combs:
		var L := int(cb[0] * RATE / 44100.0)
		var fb: float = cb[1]
		var buf := PackedFloat32Array()
		buf.resize(L)
		var p := 0
		var lp := 0.0
		for i in n:
			var y := buf[p]
			lp = y * 0.6 + lp * 0.4
			buf[p] = B.r[i] + lp * fb
			wet[i] += y * 0.25
			p += 1
			if p == L:
				p = 0
	for ap in [556, 441]:
		var L := int(ap * RATE / 44100.0)
		var buf := PackedFloat32Array()
		buf.resize(L)
		var p := 0
		for i in n:
			var bo := buf[p]
			var x := wet[i]
			buf[p] = x + bo * 0.5
			wet[i] = bo - x * 0.5
			p += 1
			if p == L:
				p = 0
	for i in n:
		B.d[i] += wet[i] * 0.28 * 0.9

static func _wav(B: Buf, gain: float, loop := false) -> AudioStreamWAV:
	var pcm := PackedByteArray()
	pcm.resize(B.d.size() * 2)
	for i in B.d.size():
		var v := B.d[i] * gain
		# nén nhẹ thay compressor
		if absf(v) > 0.7:
			v = signf(v) * (0.7 + (absf(v) - 0.7) / (1 + (absf(v) - 0.7) * 3))
		pcm.encode_s16(i * 2, int(clampf(v, -1, 1) * 32000))
	var s := AudioStreamWAV.new()
	s.format = AudioStreamWAV.FORMAT_16_BITS
	s.mix_rate = RATE
	s.stereo = false
	s.data = pcm
	if loop:
		s.loop_mode = AudioStreamWAV.LOOP_FORWARD
		s.loop_begin = 0
		s.loop_end = B.d.size()
	return s

# ------------------------------------------------------------ các tiếng (AU.play)
func _render(name: String, a: int) -> AudioStreamWAV:
	var B := Buf.new(_len(name))
	match name:
		"swap": nz(B, 0.12, 0.18, "bandpass", 900, 2400, 0, 1.2)
		"bad":
			tone(B, "triangle", 260, 180, 0.14, 0.25, 0)
			tone(B, "triangle", 200, 140, 0.16, 0.2, 0.12)
		"pop":
			nz(B, 0.07, 0.22, "lowpass", 2600, 500, 0, 0.7)
			tone(B, "sine", 520, 180, 0.09, 0.22, 0)
			pluck(B, note_of(4 + mini(a, 10)), 0.01, 0.42)
		"land": tone(B, "sine", 210, 120, 0.05, 0.06, 0)
		"make":
			for i in 4:
				pluck(B, note_of(9 + i * 2), i * 0.06, 0.32)
			tone(B, "sine", 1400, 2600, 0.25, 0.06, 0)
		"trau":
			voice(B, 0, [118, 128, 112, 96], 0.9, [[380, 5, 1.4], [820, 7, 0.5], [2200, 9, 0.12]], 0.55)
			for i in 7:
				nz(B, 0.08, 0.28, "lowpass", 420, 120, i * 0.09)
		"heo":
			voice(B, 0, [420, 520, 300], 0.18, [[900, 6, 1.2], [2100, 8, 0.4]], 0.45)
			voice(B, 0.2, [460, 560, 320], 0.22, [[900, 6, 1.2], [2100, 8, 0.4]], 0.45)
			nz(B, 0.3, 0.5, "lowpass", 300, 60, 0.35)
			tone(B, "sine", 90, 40, 0.35, 0.6, 0.35)
		"ga": voice(B, 0, [520, 780, 840, 760, 620], 1.05, [[1100, 5, 1.3], [2400, 7, 0.6], [3600, 9, 0.2]], 0.42)
		"vit":
			voice(B, 0, [330, 300], 0.13, [[1200, 4, 1.2], [2600, 6, 0.6]], 0.5)
			voice(B, 0.17, [330, 290], 0.15, [[1200, 4, 1.2], [2600, 6, 0.6]], 0.5)
		"zap":
			nz(B, 0.35, 0.3, "bandpass", 600, 5000, 0, 2)
			tone(B, "square", 900, 1800, 0.3, 0.05, 0)
		"boom":
			tone(B, "sine", 140, 40, 0.45, 0.7, 0)
			nz(B, 0.4, 0.45, "lowpass", 1800, 100, 0)
		"hay":
			nz(B, 0.16, 0.3, "highpass", 1800, 4000, 0, 0.8)
			nz(B, 0.1, 0.25, "bandpass", 700, 300, 0.03, 1)
		"mud":
			tone(B, "sine", 300, 90, 0.12, 0.25, 0)
			nz(B, 0.12, 0.18, "lowpass", 800, 200, 0)
		"egg":
			for i in 3:
				pluck(B, note_of(12 + i), i * 0.08, 0.35)
		"star":
			pluck(B, note_of(10 + a * 2), 0, 0.5)
			pluck(B, note_of(12 + a * 2), 0.07, 0.4)
		"win":
			var ds := [0, 2, 4, 5, 7, 9, 10]
			for i in ds.size():
				pluck(B, note_of(5 + ds[i]), i * 0.11, 0.45, 2.0 if i == 6 else 0.0)
		"lose":
			var ds := [7, 5, 3, 2]
			for i in ds.size():
				pluck(B, note_of(3 + ds[i]), i * 0.22, 0.4, -1.0 if i == 3 else 0.0)
		"tap": tone(B, "sine", 880, 660, 0.05, 0.12, 0)
		"coin":
			pluck(B, note_of(14), 0, 0.35)
			pluck(B, note_of(17), 0.05, 0.3)
	_reverb(B)
	return _wav(B, 0.85)

static func _len(name: String) -> float:
	match name:
		"pop", "star", "coin", "make", "egg": return 2.3
		"win": return 3.0
		"lose": return 3.0
		"trau", "ga": return 1.3
		"heo": return 0.8
	return 0.6

# nhạc: 64 bước móc đơn, 84 bpm, đàn tranh + bè trầm + song lang
func _render_music() -> AudioStreamWAV:
	var step := 60.0 / 84.0 / 2.0
	var steps := 64
	var dur := steps * step
	var tail := 2.4
	var B := Buf.new(dur + tail)
	for i in steps:
		var t := i * step
		var ch := MEL[i % MEL.length()]
		if ch != "-" and ch != ".":
			var d := ch.hex_to_int()
			pluck(B, note_of(d + 3), t, 0.34, 2.0 if i % 32 == 14 else 0.0)
			if i % 4 == 0:
				pluck(B, note_of(d - 2), t + 0.005, 0.12)
		if i % 4 == 0:
			var b: int = BASS[(i / 4) % BASS.size()]
			tone(B, "triangle", mtof(note_of(b) - 24), mtof(note_of(b) - 24), step * 3.6, 0.22, t)
		if i % 8 == 0 or i % 8 == 5:
			var tmp := Buf.new(0.12)
			tone(tmp, "square", 1250 if i % 8 else 900, 1250 if i % 8 else 900, 0.05, 0.08 if i % 8 else 0.14, 0)
			var c := _coef("bandpass", 1600 if i % 8 else 1100, 6)
			var x1 := 0.0
			var x2 := 0.0
			var y1 := 0.0
			var y2 := 0.0
			var n0 := int(t * RATE)
			for k in tmp.d.size():
				var x := tmp.d[k]
				var y: float = c[0] * x + c[1] * x1 + c[2] * x2 - c[3] * y1 - c[4] * y2
				x2 = x1
				x1 = x
				y2 = y1
				y1 = y
				if n0 + k < B.d.size():
					B.d[n0 + k] += y * 3.0
	_reverb(B)
	# đuôi vòng sau chồng lên đầu vòng: lặp không hở
	var n := int(dur * RATE)
	var L := Buf.new(dur)
	L.d.resize(n)
	for i in n:
		L.d[i] = B.d[i]
	for i in range(n, B.d.size()):
		L.d[i - n] += B.d[i]
	return _wav(L, 0.85, true)

func _build() -> void:
	var out := {}
	for nm in ["tap", "bad", "swap", "land", "make", "hay", "mud", "coin", "win", "lose", "egg", "boom", "zap", "trau", "heo", "ga", "vit"]:
		out[nm] = _render(nm, 0)
	for a in 5:
		out["star%d" % a] = _render("star", a)
	for a in 11:
		out["pop%d" % a] = _render("pop", a)
	call_deferred("_got", out, null)
	var m := _render_music()
	call_deferred("_got", {}, m)

func _got(bank: Dictionary, music) -> void:
	_bank.merge(bank, true)
	_ready_ok = true
	if music != null:
		_mus.stream = music
		_mus.volume_db = linear_to_db(0.42)
		if game.save.get("music", true):
			_mus.play()

func play(name: String, a := 0) -> void:
	if not game.save.get("sfx", true):
		return
	var now := Time.get_ticks_msec() / 1000.0
	if name in ["land", "hay", "mud"]:
		if now - float(_last.get(name, -1.0)) < 0.07:
			return
	_last[name] = now
	var key := name
	if name == "star":
		key = "star%d" % clampi(a, 0, 4)
	elif name == "pop":
		key = "pop%d" % clampi(a, 0, 10)
	if not _bank.has(key):
		return
	var p: AudioStreamPlayer = _pl[_pi]
	_pi = (_pi + 1) % _pl.size()
	p.stream = _bank[key]
	p.play()

func set_sfx(on: bool) -> void:
	game.save.sfx = on
	game.persist()

func set_music(on: bool) -> void:
	game.save.music = on
	game.persist()
	if _mus.stream == null:
		return
	if on:
		if not _mus.playing:
			_mus.play()
	else:
		_mus.stop()
