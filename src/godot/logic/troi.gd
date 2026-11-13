extends RefCounted
# Trời đất chép từ bản web: buổi trong ngày (dh, ij), thời tiết đang có (ti, rQ, iQ), bảng màu theo mùa (mG, gX, OO).
# Luật ở đây; vẽ (màu nền, ánh sáng, mưa, chớp) là phần của thread làng: đọc G.troi.st mỗi khung hình.
# Thời tiết tính theo ngày + buổi 6 tiếng (Hx / Wd ở nv.gd), giống nhau trên mọi máy.

var G
var cur := ""          # ti.cur: "" lúc mới vào game
var slot := -1
var flash := 0.0       # chớp giông: 1 rồi tắt dần (x2,6 mỗi giây)
var fT := 0.0          # tới lần chớp sau
var thT := 0.0         # tới tiếng sấm
var an := 0
var _it := 0.0
var struck := false   # ti.struck: mỗi đợt giông sét đánh cây tối đa 1 lần
var bao               # bao.gd: cây ngã, sét đánh
var st := {}           # trạng thái gửi thread làng
var hh := -1.0         # web hh: đè giờ (thử)
var force := ""        # đè thời tiết (thử)

const BAO := {"nang": "Trời tạnh, nắng đẹp trở lại.",
	"mua": "Mưa dầm rả rích: ruộng vườn tự thấm nước, khỏi tưới. Đi lại chậm hơn, mặc Áo mưa (Tủ đồ) để đi nhanh.",
	"giong": "Giông bão kéo tới! Ruộng được tưới no nước nhưng gió quật ngã cây, nhớ ra dọn.",
	"han": "Nắng hạn gắt: ruộng khô nhanh gấp rưỡi, nhớ tưới thường xuyên. Đặt lu nước, giếng gần ruộng cho đỡ."}
# kX: hình đồng hồ theo buổi
const KX := {
	"day": '<svg viewBox="0 0 24 24"><circle cx="12" cy="12" r="4.6" fill="#f6b21b" stroke="#c98a0a" stroke-width="1.2"/><g stroke="#f0a60f" stroke-width="2" stroke-linecap="round"><path d="M12 2.6v2.4M12 19v2.4M2.6 12H5M19 12h2.4M5.4 5.4l1.7 1.7M16.9 16.9l1.7 1.7M5.4 18.6l1.7-1.7M16.9 7.1l1.7-1.7"/></g></svg>',
	"dawn": '<svg viewBox="0 0 24 24"><path d="M5 16a7 7 0 0 1 14 0z" fill="#ffb347" stroke="#d9822b" stroke-width="1.2"/><path d="M2.5 19.5h19" stroke="#8a6a4a" stroke-width="2" stroke-linecap="round"/><path d="M12 4.5v3M4.8 8.3l2 2M19.2 8.3l-2 2" stroke="#f0a060" stroke-width="2" stroke-linecap="round"/></svg>',
	"dusk": '<svg viewBox="0 0 24 24"><path d="M5 16a7 7 0 0 1 14 0z" fill="#ff8a4c" stroke="#c4562a" stroke-width="1.2"/><path d="M2.5 19.5h19" stroke="#7a5a4a" stroke-width="2" stroke-linecap="round"/><path d="M8 21.5h8" stroke="#c4562a" stroke-width="1.6" stroke-linecap="round"/></svg>',
	"night": '<svg viewBox="0 0 24 24"><path d="M19.5 14.6A8 8 0 0 1 9.4 4.5a8 8 0 1 0 10.1 10.1z" fill="#f2e6a8" stroke="#bfae5a" stroke-width="1.2" stroke-linejoin="round"/><circle cx="17.6" cy="6" r="1" fill="#f2e6a8"/><circle cx="20.4" cy="9.4" r="0.7" fill="#f2e6a8"/></svg>'}
const TEN := {"nang": "Nắng đẹp", "mua": "Mưa dầm", "giong": "Giông bão", "han": "Nắng hạn"}

# mG(night): bảng màu ngày / đêm; gX[mùa] đè lên một số màu
const MG := {"skyA": ["#8fd0f5", "#07122a"], "skyB": ["#eaf6e4", "#1a3a3d"], "grassA": ["#99cc56", "#2f6e44"], "grassB": ["#92c752", "#2a653d"],
	"path": ["#e3d09b", "#6a6046"], "soilDry": ["#a4764d", "#6a4a36"], "soilWet": ["#5e3d29", "#3b271b"], "water": ["#52aee3", "#2c6aa0"],
	"waterL": ["#a9dcf6", "#5c9cc8"], "leaf": ["#4d9a3a", "#2f7a3a"], "leaf2": ["#7bbf53", "#4f9a47"], "accent": ["#dba013", "#f0bd3d"]}
const GX := [
	{"grassA": ["#99cc56", "#2f6e44"], "grassB": ["#92c752", "#2a653d"], "skyB": ["#f4ecef", "#1a3a3d"]},
	{"grassA": ["#88c74a", "#2c6c3f"], "grassB": ["#82c246", "#286339"], "skyA": ["#6ec2f3", "#07122a"], "skyB": ["#e6f6ea", "#1a3a3d"]},
	{"grassA": ["#bcc45c", "#4b6a3a"], "grassB": ["#b0b853", "#456235"], "skyA": ["#9fcbe8", "#0b1428"], "skyB": ["#f7ead0", "#2a3434"]},
	{"grassA": ["#cdb07a", "#4e5236"], "grassB": ["#c5a872", "#494d33"], "skyA": ["#9ccbea", "#0b1428"], "skyB": ["#f5ebd3", "#2a3434"], "path": ["#dac697", "#5f5a4c"]}]
# lá / cánh hoa bay theo mùa (mX, HO): số hạt theo mức hiệu ứng [thấp, vừa, cao]; mùa hạ không có
const BAY := [[8, 15, 22], [0, 0, 0], [8, 15, 22], [6, 11, 16]]
const BAY_C := [["#f78fb3", "#ffc2d6", "#ffd42e", "#f06c9b", "#ffe066"], [], ["#e0a03a", "#c9702a", "#b5852f", "#d9b44a", "#a8532a"], ["#c9a24e", "#a8732a", "#d9b44a", "#8a6a2a", "#b98a3a"]]

func _init(game) -> void:
	G = game
	bao = load("res://logic/bao.gd").new(game)
	fT = randf_range(4.0, 9.0)

func hour() -> float:
	return G.nv.hour()

func dh() -> Dictionary:
	# buổi: đêm 19:30–5:30; sáng sớm tới 7:30 (ánh hồng), hoàng hôn từ 16:30 (ánh cam)
	var t := hour()
	var night := t >= 19.5 or t < 5.5
	var tint = null
	if not night:
		if t < 7.5:
			tint = [255, 168, 138, 0.5 * (7.5 - t) / 2.0]
		elif t >= 16.5:
			tint = [255, 116, 76, 0.62 * (t - 16.5) / 3.0]
	return {"h": t, "night": night, "tint": tint, "phase": "night" if night else ("dawn" if t < 7.5 else ("dusk" if t >= 16.5 else "day"))}

func ij(night: bool) -> Dictionary:
	# hướng nắng L (x, y, z) và màu nắng c theo giờ
	var t := hour()
	if night:
		return {"L": [-0.3, -0.45, 0.84], "c": [0.55, 0.62, 0.8]}
	var a := (t - 6.0) / 12.0 * PI
	var n := maxf(0.12, sin(PI * clampf((t - 5.5) / 13.0, 0.0, 1.0)))
	var e := sqrt(maxf(0.0, 1.0 - n * n))
	var r := Vector3(cos(a) * e, sin(a) * e, n).normalized()
	var l := 1.0 - minf(1.0, n / 0.55)
	return {"L": [r.x, r.y, r.z], "c": [1.0, 0.97 - 0.2 * l, 0.9 - 0.42 * l]}

static func _mix(a: String, b: String, k: float) -> String:   # Ml
	return "#" + Color(a).lerp(Color(b), k).to_html(false)

func pal(night: bool, sea: int) -> Dictionary:   # OO
	var e := {}
	for k in MG:
		e[k] = MG[k][1 if night else 0]
	for k in GX[sea]:
		e[k] = GX[sea][k][1 if night else 0]
	if not night and sea != 3 and cur == "han":
		e.grassA = _mix(e.grassA, "#dacf88", 0.36)
		e.grassB = _mix(e.grassB, "#d3c87e", 0.36)
		e.path = _mix(e.path, "#f2e6bc", 0.22)
	return e

func wx() -> String:
	return cur if cur != "" else (force if force != "" else G.nv.Wd())

func rainy() -> bool:   # DB
	var t := wx()
	return t == "mua" or t == "giong"

func dry_k() -> float:   # VB: hạn thì đất khô nhanh gấp rưỡi (1,6)
	return 1.6 if wx() == "han" else 1.0

func walk_k() -> float:   # KB: mưa x0,8, giông x0,7 (chưa có áo mưa ở bản Godot)
	return 0.7 if cur == "giong" else (0.8 if cur == "mua" else 1.0)

func rain() -> float:   # oj: lượng mưa cho shader nền
	return 1.0 if cur == "giong" else (0.7 if cur == "mua" else 0.0)

func step(dt: float) -> void:
	# rQ mỗi khung: chớp tắt dần; mỗi giây xét đổi thời tiết, mưa thì ruộng tự tưới
	if flash > 0.0:
		flash = maxf(0.0, flash - dt * 2.6)
	if thT > 0.0:
		thT -= dt
	bao.step(dt)
	_it -= dt
	if _it > 0.0:
		if cur == "giong":
			_iq(dt)
	else:
		_it = 1.0
		var a: int = G.day() * 4 + int(floor(hour() / 6.0))
		var n: String = force if force != "" else G.nv.Wd()
		var first := cur == ""
		if n != cur:
			cur = n
			struck = false
			slot = a
			if not first:
				G.toast.emit(BAO[n])
			G.changed.emit()
		var w: Dictionary = bao.wx()
		if n == "giong" and int(w.fs) != a:
			w.fs = a
			bao.storm(first)
		if n == "mua" or n == "giong":
			var ch := false
			for f in G.g.plots:
				if f.c != null and not G.ripe(f) and float(f.w) < G.water_hold(f) * 0.9:
					f.w = G.water_hold(f)
					ch = true
			if ch:
				G.mark()
	var d := dh()
	var sea: int = G.season()
	st = {"phase": d.phase, "h": d.h, "night": d.night, "tint": d.tint, "light": ij(d.night), "wx": cur, "rain": rain(),
		"flash": flash, "bolt": bao.bolt, "season": sea, "pal": pal(d.night, sea), "bay": BAY[sea], "bay_c": BAY_C[sea]}

func _iq(dt: float) -> void:
	# giông: chớp mỗi 5–13 giây, sấm sau 0,4–1,6 giây
	fT -= dt
	if fT > 0.0:
		return
	fT = randf_range(5.0, 13.0)
	flash = 1.0
	thT = randf_range(0.4, 1.6)
	if not struck and randf() < 0.12:
		struck = true
		bao.strike()
