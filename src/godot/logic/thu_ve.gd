extends "res://logic/ve_aa.gd"
# Vẽ một con vật đi lạc trên làng (cD + RM bản web): gà / vịt sổng chuồng (ganha, vit), chim sáo (sao).
# a = con vật do luật giữ ({sp, x, y, z, face, ph, mv, fly, al, act, seed, big}); farm.gd tạo node, đặt chỗ, xếp lớp.

var a: Dictionary = {}

func _process(dt: float) -> void:
	tt += dt
	modulate.a = clampf(float(a.get("al", 1.0)), 0.0, 1.0)   # i.globalAlpha = t.al
	queue_redraw()

func foot() -> Vector2:   # chân (toạ độ làng, chưa trừ độ cao z)
	return Vector2(farm.en(float(a.x), float(a.y)), farm.nn(float(a.x), float(a.y)))

func _draw() -> void:
	var sp := String(a.get("sp", ""))
	var p := foot()
	var zm: float = farm.main.zoom
	var e: float = farm.sign_le() * 1.05 * float(a.get("big", 1.0))
	var r := 4.5 if sp == "sao" else 7.0
	_aa = 1.0 / zm
	_L(p.x, p.y + 1.0, r * e, r * 0.38 * e, Color(0, 0, 0, 0.18))
	_aa = 1.0 / (zm * e)
	var fc := 1.0 if int(a.get("face", 1)) > 0 else -1.0
	var ph := float(a.get("ph", 0.0))
	var mv := bool(a.get("mv", false))
	match sp:
		"ganha": _tf(Vector2(p.x, p.y - float(a.get("z", 0.0))), Vector2(fc * e, e)); _ganha(ph, mv)
		"vit": _tf(Vector2(p.x, p.y - float(a.get("z", 0.0))), Vector2(fc * e, e), (sin(ph) * 0.08 if mv else 0.0) * fc); _vit(ph, mv)
		"sao": _tf(Vector2(p.x, p.y - float(a.get("z", 0.0))), Vector2(fc * e, e)); _sao(ph, mv)
	_tf(Vector2.ZERO, Vector2.ONE)

static func _na(c: Color, k: float) -> Color:   # na(màu, -k): tối đi k
	return c.darkened(-k) if k < 0.0 else c.lightened(k)

func _ganha(ph: float, mv: bool) -> void:   # RM.ganha
	var e := absf(sin(ph)) * 1.4 if mv else 0.0
	var r := maxf(0.0, sin(float(a.ph) * 1.7)) * 4.0 if not mv and int(a.get("act", 0)) == 1 else 0.0
	var o := _m("#f4efe4", "#8a8680") if float(a.get("seed", 0.0)) < 0.5 else _m("#c8803a", "#6a4424")
	var l := _na(o, -0.22)
	var c := sin(ph) * 1.6 if mv else 0.0
	_Dt(-1 + c, -3, -1.4 + c, 0, "#e8a030", 0.9)
	_Dt(1.6 - c, -3, 2 - c, 0, "#e8a030", 0.9)
	_xe([-4.6, -7 - e, -9, -13 - e, -7.6, -5.6 - e], l)
	_xe([-4, -7.5 - e, -7, -12.4 - e, -5.6, -6 - e], o)
	_L(0, -6 - e, 5.6, 4, o)
	_L(-0.8, -6.4 - e, 3.4, 2.2, l)
	var f := 4 + r * 0.5
	var s := -10 - e + r
	_L(f, s, 2.4, 2.4, o)
	_L(f - 0.3, s - 2.4, 1.3, 1.1, "#d8302a")
	_L(f + 0.6, s - 2.6, 0.9, 0.8, "#d8302a")
	_xe([f + 2, s - 0.5, f + 4.2, s + 0.3, f + 2, s + 1], "#e8a030")
	_L(f + 1.3, s + 2, 0.7, 1, "#d8302a")
	_L(f + 0.9, s - 0.5, 0.5, 0.5, "#1a120c")

func _vit(ph: float, mv: bool) -> void:   # RM.vit (xoay r làm ở _tf)
	var e := absf(sin(ph)) * 1.0 if mv else 0.0
	var o := maxf(0.0, sin(float(a.ph) * 1.5)) * 3.4 if not mv and int(a.get("act", 0)) == 1 else 0.0
	var l := _m("#f6f4ee", "#8e8c88")
	var c := _m("#d8d4ca", "#6a6864")
	var f := _m("#f09a2a", "#8a5a20")
	_Dt(-1, -2.6, -1.4, 0, f, 1.1)
	_Dt(1.4, -2.6, 1.8, 0, f, 1.1)
	_L(-1.4, 0, 1.6, 0.6, f)
	_L(1.8, 0, 1.6, 0.6, f)
	_L(-0.4, -5 - e, 6.4, 3.4, l)
	_xe([-6, -5.6 - e, -8.6, -8 - e, -6.6, -4 - e], l)
	_L(-1, -5.4 - e, 3.6, 2, c)
	var s := 4.4 + o * 0.4
	var h := -10.4 - e + o
	_Dt(3.4, -6.4 - e, s - 0.4, h + 1.4, l, 3)
	_L(s, h, 2.3, 2.1, l)
	_xe([s + 1.6, h - 0.2, s + 4.6, h + 0.6, s + 1.6, h + 1.3], f)
	_L(s + 0.7, h - 0.6, 0.5, 0.5, "#1a120c")

func _sao(ph: float, mv: bool) -> void:   # RM.sao
	var fly := int(a.get("fly", 0)) != 0
	var e := absf(sin(ph)) * 3.4 if mv and not fly else 0.0
	var r := _m("#2a2a30", "#141418")
	if fly:
		var o := sin(float(a.ph) * 2.2)
		_L(0, -8, 4, 2.4, r)
		_xe([-1, -9, -7, -14 - o * 5, 2, -9], r)
		_xe([0, -9, 6, -14 - o * 5, 3, -8], r)
		_L(-1, -11.5 - o * 3, 1.6, 1, "#ffffff")
		_L(4, -9, 1.2, 0.9, "#f2c63a")
		return
	_Dt(-0.6, -3 - e, -0.6, 0, "#e8c040", 0.9)
	_Dt(1.2, -3 - e, 1.2, 0, "#e8c040", 0.9)
	_xe([-3, -6 - e, -8, -4 - e, -3, -4 - e], r)
	_L(0, -5.4 - e, 4, 2.8, r)
	_L(-1, -6 - e, 1.8, 0.8, "#ffffff")
	_L(3.4, -8.4 - e, 2.2, 2, r)
	_xe([5.2, -8.8 - e, 7.8, -8 - e, 5.2, -7.4 - e], "#f2c63a")
	_L(3.8, -8.8 - e, 0.9, 0.7, "#f2c63a")
