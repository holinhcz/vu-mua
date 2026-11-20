extends RefCounted
# ĐUA GÀ: một đường đua, xuất từ bản web bằng chính code web (tools/dg_build/ex_map.js): đường giữa mỗi 12 đơn vị
# (PX, PY, pháp tuyến, bề rộng, cầu, hàng rào), nước, dốc rơm, ngô, bó rơm, bùn, chỗ vịt qua, cảnh vật, cỏ ven đường.

var D := {}
var map := {}
var N := 0
var WORLD_W := 5200.0
var WORLD_H := 4200.0
var TSC := 0.5
var TXW := 2600
var TXH := 2100
var PX := PackedFloat32Array()
var PY := PackedFloat32Array()
var NX := PackedFloat32Array()
var NY := PackedFloat32Array()
var TA := PackedFloat32Array()
var WD := PackedFloat32Array()
var BR := PackedByteArray()
var FL := PackedByteArray()
var FR := PackedByteArray()
var ZN: Array = []
var RAMPS: Array = []
var PADS: Array = []
var BASKETS: Array = []
var STATIC_MUD: Array = []
var DUCK_SPOTS: Array = []
var AIM: Array = []
var OFFROAD := {}
var WATER: Array = []
var POND = null
var wide := false
var posts: Array = []
var tufts: Array = []
var decor: Array = []
var models: Array = []
var sky := {}
var SUN_L := [0.0, 0.0, 1.0]

func _init(d: Dictionary) -> void:
	D = d
	map = d.map
	N = int(d.N)
	WORLD_W = float(d.WORLD_W)
	WORLD_H = float(d.WORLD_H)
	TSC = float(d.TSC)
	TXW = int(d.TXW)
	TXH = int(d.TXH)
	PX = PackedFloat32Array(d.PX)
	PY = PackedFloat32Array(d.PY)
	NX = PackedFloat32Array(d.NX)
	NY = PackedFloat32Array(d.NY)
	TA = PackedFloat32Array(d.TA)
	WD = PackedFloat32Array(d.WD)
	BR = _bytes(d.BR)
	FL = _bytes(d.FL)
	FR = _bytes(d.FR)
	ZN = d.ZN
	RAMPS = d.RAMPS
	for r in RAMPS:
		r.i = int(r.i)
	PADS = d.PADS
	for p in PADS:
		p.i = int(p.i)
	BASKETS = d.BASKETS
	for b in BASKETS:
		b.i = int(b.i)
	STATIC_MUD = d.STATIC_MUD
	DUCK_SPOTS = d.DUCK_SPOTS
	AIM = d.AIM
	OFFROAD = d.OFFROAD
	WATER = map.water
	POND = map.pond
	wide = String(map.bridge.rail) == "both"
	posts = d.posts
	tufts = d.tufts
	decor = d.decor
	models = d.models
	sky = d.sky
	SUN_L = d.SUN_L

static func _bytes(a: Array) -> PackedByteArray:
	var b := PackedByteArray()
	b.resize(a.size())
	for i in a.size():
		b[i] = int(a[i])
	return b

static func seg_dist(px: float, py: float, ax: float, ay: float, bx: float, by: float) -> float:
	var dx := bx - ax
	var dy := by - ay
	var t := clampf(((px - ax) * dx + (py - ay) * dy) / (dx * dx + dy * dy), 0, 1)
	return Vector2(px - ax - dx * t, py - ay - dy * t).length()

func water_dist(x: float, y: float) -> float:
	var b := 1e9
	for w in WATER:
		var p: Array = w.pts
		for i in p.size() - 1:
			var d := seg_dist(x, y, p[i][0], p[i][1], p[i + 1][0], p[i + 1][1]) - float(w.w)
			if d < b:
				b = d
	return b

func in_pond(x: float, y: float, m := 0.0) -> bool:
	if POND == null:
		return false
	var dx := (x - float(POND.x)) / (float(POND.rx) + m)
	var dy := (y - float(POND.y)) / (float(POND.ry) + m)
	return dx * dx + dy * dy < 1

func in_water(x: float, y: float) -> bool:
	return water_dist(x, y) < 0 or in_pond(x, y, 0)

func fen(i: int) -> float:   # chỗ hàng rào / lan can đứng
	return WD[i] + 5.0 if BR[i] else WD[i] + 34.0

func clamp_w(i: int) -> float:   # gà chạy ra tới đâu thì hàng rào chặn
	return WD[i] + 1.0 if BR[i] else WD[i] + 18.0

func nearest(x: float, y: float, idx: int, back: int, fwd: int) -> int:
	var best := idx
	var bd := 1e18
	for k in range(-back, fwd + 1):
		var j := (idx + k + N) % N
		var dx := x - PX[j]
		var dy := y - PY[j]
		var d := dx * dx + dy * dy
		if d < bd:
			bd = d
			best = j
	if bd > (WD[best] * 3) * (WD[best] * 3):
		for j in N:
			var dx := x - PX[j]
			var dy := y - PY[j]
			var d := dx * dx + dy * dy
			if d < bd:
				bd = d
				best = j
	return best
