extends RefCounted
# ĐUA GÀ: hình. Cảnh một map (gói l/dg_map_<map>.wasm: mọi hình cảnh vật vẽ bằng chính code web, nền đường, dữ liệu đường)
# và khung hình từng con đua (l/dg_r_<id>.wasm nét đủ cho con mình chơi, l/dg_r_<id>_1.wasm nửa cỡ cho đối thủ):
# 17 góc nhìn (0 từ sau lưng .. 16 từ trước mặt, bên kia là lật ngang) x 8 nhịp chạy + 1 dáng đứng, nướng từ drawBirdView.
# Khung con đua giải mã khi cần (mỗi khung hình vài mili giây, giữ tối đa LRU_MAX khung), cảnh giải mã hết lúc vào đua.

const LRU_MAX := 320
const BUDGET_MS := 5.0

var P   # logic/pics.gd
var map_b := ""
var SM := {}        # tên hình cảnh -> {w,h,ax,ay,u}
var S := {}         # tên hình cảnh -> ImageTexture
var D := {}         # dữ liệu map
var RB := {}        # id con đua -> tên gói đang dùng
var RM := {}        # tên gói -> meta khung
var RT := {}        # "gói/f<i>" -> ImageTexture
var _lru: Array = []
var _q: Array = []
var _qs := {}
var _spr_left: Array = []
var gtex := {}      # mac, inf, dirt, grass, mask
var FX := {}        # gói dg_fx: ic_<món>, basket, cloud, puff0-2
var FXS := {}

func _init(pics) -> void:
	P = pics

func bundles_for(map_id: String, ids: Array, player_id: String) -> Array:
	var out := ["dg_map_" + map_id, "dg_r_npc_1", "dg_fx"]
	for id in ids:
		out.append(("dg_r_" + id) if id == player_id else ("dg_r_" + id + "_1"))
	for b in extra:
		if not out.has(b):
			out.append(b)
	return out

# extra: gói thêm (nón của con mình, con của bóng ma) — tải chung, tính vào tiến độ
var extra: Array = []
func request(map_id: String, ids: Array, player_id: String, ex := []) -> void:
	if map_b != "" and map_b != "dg_map_" + map_id:
		# đổi map: bỏ hình cảnh map cũ cho nhẹ bộ nhớ
		S = {}
		SM = {}
		gtex = {}
		P.B.erase(map_b)
	map_b = "dg_map_" + map_id
	RB = {}
	for id in ids:
		RB[id] = ("dg_r_" + id) if id == player_id else ("dg_r_" + id + "_1")
	RB["npc"] = "dg_r_npc_1"
	extra = ex
	for b in bundles_for(map_id, ids, player_id):
		P.load_bundle(b)

func ghost_as(id: String) -> void:
	# bóng ma: con ghi kỷ lục, dùng gói nửa cỡ (khóa "ghost")
	if RB.has(id):
		RB["ghost"] = RB[id]
	else:
		RB["ghost"] = "dg_r_" + id + "_1"

func progress(map_id: String, ids: Array, player_id: String) -> float:
	var bs := bundles_for(map_id, ids, player_id)
	var n := 0
	for b in bs:
		if P.has_bundle(b):
			n += 1
	return float(n) / bs.size()

func failed() -> bool:
	for b in P.B:
		if String(b).begins_with("dg_") and int(P.B[b].get("st", 0)) == 3:
			return true
	return false

# sau khi đủ gói: đọc dữ liệu map + giải nền đường; hình cảnh giải dần (pump)
func open_map() -> void:
	var m: Dictionary = P.meta(map_b)
	SM = m.get("spr", {})
	D = m.get("map", {})
	for k in ["mac", "inf"]:
		gtex[k] = _tex(map_b, k, true, false)
	for k in ["dirt", "grass", "mask"]:
		gtex[k] = _tex(map_b, k, true, false)
	_spr_left = SM.keys()
	FXS = P.meta("dg_fx").get("sz", {})
	for k in FXS:
		FX[k] = _tex("dg_fx", k, true, true)
	for b in RB.values():
		RM[b] = P.meta(b)

func sprites_done() -> bool:
	return _spr_left.is_empty()

func pump_sprites(ms: float) -> void:
	var t0 := Time.get_ticks_usec()
	while not _spr_left.is_empty() and (Time.get_ticks_usec() - t0) < ms * 1000.0:
		var k: String = _spr_left.pop_back()
		S[k] = _tex(map_b, k, true, true)

func _tex(b: String, k: String, mips: bool, fix: bool) -> ImageTexture:
	if not P.B.has(b) or int(P.B[b].get("st", 0)) != 2:
		return null
	var e = P.B[b]["idx"].get(k)
	if e == null:
		return null
	var o: int = int(P.B[b]["o"]) + int(e[0])
	var im := Image.new()
	if im.load_webp_from_buffer(P.B[b]["data"].slice(o, o + int(e[1]))) != OK:
		return null
	if im.get_format() != Image.FORMAT_RGBA8 and im.detect_alpha() != Image.ALPHA_NONE:
		im.convert(Image.FORMAT_RGBA8)
	if fix and im.get_format() == Image.FORMAT_RGBA8:
		im.fix_alpha_edges()
	if mips:
		im.generate_mipmaps()
	return ImageTexture.create_from_image(im)

func spr(name: String) -> Texture2D:
	return S.get(name)

# ---- đồ đội của con mình: gói l/dg_h_<id>.wasm, lớp nón / khăn / kính đè lên khung chạy (nướng bằng bake_hat.js)
var HT := {}
func hat_bundle(id: String) -> String:
	return "dg_h_" + id

func hat_meta(id: String) -> Dictionary:
	var b := hat_bundle(id)
	return P.meta(b) if P.has_bundle(b) else {}

func hat_tex(id: String, i: int) -> Texture2D:
	var key := id + "/" + str(i)
	var t = HT.get(key)
	if t == null:
		t = _tex(hat_bundle(id), "f" + str(i), true, true)
		if t != null:
			HT[key] = t
	return t

func fx(name: String) -> Texture2D:
	return FX.get(name)

func sm(name: String) -> Dictionary:
	return SM.get(name, {})

# ---- khung con đua
func rmeta(id: String) -> Dictionary:
	return RM.get(RB.get(id, ""), {})

# khung fi của con id: có thì trả về, chưa thì xếp hàng giải mã và trả null
func rframe(id: String, fi: int) -> Texture2D:
	var b: String = RB.get(id, "")
	var key := b + "/f" + str(fi)
	var t = RT.get(key)
	if t != null:
		return t
	if not _qs.has(key):
		_qs[key] = true
		_q.append([b, fi, key])
	return null

func prewarm(id: String, views: Array) -> void:
	var m := rmeta(id)
	if m.is_empty():
		return
	for k in views:
		var v: Dictionary = m.v[k]
		for fi in v.run:
			rframe(id, int(fi))
		rframe(id, int(v.st))

func pump(ms := BUDGET_MS) -> void:
	var t0 := Time.get_ticks_usec()
	while not _q.is_empty() and (Time.get_ticks_usec() - t0) < ms * 1000.0:
		var a: Array = _q.pop_front()
		_qs.erase(a[2])
		var t := _tex(a[0], "f" + str(a[1]), true, true)
		if t == null:
			continue
		RT[a[2]] = t
		_lru.append(a[2])
		if _lru.size() > LRU_MAX:
			RT.erase(_lru.pop_front())

func touch(key: String) -> void:
	# dùng lại: đưa xuống cuối hàng LRU (gọi thưa, chỉ khi khung đã có)
	var i := _lru.find(key)
	if i >= 0 and i < _lru.size() - 40:
		_lru.remove_at(i)
		_lru.append(key)

func free_all() -> void:
	S = {}
	RT = {}
	_lru = []
	_q = []
	_qs = {}
	gtex = {}
	FX = {}
