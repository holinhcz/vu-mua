extends Node
# CỜ GÁNH: tiếng động, dịch từ SND của bản web (game.js: tone / noiseHit qua WebAudio).
# Không có file âm thanh: mỗi tiếng được tổng hợp sẵn thành AudioStreamWAV lúc mở game (dao động sin/tam giác/vuông,
# tiếng ồn qua lọc biquad, đường bao lên 2-4 ms rồi tắt dần theo hàm mũ y như env() của web), mỗi tiếng vài bản ngẫu nhiên.

const RATE := 22050
var on := true
var _bank := {}        # tên -> [AudioStreamWAV]
var _pl := []
var _pi := 0

func _ready() -> void:
	for k in 8:
		var p := AudioStreamPlayer.new()
		add_child(p)
		_pl.append(p)
	_build()

# ------------------------------------------------------------ tổng hợp
class Buf:
	var d: PackedFloat32Array
	func _init(sec: float) -> void:
		d = PackedFloat32Array()
		d.resize(int(sec * 22050.0) + 1)

static func _env(t: float, a: float, peak: float, dec: float) -> float:
	# exponentialRamp 0.0001 -> peak trong a giây, rồi peak -> 0.0001 trong dec giây
	if t < 0.0:
		return 0.0
	if t < a:
		return 0.0001 * pow(peak / 0.0001, t / a)
	var u := (t - a) / dec
	if u > 1.0:
		return 0.0
	return peak * pow(0.0001 / peak, u)

static func _tone(B: Buf, f: float, vol: float, dec: float, type: String = "sine", delay: float = 0.0, slide: float = 0.0) -> void:
	var n0 := int(delay * RATE)
	var n := int((dec + 0.05) * RATE)
	var ph := 0.0
	for k in n:
		var i := n0 + k
		if i >= B.d.size():
			break
		var t := float(k) / RATE
		var fr := f * (pow(slide, minf(1.0, t / dec)) if slide > 0.0 else 1.0)
		ph += fr / RATE
		var x := ph - floorf(ph)
		var w := 0.0
		match type:
			"triangle": w = 4.0 * absf(x - 0.5) - 1.0
			"square": w = 1.0 if x < 0.5 else -1.0
			_: w = sin(TAU * x)
		B.d[i] += w * _env(t, 0.004, vol, dec)

static func _noise(B: Buf, f: float, q: float, vol: float, dec: float, type: String = "bandpass", delay: float = 0.0) -> void:
	# RBJ biquad, như BiquadFilterNode
	var w0 := TAU * f / RATE
	var al := sin(w0) / (2.0 * q)
	var cw := cos(w0)
	var b0: float; var b1: float; var b2: float
	if type == "lowpass":
		b0 = (1.0 - cw) / 2.0; b1 = 1.0 - cw; b2 = (1.0 - cw) / 2.0
	else:
		b0 = al; b1 = 0.0; b2 = -al
	var a0 := 1.0 + al
	var a1 := -2.0 * cw
	var a2 := 1.0 - al
	var x1 := 0.0; var x2 := 0.0; var y1 := 0.0; var y2 := 0.0
	var n0 := int(delay * RATE)
	var n := int((dec + 0.05) * RATE)
	for k in n:
		var i := n0 + k
		if i >= B.d.size():
			break
		var x := randf() * 2.0 - 1.0
		var y := (b0 * x + b1 * x1 + b2 * x2 - a1 * y1 - a2 * y2) / a0
		x2 = x1; x1 = x; y2 = y1; y1 = y
		B.d[i] += y * _env(float(k) / RATE, 0.002, vol, dec)

static func _wav(B: Buf) -> AudioStreamWAV:
	var pcm := PackedByteArray()
	pcm.resize(B.d.size() * 2)
	for i in B.d.size():
		pcm.encode_s16(i * 2, int(clampf(B.d[i], -1.0, 1.0) * 32000.0))
	var s := AudioStreamWAV.new()
	s.format = AudioStreamWAV.FORMAT_16_BITS
	s.mix_rate = RATE
	s.stereo = false
	s.data = pcm
	return s

func _add(name: String, sec: float, fn: Callable, variants: int = 1) -> void:
	var a := []
	for v in variants:
		var B := Buf.new(sec)
		fn.call(B)
		a.append(_wav(B))
	_bank[name] = a

func _build() -> void:
	# clack trên đất / chạm quân khác (v = 1, âm lượng chỉnh lúc phát)
	_add("clack0", 0.12, func(B): _noise(B, 700 + randf() * 300, 1.4, 0.2, 0.06, "lowpass"); _noise(B, 2100 + randf() * 600, 4, 0.05, 0.03), 4)
	_add("clack1", 0.1, func(B): _noise(B, 2600 + randf() * 1600, 7, 0.16, 0.045); _tone(B, 2300 + randf() * 900, 0.05, 0.03), 4)
	_add("tap", 0.16, func(B): _noise(B, 240, 1, 0.5, 0.09, "lowpass"); _noise(B, 900, 1.2, 0.12, 0.05, "lowpass", 0.005))
	_add("sel", 0.14, func(B): _tone(B, 880, 0.05, 0.08))
	_add("win", 1.3, func(B):
		var fs := [523, 659, 784, 1047, 784, 1047, 1319]
		for i in fs.size(): _tone(B, fs[i], 0.09, 0.42, "triangle", i * 0.11))
	_add("lose", 1.1, func(B):
		var fs := [392, 349, 330, 262]
		for i in fs.size(): _tone(B, fs[i], 0.08, 0.5, "triangle", i * 0.16))
	for n in [2, 4, 6]:
		_add("ganh" + str(n), 0.75, func(B):
			_tone(B, 330, 0.1, 0.5, "triangle", 0, 1.5)
			var fs := [523, 659, 784, 1047].slice(0, 2 + mini(2, n >> 1))
			for i in fs.size(): _tone(B, fs[i], 0.09, 0.35, "triangle", 0.08 + i * 0.07)
			_noise(B, 1800, 3, 0.08, 0.12, "bandpass", 0.02))
	_add("vay", 1.3, func(B):
		_tone(B, 98, 0.28, 1.2, "sine"); _tone(B, 196, 0.1, 0.9, "sine")
		var fs := [392, 494, 587, 784]
		for i in fs.size(): _tone(B, fs[i], 0.07, 0.4, "triangle", 0.15 + i * 0.09))
	_add("mo", 0.4, func(B): _tone(B, 740, 0.08, 0.14, "square", 0, 0.7); _tone(B, 740, 0.08, 0.14, "square", 0.18, 0.7))

func _play(name: String, vol := 1.0) -> void:
	if not on or not _bank.has(name):
		return
	var a: Array = _bank[name]
	var p: AudioStreamPlayer = _pl[_pi]
	_pi = (_pi + 1) % _pl.size()
	p.stream = a[randi() % a.size()]
	p.volume_db = linear_to_db(maxf(0.001, vol))
	p.play()

func clack(v: float, on_stone: bool) -> void:
	_play("clack1" if on_stone else "clack0", minf(1.0, v))
func tap() -> void: _play("tap")
func sel() -> void: _play("sel")
func win() -> void: _play("win")
func lose() -> void: _play("lose")
func ganh(n: int) -> void: _play("ganh" + str(clampi((n >> 1) * 2, 2, 6)))
func vay() -> void: _play("vay")
func mo() -> void: _play("mo")
