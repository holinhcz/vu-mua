extends Node
# ĐUA GÀ: âm thanh. Web tổng hợp bằng WebAudio (snd / voice / tone / tiếng ồn mưa, sấm). Ở đây tổng hợp đúng các công
# thức đó ra AudioStreamWAV trong luồng phụ lúc mở game (không khựng), rồi phát lại: tiếng động theo sự kiện của luật đua,
# nhạc nền từng map (vòng 32 nhịp, vòng cuối nhanh 1.15), tiếng mưa lặp, tiếng giọt, sấm.

const RATE := 22050
const RAIN_K := 0.4
const MUSICS := [
	{"bpm": 132, "lead": "square", "lv": .022, "bass": "triangle", "bv": .06, "perc": "hat", "mel": [72, 0, 76, 79, 77, 0, 76, 74, 72, 0, 74, 76, 74, 0, 71, 67, 72, 0, 76, 79, 81, 0, 79, 77, 76, 74, 72, 74, 72, 0, 0, 0], "bas": [48, 48, 55, 55, 53, 53, 55, 55, 48, 48, 55, 55, 53, 55, 48, 48]},
	{"bpm": 108, "lead": "triangle", "lv": .06, "bass": "triangle", "bv": .05, "perc": "soft", "mel": [69, 0, 72, 74, 76, 0, 74, 72, 69, 0, 67, 69, 72, 0, 0, 0, 74, 0, 76, 79, 76, 0, 74, 72, 74, 0, 72, 69, 67, 0, 69, 0], "bas": [45, 45, 52, 52, 48, 48, 55, 55, 45, 45, 52, 52, 43, 43, 45, 45]},
	{"bpm": 146, "lead": "square", "lv": .02, "bass": "sawtooth", "bv": .028, "perc": "wood", "mel": [76, 76, 0, 79, 81, 0, 79, 76, 74, 0, 76, 74, 72, 0, 69, 0, 72, 72, 0, 74, 76, 0, 79, 81, 79, 76, 74, 72, 74, 0, 0, 0], "bas": [45, 52, 45, 52, 50, 57, 50, 57, 48, 55, 48, 55, 52, 59, 52, 59]}]

static var muted := false   # nút Âm thanh trong bảng tạm dừng (giữ suốt phiên chơi)

var music_id := 0
var _bank := {}
var _pl: Array = []
var _pi := 0
var _th: Thread
var _ok := false
var _rain: AudioStreamPlayer
var _mus: AudioStreamPlayer
var _mus_k := ""            # "m1" / "m115" đang phát
var _later: Array = []      # [còn bao lâu, tên]

func _init(mid := 0) -> void:
	music_id = clampi(mid, 0, MUSICS.size() - 1)

func _ready() -> void:
	for k in 14:
		var p := AudioStreamPlayer.new()
		add_child(p)
		_pl.append(p)
	_rain = AudioStreamPlayer.new()
	_rain.volume_db = -80
	add_child(_rain)
	_mus = AudioStreamPlayer.new()
	add_child(_mus)
	_th = Thread.new()
	_th.start(_build)

func _exit_tree() -> void:
	if _th != null and _th.is_started():
		_th.wait_to_finish()

func ready_ok() -> bool:
	return _ok

func play(name: String) -> void:
	if muted or not _ok:
		return
	var s = _bank.get(name)
	if s == null:
		return
	var p: AudioStreamPlayer = _pl[_pi]
	_pi = (_pi + 1) % _pl.size()
	p.stream = s
	p.play()

func later(sec: float, name: String) -> void:
	_later.append([sec, name])

# sự kiện của luật đua -> tiếng (tên như SFX của web)
func on_event(e: Array) -> void:
	var n: String = e[0]
	match n:
		"tier":
			play("tier2" if int(e[1]) > 1 else "tier1")
		"finish":
			play("jwin" if int(e[1]) <= 3 else "jlose")
		"thunder":
			later(0.3 + randf() * 0.9, "thunder%d" % (randi() % 2))
		"result":
			pass
		_:
			play(n)

# mỗi khung: nhạc (on / nhanh), mưa theo độ mưa k, giọt mưa, tiếng hẹn giờ
func tick(dt: float, mus_on: bool, fast: bool, wk: float, paused: bool) -> void:
	if not _ok:
		return
	var i := _later.size() - 1
	while i >= 0:
		_later[i][0] -= dt
		if _later[i][0] <= 0:
			play(_later[i][1])
			_later.remove_at(i)
		i -= 1
	# mưa: rainGain = k*.055
	if _rain.stream == null:
		_rain.stream = _bank.get("rain")
	var rv := 0.0 if muted or paused else wk * 0.055
	if rv > 0.0005:
		if not _rain.playing:
			_rain.play()
		_rain.volume_db = linear_to_db(rv / RAIN_K)
	elif _rain.playing:
		_rain.stop()
	if not paused and wk > 0.3 and randf() < dt * 14 * wk:
		play("drip%d" % (randi() % 4))
	# nhạc: vòng 32 nhịp; vòng cuối nhanh 1.15, đổi giữa chừng thì giữ đúng chỗ trong bài
	var want := "" if muted or paused or not mus_on else ("m115_%d" if fast else "m1_%d") % music_id
	if want != _mus_k:
		var pos := 0.0
		var frac := -1.0
		if _mus.playing and _mus_k != "":
			var len0: float = _mus.stream.get_length()
			frac = fmod(_mus.get_playback_position(), len0) / len0
		_mus.stop()
		_mus_k = want
		if want != "":
			_mus.stream = _bank.get(want)
			if frac >= 0 and _mus.stream != null:
				pos = frac * _mus.stream.get_length()
			_mus.play(pos)

func stop_all() -> void:
	_later.clear()
	_mus.stop()
	_mus_k = ""
	_rain.stop()
	for p in _pl:
		p.stop()

# ------------------------------------------------------------ tổng hợp
class Buf:
	var d: PackedFloat32Array
	func _init(sec: float) -> void:
		d = PackedFloat32Array()
		d.resize(int(sec * 22050.0) + 1)

static func _wave(type: String, x: float) -> float:
	match type:
		"square":
			return 1.0 if x < .5 else -1.0
		"sawtooth":
			return 2.0 * x - 1.0
		"triangle":
			return 4.0 * x - 1.0 if x < .5 else 3.0 - 4.0 * x
	return sin(TAU * x)

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
		# WebAudio: Q của lowpass / highpass tính bằng dB
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

static func _filt(x: PackedFloat32Array, c: Array) -> PackedFloat32Array:
	var y := PackedFloat32Array()
	y.resize(x.size())
	var x1 := 0.0
	var x2 := 0.0
	var y1 := 0.0
	var y2 := 0.0
	for i in x.size():
		var v: float = c[0] * x[i] + c[1] * x1 + c[2] * x2 - c[3] * y1 - c[4] * y2
		x2 = x1
		x1 = x[i]
		y2 = y1
		y1 = v
		y[i] = v
	return y

# snd(f, dur, type, vol, slide) của web: tần số trượt mũ f -> slide, âm lượng giảm mũ vol -> .0001 trong dur
static func snd(B: Buf, t: float, f: float, dur: float, type: String, vol: float, slide := 0.0) -> void:
	var n0 := int(t * RATE)
	var n := int(dur * RATE)
	var ph := 0.0
	for k in n:
		var i := n0 + k
		if i >= B.d.size():
			break
		var u := float(k) / n
		var fr := f * pow(slide / f, u) if slide > 0 else f
		ph += fr / RATE
		B.d[i] += _wave(type, ph - floorf(ph)) * vol * pow(0.0001 / vol, u)

# tone(f, t, d, type, vol) của nhạc: như snd không trượt, dừng sau d + .02
static func tone(B: Buf, t: float, f: float, d: float, type: String, vol: float, wrap := false) -> void:
	var n0 := int(t * RATE)
	var n := int((d + 0.02) * RATE)
	var L := B.d.size()
	var ph := 0.0
	for k in n:
		var i := n0 + k
		if i >= L:
			if not wrap:
				break
			i -= L
		var tt := float(k) / RATE
		ph += f / RATE
		var g := vol * pow(0.0001 / vol, tt / d) if tt < d else 0.0001
		B.d[i] += _wave(type, ph - floorf(ph)) * g

static func _pw(pts: Array, t: float) -> float:
	if t <= pts[0][0]:
		return pts[0][1]
	for j in range(1, pts.size()):
		if t <= pts[j][0]:
			var a: Array = pts[j - 1]
			var b: Array = pts[j]
			return lerpf(a[1], b[1], (t - a[0]) / maxf(0.00001, b[0] - a[0]))
	return pts[pts.size() - 1][1]

# voice(delay, fpts, gpts, forms, vib) của web: răng cưa qua các lọc dải (formant), đường cao độ và âm lượng tuyến tính
static func voice(B: Buf, delay: float, fp: Array, gp: Array, forms: Array, vib := 0.0) -> void:
	var t0 := 0.02 + delay
	var dur: float = gp[gp.size() - 1][0] + 0.05
	var n := int(dur * RATE)
	var src := PackedFloat32Array()
	src.resize(n)
	var ph := 0.0
	for k in n:
		var tt := float(k) / RATE
		var f := _pw(fp, tt)
		if vib > 0:
			f += 14.0 * sin(TAU * vib * tt)
		ph += f / RATE
		src[k] = 2.0 * (ph - floorf(ph)) - 1.0
	var out := PackedFloat32Array()
	out.resize(n)
	for fq in forms:
		var y := _filt(src, _coef("bandpass", fq[0], fq[1]))
		for k in n:
			out[k] += y[k]
	var n0 := int(t0 * RATE)
	for k in n:
		var i := n0 + k
		if i >= B.d.size():
			break
		B.d[i] += out[k] * _pw(gp, float(k) / RATE)

static func _wav(B: Buf, loop := false) -> AudioStreamWAV:
	var pcm := PackedByteArray()
	pcm.resize(B.d.size() * 2)
	for i in B.d.size():
		pcm.encode_s16(i * 2, int(clampf(B.d[i], -1, 1) * 32000))
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

static func nf(n: float) -> float:
	return 440.0 * pow(2.0, (n - 69) / 12.0)

func _one(out: Dictionary, name: String, sec: float, f: Callable) -> void:
	var B := Buf.new(sec)
	f.call(B)
	out[name] = _wav(B)

func _build() -> void:
	var out := {}
	_one(out, "beep", .2, func(B): snd(B, 0, 440, .18, "square", .08))
	_one(out, "go", .42, func(B): snd(B, 0, 880, .4, "square", .1))
	_one(out, "pick", .2, func(B):
		snd(B, 0, 660, .08, "triangle", .12)
		snd(B, .07, 990, .1, "triangle", .12))
	_one(out, "tick", .04, func(B): snd(B, 0, 1300, .03, "square", .03))
	_one(out, "hit", .27, func(B):
		snd(B, 0, 300, .25, "sawtooth", .08, 90)
		snd(B, 0, 1200, .12, "square", .04, 500))
	_one(out, "boost", .52, func(B): snd(B, 0, 200, .5, "sawtooth", .06, 700))
	_one(out, "throw", .17, func(B): snd(B, 0, 500, .15, "triangle", .08, 200))
	_one(out, "shield", .32, func(B): snd(B, 0, 300, .3, "sine", .12, 600))
	_one(out, "zap", .37, func(B): snd(B, 0, 1500, .35, "sawtooth", .06, 60))
	_one(out, "lap", .34, func(B):
		snd(B, 0, 784, .12, "square", .08)
		snd(B, .12, 1046, .2, "square", .08))
	_one(out, "splash", .52, func(B):
		snd(B, 0, 600, .4, "sawtooth", .05, 80)
		snd(B, 0, 200, .5, "triangle", .08, 60))
	_one(out, "whoosh", .62, func(B): snd(B, 0, 300, .6, "triangle", .1, 1200))
	_one(out, "thud", .22, func(B): snd(B, 0, 140, .2, "triangle", .12, 70))
	_one(out, "slip", .32, func(B): snd(B, 0, 900, .3, "triangle", .07, 300))
	_one(out, "pad", .27, func(B): snd(B, 0, 400, .25, "square", .05, 1200))
	_one(out, "tier1", .1, func(B): snd(B, 0, 1000, .08, "square", .04))
	_one(out, "tier2", .1, func(B): snd(B, 0, 1400, .08, "square", .04))
	_one(out, "stomp", .47, func(B):
		snd(B, 0, 70, .45, "sine", .32, 34)
		snd(B, 0, 150, .2, "triangle", .14, 55)
		snd(B, 0, 900, .06, "square", .03, 200))
	_one(out, "chirp", .2, func(B):
		for k in 4:
			snd(B, k * .038, 4300, .045, "sine", .075, 4150)
			snd(B, k * .038, 8600, .03, "sine", .018, 8300))
	for k in 4:
		var f := 2600.0 + randf() * 2400
		_one(out, "drip%d" % k, .03, func(B): snd(B, 0, f, .025, "sine", .012))
	_one(out, "quack", .4, func(B):
		voice(B, 0, [[0, 330], [.13, 230]], [[0, 0], [.015, .32], [.1, .22], [.15, 0]], [[1100, 4], [2500, 5]])
		voice(B, .17, [[0, 310], [.12, 210]], [[0, 0], [.015, .3], [.09, .2], [.14, 0]], [[1100, 4], [2500, 5]]))
	_one(out, "bark", .45, func(B):
		for d in [0.0, .2]:
			voice(B, d, [[0, 520], [.04, 640], [.13, 360]], [[0, 0], [.01, .34], [.08, .24], [.14, 0]], [[800, 3], [1900, 4]]))
	_one(out, "meow", .6, func(B): voice(B, 0, [[0, 560], [.16, 780], [.48, 520]], [[0, 0], [.06, .24], [.36, .2], [.52, 0]], [[1000, 3], [2600, 5]], 5))
	_one(out, "baa", .8, func(B): voice(B, 0, [[0, 430], [.65, 400]], [[0, 0], [.05, .26], [.55, .2], [.7, 0]], [[700, 3], [1500, 4]], 9))
	_one(out, "bleat", .65, func(B): voice(B, 0, [[0, 540], [.5, 480]], [[0, 0], [.04, .24], [.42, .18], [.55, 0]], [[900, 4], [2200, 5]], 13))
	_one(out, "oink", .45, func(B):
		for d in [0.0, .2]:
			voice(B, d, [[0, 170], [.07, 230], [.16, 140]], [[0, 0], [.02, .34], [.12, .24], [.17, 0]], [[600, 4], [1300, 5]]))
	_one(out, "moo", 1.25, func(B): voice(B, 0, [[0, 150], [.25, 178], [1.05, 118]], [[0, 0], [.18, .36], [.9, .3], [1.15, 0]], [[500, 3], [1100, 4]]))
	_one(out, "low", 1.4, func(B): voice(B, 0, [[0, 108], [.3, 132], [1.25, 88]], [[0, 0], [.2, .4], [1.05, .32], [1.3, 0]], [[420, 3], [950, 4]]))
	_one(out, "honk", .95, func(B):
		for d in [0.0, .3, .6]:
			voice(B, d, [[0, 400], [.06, 440], [.24, 360]], [[0, 0], [.02, .22], [.2, .16], [.26, 0]], [[900, 3], [2100, 4]], 6))
	# gà gáy "ò ó o o" (crowSnd(.5))
	var v := .5 * .3
	_one(out, "crow", 1.2, func(B): voice(B, 0, [[0, 420], [.12, 600], [.16, 560], [.3, 740], [.36, 720], [.75, 800], [1.1, 500]],
		[[0, 0], [.03, v], [.12, v * .55], [.15, v * .08], [.19, v], [.32, v * .6], [.35, v * .1], [.4, v], [.85, v * .9], [1.12, 0]], [[1150, 2.5], [2700, 3.5]], 7))
	# kèn về đích: thắng / thua
	_one(out, "jwin", 1.05, func(B):
		var ns := [72, 76, 79, 84, 79, 84]
		for i in ns.size():
			tone(B, .05 + i * .14, nf(ns[i]), .2, "square", .05))
	_one(out, "jlose", .8, func(B):
		var ns := [67, 72, 71, 67]
		for i in ns.size():
			tone(B, .05 + i * .14, nf(ns[i]), .2, "square", .05))
	# sấm: ồn nâu qua lọc thấp 260 -> 70, lên nhanh rồi tắt dần trong 3 giây
	for vv in 2:
		var B := Buf.new(3.0)
		var x := PackedFloat32Array()
		x.resize(B.d.size())
		var w := 0.0
		for i in x.size():
			w = w * .97 + (randf() * 2 - 1) * .03
			x[i] = w * 6
		var x1 := 0.0
		var x2 := 0.0
		var y1 := 0.0
		var y2 := 0.0
		var c := []
		for i in x.size():
			var tt := float(i) / RATE
			if i % 64 == 0:
				c = _coef("lowpass", 260 * pow(70.0 / 260.0, tt / 3.0), 0)
			var y: float = c[0] * x[i] + c[1] * x1 + c[2] * x2 - c[3] * y1 - c[4] * y2
			x2 = x1
			x1 = x[i]
			y2 = y1
			y1 = y
			var g := 0.0
			if tt < .08:
				g = .0001 * pow(.4 / .0001, tt / .08)
			elif tt < .6:
				g = .4 * pow(.12 / .4, (tt - .08) / .52)
			else:
				g = .12 * pow(.0001 / .12, (tt - .6) / 2.4)
			B.d[i] = y * g
		out["thunder%d" % vv] = _wav(B)
	# mưa: ồn trắng 2 giây qua lọc cao 3200 (x.45), dải 1100 (x.8), thấp 260 (x1.3); âm lượng chỉnh lúc phát
	var RB := Buf.new(2.0)
	var nz := PackedFloat32Array()
	nz.resize(RB.d.size())
	for i in nz.size():
		nz[i] = randf() * 2 - 1
	for f in [["highpass", 3200.0, .7, .45], ["bandpass", 1100.0, .8, .8], ["lowpass", 260.0, .7, 1.3]]:
		var y := _filt(nz, _coef(f[0], f[1], f[2]))
		for i in y.size():
			RB.d[i] += y[i] * f[3]
	# nối vòng: trộn 0.1 giây cuối vào đầu cho khỏi tách
	var xf := int(.1 * RATE)
	var L := RB.d.size()
	for i in xf:
		var u := float(i) / xf
		RB.d[i] = RB.d[i] * u + RB.d[L - xf + i] * (1 - u)
	RB.d.resize(L - xf)
	# ghi ở mức x RAIN_K cho khỏi vỡ tiếng, lúc phát chia lại
	for i in RB.d.size():
		RB.d[i] *= RAIN_K
	out.rain = _wav(RB, true)
	# nhạc nền: một vòng 32 nhịp ở tốc độ thường và vòng cuối (x1.15); đuôi nốt quấn về đầu vòng
	for mi in MUSICS.size():
		_music(out, mi)
	call_deferred("_done", out)

func _music(out: Dictionary, mi: int) -> void:
	var M: Dictionary = MUSICS[mi]
	for tp in [[1.0, "m1_%d" % mi], [1.15, "m115_%d" % mi]]:
		var spb: float = 60.0 / (M.bpm * tp[0]) / 2.0
		var B := Buf.new(spb * 32)
		B.d.resize(int(round(spb * 32 * RATE)))
		for st in 32:
			var t := st * spb
			var m: int = M.mel[st]
			if m:
				tone(B, t, nf(m), spb * (1.6 if M.lead == "triangle" else .9), M.lead, M.lv, true)
				if M.perc == "soft":
					tone(B, t + spb * .5, nf(m + 12), spb * .6, "sine", M.lv * .25, true)
			if st % 2 == 0:
				tone(B, t, nf(M.bas[(st / 2) % 16]), spb * 1.8, M.bass, M.bv, true)
			if M.perc == "hat" and st % 4 == 2:
				tone(B, t, 2400, .03, "square", .008, true)
			elif M.perc == "wood":
				if st % 2 == 1:
					tone(B, t, 1250, .035, "square", .012, true)
				if st % 8 == 4:
					tone(B, t, 180, .12, "triangle", .07, true)
			elif M.perc == "soft" and st % 8 == 0:
				tone(B, t, 110, .25, "sine", .06, true)
		out[tp[1]] = _wav(B, true)

func _done(out: Dictionary) -> void:
	_bank = out
	_ok = true
	if _th != null and _th.is_started():
		_th.wait_to_finish()
