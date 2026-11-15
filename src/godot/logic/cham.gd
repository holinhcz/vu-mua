extends Node
# CHẠM TRÊN ĐIỆN THOẠI (pointerdown / pointermove / pointerup của #stage bản web):
# - Zoom 2 ngón: lúc ngón thứ hai chạm ghi sp = {khoảng cách d, zoom z, điểm làng nằm giữa 2 ngón}, bỏ nhấn giữ đang chờ;
#   mỗi lần ngón nhích: zoom = sp.z x d / sp.d (trong giới hạn), điểm làng đó luôn nằm giữa 2 ngón. Tính từ chỗ ngón hiện tại,
#   không cộng dồn từng lần nhích; nền (main.gd) không tự zoom / kéo thêm khi đang 2 ngón.
# - Chuột giả: trình duyệt điện thoại bắn thêm sự kiện chuột sau mỗi lần chạm (web chỉ xét pointerType "mouse"): bỏ hết,
#   nên nhấn giữ không hiện chữ trỏ chuột, không kéo làng lần nữa theo chuột giả.
# Nút này nằm cuối cây nên nhận sự kiện trước mọi nút khác.

var farm
var T := {}          # ngón đang chạm: index -> vị trí
var sp = null
var last_touch := -1e9

func _now() -> float:
	return Time.get_ticks_msec()

func _mid() -> Dictionary:   # hH: khoảng cách (>= 10) và điểm giữa 2 ngón đầu
	var ks: Array = T.keys()
	var a: Vector2 = T[ks[0]]
	var b: Vector2 = T[ks[1]]
	return {"d": maxf(10.0, a.distance_to(b)), "m": (a + b) * 0.5}

func _input(e: InputEvent) -> void:
	if e is InputEventScreenTouch:
		last_touch = _now()
		if e.pressed:
			T[e.index] = e.position
		else:
			T.erase(e.index)
		if T.size() >= 2 and not _modal():
			var h := _mid()
			var M = farm.main
			sp = {"d": h.d, "z": M.zoom, "w": M.cam + h.m / M.zoom}
			farm._lp = {}
			farm.sw = null
		else:
			sp = null
		return
	if e is InputEventScreenDrag:
		last_touch = _now()
		T[e.index] = e.position
		if sp != null and T.size() >= 2:
			if _modal():
				sp = null
				return
			var h := _mid()
			var M = farm.main
			var z := clampf(float(sp.z) * float(h.d) / float(sp.d), M.zmin, M.zmax)
			M.zoom = z
			M.cam = sp.w - h.m / z
			if M.has_method("_clamp_cam"):
				M._clamp_cam()
			get_viewport().set_input_as_handled()
		return
	if (e is InputEventMouseButton or e is InputEventMouseMotion) and (T.size() > 0 or _now() - last_touch < 900.0):
		get_viewport().set_input_as_handled()   # chuột giả của trình duyệt sau khi chạm

func _modal() -> bool:   # bảng toàn màn đang mở: 2 ngón cuộn bảng, không zoom làng
	return bool(get_tree().get_meta("ui_modal", false))
