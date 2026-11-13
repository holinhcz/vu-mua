extends Node2D
# Full-map test: the village ground (cut into 384 px pieces at 6 levels of sharpness, 6 px per world unit at the
# sharpest) and every object (own picture each, 5 levels), drag + pinch/wheel zoom, frame meter. No game logic.
# Pieces come packed in bundle files (the host allows only ~500 files); each piece is decoded only when it is on
# screen, nearest the middle first, a few milliseconds per frame, and dropped again when memory runs over budget.

const BASE_PXU := 6.0        # level 0 = 6 picture pixels per world unit (the game's own sharpest sprite level)
const SUB := 384             # piece size in pixels
const GLEV := 6              # ground levels 0..5
const BASE_L := 4            # ground level always kept under everything (0.5 px/unit)
const DECODE_MS := 8.0       # decode budget per frame once the first view is sharp (40 ms before, under the loading text)
const NHTTP := 4
const BUILD := "78"          # shown in the meter = the artifact version it ships as (bump with every publish), so a stale copy on a phone is easy to spot

var info := {}
var base_url := ""
var cam := Vector2.ZERO      # world point at the top-left of the screen
var zoom := 1.0              # screen pixels per world unit
var zmin := 0.05
var zmax := 8.0
var dpr := 1.0
var budget_mb := 320.0

var lev_nodes := []          # Node2D per ground level
var obj_root: Node2D
var meter: Label
var meter_full := ""
var status: Label
var cover: ColorRect         # hides the map until the first view is sharp
var pbar_bg: ColorRect
var pbar: ColorRect

# bundles: name -> {st:0 queued/1 loading/2 ready/3 failed, data:PackedByteArray, ent:{key:[off,len]}, used:int, pri:float}
var bundles := {}
var have_bundle := {}        # name -> true for bundles that exist (from info.json)
var fetch_q := []            # bundle names waiting
var http_free := []
# ground pieces: "l_sx_sy" -> {spr:Sprite2D, mb:float, used:int}
var tiles := {}
# objects
var objs := []               # per object: {x,y,w,h,cx,cy,spr:Sprite2D, lev:int (loaded best), tex:{l:Texture2D}, used:int}
var decode_want := {}        # key -> [priority, kind, args]
var tex_mb := 0.0
var frame_no := 0
var jsw = null              # window, for test hooks (window.__gdcam = "x,y,zoom", window.__gdmeter)

# meter
var ft_last := 0
var pf_code := 0.0        # (b67) per 2 s window: script time of all _process (village + logic + UI), draw calls
var pf_draw := 0.0
var pf_code_shown := 0.0
var pf_draw_shown := 0.0
var ft_worst := 0.0
var ft_worst_shown := 0.0
var ft_win_start := 0
var ft_count := 0
var fps_shown := 0.0
var dec_ms_frame := 0.0
var dec_ms_worst := 0.0

func _ready() -> void:
	RenderingServer.set_default_clear_color(Color(0.52, 0.62, 0.36))
	dpr = DisplayServer.screen_get_scale()
	sway_off = _tflag("__nosw")
	if OS.has_feature("web"):
		var d = JavaScriptBridge.eval("window.devicePixelRatio||1")
		if d != null:
			dpr = float(d)
		base_url = str(JavaScriptBridge.eval("new URL('.', location.href).href"))
		jsw = JavaScriptBridge.get_interface("window")
	else:
		base_url = OS.get_environment("NT_BASE")
		if base_url == "":
			base_url = "http://localhost:8765/gdl/"
	zmax = max(1.955 * dpr, 2.55)
	for l in GLEV:
		var n := Node2D.new()
		n.z_index = -30 - l   # set per frame in _update_view
		add_child(n)
		lev_nodes.append(n)
	obj_root = Node2D.new()
	obj_root.z_index = 0
	obj_root.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	add_child(obj_root)
	var zf := ZFixer.new()   # (b56) after the logic's own sort each frame: puts its nodes at their web depth k
	zf.m = self
	zf.process_priority = 100
	add_child(zf)
	var pm0 := PMark.new()
	pm0.m = self
	pm0.process_priority = -1000000
	add_child(pm0)
	var pm1 := PMark.new()
	pm1.m = self
	pm1.first = false
	pm1.process_priority = 1000000
	add_child(pm1)
	get_tree().process_frame.connect(_pt_frame)
	# ban đêm: every village shader ends with night_col() (night.gdshaderinc); plain pictures share sprite_night
	night_mat = ShaderMaterial.new()
	night_mat.shader = load("res://sprite_night.gdshader")
	_nm(night_mat)
	night_raw = ShaderMaterial.new()   # (b54) a picture that IS the night frame of the export: same shader, no night formula
	night_raw.shader = night_mat.shader
	night_raw.set_shader_parameter("uNight", 0.0)
	var ui := CanvasLayer.new()
	add_child(ui)
	ui_layer = ui
	cover = ColorRect.new()
	cover.color = Color(0.043, 0.067, 0.059)
	ui.add_child(cover)
	pbar_bg = ColorRect.new()
	pbar_bg.color = Color(0.75, 0.84, 0.78, 0.18)
	ui.add_child(pbar_bg)
	pbar = ColorRect.new()
	pbar.color = Color(0.85, 0.70, 0.35)
	ui.add_child(pbar)
	meter = Label.new()
	meter.position = Vector2(8, 8) * dpr
	meter.add_theme_font_size_override("font_size", int(13 * dpr))
	meter.add_theme_color_override("font_color", Color(1, 1, 1))
	meter.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.85))
	meter.add_theme_constant_override("outline_size", int(4 * dpr))
	ui.add_child(meter)
	# Link 11-13: only one small line (version + fps) on screen; the full meter stays readable by the test hook __gdmeter
	status = Label.new()
	status.add_theme_font_size_override("font_size", int(15 * dpr))
	status.add_theme_color_override("font_color", Color(0.62, 0.70, 0.65))
	status.text = "Đang tải làng…"
	ui.add_child(status)
	_layout_cover(0.0)
	for k in NHTTP:
		var h := HTTPRequest.new()
		h.accept_gzip = false   # the browser already unpacked the body; unpacking again fails
		h.download_chunk_size = 1 << 20
		add_child(h)
		h.request_completed.connect(_on_http.bind(h))
		http_free.append(h)
	_get_json("info.json")

# ---------------------------------------------------------------- loading
var _json_req: HTTPRequest
func _get_json(name: String) -> void:
	_json_req = HTTPRequest.new()
	_json_req.accept_gzip = false   # the browser already unpacked the body; unpacking again fails
	add_child(_json_req)
	_json_req.request_completed.connect(func(res, code, _h, body):
		if res != HTTPRequest.RESULT_SUCCESS or code != 200:
			status.text = "Lỗi tải info.json (" + str(res) + "/" + str(code) + ")"
			return
		info = JSON.parse_string(body.get_string_from_utf8())
		_start())
	_json_req.request(base_url + name)

func _start() -> void:
	_op2_probe()
	var W: float = info["DW"] - info["ub"]
	var H: float = info["VW"] - info["hb"]
	var vs := get_viewport_rect().size
	_limits()
	zoom = clamp(dpr * 1.0, zmin, zmax)
	# sky behind the mountains at the top edge of the map (the game paints it; the pieces are clear there)
	# (b59) the sky is the web's bG(): drawn on the screen behind the whole village (sun / moon + stars, clouds)
	var skl := CanvasLayer.new()
	skl.layer = -1
	add_child(skl)
	var skb := SkyBG.new()
	skb.main = self
	if not _tflag("__nosky"):
		skl.add_child(skb)
	var hzn := Horizon.new()   # (b60) web TH.hz: mountains + tree line on the horizon over the cleared top edge
	hzn.main = self
	hzn.z_index = -39
	if not _tflag("__nohz"):
		add_child(hzn)
	var c := Vector2(info["start"][0], info["start"][1])
	cam = c - vs / zoom / 2
	# objects: one sprite each, in the game's draw order
	var o_list: Array = info["objs"]
	for j in o_list.size():
		var r: Array = o_list[j]
		var s := Sprite2D.new()
		s.centered = false
		s.material = night_mat
		s.position = Vector2(r[0], r[1])
		s.visible = false
		var okk: Array = info.get("ok", [])
		if j < okk.size():
			s.set_meta("k", float(okk[j]))   # (b56) the web's draw key: objects, scenery and the logic's things share one order
		obj_root.add_child(s)
		var od := {"x": r[0], "y": r[1], "w": r[2], "h": r[3], "spr": s, "lev": 99, "pc": str(r[7]) if r.size() > 7 else "", "op": info["op"][j]}
		if od["op"] != null and str(od["op"][0]) == "~hive":
			# (b51) tổ ong: drawn live by Godot from the web game's own hive code (aZ): no picture, bees fly round it
			var hv := HiveNode.new()
			hv.position = Vector2(float(od["op"][1]), float(od["op"][2]))
			hv.material = night_mat
			# the web hangs each hive in a tràm tree of the rừng tràm; those trees are not in the Godot village yet, so
			# the hives wait hidden (they would float on bare ground) until the logic adds the tràm forest
			hv.visible = false
			if s.has_meta("k"):
				hv.set_meta("k", s.get_meta("k"))
			obj_root.add_child(hv)
			s.queue_free()
			od["spr"] = hv
			od["hive"] = true
		if r.size() > 6 and SWAY_KIND.has(str(r[6])):
			# turns about the foot: the bottom centre, a little up (the picture runs past the foot by its shadow)
			od["piv"] = Vector2(float(r[0]) + float(r[2]) * 0.5, float(r[1]) + float(r[3]) * 0.88)
			s.position = od["piv"]
			s.self_modulate = Color(1, 1, 1, SWAY_A)
		objs.append(od)
	if info.get("native", false):
		_make_ground()
		_load_scenery()
		_load_leaves()
		_load_pond()
		_load_song()
	_load_water()

# ---------------------------------------------------------------- native ground (no captured pictures)
# Layer 1: the whole village diamond is wild grass from the game's texture; scenery is placed on top as sprites,
# one picture per kind (n/sc/<j>.webp), in the game's draw order (n/sc.json).
var ground: Node2D
var gparts := 0
var sc_root: Node2D
var sc_tex_n := 0
var sc_tex_have := 0
var sc_q := []
var sc_busy := 0
var sc_data := {}
var sc_spr := []   # per variant: list of sprites waiting for its picture
func _make_ground() -> void:
	_fetch("n/n2_codai.webp", func(b):
		var img := Image.new()
		if img.load_webp_from_buffer(b) != OK:
			status.text = "Lỗi ảnh cỏ"
			return
		img.generate_mipmaps()
		var mat := ShaderMaterial.new()
		mat.shader = load("res://ground.gdshader")
		_nm(mat)
		codai_tex = ImageTexture.create_from_image(img)   # hill top still reads it
		_load_lots(mat)
		_build_fall()
		var N0: Array = info["N"]
		mat.set_shader_parameter("uT", Vector4(info["ki"], info["hi"], N0[0], N0[2]))
		mat.set_shader_parameter("uTN", Vector2(N0[1] - N0[0], N0[3] - N0[2]))
		_fetch("n/roadcol.json", func(b3):
			var rc = JSON.parse_string(b3.get_string_from_utf8())
			var V := func(a) -> Vector3: return Vector3(a[0], a[1], a[2])
			for nm2 in ["G", "O", "RG", "RO"]:
				var arr := PackedVector3Array()
				for e in rc[nm2]:
					arr.append(V.call(e))
				mat.set_shader_parameter("r" + nm2, arr)
			for nm2 in ["S", "B", "E"]:
				mat.set_shader_parameter("e" + nm2 + "g", V.call(rc["ex"]["p" + nm2][0]))
				mat.set_shader_parameter("e" + nm2 + "o", V.call(rc["ex"]["p" + nm2][1]))
			gparts += 1)
		var RK := ["dat", "do", "cat", "soi", "gach", "da", "codai", "co", "dat2"]   # (n41) + wild grass, lawn, yard earth
		var rimg := {}
		for j in RK.size():
			var nm3: String = RK[j]
			_fetch(("n/n2_dat" if nm3 == "dat2" else ("n/n2_" if j >= 6 else "n/dg2_") + nm3) + ".webp", func(b4):
				var im4 := Image.new()
				if im4.load_webp_from_buffer(b4) != OK:
					status.text = "Lỗi ảnh đường " + nm3
					return
				im4.convert(Image.FORMAT_RGB8)
				im4.generate_mipmaps()
				rimg[nm3] = im4
				if rimg.size() == RK.size():
					var arr := []
					for nm4 in RK:
						arr.append(rimg[nm4])
					var ta := Texture2DArray.new()
					ta.create_from_images(arr)
					mat.set_shader_parameter("uRA", ta)
					gparts += 6)
		for nm in ["tile", "road"]:
			_fetch("n/" + nm + ".png", func(b2):
				var im2 := Image.new()
				if im2.load_png_from_buffer(b2) != OK:
					status.text = "Lỗi ảnh " + nm
					return
				mat.set_shader_parameter({"tile": "uTC", "road": "uRD"}[nm], ImageTexture.create_from_image(im2))
				if nm == "tile":
					tile_img = im2
					_build_pondwater()
				else: road_img = im2
				gparts += 2 if nm == "tile" else 1)
		# layer 4: ponds, canal, ditches (fields + the game's colours + bank detail textures)
		_fetch("n/pond.json", func(b5):
			var pj = JSON.parse_string(b5.get_string_from_utf8())
			var bx: Array = pj["box"]
			mat.set_shader_parameter("uPB", Vector4(bx[0], bx[1], bx[2], bx[3]))
			for nm5 in ["mid", "mudS", "dpc", "sky", "band", "lip", "mud", "face", "faceW", "faceD"]:
				var cc: Array = pj[nm5]
				mat.set_shader_parameter("p" + nm5.substr(0, 1).to_upper() + nm5.substr(1), Vector3(cc[0], cc[1], cc[2]))
			gparts += 1)
		for nm6 in ["pond.png", "pt1.webp", "pt2.webp", "pt3.png"]:
			var nmx: String = nm6
			_fetch("n/" + nmx, func(b6):
				var im6 := Image.new()
				var er := im6.load_png_from_buffer(b6) if nmx.ends_with(".png") else im6.load_webp_from_buffer(b6)
				if er != OK:
					status.text = "Lỗi ảnh " + nmx
					return
				if nmx != "pond.png":
					im6.generate_mipmaps()
				mat.set_shader_parameter({"pond.png": "uPF", "pt1.webp": "uPT1", "pt2.webp": "uPT2", "pt3.png": "uPT3"}[nmx], ImageTexture.create_from_image(im6))
				gparts += 1)
		var g := Polygon2D.new()
		var N: Array = info["N"]   # tile range F0, Uo, vo, Vl
		var ki: float = info["ki"]
		var hi: float = info["hi"]
		var P := func(s: float, h: float) -> Vector2: return Vector2(ki + (s - h) * 32.0, hi + (s + h) * 16.0)
		g.polygon = PackedVector2Array([P.call(N[0], N[2]), P.call(N[1], N[2]), P.call(N[1], N[3]), P.call(N[0], N[3])])
		g.material = mat
		g.z_index = -40
		add_child(g)
		ground = g)

# ---------------------------------------------------------------- bought land (n41, web ci()/tc() + NEN2 own()/tv())
# Which lot every tile belongs to (n/parcel.png), the lots' names and aliases, and the wild things that stand on unbought
# land (n/parcel.json). The ground's wild-grass zone takes 1 on unbought tiles; on bought ones only the rough round a wild
# bush that still stands next door. The game's land list is read from the logic (G.g.land) whenever it changes.
var lot_mat: ShaderMaterial = null
var lot_info := {}
var lot_idx := PackedByteArray()
var lot_nz: Image = null
var lot_tex: ImageTexture = null
var lot_land := {"nha": 1}
var lot_sig := ""
var lot_t := 0.0
var lot_spr := []
func _load_lots(mat: ShaderMaterial) -> void:
	lot_mat = mat
	var got := {}
	var go := func():
		if got.size() < 3:
			return
		lot_info = got["j"]
		lot_idx = got["p"].get_data()
		lot_nz = got["n"]
		lot_nz.convert(Image.FORMAT_RGBA8)
		var L: Array = lot_info["L2"]
		var L1: Array = lot_info["L1"]
		var L4: Array = lot_info["L4"]
		mat.set_shader_parameter("uNL", Vector4(L[0], L[1], L1[0], L1[1]))
		mat.set_shader_parameter("uNL4", Vector2(L4[0], L4[1]))
		_lot_apply()
		gparts += 1
	_fetch("n/parcel.json", func(b):
		got["j"] = JSON.parse_string(b.get_string_from_utf8())
		go.call())
	for nm in ["parcel", "nz"]:
		var nmx: String = nm
		_fetch("n/" + nmx + ".png", func(b):
			var im := Image.new()
			im.load_png_from_buffer(b)
			if nmx == "parcel":
				im.convert(Image.FORMAT_L8)
			got[{"parcel": "p", "nz": "n"}[nmx]] = im
			go.call())
func _owned(t: String) -> bool:
	if t == "nha":
		return true
	var tg: Dictionary = lot_info.get("tg", {})
	var a: String = tg.get(t, t)
	if lot_land.has(a):
		return true
	for n in tg.keys():
		if tg[n] == a and lot_land.has(n):
			return true
	return false
func _lot_vis(s: Node) -> bool:
	if s.has_meta("cay") and s.get_meta("cay"):
		return false
	if s.has_meta("xg") and s.get_meta("xg"):
		return false
	return not s.has_meta("pc") or not _owned(s.get_meta("pc"))
# called by the logic when a lot is bought; also polled, so a loaded save shows right
func land_changed(land) -> void:
	if land is Dictionary:
		lot_land = land.duplicate()
		lot_sig = _lot_key(lot_land)
		_lot_apply()
func _lot_key(d: Dictionary) -> String:
	var ks := d.keys()
	ks.sort()
	return ",".join(PackedStringArray(ks))
var lot_test := -1   # check page: ?lot=all shows every lot bought (no effect on the save)
func _lot_poll() -> void:
	lot_t += get_process_delta_time()
	if lot_t < 0.5:
		return
	lot_t = 0.0
	if lot_test < 0:
		lot_test = 0
		if OS.has_feature("web"):
			var q = JavaScriptBridge.eval("String(location.search)")
			if q is String and q.contains("lot=all"):
				lot_test = 1
	if lot_test == 1:
		if lot_sig != "all" and not lot_info.is_empty():
			var all := {}
			for n in lot_info["names"]:
				all[n] = 1
			land_changed(all)
			lot_sig = "all"
		return
	var G = get_node_or_null("/root/G")
	if G == null:
		return
	var g = G.get("g")
	if not (g is Dictionary) or not g.has("land"):
		return
	var k := _lot_key(g["land"])
	if k != lot_sig:
		land_changed(g["land"])
func _lot_apply() -> void:
	for s in lot_spr:
		if is_instance_valid(s) and s.texture != null:
			s.visible = _lot_vis(s)
	if lot_nz == null or lot_info.is_empty():
		return
	var names: Array = lot_info["names"]
	var own := []
	for n in names:
		own.append(_owned(n))
	var NN: Array = lot_info["N"]
	var W: int = NN[0]
	var H: int = NN[1]
	var F0: int = lot_info["F0"]
	var vo: int = lot_info["vo"]
	# rough grass round a wild thing that still stands (web zidx WR: own tile .95, ring .62)
	var wr := PackedFloat32Array()
	wr.resize(W * H)
	for w in lot_info["wild"]:
		if _owned(str(w[4])):
			continue
		for a in range(-1, int(w[2]) + 1):
			for b in range(-1, int(w[3]) + 1):
				var x: int = int(w[0]) + a - F0
				var y: int = int(w[1]) + b - vo
				if x < 0 or y < 0 or x >= W or y >= H:
					continue
				var inn := a >= 0 and b >= 0 and a < int(w[2]) and b < int(w[3])
				wr[y * W + x] = maxf(wr[y * W + x], 0.95 if inn else 0.62)
	# swept earth yards round houses, pavilions, shrines (NEN2 put()/YD), only for things that show
	var yd := PackedByteArray()
	yd.resize(W * H)
	for e in lot_info["yd"]:
		if str(e[6]) != "" and not _owned(str(e[6])):
			continue
		var r: int = e[4]
		var f: int = e[5]
		for a in range(-r, int(e[2]) + r + f):
			for b in range(-r, int(e[3]) + r + f):
				var x: int = int(e[0]) + a - F0
				var y: int = int(e[1]) + b - vo
				if x >= 0 and y >= 0 and x < W and y < H:
					yd[y * W + x] = 1
	var d := lot_nz.get_data()
	for y in H:
		for x in W:
			var p: int = lot_idx[y * W + x]
			var v := 1.0
			if p > 0 and own[p - 1]:
				v = 0.0 if yd[y * W + x] == 1 else wr[y * W + x]
			d[(y * 1024 + x) * 4 + 2] = int(round(v * 100.0)) + (128 if yd[y * W + x] == 1 else 0)   # B = wild*100 + 128 on a yard
	lot_nz.set_data(1024, 1024, false, Image.FORMAT_RGBA8, d)
	if lot_tex == null:
		lot_tex = ImageTexture.create_from_image(lot_nz)
		lot_mat.set_shader_parameter("uNZ", lot_tex)
	else:
		lot_tex.update(lot_nz)

# ---------------------------------------------------------------- weather, time of day, seasons (n44, web sQ / IO / OO)
# The logic (troi.gd) sends its state every frame; this side draws it like the web's top layer sQ: dawn / dusk tint,
# storm (dark wash, 120 rain streaks, flash, bolt), drought haze, leaves / petals blowing by season, and the season's
# grass colours for the lawn and the wild grass (NEN2 C.base / C.wild from OO grassA/grassB).
var troi := {}
var troi_fx: Node2D = null
var troi_grass := ""
func troi_set(st) -> void:
	if not (st is Dictionary):
		return
	troi = st
	if troi_fx == null:
		var cl := CanvasLayer.new()
		cl.layer = 5   # over the village, under the game's UI (layer 10)
		add_child(cl)
		troi_fx = TroiFX.new()
		troi_fx.main = self
		cl.add_child(troi_fx)
	if night_force < 0 and st.has("night") and int(bool(st["night"])) != night_cur:
		_night_tick()
	var pal = st.get("pal", null)
	# night darkening is the night shader's job: the grass keeps the season's DAY colours
	if pal is Dictionary and ground != null and not bool(st.get("night", false)):
		var key := str(pal.get("grassA", "")) + str(pal.get("grassB", "")) + str(st.get("season", 0))
		if key != troi_grass:
			troi_grass = key
			_troi_grass(pal, int(st.get("season", 0)))
# mưa: gợn vòng trên sông/ao theo lượng mưa (web oj x zf), đất ướt sẫm dần trong ~25 s, tạnh thì khô dần ~2 phút
var rain_wet := 0.0
var rain_rr := 0.0
var rain_sent := Vector2(-1, -1)
var rain_ms := 0
func _rain_tick(_d: float) -> void:
	_leaf_tick()
	_ss_tick()
	# wall clock, not frame delta: a slow phone frame must not slow the soil getting wet
	var now := Time.get_ticks_msec()
	var dt := clampf((now - rain_ms) / 1000.0, 0.0, 1.0) if rain_ms > 0 else 0.0
	rain_ms = now
	var r: float = float(troi.get("rain", 0.0))
	rain_rr = move_toward(rain_rr, r, dt / 3.0)
	rain_wet = move_toward(rain_wet, 1.0 if r > 0.0 else 0.0, dt / (25.0 if r > 0.0 else 120.0))
	var zf := smoothstep(0.3, 0.75, zoom / maxf(dpr, 0.01))
	var v := Vector2(snappedf(rain_rr * zf, 0.01), snappedf(rain_wet * (0.55 + 0.25 * r), 0.005))
	if v == rain_sent:
		return
	rain_sent = v
	if water != null and water.material != null:
		(water.material as ShaderMaterial).set_shader_parameter("uRain", v.x)
	if pond_water != null and pond_water.material != null:
		(pond_water.material as ShaderMaterial).set_shader_parameter("uRain", v.x)
	if ground != null and ground.material != null:
		(ground.material as ShaderMaterial).set_shader_parameter("uWet", v.y)
	if track_mat != null:
		track_mat.set_shader_parameter("uWet", v.y)
func _hexc(h: String) -> Vector3:
	var c := Color(h)
	return Vector3(c.r8, c.g8, c.b8)
func _mlc(a: Vector3, b: Vector3, t: float) -> Vector3:
	return Vector3(roundf(a.x * (1.0 - t) + b.x * t), roundf(a.y * (1.0 - t) + b.y * t), roundf(a.z * (1.0 - t) + b.z * t))
# NEN2.tex(): gain sqrt(target / texture mean) kept within .75..1.06, the rest an offset; +6/+3/+3 as tuned on screen
func _recol(mean: Vector3, t: Vector3) -> Array:
	var g := Vector3(clampf(sqrt(t.x / mean.x), 0.75, 1.06), clampf(sqrt(t.y / mean.y), 0.75, 1.06), clampf(sqrt(t.z / mean.z), 0.75, 1.06))
	var o := (t - mean * g) / 255.0 + Vector3(0.0235, 0.0122, 0.0119)
	return [g, o]
func _troi_grass(pal: Dictionary, sea: int) -> void:
	var b0 := _mlc(_hexc(pal["grassA"]), _hexc(pal["grassB"]), 0.5)
	var k3 := sea == 3
	var base := _mlc(b0, _hexc("#8a9248"), 0.26) if k3 else _mlc(b0, _hexc("#5a8236"), 0.22)
	var wild := _mlc(b0, _hexc("#9a9a50"), 0.38) if k3 else _mlc(b0, _hexc("#6f7a3a"), 0.52)
	var rw := _recol(Vector3(79.85, 88.23, 42.05), wild)
	var rc := _recol(Vector3(63.62, 98.56, 35.67), base)
	var m: ShaderMaterial = ground.material
	m.set_shader_parameter("gW", rw[0])
	m.set_shader_parameter("oW", rw[1])
	m.set_shader_parameter("gC", rc[0])
	m.set_shader_parameter("oC", rc[1])
	if track_mat != null:
		track_mat.set_shader_parameter("oY", Vector3(0.0129, 0.0074, 0.0044) if sea != 3 else Vector3(0.0129, 0.0074, 0.0044) + (Vector3(0xc9, 0xa8, 0x78) - Vector3(0xc2, 0xa2, 0x74)) / 255.0)
	m.set_shader_parameter("oY", Vector3(0.0129, 0.0074, 0.0044) if sea != 3 else Vector3(0.0129, 0.0074, 0.0044) + (Vector3(0xc9, 0xa8, 0x78) - Vector3(0xc2, 0xa2, 0x74)) / 255.0)

# the game's own hash (Me), JS number semantics
static func me_hash(t: int, a: int) -> float:
	var n := _i32(float(t) * 374761393.0 + float(a) * 668265263.0)
	var u := n & 0xffffffff
	n = _i32(float(_i32(n ^ (u >> 13))) * 1274126177.0)
	u = n & 0xffffffff
	return float((n ^ (u >> 16)) & 0xffffffff) / 4294967295.0
static func _i32(v: float) -> int:
	var x := int(fmod(v, 4294967296.0))
	x = x & 0xffffffff
	return x - 4294967296 if x >= 2147483648 else x

class TroiFX extends Node2D:
	var main
	var t := 0.0
	var leaves := []
	var leaf_sea := -1
	var bolt := PackedVector2Array()
	var bolt_on := false
	func _process(dt: float) -> void:
		if main.motion_off:
			dt = 0.0   # Cài đặt / Chuyển động tắt: the scene stands still (web he)
		t += dt
		var st: Dictionary = main.troi
		var k: float = main.dpr
		var W := get_viewport_rect().size.x / k
		var H := get_viewport_rect().size.y / k
		# leaves / petals (web IO)
		var bay = st.get("bay", [])
		var n: int = int(bay[main.fx_q]) if bay is Array and bay.size() > main.fx_q else 0
		var sea: int = int(st.get("season", 0))
		if sea != leaf_sea:
			leaf_sea = sea
			leaves.clear()
		var cols: Array = st.get("bay_c", [])
		while leaves.size() < n and cols.size() > 0:
			leaves.append(_leaf(W, H, cols, sea, true))
		while leaves.size() > n:
			leaves.pop_back()
		for i in leaves.size():
			var p: Dictionary = leaves[i]
			p.ph += dt
			p.x += (p.vx + sin(p.ph * 1.3) * 12.0) * dt
			p.y += p.vy * dt
			p.a += p.va * dt
			if p.y > H + 20.0 or p.x < -40.0:
				leaves[i] = _leaf(W, H, cols, sea, false)
		var fl: float = float(st.get("flash", 0.0))
		if fl > 0.7 and not bolt_on:
			bolt_on = true
			bolt = PackedVector2Array()
			var x := randf_range(W * 0.15, W * 0.85)
			var y := 0.0
			bolt.append(Vector2(x, y))
			while y < H * 0.35:
				y += randf_range(10.0, 26.0)
				x += randf_range(-14.0, 14.0)
				bolt.append(Vector2(x, y))
		elif fl <= 0.7:
			bolt_on = false
		queue_redraw()
	func _leaf(W: float, H: float, cols: Array, sea: int, first: bool) -> Dictionary:
		var r := (3.4 if sea >= 2 else 2.4) + randf() * 1.6
		return {"x": randf_range(-20.0, W + 100.0), "y": randf_range(-20.0, H) if first else -10.0, "vx": -randf_range(14.0, 38.0),
			"vy": randf_range(18.0, 40.0), "r": r, "a": randf() * TAU, "va": randf_range(-2.0, 2.0), "ph": randf() * 10.0,
			"c": Color(str(cols[randi() % cols.size()]))}
	func _draw() -> void:
		var st: Dictionary = main.troi
		if st.is_empty():
			return
		var k: float = main.dpr
		var W := get_viewport_rect().size.x / k
		var H := get_viewport_rect().size.y / k
		draw_set_transform(Vector2.ZERO, 0.0, Vector2(k, k))
		var R := Rect2(0, 0, W, H)
		var tint = st.get("tint", null)
		if tint is Array and tint.size() >= 4:
			draw_rect(R, Color(tint[0] / 255.0, tint[1] / 255.0, tint[2] / 255.0, float(tint[3])))
		var wx: String = str(st.get("wx", ""))
		if wx == "giong":
			draw_rect(R, Color(20 / 255.0, 30 / 255.0, 50 / 255.0, 0.2))
			var c := Color(200 / 255.0, 225 / 255.0, 1.0, 0.55)
			for i in 120:
				var x := fmod(main.me_hash(i, 5) * (W + 120.0) + t * 140.0, W + 120.0) - 60.0
				var y := fmod(main.me_hash(i, 6) * H + t * 560.0, H)
				draw_line(Vector2(x, y), Vector2(x - 9.0, y + 15.0), c, 1.3, true)
			var fl: float = float(st.get("flash", 0.0))
			if fl > 0.0:
				draw_rect(R, Color(235 / 255.0, 240 / 255.0, 1.0, 0.55 * fl * fl))
			if fl > 0.7 and bolt.size() > 1:
				draw_polyline(bolt, Color(1, 1, 1, 0.9), 2.0, true)
		elif wx == "han" and not bool(st.get("night", false)):
			draw_rect(R, Color(1.0, 190 / 255.0, 90 / 255.0, 0.03))
			var hc := Color(1.0, 240 / 255.0, 210 / 255.0, 0.12)
			for d in 14:
				var y0 := H * (0.2 + 0.06 * d) + sin(t * 1.3 + d) * 3.0
				var pts := PackedVector2Array()
				var x := 0.0
				while x <= W:
					pts.append(Vector2(x, y0 + sin(x * 0.03 + t * 2.0 + d) * 2.0))
					x += 8.0
				draw_polyline(pts, hc, 1.0, true)
		for p in leaves:
			draw_set_transform(Vector2(p.x, p.y) * k, p.a, Vector2(k, k))
			draw_colored_polygon(_ell(p.r, p.r * 0.5), p.c)
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	func _ell(rx: float, ry: float) -> PackedVector2Array:
		var a := PackedVector2Array()
		for i in 10:
			var q := i / 10.0 * TAU
			a.append(Vector2(cos(q) * rx, sin(q) * ry))
		return a

# fallen / burnt / young trees after a storm (logic bao.gd draws them): hide the standing tree picture at that tile
var cay_hidden := {}   # sk -> [sprites]
func cay_an(hide) -> void:
	if not (hide is Dictionary):
		return
	for sk in cay_hidden.keys():
		if not hide.has(sk):
			for sp in cay_hidden[sk]:
				if sp is int:
					objs[sp]["cay"] = false   # the object loop shows it again
				elif is_instance_valid(sp):
					sp.set_meta("cay", false)
					sp.visible = sp.texture != null and _lot_vis(sp)
			cay_hidden.erase(sk)
	var ki: float = info["ki"]
	var hi: float = info["hi"]
	for sk in hide.keys():
		if cay_hidden.has(sk):
			continue
		var e: Array = hide[sk]
		var gx: float = e[0]
		var gy: float = e[1]
		var fw: float = e[2]
		var fd: float = e[3]
		var ax := ki + (gx - gy) * 32.0 + (fw - fd) * 16.0
		var ay := hi + (gx + gy) * 16.0 + (fw + fd) * 8.0
		var got := []
		# scenery: anchored exactly at the tile's foot point
		if not sc_data.is_empty():
			var V: Array = sc_data["v"]
			for j in sc_spr.size():
				for sp in sc_spr[j]:
					var v = V[j]
					if v == null:
						continue
					var bx: float = sp.position.x - (0.0 if sp.has_meta("sw") else float(v[0]))
					var by: float = sp.position.y - (0.0 if sp.has_meta("sw") else float(v[1]))
					if absf(bx - ax) < 3.0 and absf(by - ay) < 3.0:
						got.append(sp)
		# objects: same kind, bottom centre nearest the foot point
		var best := -1
		var bd := 60.0
		var olist: Array = info["objs"]
		for j in objs.size():
			var r: Array = olist[j]
			if str(r[6]) != str(e[4]):
				continue
			var o: Dictionary = objs[j]
			var d := absf(o["x"] + o["w"] * 0.5 - ax) + absf(o["y"] + o["h"] - ay) * 0.5
			if d < bd:
				bd = d
				best = j
		for sp in got:
			sp.set_meta("cay", true)
			sp.visible = false
		if best >= 0:
			objs[best]["cay"] = true
			objs[best]["spr"].visible = false
			got.append(best)
		cay_hidden[sk] = got

func _load_scenery() -> void:
	# (b56) the web draws scenery, village objects, the player's things, plots and people in ONE list sorted by k (gx+gy,
	# BE() then a.sort(x.k-k.k)): what stands on a nearer tile covers what stands behind. So scenery lives in obj_root too.
	sc_root = obj_root
	if _tflag("__nosort"):   # b55 way: scenery in its own layer under everything standing
		sc_root = Node2D.new()
		sc_root.z_index = -10
		sc_root.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
		add_child(sc_root)
	var got := {}
	var go := func():
		if got.size() < 3:
			return
		_build_scenery(got["sc"], got["vg"], got["road"])
	_fetch("n/sc.json", func(body):
		got["sc"] = JSON.parse_string(body.get_string_from_utf8())
		go.call())
	_fetch("n/vg.json", func(body):
		got["vg"] = JSON.parse_string(body.get_string_from_utf8())
		go.call())
	_fetch("n/road.png", func(body):
		var im := Image.new()
		im.load_png_from_buffer(body)
		got["road"] = im
		go.call())

# Road verges (DUONG rows() + dg_rao draw): every edge of a road tile (earth band or laid road) that faces open land,
# not water, gets a row of the game's own grass, bush and wild-flower pictures (n/vg/<id>_<v>.webp), evenly spaced.
# Pure rule on the road map: lay a road and its verges follow.
var vg_tex := {}
var vg_rows := []
# ---------------------------------------------------------------- layer 4: what grows at the water (pondgen.gd rules)
class PondPics extends Node2D:
	var items := []   # [name, x, y, scale x (negative = mirrored), scale y]
	var meta := {}
	# every plant frame lives in ONE picture made in memory once (main._pi_atlas), so the phone draws all of them in a
	# few batches instead of one draw call per plant (3000 bank plants = 3000 calls made every tide step stutter)
	var atl: Texture2D = null
	var arect := {}
	func _draw() -> void:
		if atl == null:
			return
		for e in items:
			var r = arect.get(e[0])
			if r == null:
				continue
			var m: Array = meta[e[0]]
			draw_set_transform(Vector2(e[1], e[2]), 0.0, Vector2(e[3], e[4]))
			draw_texture_rect_region(atl, Rect2(m[0], m[1], m[2], m[3]), r)
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

# the pond and bank plant frames (n/pi/<name>.webp, separate files on disk) packed into one texture once they are all in:
# shelves sorted by height, 8 px clear gap so the mipmaps do not bleed; then every waiting PondPics node gets it
var pi_atlas: Texture2D = null
var pi_rect := {}
var pi_imgs := {}
var pi_want := 0
var pi_wait := []
func _pi_load(names: Array, node: PondPics) -> void:
	if pi_atlas != null:
		node.atl = pi_atlas; node.arect = pi_rect; node.queue_redraw()
		return
	pi_wait.append(node)
	if pi_want > 0:
		return
	pi_want = names.size()
	for nm in names:
		var nmx: String = nm
		_fetch_in("pi", nmx, func(b):   # v=2: lossless copies (11-13)
			var img := Image.new()
			if img.load_webp_from_buffer(b) != OK:
				img = Image.create(1, 1, false, Image.FORMAT_RGBA8)
			img.convert(Image.FORMAT_RGBA8)
			pi_imgs[nmx] = img
			if pi_imgs.size() == pi_want:
				_pi_pack())
func _pi_pack() -> void:
	var ks: Array = pi_imgs.keys()
	ks.sort_custom(func(a, b): return pi_imgs[a].get_height() > pi_imgs[b].get_height())
	var W := 2048
	var G := 8
	var x := G; var y := G; var rowh := 0
	var at := {}
	for k in ks:
		var im: Image = pi_imgs[k]
		if x + im.get_width() + G > W:
			x = G; y += rowh + G; rowh = 0
		at[k] = Vector2i(x, y)
		x += im.get_width() + G
		rowh = maxi(rowh, im.get_height())
	var H := y + rowh + G
	var big := Image.create(W, H, false, Image.FORMAT_RGBA8)
	for k in ks:
		var im: Image = pi_imgs[k]
		big.blit_rect(im, Rect2i(0, 0, im.get_width(), im.get_height()), at[k])
		pi_rect[k] = Rect2(Vector2(at[k]), Vector2(im.get_width(), im.get_height()))
	big.generate_mipmaps()
	pi_atlas = ImageTexture.create_from_image(big)
	tex_mb += W * H * 4 * 1.33 / 1048576.0
	print("plant atlas: ", ks.size(), " frames, ", W, "x", H)
	pi_imgs.clear()
	for n in pi_wait:
		if is_instance_valid(n):
			n.atl = pi_atlas; n.arect = pi_rect; n.queue_redraw()
	pi_wait.clear()

func _load_pond() -> void:
	var got := {}
	var go := func():
		if got.size() < 3:
			return
		var pj: Dictionary = got["json"]
		var im: Image = got["png"]
		var G = load("res://pondgen.gd").new()
		var bx: Array = pj["box"]
		G.X0 = bx[0]; G.Y0 = bx[1]; G.NX = int(bx[2]); G.NY = int(bx[3])
		G.ki = info["ki"]; G.hi = info["hi"]
		G.meta = got["meta"]
		G.F.resize(G.NX * G.NY); G.D.resize(G.NX * G.NY)
		for v in G.NY:
			for u in G.NX:
				var c := im.get_pixel(u, v)
				G.F[v * G.NX + u] = (c.r * 255.0 - 20.0) / 200.0
				G.D[v * G.NX + u] = (c.a * 255.0 - 20.0) / 200.0
		# (n16c) the brook left the fall's pool through a pinched neck: open it out into a funnel (field + picture)
		var nk0 := Vector2(4580.0, 572.0); var nk1 := Vector2(4556.0, 610.0)
		var gc: Vector2 = G.s2g((nk0.x + nk1.x) * 0.5, (nk0.y + nk1.y) * 0.5)
		var uc := int((gc.x - G.X0) * G.S); var vc := int((gc.y - G.Y0) * G.S)
		for v in range(maxi(vc - 24, 0), mini(vc + 25, G.NY)):
			for u in range(maxi(uc - 24, 0), mini(uc + 25, G.NX)):
				var P: Vector2 = G.scr(u, v)
				var ab := nk1 - nk0
				var t := clampf((P - nk0).dot(ab) / ab.dot(ab), 0.0, 1.0)
				var dd := P.distance_to(nk0 + ab * t)
				var r := lerpf(24.0, 15.0, t)
				if dd < r:
					var val := 0.5 + 0.3 * (1.0 - dd / r)
					var q: int = v * G.NX + u
					if val > G.F[q]:
						G.F[q] = val
						var c2 := im.get_pixel(u, v)
						c2.r = (val * 200.0 + 20.0) / 255.0
						im.set_pixel(u, v, c2)
		G.NH = str(pj.get("nh", "")).to_ascii_buffer()
		G.WILD = str(pj.get("wild", "")).to_ascii_buffer()
		G.BUSY = str(pj.get("busy", "")).to_ascii_buffer()
		for a in [G.NH, G.WILD, G.BUSY]:
			for i in a.size():
				a[i] = a[i] - 48
		# (n16) the shore was the bilinear outline of 4 samples a tile: a kink every 8 px ("lởm chởm"). The GPU gets the
		# field upsampled x2 with a cubic filter in half floats, so the outline bends smoothly (rules keep G.F)
		var im2 := im.duplicate()
		im2.convert(Image.FORMAT_RGBAF)
		im2.resize(im.get_width() * 2, im.get_height() * 2, Image.INTERPOLATE_CUBIC)
		im2.convert(Image.FORMAT_RGBAH)
		pond_cols = pj
		pond_G = G; pond_tex = ImageTexture.create_from_image(im2)
		pond_b = Vector4(bx[0], bx[1], bx[2], bx[3])
		var t0 := Time.get_ticks_msec()
		var r: Dictionary = G.build()
		print("pond rules: ", r["items"].size(), " items, ", Time.get_ticks_msec() - t0, " ms")
		var ni := PondPics.new()
		ni.material = night_mat
		ni.items = r["items"]; ni.meta = got["meta"]; ni.z_index = -35
		ni.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
		add_child(ni)
		_build_refl_pond()
		_build_fall()
		_build_pondwater()
		_pond_banks()
		_pi_load(got["meta"].keys(), ni)
	_fetch("n/pond.json", func(b):
		got["json"] = JSON.parse_string(b.get_string_from_utf8())
		go.call())
	_fetch("n/pi.json", func(b):
		got["meta"] = JSON.parse_string(b.get_string_from_utf8())
		go.call())
	_fetch("n/pond.png", func(b):
		var im := Image.new()
		if im.load_png_from_buffer(b) == OK:
			got["png"] = im
			go.call())

# ---------------------------------------------------------------- layer 5: river banks (songgen.gd rules)
class BankPics extends Node2D:
	# every op becomes triangles of one mesh (one draw call, painter order kept); UV = (texture mode, amount)
	var ops := []
	var mesh: ArrayMesh = null
	var white: Texture2D = null
	func build() -> void:
		var V := PackedVector2Array(); var Cc := PackedColorArray(); var U := PackedVector2Array()
		# UV.x = mode + 0.5 * e, where e runs 0 -> 1 across a strip quad (first edge -> second edge): the shader softens
		# both long edges over one screen pixel (the game's canvas drew antialiased edges); other shapes keep e = 0.5
		var EQ := [0.0, 0.0, 1.0, 1.0]
		var tri := func(P: PackedVector2Array, cv, mode: float, amt: float):
			var idx: PackedInt32Array
			var quad := P.size() == 4
			if quad:
				idx = PackedInt32Array([0, 1, 2, 0, 2, 3])
			elif P.size() == 3:
				idx = PackedInt32Array([0, 1, 2])
			else:
				idx = Geometry2D.triangulate_polygon(P)
			var per: bool = cv is PackedColorArray
			for i in idx:
				V.append(P[i])
				Cc.append(cv[i] if per else cv)
				U.append(Vector2(mode + 0.5 * (EQ[i] if quad else 0.5), amt))
		for o in ops:
			var P: PackedVector2Array = o[2]
			if o[0] == 0:
				tri.call(P, o[1], float(o[3]), o[4])
			else:
				for Q in _thick(P, o[5], o[6]):
					tri.call(Q, o[1], float(o[3]), o[4])
		var arr := []
		arr.resize(Mesh.ARRAY_MAX)
		arr[Mesh.ARRAY_VERTEX] = V
		arr[Mesh.ARRAY_COLOR] = Cc
		arr[Mesh.ARRAY_TEX_UV] = U
		mesh = ArrayMesh.new()
		mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)
		var im := Image.create(1, 1, false, Image.FORMAT_RGBA8)
		im.fill(Color.WHITE)
		white = ImageTexture.create_from_image(im)
		queue_redraw()
	func _draw() -> void:
		if mesh != null:
			draw_mesh(mesh, white)
	# a polyline as one quad per segment, widened by half the width at the ends (caps)
	static func _thick(P: PackedVector2Array, w: float, closed: bool) -> Array:
		var out := []
		var n := P.size()
		var hw := w * 0.5
		var m := n if closed else n - 1
		for j in m:
			var p0: Vector2 = P[j]
			var p1: Vector2 = P[(j + 1) % n]
			var d := p1 - p0
			if d.length() < 1e-6: continue
			var t := d.normalized() * hw
			var nv := Vector2(-t.y, t.x)
			if not closed:
				if j == 0: p0 -= t
				if j == m - 1: p1 += t
			out.append(PackedVector2Array([p0 + nv, p1 + nv, p1 - nv, p0 - nv]))
		return out

# Layer 5: river banks, rebuilt from the game's tables at one of its 7 tide steps (0 = full, 6 = lowest ebb).
# The step follows the clock like the game (12.42 h cycle, local time); the button cycles steps for checking.
var ui_layer: CanvasLayer = null
var song_got := {}
var tile_img: Image = null   # n/tile.png: A = kind * 16 + flags (for the flood's rice tips)
var road_img: Image = null   # n/road.png: R = road tier
var flood_force := -1        # nước nổi: -1 = the game's calendar (autumn days 2-6), 0 off, 1 on
var flood_btn: Button = null
var wimg_f: Image = null
var song_mat: ShaderMaterial = null
var song_lv := {}            # step -> [BankPics, PondPics], built once, kept
var song_cur := -1
var song_force := -1         # -1 = follow the clock
var song_btn: Button = null
var song_next_check := 0
func _tide_step() -> int:
	if song_force >= 0:
		return song_force
	# game: dk() = days since 2026-10-12 local * 24 + local hour; p6 = cos(dk / 12.42 * 2pi); step = round(sst(.55,-.35,p6) * 6)
	var bias: float = float(Time.get_time_zone_from_system().get("bias", 0))
	var loc := Time.get_unix_time_from_system() + bias * 60.0
	var p0 := 20738.0   # days from 1970-01-01 to 2026-10-12 (the game's pX)
	var dk := loc / 3600.0 - p0 * 24.0
	var p := cos(dk / 12.42 * PI * 2.0)
	var t := clampf((p - 0.55) / (-0.35 - 0.55), 0.0, 1.0)
	return int(roundf(t * t * (3.0 - 2.0 * t) * 6.0))
# the game's calendar (vr/t3/qs): local days since 2026-10-12, 28-day year of 4 seasons of 7 days; the flood (mu) comes
# in autumn (season 2) on days 2..6
# ban đêm like the game (dh(): night from 19:30 to 5:30 local time); -1 = clock, 0 day, 1 night
var night_force := -1
var night_mat: ShaderMaterial = null
var night_raw: ShaderMaterial = null
# cây đung đưa (web: plants with sway:1 turn about their foot, sin(t*1.1+ph)*.017 rad, only at zoom >= .7). One material
# for every picture (so they still batch): a swaying sprite has its local origin at its foot and alpha 254/255, which the
# shader reads as "sway" (and draws at full alpha)
const SWAY_A := 254.0 / 255.0
var sway_spr := []
var sway_on := false
var sway_off := false
var motion_off := false
var fx_q := 2
# Cài đặt (logic ui_set.gd): q = 0 Tiết kiệm, 1 Cân bằng, 2 Nét -> how many leaves / petals blow by (web BAY [low, mid, high])
func set_quality(q) -> void:
	fx_q = clampi(int(q), 0, 2)
func set_motion(_off) -> void:
	pass   # Link 11-13: motion always on, on every device, no switch
const SWAY_KIND := {"hibiscus": 1, "banana": 1, "bamboo": 1, "lotus": 1, "bougainvillea": 1, "coconut": 1, "areca": 1, "mango": 1,
	"reed": 1, "jackfruit": 1, "papaya": 1, "dieu": 1, "mai": 1, "dao": 1, "wildbanana": 1, "wildbush": 1, "tallgrass": 1, "tram": 1}
# below zoom .7 (css) the web stops the sway: the sprites go back to the one plain material so far views still batch
func _sway_tick() -> void:
	var on := zoom / maxf(dpr, 0.01) >= 0.7 and not sway_off and not motion_off

	if on == sway_on:
		return
	sway_on = on
	night_mat.set_shader_parameter("uSway", 1.0 if on else 0.0)
	night_raw.set_shader_parameter("uSway", 1.0 if on else 0.0)
var night_mats := []   # every material whose shader has uNight
var night_btn: Button = null
var night_cur := -1
func _nm(m: ShaderMaterial) -> void:
	night_mats.append(m)
	m.set_shader_parameter("uNight", 1.0 if night_cur == 1 else 0.0)
func _night_on() -> bool:
	if night_force >= 0:
		return night_force == 1
	if troi.has("night"):
		return bool(troi["night"])   # (n44) the logic's clock (web dh(), boot gio:21.5 works too)
	var t := Time.get_time_dict_from_system()
	var h: float = t["hour"] + t["minute"] / 60.0
	return h >= 19.5 or h < 5.5
func _night_tick() -> void:
	var on := _night_on()
	if int(on) != night_cur:
		night_cur = int(on)
		for m in night_mats:
			m.set_shader_parameter("uNight", 1.0 if on else 0.0)
		for o in objs:   # (b54) objects switch to / from their night pictures
			if o.has("op") and o["op"] != null:
				o["lev"] = 99
		_sc_night_apply()
	if night_btn == null:
		night_btn = Button.new()
		night_btn.visible = false
		night_btn.add_theme_font_size_override("font_size", int(13 * dpr))
		night_btn.position = Vector2(8, 136) * dpr
		night_btn.pressed.connect(func():
			# clock -> night -> day -> clock
			night_force = 1 if night_force < 0 else (0 if night_force == 1 else -1)
			_night_tick())
		ui_layer.add_child(night_btn)
		ui_layer.move_child(night_btn, 0)   # under the loading cover
	night_btn.text = "Trời: %s · %s" % ["đêm" if on else "ngày", "theo giờ" if night_force < 0 else "bấm đổi"]
func _flood_on() -> bool:
	if flood_force >= 0:
		return flood_force == 1
	var bias: float = float(Time.get_time_zone_from_system().get("bias", 0))
	var days := int(floor((Time.get_unix_time_from_system() + bias * 60.0) / 86400.0)) - 20738
	var t := posmod(days, 28)
	var day := t % 7 + 1
	return t / 7 == 2 and day >= 2 and day <= 6
func _flood_apply(on: bool) -> void:
	if water != null:
		water.material.set_shader_parameter("uFlood", 1.0 if on else 0.0)
	if refl_root != null:
		refl_root.material.set_shader_parameter("uFlood", 1.0 if on else 0.0)
		refl_root.visible = not on
	if refl_fl != null:
		refl_fl.visible = on
	if flood_btn != null:
		flood_btn.text = "Nước nổi: %s · %s" % ["có" if on else "không", "theo lịch" if flood_force < 0 else "bấm đổi"]
func _song_show(step: int) -> void:
	if song_got.size() < 2 or song_mat == null:
		return
	var fl := _flood_on() and wimg_f != null
	_flood_apply(fl)
	if fl: step = 7   # the flood replaces every tide (the game: L = 0, no banks drawn)
	if step != song_cur and not song_lv.has(step):
		var G = load("res://songgen.gd").new()
		G.ki = info["ki"]; G.hi = info["hi"]
		G.setup(song_got["song"], song_got["meta"], 0.0 if step == 7 else step / 6.0)
		if step == 7:
			G.F = true
			if tile_img != null and road_img != null:
				var N: Array = info["N"]
				var ti := tile_img
				var rim := road_img
				G.kindf = func(x: int, y: int) -> int:
					var i := x - int(N[0])
					var j := y - int(N[2])
					if i < 0 or j < 0 or i >= ti.get_width() or j >= ti.get_height(): return -1
					if j < rim.get_height() and i < rim.get_width() and rim.get_pixel(i, j).r8 > 0: return -1
					var k := ti.get_pixel(i, j).a8 / 16
					return k if (k == 0 or k == 1 or k == 3) else -1
		var t0 := Time.get_ticks_msec()
		G.build()
		var bk := BankPics.new()
		bk.ops = G.ops
		bk.z_index = -19
		bk.build()
		bk.material = song_mat
		var pl := PondPics.new()
		pl.material = night_mat
		pl.items = G.plants; pl.meta = song_got["meta"]; pl.z_index = -18
		_pi_load(song_got["meta"].keys(), pl)
		pl.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
		print("bank step ", step, ": ", G.ops.size(), " ops, ", G.plants.size(), " plants, ", Time.get_ticks_msec() - t0, " ms")
		add_child(bk); add_child(pl)
		song_lv[step] = [bk, pl]
	if step == song_cur:
		_song_label()
		return
	for k in song_lv.keys():
		var on: bool = (k == step)
		song_lv[k][0].visible = on
		song_lv[k][1].visible = on
	song_lv[step][1].queue_redraw()
	song_cur = step
	_song_label()
func _song_label() -> void:
	if song_btn != null and song_cur >= 0:
		var step := song_cur
		if step == 7:
			song_btn.text = "Nước sông: nước nổi tràn bờ"
			return
		var nm: Array = ["lớn", "lớn", "xuống", "lưng", "xuống", "ròng", "ròng cạn"]
		song_btn.text = "Nước sông: nấc %d/6 %s · %s" % [step, nm[step], "theo giờ" if song_force < 0 else "bấm đổi"]
func _song_tick() -> void:
	var now := Time.get_ticks_msec()
	if now < song_next_check:
		return
	song_next_check = now + 20000
	_night_tick()
	_song_show(_tide_step())
func _load_song() -> void:
	var go := func():
		if song_got.size() < 2:
			return
		song_mat = ShaderMaterial.new()
		song_mat.shader = load("res://bank.gdshader")
		_nm(song_mat)
		song_mat.set_shader_parameter("uKH", Vector2(info["ki"], info["hi"]))
		if wtex.has("flood.png"):
			song_mat.set_shader_parameter("uF", wtex["flood.png"])
			song_mat.set_shader_parameter("uFM", wmap)
		var GW = load("res://songgen.gd").new()
		GW.ki = info["ki"]; GW.hi = info["hi"]
		GW.setup(song_got["song"], song_got["meta"], 0.0)
		song_mat.set_shader_parameter("uWash", ImageTexture.create_from_image(GW.wash_image()))
		song_mat.set_shader_parameter("uWG", Vector3(GW.X0, GW.ST, GW.NJ))
		var dl: Color = GW.col("dull")
		song_mat.set_shader_parameter("uDull", Vector4(dl.r, dl.g, dl.b, 0.0))   # unbought-lot wash off (Link 2026-11-12)
		for nm in ["pt1.webp", "pt2.webp", "pt3.png", "pt4.png"]:
			var nmx: String = nm
			_fetch("n/" + nmx, func(b):
				var im := Image.new()
				var er := im.load_png_from_buffer(b) if nmx.ends_with(".png") else im.load_webp_from_buffer(b)
				if er == OK:
					im.generate_mipmaps()
					song_mat.set_shader_parameter("u" + nmx.substr(0, 3).to_upper(), ImageTexture.create_from_image(im)))
		song_btn = Button.new()
		song_btn.visible = false
		song_btn.add_theme_font_size_override("font_size", int(13 * dpr))
		song_btn.position = Vector2(8, 72) * dpr
		song_btn.pressed.connect(func():
			# clock -> 0 -> 1 ... -> 6 -> clock
			song_force = song_force + 1 if song_force < 6 else -1
			_song_show(_tide_step()))
		ui_layer.add_child(song_btn)
		ui_layer.move_child(song_btn, 0)   # under the loading cover
		flood_btn = Button.new()
		flood_btn.visible = false
		flood_btn.add_theme_font_size_override("font_size", int(13 * dpr))
		flood_btn.position = Vector2(8, 104) * dpr
		flood_btn.pressed.connect(func():
			# calendar -> on -> off -> calendar
			flood_force = 1 if flood_force < 0 else (0 if flood_force == 1 else -1)
			_song_show(_tide_step()))
		ui_layer.add_child(flood_btn)
		ui_layer.move_child(flood_btn, 0)
		_song_show(_tide_step())
		_pond_banks()
	_fetch("n/song.json", func(b):
		song_got["song"] = JSON.parse_string(b.get_string_from_utf8())
		go.call())
	_fetch("n/pi.json", func(b):
		song_got["meta"] = JSON.parse_string(b.get_string_from_utf8())
		go.call())

class VergeRow extends Node2D:
	var items := []   # [name, x, y, sc, flip]
	var meta := {}
	var tex := {}
	var atl: Texture2D = null   # zoomed out: the half-size scenery atlas (main._sc_pack), so every row batches
	var arect := {}
	func _draw() -> void:
		for e in items:
			var m: Array = meta[e[0]]
			draw_set_transform(Vector2(e[1], e[2]), 0.0, Vector2(-e[3] if e[4] else e[3], e[3]))
			if atl != null:
				var r = arect.get("v:" + e[0])
				if r != null:
					draw_texture_rect_region(atl, Rect2(m[0], m[1], m[2], m[3]), r)
				continue
			var t: Texture2D = tex.get(e[0])
			if t == null:
				continue
			draw_texture_rect(t, Rect2(m[0], m[1], m[2], m[3]), false)
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

func _h2(x: float, y: float) -> float:
	var n := sin(x * 127.1 + y * 311.7) * 43758.5453
	return n - floor(n)

func _verges(road: Image, meta: Dictionary) -> Array:
	var N: Array = info["N"]
	var ki: float = info["ki"]
	var hi: float = info["hi"]
	var W := road.get_width()
	var H := road.get_height()
	var tier := func(x: int, y: int) -> int:
		var i := x - int(N[0])
		var j := y - int(N[2])
		if i < 0 or j < 0 or i >= W or j >= H:
			return 0
		return road.get_pixel(i, j).r8
	var aflag := func(x: int, y: int) -> int:
		var i := x - int(N[0])
		var j := y - int(N[2])
		if i < 0 or j < 0 or i >= W or j >= H:
			return 0
		return road.get_pixel(i, j).a8
	var D4 := [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]
	var FL := ["h_muoi_gio", "h_dua_can", "h_ngu_sac", "h_mai_dia", "h_da_yen", "h_cuc_la_nho", "h_cuc_vang", "h_cuc_trang"]
	var NF := [0, 0, 1, 2, 0, 1, 0, 2]
	var out := []
	for y in range(int(N[2]), int(N[3])):
		for x in range(int(N[0]), int(N[1])):
			var t: int = tier.call(x, y)
			if t != 2 and t != 4:
				continue
			for dd: Vector2i in D4:
				var nx: int = x + dd.x
				var ny: int = y + dd.y
				if tier.call(nx, ny) != 0 or (aflag.call(nx, ny) >> 4) & 1 == 1:
					continue
				var ax: int = 0 if dd.x != 0 else 1
				var ay: int = 0 if dd.y != 0 else 1
				var ex: int = 0
				for e in [-1, 1]:
					var ki2: int = D4.find(Vector2i(ax * e, ay * e))
					if (aflag.call(x, y) >> ki2) & 1 == 1:
						ex |= 256 if e < 0 else 512
					elif tier.call(x + ax * e, y + ay * e) != 0 or tier.call(x + ax * e + dd.x, y + ay * e + dd.y) != 0:
						ex |= 2048 if e < 0 else 4096
				var vv: int = int(floor(_h2(x * 1.7 + dd.x, y * 2.3 + dd.y) * 8.0))
				var fv: int = int(floor(_h2(x * 5.3 - dd.y * 2.1, y * 0.7 + dd.x * 3.9) * 8.0))
				var d: bool = dd.x != 0
				var sd: float = 1.0 if (dd.x if dd.x != 0 else dd.y) > 0 else -1.0
				var u0: float = -0.85 if ex & 256 else (-0.56 if ex & 2048 else -0.5)
				var u1: float = 0.85 if ex & 512 else (0.56 if ex & 4096 else 0.5)
				var Q := []
				for j in 9:
					var uu: float = u0 + (u1 - u0) * j / 8.0
					var a: float = sd * 0.5 if d else uu
					var b: float = uu if d else sd * 0.5
					Q.append(Vector2((a - b) * 32.0, (a + b) * 16.0))
				var LQ := [0.0]
				var tot := 0.0
				for j in 8:
					tot += Q[j].distance_to(Q[j + 1])
					LQ.append(tot)
				var at2 := func(s0: float) -> Vector2:
					for m in 8:
						if s0 <= LQ[m + 1] or m == 7:
							var f: float = (s0 - LQ[m]) / max(1e-6, LQ[m + 1] - LQ[m])
							return Q[m] + (Q[m + 1] - Q[m]) * f
					return Q[8]
				var hh := func(k: float) -> float:
					var z := sin(k * 91.7 + vv * 47.3 + 3.1) * 4375.5
					return z - floor(z)
				var hf := func(k: float) -> float:
					var z := sin(k * 53.9 + fv * 71.3 + vv * 13.7 + 1.7) * 4375.5
					return z - floor(z)
				var ns: int = maxi(2, int(round(tot / 5.6)))
				var S := []
				for j in ns:
					var s0: float = (j + 0.5 + (hh.call(j + 3) - 0.5) * 0.35) / ns * tot
					var q: Vector2 = at2.call(s0)
					var r: float = hh.call(j + 11)
					var id: String = "bui_la" if r < 0.13 else ("c_lau" if r < 0.17 else "c_xanh")
					var sc: float = (0.36 + hh.call(j + 5) * 0.06) if id == "c_lau" else ((0.6 + hh.call(j + 5) * 0.12) if id == "bui_la" else (0.44 + hh.call(j + 5) * 0.14))
					S.append([id + "_" + str(int(floor(hh.call(j + 41) * 4.0))), q.x + (hh.call(j + 21) - 0.5) * 1.6, q.y + (hh.call(j + 31) - 0.5) * 1.2, sc, hh.call(j + 51) < 0.5])
				for j in NF[fv]:
					var q2: Vector2 = at2.call((0.15 + 0.7 * hf.call(200 + j)) * tot)
					S.append([FL[int(floor(hf.call(210 + j) * FL.size())) % FL.size()] + "_" + str(int(floor(hf.call(230 + j) * 4.0))), q2.x, q2.y + 0.6, 0.5 + hf.call(220 + j) * 0.1, hf.call(240 + j) < 0.5])
				S.sort_custom(func(p, q): return p[2] < q[2])
				var row := VergeRow.new()
				row.position = Vector2(ki + (x - y) * 32.0, hi + (x + y + 1) * 16.0)
				row.items = S
				row.meta = meta
				row.tex = vg_tex
				out.append([x + y + 1 + (0.47 if sd > 0 else -0.47), row])
	return out

func _build_scenery(sc: Dictionary, vmeta: Dictionary, road: Image) -> void:
	sc_data = sc
	var V: Array = sc_data["v"]
	for j in V.size():
		sc_spr.append([])
	var L := []
	for r in sc_data["i"]:
		L.append([float(r[4]), r])
	vg_meta = vmeta
	for e in _verges(road, vmeta):
		L.append([e[0], e[1]])
		vg_rows.append(e[1])
	L.sort_custom(func(a, b): return a[0] < b[0])
	for e in L:
		if e[1] is Node2D:
			e[1].material = night_mat
			e[1].set_meta("k", e[0])
			sc_root.add_child(e[1])
			continue
		var r: Array = e[1]
		var j: int = r[0]
		var v: Array = V[j]
		var s := Sprite2D.new()
		s.centered = false
		s.material = night_mat
		s.position = Vector2(r[1] + v[0], r[2] + v[1])
		if int(r[3]) == 1 and j != 16:
			s.position = Vector2(r[1], r[2])   # sway: local origin at the foot, the picture drawn by offset
			s.set_meta("sw", true)
			s.self_modulate = Color(1, 1, 1, SWAY_A)
		s.visible = false
		if r.size() > 5 and str(r[5]) != "":
			s.set_meta("pc", str(r[5]))   # (n41) wild bush/reed/stump: gone once its lot is bought
			lot_spr.append(s)
		s.set_meta("k", e[0])
		sc_root.add_child(s)
		sc_spr[j].append(s)
		if absf(float(r[1]) - 4636.0) < 1.0 and absf(float(r[2]) - 480.0) < 1.0 and float(v[2]) > 300.0:
			hill_spr = s
	if sc_root == obj_root:
		_zsort_all()
	for j in V.size():
		if V[j] != null and sc_spr[j].size() > 0:
			sc_q.append(j)
	for nm in vmeta.keys():
		sc_q.append(nm)
	sc_tex_n = sc_q.size()
	_pump_scenery()
	_build_refl()
	_build_fall()
	if road_pend.size() > 0:
		road_set(road_pend[0], road_pend[1])

func _pump_scenery() -> void:
	while sc_busy < 6 and sc_q.size() > 0:
		var j = sc_q.pop_front()
		sc_busy += 1
		if j is String:
			_fetch_in("vg", j, func(b):
				sc_busy -= 1
				var img := Image.new()
				if img.load_webp_from_buffer(b) == OK:
					_sc_keep_half("v:" + j, img)
					img.generate_mipmaps()
					vg_tex[j] = ImageTexture.create_from_image(img)
					tex_mb += img.get_width() * img.get_height() * 4 * 1.33 / 1048576.0
				sc_tex_have += 1
				if sc_tex_have == sc_tex_n:
					for row in vg_rows:
						row.queue_redraw()
					_sc_pack()
				_pump_scenery())
			continue
		# (b47) kinds that use the very same picture share one file: sc.json "f"[j] = the file it is read from
		var fj: int = int(sc_data["f"][j]) if sc_data.has("f") else j
		# v=12 on cao su 31-34: now the godot/caylang/caosu export d0-d3 (b49), the same set as its other seasons
		_fetch("n/sc/" + str(fj) + (".webp?v=11" if fj == 16 else ".webp?v=12" if fj >= 31 and fj <= 34 else ".webp?v=10"), func(b):   # 16 = the hill, lossless since 11-13   # v=9: pictures at the source's own px/unit (11-12), phones drop the old 6 px copies
			sc_busy -= 1
			var img := Image.new()
			if img.load_webp_from_buffer(b) == OK:
				_sc_keep_half(j, img)
				img.generate_mipmaps()
				var tex := ImageTexture.create_from_image(img)
				var v: Array = sc_data["v"][j]
				var k := Vector2(v[2] / img.get_width(), v[3] / img.get_height())
				sc_full[j] = [tex, k]
				for s in sc_spr[j]:
					s.texture = tex
					s.scale = k
					if s.has_meta("sw"):
						s.offset = Vector2(v[0] / k.x, v[1] / k.y)
					s.visible = _lot_vis(s)
				for s in sc_rspr.get(j, []):
					s.texture = tex
					s.scale = Vector2(k.x, -k.y)
					s.visible = _lot_vis(s)
				sc_rspr.erase(j)
				tex_mb += img.get_width() * img.get_height() * 4 * 1.33 / 1048576.0
			sc_tex_have += 1
			if sc_tex_have == sc_tex_n:
				_sc_pack()
				_sc_night_apply()
			_pump_scenery())

# Zoomed out, thousands of scenery pictures are on screen and each one has its own texture: the phone makes one draw
# call per picture (zoom 0.22: 6-24 fps). So every picture is also kept at half size, and once all are in they are
# packed into ONE texture in memory (the files stay separate). Below 2.4 screen px per map unit (half size is still
# sharp there) every sprite and verge row draws from that atlas and batches; closer in, the full pictures come back.
var sc_half := {}    # picture -> half-size Image, until packed
var sc_full := {}    # picture j -> [full texture, scale]
var sc_rall := {}    # picture j -> every reflection sprite of it
var sc_atl: Texture2D = null
var sc_arect := {}
var sc_far := -1
func _sc_keep_half(key, img: Image) -> void:
	var h := img.duplicate()
	h.resize(maxi(1, img.get_width() / 2), maxi(1, img.get_height() / 2), Image.INTERPOLATE_LANCZOS)   # sharp half (Link 11-13 "lớp mờ nào nữa")
	h.convert(Image.FORMAT_RGBA8)
	sc_half[key] = h
func _sc_pack() -> void:
	if sc_atl != null or sc_half.is_empty():
		return
	if _tflag("__noatl"):   # test switch: the headless test GPU runs out of memory on the 4096x6600 atlas
		return
	var ks: Array = sc_half.keys()
	ks.sort_custom(func(a, b): return sc_half[a].get_height() > sc_half[b].get_height())
	var W := 4096
	var G := 8
	var at := {}
	var H := 0
	for tries in 2:
		var x := G; var y := G; var rowh := 0
		at.clear()
		for k in ks:
			var im: Image = sc_half[k]
			if x + im.get_width() + G > W:
				x = G; y += rowh + G; rowh = 0
			at[k] = Vector2i(x, y)
			x += im.get_width() + G
			rowh = maxi(rowh, im.get_height())
		H = y + rowh + G
		if H <= 8192:
			break
		W = 8192
	var big := Image.create(W, H, false, Image.FORMAT_RGBA8)
	for k in ks:
		var im: Image = sc_half[k]
		big.blit_rect(im, Rect2i(0, 0, im.get_width(), im.get_height()), at[k])
		sc_arect[k] = Rect2(Vector2(at[k]), Vector2(im.get_width(), im.get_height()))
	big.generate_mipmaps()
	sc_atl = ImageTexture.create_from_image(big)
	tex_mb += W * H * 4 * 1.33 / 1048576.0
	print("scenery atlas: ", ks.size(), " pictures, ", W, "x", H)
	sc_half.clear()
	sc_far = -1
func _sc_mode() -> void:
	if sc_atl == null:
		return
	var far := sc_far
	if zoom < 2.4: far = 1      # half size of the 5 px/unit trees = 2.5 px/unit: still >= the screen below 2.4
	elif zoom > 2.6: far = 0
	elif far < 0: far = 0
	if far == sc_far:
		return
	sc_far = far
	for j in sc_full.keys():
		if night_cur == 1 and sc_ntex.get(j) != null:
			continue   # (b54) drawn from its own night picture
		var full: Array = sc_full[j]
		var r = sc_arect.get(j)
		var v: Array = sc_data["v"][j]
		var use := far == 1 and r != null
		var k: Vector2 = Vector2(v[2] / r.size.x, v[3] / r.size.y) if use else full[1]
		for sp in sc_spr[j]:
			_sc_set(sp, use, full[0], r, k)
			if sp.has_meta("sw"):
				sp.offset = Vector2(v[0] / k.x, v[1] / k.y)
		for sp in sc_rall.get(j, []):
			if is_instance_valid(sp) and sp.texture != null:
				_sc_set(sp, use, full[0], r, Vector2(k.x, -k.y))
	for row in vg_rows:
		row.atl = sc_atl if far == 1 else null
		row.arect = sc_arect
		row.queue_redraw()
# (b54) scenery that is a godot/ export frame (sc.json "n" = file numbers, tools/nightsc.py) uses the export's NIGHT frame
# n/sc/<f>n.webp at night (same crop and size as the day one), without the night formula; the others keep the formula.
var sc_ntex := {}
func _sc_night_apply() -> void:
	if sc_tex_have < sc_tex_n or sc_tex_n == 0:
		return
	var N: Dictionary = sc_data.get("n", {})
	for j in sc_full.keys():
		var fj: int = int(sc_data["f"][j]) if sc_data.has("f") else j
		if not N.has(str(fj)):
			continue
		if night_cur == 1:
			if not sc_ntex.has(j):
				sc_ntex[j] = null
				_fetch("n/sc/" + str(fj) + "n.webp", func(b):
					var img := Image.new()
					if img.load_webp_from_buffer(b) != OK:
						return
					img.generate_mipmaps()
					sc_ntex[j] = ImageTexture.create_from_image(img)
					tex_mb += img.get_width() * img.get_height() * 4 * 1.33 / 1048576.0
					_sc_night_set(j))
			else:
				_sc_night_set(j)
		else:
			for sp in sc_spr[j]:
				sp.material = night_mat
	if night_cur != 1:
		sc_far = -1
		_sc_mode()
		if sc_atl == null:
			for j in sc_full.keys():
				for sp in sc_spr[j]:
					sp.texture = sc_full[j][0]
func _sc_night_set(j) -> void:
	var t: Texture2D = sc_ntex.get(j)
	if t == null or night_cur != 1:
		return
	var full: Array = sc_full[j]
	var v: Array = sc_data["v"][j]
	for sp in sc_spr[j]:
		sp.texture = t
		sp.region_enabled = false
		sp.scale = full[1]
		if sp.has_meta("sw"):
			sp.offset = Vector2(v[0] / full[1].x, v[1] / full[1].y)
		sp.material = night_raw
func _sc_set(sp: Sprite2D, use: bool, full: Texture2D, r, k: Vector2) -> void:
	if use:
		sp.texture = sc_atl
		sp.region_enabled = true
		sp.region_rect = r
	else:
		sp.texture = full
		sp.region_enabled = false
	sp.scale = k

# ---------------------------------------------------------------- river (shader v5)
var water: Node2D
var wtex := {}
# Small pictures of one kind travel in one container (n/<pack>.wasm: u32 json length, json {name: [offset, length]},
# then each picture's own webp bytes unchanged), so the artifact stays under its file count; each picture stays its own file
var packs := {}
func _fetch_in(pack: String, name: String, cb: Callable) -> void:
	if packs.has(pack):
		var P = packs[pack]
		if P is Array:
			P.append([name, cb])
			return
		var e = P["i"].get(name)
		if e != null:
			cb.call(P["b"].slice(P["o"] + int(e[0]), P["o"] + int(e[0]) + int(e[1])))
		return
	packs[pack] = [[name, cb]]
	_fetch("n/" + pack + ".wasm?v=1", func(b: PackedByteArray):
		var jl := b.decode_u32(0)
		var waiting: Array = packs[pack]
		packs[pack] = {"i": JSON.parse_string(b.slice(4, 4 + jl).get_string_from_utf8()), "b": b, "o": 4 + jl}
		for w in waiting:
			_fetch_in(pack, w[0], w[1]))
# At start dozens of files are asked for at once; a browser can refuse some (ERR_INSUFFICIENT_RESOURCES, seen 11-13 on the
# ground's own textures = white ground). So at most 8 run at a time, the rest wait their turn, and a failed one is
# asked again (5 tries, waiting longer each time).
var fq := []
var f_run := 0
func _fetch(name: String, cb: Callable, tries: int = 0, prio: bool = false) -> void:
	if f_run >= 8:
		if prio:
			fq.push_front([name, cb, tries])
		else:
			fq.append([name, cb, tries])
		return
	f_run += 1
	var h := HTTPRequest.new()
	h.accept_gzip = false   # the browser already unpacked the body; unpacking again fails
	add_child(h)
	h.request_completed.connect(func(res, code, _hd, body):
		h.queue_free()
		f_run -= 1
		if res == HTTPRequest.RESULT_SUCCESS and code == 200:
			cb.call(body)
		elif tries < 5 and code != 404:
			get_tree().create_timer(0.5 * (tries + 1)).timeout.connect(func(): _fetch(name, cb, tries + 1))
		else:
			status.text = "Lỗi tải " + name
		while f_run < 8 and fq.size() > 0:
			var q: Array = fq.pop_front()
			_fetch(q[0], q[1], q[2]))
	if h.request(base_url + name) != OK:
		h.queue_free()
		f_run -= 1
		get_tree().create_timer(0.5 * (tries + 1)).timeout.connect(func(): _fetch(name, cb, tries + 1))

func _load_water() -> void:
	if not info.has("river"):
		return
	_fetch("w/riv.json", func(body):
		var rj = JSON.parse_string(body.get_string_from_utf8())
		var need := ["mapA.png", "mapB.png", "refl.webp", "noise.png", "flood.png"]
		for nm in need:
			_fetch("w/" + nm, func(b):
				var img := Image.new()
				var ok := img.load_png_from_buffer(b) if nm.ends_with(".png") else img.load_webp_from_buffer(b)
				if ok != OK:
					status.text = "Lỗi ảnh " + nm
					return
				if nm == "noise.png":
					img.generate_mipmaps()
				if nm == "mapA.png":
					wimg_a = img
				if nm == "flood.png":
					wimg_f = img
				wtex[nm] = ImageTexture.create_from_image(img)
				if wtex.size() == need.size():
					_make_water(rj)))

func _make_water(rj: Dictionary) -> void:
	var mat := ShaderMaterial.new()
	mat.shader = load("res://water.gdshader")
	_nm(mat)
	mat.set_shader_parameter("uA", wtex["mapA.png"])
	mat.set_shader_parameter("uB", wtex["mapB.png"])
	mat.set_shader_parameter("uR", wtex["refl.webp"])
	mat.set_shader_parameter("uN", wtex["noise.png"])
	mat.set_shader_parameter("uMap", Vector4(rj["x"], rj["y"], rj["w"], rj["h"]))
	var rf: Array = info["refl"]
	mat.set_shader_parameter("uRef", Vector4(rf[0], rf[1], rf[2], rf[3]))
	var dp: Array = rj["deep"]
	var sh: Array = rj["shal"]
	mat.set_shader_parameter("uDeep", Vector3(dp[0], dp[1], dp[2]) / 255.0)
	mat.set_shader_parameter("uShal", Vector3(sh[0], sh[1], sh[2]) / 255.0)
	mat.set_shader_parameter("uGain", Vector3(0.88, 0.914, 0.916))
	mat.set_shader_parameter("uDbg", Vector4(1, 1, 0, 1))
	mat.set_shader_parameter("uF", wtex["flood.png"])
	if song_mat != null:
		song_mat.set_shader_parameter("uF", wtex["flood.png"])
		song_mat.set_shader_parameter("uFM", Vector4(rj["x"], rj["y"], rj["w"], rj["h"]))
	water = WaterRect.new()
	water.rect = Rect2(rj["x"], rj["y"], rj["w"], rj["h"])
	water.material = mat
	water.z_index = -21   # over the blurry fallback levels, under the tree reflections (-20) and the banks
	add_child(water)
	wmap = Vector4(rj["x"], rj["y"], rj["w"], rj["h"])
	_build_refl()
	_build_pondwater()
	if song_cur >= 0: _song_show(_tide_step())   # the flood may be waiting for the flood map

# ---------------------------------------------------------------- tree reflections
# every scenery picture whose foot stands within reach of the river gets an upside-down copy, mirrored about a line
# half way from its foot down to the water, so the mirrored foot sits on the waterline (refl.gdshader clips it to
# the water and sways it)
var wimg_a: Image = null
var wmap := Vector4()
var refl_root: Node2D = null
var sc_rspr := {}   # variant -> reflection sprites waiting for its picture
var refl_fl: Node2D = null   # the set used in the flood (nước nổi)
# the hill fall's moving water (fall.gdshader, the game's v739 shader); the game's hill W: xw 4624, lip 301, base 536,
# pool 554, ledge = base - HP.H1 - 1
class FallFX extends Node2D:
	var rect := Rect2()
	var mat: ShaderMaterial = null
	func _ph(tm: float, r: float) -> float:
		var q := tm * r
		return q - floorf(q / 32.0) * 32.0
	func _process(_d: float) -> void:
		var tm := Time.get_ticks_msec() / 1000.0
		var K := 5.0
		mat.set_shader_parameter("uF", Vector4(_ph(tm, K), _ph(tm, K * 2.0), _ph(tm, K * 4.0), _ph(tm, 2.5)))
		mat.set_shader_parameter("uB", Vector4(_ph(tm, 0.9), _ph(tm, 1.6), _ph(tm, 0.45), _ph(tm, 0.8)))
		mat.set_shader_parameter("uD", Vector4(_ph(tm, 0.75), _ph(tm, K * 0.5), 0.0, 0.0))
		mat.set_shader_parameter("uK", Vector4(K, fmod(tm * 0.3, 1.0), fmod(tm * 0.5, 1.0), fmod(tm, 64.0)))
	func _draw() -> void:
		draw_rect(rect, Color.WHITE)
var fall_fx: FallFX = null
var codai_tex: ImageTexture = null
var hill_spr: Sprite2D = null
func _build_fall() -> void:
	if fall_fx != null or pond_tex == null or hill_spr == null or codai_tex == null:
		return
	var xw := 4624.0; var lip := 301.0; var base := 536.0; var pool := 554.0
	var fm := ShaderMaterial.new()
	fm.shader = load("res://fall.gdshader")
	_nm(fm)
	fm.set_shader_parameter("uW", Vector2(xw, lip))
	fm.set_shader_parameter("uG", Vector4(base - 116.0 - 1.0 - lip, base - lip, pool - lip, 0.0))
	fm.set_shader_parameter("uPF", pond_tex)
	fm.set_shader_parameter("uPB", pond_b)
	fm.set_shader_parameter("uKH", Vector2(pond_G.ki, pond_G.hi))
	fall_fx = FallFX.new()
	fall_fx.mat = fm
	fall_fx.material = fm
	fall_fx.rect = Rect2(xw - 130.0, lip - 16.0, 260.0, pool + 60.0 - (lip - 16.0))
	# drawn right after the hill picture: over the cliff, under everything standing in front of it (the game's ovl())
	sc_root.add_child(fall_fx)
	sc_root.move_child(fall_fx, hill_spr.get_index() + 1)
	_fall_particles(xw, lip, base)
	# the pool rocks, cut out of the hill picture (tools/fallrock.py), lie OVER the fall's foam: the water breaks round them
	_fetch("n/fallrock.webp?v=2", func(bq):
		var iq0 := Image.new()
		if iq0.load_webp_from_buffer(bq) != OK:
			return
		# (n16) room below the rocks for their reflection and foam ring on the water (fallrock.gdshader)
		iq0.convert(Image.FORMAT_RGBA8)
		var iq := Image.create(iq0.get_width(), iq0.get_height() + 40, false, Image.FORMAT_RGBA8)
		iq.blit_rect(iq0, Rect2i(0, 0, iq0.get_width(), iq0.get_height()), Vector2i.ZERO)
		var rs := Sprite2D.new()
		rs.centered = false
		rs.texture = ImageTexture.create_from_image(iq)
		rs.scale = Vector2.ONE / 6.0
		rs.position = hill_spr.position + Vector2(569.0, 1868.0) / 6.0
		var rm := ShaderMaterial.new()
		rm.shader = load("res://fallrock.gdshader")
		_nm(rm)
		rs.material = rm
		fall_fx.mat.set_shader_parameter("uRk", rs.texture)
		fall_fx.mat.set_shader_parameter("uRkR", Vector4(rs.position.x, rs.position.y, iq.get_width() / 6.0, iq.get_height() / 6.0))
		fall_fx.add_child(rs)
		if fall_mist != null:
			fall_fx.move_child(fall_mist, -1))
	# the hill's flat lime top -> the village's grass (hilltop.gdshader), right on the hill picture, under the fall
	_fetch("n/hilltop.webp", func(bt):
		var it := Image.new()
		if it.load_webp_from_buffer(bt) != OK:
			return
		var hm := ShaderMaterial.new()
		hm.shader = load("res://hilltop.gdshader")
		_nm(hm)
		hm.set_shader_parameter("uCodai", codai_tex)
		var ht := Sprite2D.new()
		ht.centered = false
		ht.texture = ImageTexture.create_from_image(it)
		ht.scale = Vector2.ONE / 6.0
		ht.position = hill_spr.position + Vector2(622.0, 0.0) / 6.0
		ht.material = hm
		sc_root.add_child(ht)
		sc_root.move_child(ht, hill_spr.get_index() + 1))
# (n16, Link "godot mày đéo có hiệu ứng riêng cho thác à"): the fall's motion from Godot particles (like the xưởng
# fire/smoke) over the shader sheet: white streaks racing down the curtain, drops thrown up where it lands, a cloud of
# spray drifting off the pool. Textures made here; all children of fall_fx (same place in the draw order).
var fall_mist: CPUParticles2D = null
func _ptex(w: int, h: int, kind: int) -> ImageTexture:
	var im := Image.create(w, h, false, Image.FORMAT_RGBA8)
	for y in h:
		for x in w:
			var u := (x + 0.5) / w * 2.0 - 1.0
			var v := (y + 0.5) / h * 2.0 - 1.0
			var a := 0.0
			if kind == 0:   # streak: soft across, long taper
				a = exp(-u * u * 3.0) * clampf(1.0 - absf(v), 0.0, 1.0) * clampf((v + 1.0) * 1.5, 0.0, 1.0)
			elif kind == 1:   # drop
				a = clampf(1.0 - sqrt(u * u + v * v), 0.0, 1.0)
				a = a * a * (3.0 - 2.0 * a)
			else:   # puff
				var r := sqrt(u * u + v * v)
				a = exp(-r * r * 3.2) * clampf(1.0 - r, 0.0, 1.0)
			im.set_pixel(x, y, Color(1, 1, 1, a))
	im.generate_mipmaps()
	return ImageTexture.create_from_image(im)
func _pgrad(pts: Array) -> Gradient:
	var g := Gradient.new()
	var o := PackedFloat32Array(); var c := PackedColorArray()
	for q in pts:
		o.append(q[0]); c.append(Color(q[1], q[2], q[3], q[4]))
	g.offsets = o; g.colors = c
	return g
func _pcurve(a: float, b: float) -> Curve:
	var cv := Curve.new()
	cv.add_point(Vector2(0.0, a)); cv.add_point(Vector2(1.0, b))
	return cv
func _fall_particles(xw: float, lip: float, base: float) -> void:
	var H := base - lip
	# 1 streaks on the curtain: start slow at the lip, fall under gravity, longer as they speed up
	var st := CPUParticles2D.new()
	st.texture = _ptex(8, 48, 0)
	st.amount = 90
	st.lifetime = 0.95
	st.preprocess = 1.0
	st.position = Vector2(xw, lip + 2.0)
	# (n16b) the sheet opens out as it falls: each streak leaves the lip angled out by where it starts
	var ep := PackedVector2Array(); var en := PackedVector2Array()
	for k in 23:
		var x0 := -11.0 + k
		ep.append(Vector2(x0, 0.0))
		en.append(Vector2(x0 / 12.5 * 15.0 / 0.95, 40.0).normalized())
	st.emission_shape = CPUParticles2D.EMISSION_SHAPE_DIRECTED_POINTS
	st.emission_points = ep
	st.emission_normals = en
	st.direction = Vector2(1, 0); st.spread = 0.0
	st.gravity = Vector2(0, 2.0 * (H - 40.0 * 0.95) / (0.95 * 0.95))
	st.initial_velocity_min = 30.0; st.initial_velocity_max = 50.0
	st.particle_flag_align_y = true
	st.scale_amount_min = 0.2; st.scale_amount_max = 0.34
	st.scale_amount_curve = _pcurve(0.35, 1.0)
	st.color_ramp = _pgrad([[0.0, 1, 1, 1, 0.0], [0.12, 1, 1, 1, 0.5], [0.85, 1, 1, 1, 0.55], [1.0, 1, 1, 1, 0.0]])
	st.material = night_mat
	fall_fx.add_child(st)
	# 2 splash: drops thrown up and out where the sheet lands, falling back into the pool
	var sp := CPUParticles2D.new()
	sp.texture = _ptex(12, 12, 1)
	sp.amount = 130
	sp.lifetime = 0.6
	sp.preprocess = 1.0
	sp.position = Vector2(xw + 1.0, base + 5.0)
	sp.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	sp.emission_rect_extents = Vector2(27.0, 2.0)
	sp.direction = Vector2(0, -1); sp.spread = 38.0
	sp.gravity = Vector2(0, 320.0)
	sp.initial_velocity_min = 30.0; sp.initial_velocity_max = 72.0
	sp.scale_amount_min = 0.1; sp.scale_amount_max = 0.26
	sp.color_ramp = _pgrad([[0.0, 1, 1, 1, 0.9], [0.7, 0.95, 0.98, 1, 0.7], [1.0, 0.95, 0.98, 1, 0.0]])
	sp.material = night_mat
	fall_fx.add_child(sp)
	# 3 spray cloud: soft puffs rising off the foot, drifting with the breeze, growing and thinning
	var ms := CPUParticles2D.new()
	ms.texture = _ptex(64, 64, 2)
	ms.amount = 28
	ms.lifetime = 3.6
	ms.preprocess = 4.0
	ms.position = Vector2(xw + 3.0, base)
	ms.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	ms.emission_rect_extents = Vector2(32.0, 5.0)
	ms.direction = Vector2(0, -1); ms.spread = 70.0
	ms.gravity = Vector2(4.0, -5.0)
	ms.initial_velocity_min = 5.0; ms.initial_velocity_max = 16.0
	ms.scale_amount_min = 0.38; ms.scale_amount_max = 0.7
	ms.scale_amount_curve = _pcurve(0.55, 1.0)
	ms.angle_min = 0.0; ms.angle_max = 360.0
	ms.color_ramp = _pgrad([[0.0, 1, 1, 1, 0.0], [0.2, 1, 1, 1, 0.2], [0.7, 1, 1, 1, 0.12], [1.0, 1, 1, 1, 0.0]])
	ms.material = night_mat
	fall_fx.add_child(ms)
	fall_mist = ms
# (n17, Link "làm như bờ ở sông") the banks of the ponds, the canal and the brook: the river's own bank drawing
# (pondriver.gd extends songgen.gd) on the pond shore lines, drawn like the river's (BankPics + song_mat, plants with
# PondPics). Needs both the pond fields and the river tables, so whichever loader finishes last builds it.
var pond_bk_done := false
func _pond_banks() -> void:
	if pond_bk_done or pond_G == null or song_mat == null or song_got.size() < 2:
		return
	pond_bk_done = true
	var t0 := Time.get_ticks_msec()
	var R = load("res://pondriver.gd").new()
	R.ki = info["ki"]; R.hi = info["hi"]
	R.setup(song_got["song"], song_got["meta"], 0.0)
	R.build_ponds(pond_G.banks(R.SP))
	var bk := BankPics.new()
	bk.ops = R.ops
	bk.z_index = -36
	bk.build()
	bk.material = song_mat
	add_child(bk)
	var pl := PondPics.new()
	pl.material = night_mat
	pl.items = R.plants; pl.meta = song_got["meta"]; pl.z_index = -35
	pl.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	add_child(pl)
	_pi_load(song_got["meta"].keys(), pl)
	print("pond banks: ", R.ops.size(), " ops, ", R.plants.size(), " plants, ", Time.get_ticks_msec() - t0, " ms")
var pond_water: WaterRect = null
# ponds / canal / brook get the river's water (pondwater.gdshader), over the ground's pond (z -38), under the pond's
# tree reflections (-37), the banks (-36) and the plants and mats (-35)
func _build_pondwater() -> void:
	if pond_water != null or pond_tex == null or tile_img == null or not wtex.has("noise.png"):
		return
	var m := ShaderMaterial.new()
	m.shader = load("res://pondwater.gdshader")
	_nm(m)
	m.set_shader_parameter("uPF", pond_tex)
	m.set_shader_parameter("uPB", pond_b)
	m.set_shader_parameter("uKH", Vector2(pond_G.ki, pond_G.hi))
	m.set_shader_parameter("uN", wtex["noise.png"])
	m.set_shader_parameter("uTC", ImageTexture.create_from_image(tile_img))
	var N0: Array = info["N"]
	m.set_shader_parameter("uT0", Vector2(N0[0], N0[2]))
	for nm in ["mid", "mudS", "dpc", "sky", "band"]:
		var cc: Array = pond_cols[nm]
		m.set_shader_parameter("p" + nm.substr(0, 1).to_upper() + nm.substr(1), Vector3(cc[0], cc[1], cc[2]))
	var x0 := 1e9; var y0 := 1e9; var x1 := -1e9; var y1 := -1e9
	for c in [Vector2(pond_b.x, pond_b.y), Vector2(pond_b.x + pond_b.z / 4.0, pond_b.y), Vector2(pond_b.x, pond_b.y + pond_b.w / 4.0), Vector2(pond_b.x + pond_b.z / 4.0, pond_b.y + pond_b.w / 4.0)]:
		var X: float = pond_G.ki + (c.x - c.y) * 32.0
		var Y: float = pond_G.hi + (c.x + c.y) * 16.0
		x0 = minf(x0, X); x1 = maxf(x1, X); y0 = minf(y0, Y); y1 = maxf(y1, Y)
	pond_water = WaterRect.new()
	pond_water.rect = Rect2(x0, y0, x1 - x0, y1 - y0)
	pond_water.material = m
	pond_water.z_index = -38
	add_child(pond_water)
var pond_G = null
var pond_cols := {}
var pond_tex: Texture2D = null
var pond_b := Vector4()
var refl_pond: Node2D = null
# trees by the ponds, the canal and the creek are mirrored in their water too (drawn under the pond plants)
func _build_refl_pond() -> void:
	if refl_pond != null or pond_G == null or sc_data.is_empty():
		return
	var G = pond_G
	var wet_p := func(x: float, y: float) -> bool: return G.fs(G.F, x, y) > 0.5
	refl_pond = _refl_set(wet_p, 0.0, true)
func _build_refl() -> void:
	_build_refl_pond()
	if refl_root != null or wimg_a == null or sc_data.is_empty() or water == null:
		return
	var W := wimg_a.get_width()
	var H := wimg_a.get_height()
	var sx := W / wmap.z
	var sy := H / wmap.w
	var wet_a := func(x: float, y: float) -> bool:
		var px := int((x - wmap.x) * sx)
		var py := int((y - wmap.y) * sy)
		return px >= 0 and py >= 0 and px < W and py < H and wimg_a.get_pixel(px, py).g8 > 0
	refl_root = _refl_set(wet_a, 0.0)
	if wimg_f != null:
		var wet_f := func(x: float, y: float) -> bool:
			if wet_a.call(x, y): return true
			var px := int((x - wmap.x) * sx)
			var py := int((y - wmap.y) * sy)
			return px >= 0 and py >= 0 and px < W and py < H and wimg_f.get_pixel(px, py).r8 > 132
		refl_fl = _refl_set(wet_f, 1.0)
		refl_fl.visible = false
	if song_cur >= 0: _flood_apply(_flood_on())
func _refl_set(wet: Callable, fl: float, pond := false) -> Node2D:
	var root := Node2D.new()
	root.z_index = -37 if pond else -20
	root.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	var rm := ShaderMaterial.new()
	rm.shader = load("res://refl.gdshader")
	_nm(rm)
	if pond:
		rm.set_shader_parameter("uPond", 1.0)
		rm.set_shader_parameter("uPF", pond_tex)
		rm.set_shader_parameter("uPB", pond_b)
		rm.set_shader_parameter("uKH", Vector2(pond_G.ki, pond_G.hi))
	else:
		rm.set_shader_parameter("uA", wtex["mapA.png"])
		rm.set_shader_parameter("uMap", wmap)
	if wtex.has("flood.png"): rm.set_shader_parameter("uF", wtex["flood.png"])
	rm.set_shader_parameter("uFlood", fl)
	root.material = rm
	add_child(root)
	var V: Array = sc_data["v"]
	var n := 0
	for r in sc_data["i"]:
		var j: int = r[0]
		var v = V[j]
		if v == null or float(v[3]) < 8.0:
			continue
		var bx: float = r[1]
		var by: float = r[2]
		# standing in the water (the flood): mirrored about its own foot; on the bank: about a line half way down to the water
		var dy0 := -1.0
		if fl > 0.5 and wet.call(bx, by):
			dy0 = 0.0
		else:
			var dy := 2.0
			while dy <= 44.0:
				if wet.call(bx, by + dy):
					dy0 = dy
					break
				dy += 3.0
		if dy0 < 0.0:
			continue
		var ym := by + dy0 * 0.5
		var s := Sprite2D.new()
		s.centered = false
		s.use_parent_material = true
		if r.size() > 5 and str(r[5]) != "":
			s.set_meta("pc", str(r[5]))
			lot_spr.append(s)
		var yt := by + float(v[1])
		s.position = Vector2(bx + float(v[0]), 2.0 * ym - yt)
		var src: Sprite2D = null
		if sc_spr[j].size() > 0: src = sc_spr[j][0]
		if src != null and src.texture != null:
			s.texture = src.texture
			s.scale = Vector2(src.scale.x, -src.scale.y)
			s.visible = _lot_vis(s)
		else:
			s.visible = false
			if not sc_rspr.has(j): sc_rspr[j] = []
			sc_rspr[j].append(s)
		if not sc_rall.has(j): sc_rall[j] = []
		sc_rall[j].append(s)
		root.add_child(s)
		n += 1
	print("tree reflections (flood %d, pond %d): %d" % [int(fl), int(pond), n])
	return root

class WaterRect extends Node2D:
	var rect := Rect2()
	var col := Color.WHITE
	func _draw() -> void:
		draw_rect(rect, col)

func _want_bundle(nm: String, pri: float) -> void:
	if not have_bundle.has(nm):
		return
	if bundles.has(nm):
		var b: Dictionary = bundles[nm]
		b["used"] = frame_no
		if b["st"] == 0:
			b["pri"] = max(b["pri"], pri)
		return
	bundles[nm] = {"st": 0, "data": PackedByteArray(), "ent": {}, "used": frame_no, "pri": pri}
	fetch_q.append(nm)

func _pump_fetch() -> void:
	while http_free.size() > 0 and fetch_q.size() > 0:
		# highest priority first
		var bi := 0
		var bp := -1e18
		for k in fetch_q.size():
			var p: float = bundles[fetch_q[k]]["pri"]
			if p > bp:
				bp = p
				bi = k
		var nm: String = fetch_q[bi]
		fetch_q.remove_at(bi)
		var h: HTTPRequest = http_free.pop_back()
		h.set_meta("nm", nm)
		bundles[nm]["st"] = 1
		var v: String = str(info.get("bh", {}).get(nm, ""))
		var err := h.request(base_url + "d/" + nm + ".wasm" + ("?v=" + v if v != "" else ""))
		if err != OK:
			bundles[nm]["st"] = 3
			http_free.append(h)

func _on_http(res, code, _headers, body: PackedByteArray, h: HTTPRequest) -> void:
	var nm: String = h.get_meta("nm")
	http_free.append(h)
	var b: Dictionary = bundles[nm]
	if res != HTTPRequest.RESULT_SUCCESS or code != 200 or body.size() < 8:
		b["st"] = 3
		return
	# header: "NTB1", u32 n, n x (s16 a, s16 b, u32 off, u32 len)
	var n := body.decode_u32(4)
	var ent := {}
	for k in n:
		var o := 8 + k * 12
		var a := body.decode_s16(o)
		var c := body.decode_s16(o + 2)
		ent[str(a) + "_" + str(c)] = [body.decode_u32(o + 4), body.decode_u32(o + 8)]
	b["data"] = body
	b["ent"] = ent
	b["st"] = 2

# ---------------------------------------------------------------- per frame
func _process(_dt: float) -> void:
	frame_no += 1
	var tq := Time.get_ticks_usec()
	var tq0 := tq
	if jsw != null and frame_no % 10 == 0:
		_gift_poll()
	if frame_no % 15 == 7:
		_lv_night()
	tq = _pt_add("đêm", tq)
	_lot_poll()
	_song_tick()
	tq = _pt_add("sông", tq)
	_rain_tick(_dt)
	_sway_tick()
	tq = _pt_add("lắc", tq)
	var now := Time.get_ticks_usec()
	if ft_last > 0:
		var ms := (now - ft_last) / 1000.0
		if ms > 1000.0:   # (b67) the tab was hidden (the browser stops the game): start a new window, it is not a slow frame
			ft_win_start = now
			ft_count = 0
			ft_worst = 0.0
			pf_code = 0.0
			pf_draw = 0.0
		else:
			ft_worst = max(ft_worst, ms)
	ft_last = now
	ft_count += 1
	pf_code += Performance.get_monitor(Performance.TIME_PROCESS) * 1000.0
	pf_draw += Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)
	if now - ft_win_start > 2000000:
		fps_shown = ft_count * 1e6 / float(now - ft_win_start)
		ft_worst_shown = ft_worst
		pf_code_shown = pf_code / maxf(1.0, ft_count)
		var po := []
		for k in ["trước", "tổng", "sau", "main", "xếp", "đêm", "sông", "lắc", "nhìn", "tải", "đồng hồ"]:
			po.append("%s %.1f" % [k, pt.get(k, 0.0) / 1000.0 / maxf(1.0, ft_count)])
		pt_shown = " · ".join(po)
		pt.clear()
		if do_on <= 0 and do2_on <= 0:
			pt_drw = _drw_text(ft_count)
		pt_proc = _proc_count()
		pf_draw_shown = pf_draw / maxf(1.0, ft_count)
		pf_code = 0.0
		pf_draw = 0.0
		ft_worst = 0.0
		ft_count = 0
		ft_win_start = now
		dec_ms_worst = 0.0
	if info.is_empty():
		if not first_ready:
			_layout_cover(0.0)
		return
	if jsw != null and frame_no % 10 == 0:
		var rq = jsw.__gdroad   # test hook: window.__gdroad = '{"add":{"x,y":"gach"},"rm":["x,y"]}'
		if rq != null and str(rq) != "":
			jsw.__gdroad = ""
			var rj = JSON.parse_string(str(rq))
			if rj is Dictionary:
				road_set(rj.get("add", {}), rj.get("rm", []))
		var c = jsw.__gdcam
		if c != null and str(c) != "":
			var p := str(c).split(",")
			zoom = float(p[2]) * dpr
			cam = Vector2(float(p[0]), float(p[1])) - get_viewport_rect().size / zoom / 2
			if p.size() > 4:
				flood_force = int(p[4])
			if p.size() > 5:
				night_force = int(p[5])
				_night_tick()
			if p.size() > 3:
				song_force = int(p[3])
				_song_show(_tide_step())
			jsw.__gdcam = ""
		var dbg = jsw.__gdsh
		if dbg != null and str(dbg) != "" and water != null:
			var q := str(dbg).split(",")
			water.material.set_shader_parameter("uDbg", Vector4(float(q[0]), float(q[1]), float(q[2]), float(q[3])))
			jsw.__gdsh = ""
		var hd = jsw.__gdhide
		if hd != null and str(hd) != "" and song_lv.has(song_cur):
			var hs := str(hd)
			song_lv[song_cur][0].visible = not hs.contains("b")
			song_lv[song_cur][1].visible = not hs.contains("p")
			jsw.__gdhide = ""
		jsw.__gdmeter = meter_full
		jsw.__gddc = str(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)) + "," + str(Performance.get_monitor(Performance.RENDER_TOTAL_OBJECTS_IN_FRAME)) + "," + str(Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME))
	_clamp_cam()
	get_viewport().canvas_transform = Transform2D(0.0, Vector2(zoom, zoom), 0.0, -cam * zoom)
	tq = Time.get_ticks_usec()
	_update_view()
	tq = _pt_add("nhìn", tq)
	_pump_fetch()
	_decode_some()
	_evict()
	tq = _pt_add("tải", tq)
	_do_step()
	_do2_step()
	if frame_no % 15 == 0:   # (b70) the meter (JS read + Label relayout) 4x a second, not every frame
		_update_meter()
	tq = _pt_add("đồng hồ", tq)
	pt["main"] = pt.get("main", 0.0) + (tq - tq0)

func _level_for(pxu: float, nlev: int, base := BASE_PXU) -> int:
	# finest level needed so that picture pixels >= screen pixels
	var l := int(floor(log(base / pxu) / log(2.0)))
	return clamp(l, 0, nlev - 1)

var cur_l := 0
var need_n := 0
var have_n := 0
var first_ready := false
var t_start := 0
func _update_view() -> void:
	_sc_mode()
	var vs := get_viewport_rect().size
	var w0 := cam
	var w1 := cam + vs / zoom
	var mid := (w0 + w1) / 2
	var l := _level_for(zoom, GLEV)
	cur_l = l
	# draw order: the fallback levels (one coarser, and the two small whole-map ones) go UNDER the river water, the
	# sharp level over it. Otherwise their blurred plants and bank show through the see-through edges of the sharp
	# pieces (leaves, reeds and the bank reaching over the water) as a smear.
	for k in GLEV:
		lev_nodes[k].visible = (k == l or k == l + 1 or k == BASE_L or k == GLEV - 1)
		lev_nodes[k].z_index = -10 if k == l else -30 - k
	decode_want.clear()
	var X0: float = info["X0"]
	var Y0: float = info["Y0"]
	var levs := [l]
	if l + 1 < GLEV:
		levs.append(l + 1)
	need_n = 0
	have_n = 0
	for ll in levs:
		var U: float = SUB / (BASE_PXU / pow(2.0, ll))   # world units per piece
		var m := U * 0.25
		var sx0 := int(floor((w0.x - m - X0) / U))
		var sx1 := int(floor((w1.x + m - X0) / U))
		var sy0 := int(floor((w0.y - m - Y0) / U))
		var sy1 := int(floor((w1.y + m - Y0) / U))
		for sy in range(sy0, sy1 + 1):
			for sx in range(sx0, sx1 + 1):
				var key := str(ll) + "_" + str(sx) + "_" + str(sy)
				var c := Vector2(X0 + (sx + 0.5) * U, Y0 + (sy + 0.5) * U)
				var pri := -c.distance_to(mid) * zoom - (0.0 if ll == l else 100000.0) * 0.0 + (5000.0 if ll == l + 1 else 0.0)
				var inview: bool = ll == l and c.x + U / 2 > w0.x and c.x - U / 2 < w1.x and c.y + U / 2 > w0.y and c.y - U / 2 < w1.y
				if tiles.has(key):
					tiles[key]["used"] = frame_no
					if inview:
						need_n += 1
						have_n += 1
					continue
				var bn := "g" + str(ll) + "_" + str(sx >> 3) + "_" + str(sy >> 3)
				if not have_bundle.has(bn):
					continue
				var bst: int = bundles.get(bn, {}).get("st", 0)
				if inview and (bst < 2 or (bst == 2 and bundles[bn]["ent"].has(str(sx) + "_" + str(sy)))):
					need_n += 1
				_want_bundle(bn, pri)
				var b: Dictionary = bundles[bn]
				if b["st"] == 2:
					var ek := str(sx) + "_" + str(sy)
					if b["ent"].has(ek):
						decode_want[key] = [pri, 0, [ll, sx, sy, bn, ek]]
	# keep the base levels marked used
	for key in tiles.keys():
		var ll := int(key.get_slice("_", 0))
		if ll >= BASE_L:
			tiles[key]["used"] = frame_no
	# base levels: decode everything they have
	for ll in [BASE_L, GLEV - 1]:
		for bn in bundles.keys():
			if not bn.begins_with("g" + str(ll) + "_"):
				continue
			var b: Dictionary = bundles[bn]
			if b["st"] != 2:
				continue
			for ek in b["ent"].keys():
				var key: String = str(ll) + "_" + ek
				if not tiles.has(key):
					var p: PackedStringArray = str(ek).split("_")
					decode_want[key] = [1e7 if ll == GLEV - 1 else 1e6, 0, [ll, int(p[0]), int(p[1]), bn, ek]]
	# objects (b51): every placement shows the ONE shared picture of its thing (n/op/<name>.webp), fetched once
	for j in objs.size():
		var o: Dictionary = objs[j]
		if o["op"] == null or o.has("hive"):
			continue
		var r := Rect2(o["x"], o["y"], o["w"], o["h"])
		if not r.intersects(Rect2(w0 - (w1 - w0) * 0.25, (w1 - w0) * 1.5)):
			continue
		if (o["pc"] != "" and not _owned(o["pc"])) or o.get("cay", false) or o.get("xg", false):
			o["spr"].visible = false   # (n41) the lot's own scenery shows only once it is bought (web tc())
			continue
		var nm: String = o["op"][0]
		if not first_ready and r.intersects(Rect2(w0, w1 - w0)):
			need_n += 1
			if op_tex.get(nm) != null:
				have_n += 1
		if not op_tex.has(nm):
			_op_want(nm)
		_show_obj(o, 0)
	if info.get("native", false):
		need_n += 1 + sc_tex_n
		have_n += (1 if ground != null and gparts >= 16 else 0) + sc_tex_have
		if ground != null and gparts >= 16:
			ground.material.set_shader_parameter("uRoads", 1.0)
			ground.material.set_shader_parameter("uPond", 1.0)
			if track_mat == null:
				_load_tracks()

func _show_obj(o: Dictionary, want: int) -> void:
	if o.has("sst"):   # (b49) this season's own picture (mai): one full picture, mipmapped like the scenery
		var s0: Sprite2D = o["spr"]
		var st: Array = o["sst"]
		if o["lev"] != -2:
			o["lev"] = -2
			s0.texture = st[0]
			var k0 := 1.0 / 9.0
			s0.scale = Vector2(k0, k0)
			var tl: Vector2 = st[1]
			s0.offset = (tl - (o["piv"] if o.has("piv") else Vector2(o["x"], o["y"]))) / k0
		s0.visible = true
		return
	var s: Sprite2D = o["spr"]
	var nm: String = o["op"][0] if o["op"] != null else ""
	# (b54) at night the export's own night frame (lamps lit, night colours painted like the web), drawn without the formula
	var nn = info.get("opn", {}).get(nm) if night_cur == 1 else null
	var ntex: Texture2D = null
	if nn != null:
		ntex = op_tex.get(nn[0])
		if ntex == null and not op_tex.has(nn[0]):
			_op_want(nn[0])
	var tex: Texture2D = op_tex.get(nm) if ntex == null else ntex
	if tex == null:
		if nn != null and not op_tex.has(nm):
			_op_want(nm)
		s.visible = false
		return
	var lv := 1 if ntex != null else 0
	if o["lev"] != lv:
		o["lev"] = lv
		var p: Array = o["op"]
		s.texture = tex
		var fl: bool = p.size() > 5 and int(p[5]) == 1   # placed mirrored
		s.flip_h = fl
		var tl := Vector2(float(p[1]), float(p[2]))
		var w := float(p[3])
		if ntex != null:
			var dw := float(nn[5])
			var sc := float(p[3]) / dw   # placement size vs the export's day size (normally 1)
			var dx := float(nn[1]) * sc
			if fl:
				dx = dw * sc - (float(nn[1]) + float(nn[3])) * sc
			tl += Vector2(dx, float(nn[2]) * sc)
			w = float(nn[3]) * sc
			s.material = night_raw
		else:
			s.material = night_mat
		var k := w / tex.get_width()
		s.scale = Vector2(k, k)
		if o.has("piv"):
			s.offset = (tl - o["piv"]) / k
		else:
			s.position = tl
			s.offset = Vector2.ZERO
	s.visible = true

# (b51) one picture file per thing, shared by every placement: fetched once, mipmapped once
var op_tex := {}             # name -> Texture2D (null while loading)
# for other code (the shop): the shared picture of godot/<grp>/<dir>/<frame>.png as name "<grp>-<dir>-<frame>"; null until
# it has arrived (the first call starts the fetch). op_box: [ox, oy, gw, gh] game units from the thing's anchor (tile centre).
func op_pic(nm: String) -> Texture2D:
	if not op_tex.has(nm):
		if info.get("opb", {}).has(nm) or not _op2_on():
			_op_want(nm)
		else:
			_op2_want(nm)
	return op_tex.get(nm)
func op_box(nm: String) -> Array:
	var b = info.get("opb", {}).get(nm)
	if b != null:
		return b
	if _op2_on():
		var r = JavaScriptBridge.eval("JSON.stringify((window.__op2j||{})[" + JSON.stringify(nm) + "]||[])")
		if r != null:
			var a = JSON.parse_string(str(r))
			if a is Array:
				return a
	return []

# (b52) the shop's pictures that the village does not use live in a second artifact (info.op2 = its address; Link 11-13
# "tạo artifact phụ"), because one version of this one holds at most 256 MiB / 511 files. The page asks it once for op.json
# (plain first, then with the viewer's sign-in cookie); the meter shows "kho phụ: ok" or the error, so a phone test tells
# whether the host lets one artifact read another's files.
var op2_mode := ""          # "", "omit", "include", or "x" = cannot
var op2_cb = null
func _op2_probe() -> void:
	if jsw == null or not info.has("op2"):
		return
	JavaScriptBridge.eval("(function(b){window.__op2t='đang thử';window.__op2b=b;function t(c){return fetch(b+'op.json',{credentials:c,mode:'cors'}).then(function(r){if(!r.ok)throw 'HTTP '+r.status;return r.json()})}" +
		"t('omit').then(function(j){window.__op2j=j;window.__op2m='omit';window.__op2t='ok'},function(e){t('include').then(function(j){window.__op2j=j;window.__op2m='include';window.__op2t='ok (cookie)'},function(e2){window.__op2m='x';window.__op2t='lỗi: '+e+' / '+e2})})})(" + JSON.stringify(str(info["op2"])) + ")")
func _op2_on() -> bool:
	if jsw == null or not info.has("op2"):
		return false
	if op2_mode == "":
		var m = jsw.__op2m
		if m != null and str(m) != "":
			op2_mode = str(m)
	return op2_mode == "omit" or op2_mode == "include"
func _op2_want(nm: String) -> void:
	op_tex[nm] = null
	if op2_cb == null:
		op2_cb = JavaScriptBridge.create_callback(func(args):
			var n2: String = str(args[0])
			var b64: String = str(args[1])
			if b64 == "":
				return
			var img := Image.new()
			if img.load_webp_from_buffer(Marshalls.base64_to_raw(b64)) != OK:
				return
			img.generate_mipmaps()
			op_tex[n2] = ImageTexture.create_from_image(img)
			tex_mb += img.get_width() * img.get_height() * 4 * 1.33 / 1048576.0)
		jsw.__op2got = op2_cb
	JavaScriptBridge.eval("(function(n){fetch(window.__op2b+'n/op/'+n+'.webp',{credentials:window.__op2m,mode:'cors'}).then(function(r){if(!r.ok)throw 0;return r.arrayBuffer()}).then(function(a){var u=new Uint8Array(a),s='',k=0;for(;k<u.length;k+=32768)s+=String.fromCharCode.apply(null,u.subarray(k,k+32768));window.__op2got(n,btoa(s))},function(){window.__op2got(n,'')})})(" + JSON.stringify(nm) + ")")
func _op_want(nm: String) -> void:
	op_tex[nm] = null
	if op_raw.has(nm):
		_op_dec(nm, op_raw[nm])
		op_raw.erase(nm)
		return
	_fetch("n/op/" + nm + ".webp", func(b: PackedByteArray): _op_dec(nm, b), 0, true)
func _op_dec(nm: String, b: PackedByteArray) -> void:
	var img := Image.new()
	if img.load_webp_from_buffer(b) != OK:
		return
	img.generate_mipmaps()
	op_tex[nm] = ImageTexture.create_from_image(img)
	tex_mb += img.get_width() * img.get_height() * 4 * 1.33 / 1048576.0
	if opn_day.is_empty():
		for k in info.get("opn", {}):
			opn_day[info["opn"][k][0]] = k
	var dn: String = opn_day.get(nm, nm)
	for o in objs:
		if o["op"] != null and (o["op"][0] == nm or o["op"][0] == dn):
			o["lev"] = 99
var opn_day := {}   # night picture name -> day picture name
# (b54, Link 11-13 "ấn vô thì delay 1s 2s mới load ảnh") once the first view is sharp, the file of every shop/village
# picture (info.opb) is fetched in the background and kept as bytes (about 50 MB), 3 at a time so the ones the player
# asks for go first; opening a shop tab then only decodes them, no waiting on the network.
var op_raw := {}
var op_pre := []
var op_pre_run := 0
func _op_prefetch_start() -> void:
	for nm in info.get("opb", {}).keys():
		if not op_tex.has(nm):
			op_pre.append(nm)
	_op_prefetch_next()
func _op_prefetch_next() -> void:
	while op_pre_run < 3 and op_pre.size() > 0:
		var nm: String = op_pre.pop_front()
		if op_tex.has(nm) or op_raw.has(nm):
			continue
		op_pre_run += 1
		_fetch("n/op/" + nm + ".webp", func(b: PackedByteArray):
			op_pre_run -= 1
			if not op_tex.has(nm) or op_tex[nm] == null:
				if op_tex.has(nm):
					_op_dec(nm, b)   # asked for while it was on the way
				else:
					op_raw[nm] = b
			_op_prefetch_next())

func _decode_some() -> void:
	var t0 := Time.get_ticks_usec()
	dec_ms_frame = 0.0
	if decode_want.is_empty():
		return
	var keys := decode_want.keys()
	keys.sort_custom(func(a, b): return decode_want[a][0] > decode_want[b][0])
	var n := 0
	for key in keys:
		var spent := (Time.get_ticks_usec() - t0) / 1000.0
		if n > 0 and spent > (DECODE_MS if first_ready else 40.0):
			break
		var d: Array = decode_want[key]
		var a: Array = d[2]
		var b: Dictionary = bundles[a[a.size() - 2]]
		var e: Array = b["ent"][a[a.size() - 1]]
		var bytes: PackedByteArray = b["data"].slice(e[0], e[0] + e[1])
		b["used"] = frame_no
		var img := Image.new()
		if img.load_webp_from_buffer(bytes) != OK:
			b["ent"].erase(a[a.size() - 1])
			continue
		var tex := ImageTexture.create_from_image(img)
		var mb := img.get_width() * img.get_height() * 4 / 1048576.0
		tex_mb += mb
		n += 1
		if d[1] == 0:
			var ll: int = a[0]
			var U: float = SUB / (BASE_PXU / pow(2.0, ll))
			var s := Sprite2D.new()
			s.centered = false
			s.texture = tex
			s.material = night_mat
			s.position = Vector2(info["X0"] + a[1] * U, info["Y0"] + a[2] * U)
			var k := pow(2.0, ll) / BASE_PXU
			s.scale = Vector2(k, k)
			lev_nodes[ll].add_child(s)
			tiles[key] = {"spr": s, "mb": mb, "used": frame_no}
	dec_ms_frame = (Time.get_ticks_usec() - t0) / 1000.0
	dec_ms_worst = max(dec_ms_worst, dec_ms_frame)

func _evict() -> void:
	if frame_no % 15 != 0:
		return
	# raw bundle bytes: keep at most ~80 MB of the least recently used
	var raw := 0
	var bl := []
	for nm in bundles.keys():
		var b: Dictionary = bundles[nm]
		if b["st"] == 2:
			raw += b["data"].size()
			bl.append(nm)
	if raw > 80 * 1048576:
		bl.sort_custom(func(a, b): return bundles[a]["used"] < bundles[b]["used"])
		for nm in bl:
			if raw <= 60 * 1048576:
				break
			if nm.begins_with("g4_") or nm.begins_with("g5_"):
				continue
			raw -= bundles[nm]["data"].size()
			bundles.erase(nm)
	if tex_mb <= budget_mb:
		return
	var tl := []
	for key in tiles.keys():
		if tiles[key]["used"] < frame_no - 2:
			tl.append(key)
	tl.sort_custom(func(a, b): return tiles[a]["used"] < tiles[b]["used"])
	for key in tl:
		if tex_mb <= budget_mb * 0.85:
			break
		var t: Dictionary = tiles[key]
		t["spr"].queue_free()
		tex_mb -= t["mb"]
		tiles.erase(key)

func _update_meter() -> void:
	var loading := 0
	for nm in bundles.keys():
		if bundles[nm]["st"] <= 1:
			loading += 1
	var txt := "bản " + BUILD + " · %d fps · chậm nhất %d ms · zoom %.2f (mức %d)\nnền %d mảnh · ảnh %d MB · giải %.1f ms" % [round(fps_shown), round(ft_worst_shown), zoom / dpr, cur_l, tiles.size(), round(tex_mb), dec_ms_worst]
	if loading > 0 or decode_want.size() > 0:
		txt += " · đang tải %d gói, %d ảnh" % [loading, decode_want.size()]
	if jsw != null:
		# real drawing size on this phone (Link 11-12 "chữ vẽ code còn mờ"): canvas pixels vs page css px x dpr
		var dg = JavaScriptBridge.eval("(function(){var c=document.getElementById('canvas'),v=window.visualViewport,r=c.getBoundingClientRect(),g=c.__gl||(c.__gl=c.getContext('webgl2'));return 'khung '+c.width+'x'+c.height+' · ve '+(g?g.drawingBufferWidth+'x'+g.drawingBufferHeight:'?')+' · trang '+innerWidth+'x'+innerHeight+' · hien '+(r.width*devicePixelRatio).toFixed(1)+'x'+(r.height*devicePixelRatio).toFixed(1)+' diem'+' · dpr '+devicePixelRatio+' · zoom trang '+(v?v.scale.toFixed(2):'?')+' · man '+screen.width+'x'+screen.height})()")
		if dg != null:
			txt += "\n" + str(dg).replace(" · trang", "\ntrang").replace(" · dpr", "\ndpr") + " · godot %dx%d" % [int(get_viewport_rect().size.x), int(get_viewport_rect().size.y)]
		var o2 = jsw.__op2t
		if o2 != null and str(o2) != "":
			txt += "\nkho phụ: " + str(o2)
		var pre = jsw.__gdpre
		if pre != null and str(pre) != "":
			txt += "\n" + str(pre)
	meter_full = txt
	meter.text = "bản " + BUILD + " · %d fps · chậm nhất %d ms" % [round(fps_shown), round(ft_worst_shown)]
	meter.text += "\ncode %.1f ms · vẽ %d lệnh · %d vật" % [pf_code_shown, round(pf_draw_shown), obj_root.get_child_count() if obj_root != null else 0]
	meter.text += "\n" + pt_shown + "\nchạy: " + pt_proc + "\nvẽ lại/khung: " + pt_drw
	if jsw != null and info.has("op2"):
		var o2 = jsw.__op2t
		meter.text += "\nkho phụ: " + (str(o2) if o2 != null else "?")
	# first view: say it is loading until every piece on screen is sharp
	if not first_ready:
		if t_start == 0:
			t_start = Time.get_ticks_msec()
		var wok: bool = water != null or not info.get("river", false)
		if (need_n > 0 and have_n >= need_n and wok) or Time.get_ticks_msec() - t_start > 90000:
			first_ready = true
			get_tree().create_timer(2.0).timeout.connect(_op_prefetch_start)
			status.text = ""
			cover.visible = false
			pbar.visible = false
			pbar_bg.visible = false
			if jsw != null:
				jsw.__gdready = 1   # the page starts storing the whole village only now (it would slow this view)
		else:
			_layout_cover((float(have_n) / max(need_n, 1)) * (1.0 if wok else 0.95))

func _layout_cover(f: float) -> void:
	var vs := get_viewport_rect().size
	cover.position = Vector2.ZERO
	cover.size = vs
	if not status.text.begins_with("Lỗi"):
		status.text = "Đang tải làng… %d%%" % [int(100.0 * f)] if f > 0.0 else "Đang tải làng…"
	status.reset_size()
	status.position = vs / 2 - status.size / 2 - Vector2(0, 8 * dpr)
	var bw := 220.0 * dpr
	pbar_bg.size = Vector2(bw, 6 * dpr)
	pbar_bg.position = Vector2(vs.x / 2 - bw / 2, vs.y / 2 + status.size.y / 2)
	pbar.size = Vector2(bw * clamp(f, 0.0, 1.0), 6 * dpr)
	pbar.position = pbar_bg.position

# the game's own limits: the view always stays inside the village (x 0..Kp, y xf-320..Up) and never zooms out
# further than the village fills the screen, or 5600 units across (game kh())
func _view_box() -> Rect2:
	if info.has("view"):
		var v: Array = info["view"]
		return Rect2(v[0], v[1], v[2] - v[0], v[3] - v[1])
	return Rect2(info["ub"], info["hb"], info["DW"] - info["ub"], info["VW"] - info["hb"])

func _limits() -> void:
	var vs := get_viewport_rect().size
	var bx := _view_box()
	zmin = max(max(vs.x / bx.size.x, vs.y / bx.size.y), vs.x / 5600.0)
	zmin = min(zmin, zmax)

func _clamp_cam() -> void:
	_limits()
	zoom = clamp(zoom, zmin, zmax)
	var vs := get_viewport_rect().size / zoom
	var bx := _view_box()
	var a := bx.position
	var b := bx.end
	for i in 2:
		if vs[i] >= b[i] - a[i]:
			cam[i] = (a[i] + b[i]) / 2 - vs[i] / 2
		else:
			cam[i] = clamp(cam[i], a[i], b[i] - vs[i])

# ---------------------------------------------------------------- input
var touches := {}
var mdrag := false

func _zoom_at(p: Vector2, nz: float) -> void:
	nz = clamp(nz, zmin, zmax)
	var w := cam + p / zoom
	zoom = nz
	cam = w - p / zoom

# (n39) finger bookkeeping sees EVERY touch (_input), also the ones a panel/button or a swipe takes;
# else a finger lifted over UI stays "down" and the next one-finger drag pinches around that dead point (jump)
var tprev := {}
func _input(e: InputEvent) -> void:
	if e is InputEventScreenTouch:
		if e.pressed:
			touches[e.index] = e.position
		else:
			touches.erase(e.index)
		tprev.erase(e.index)
	elif e is InputEventScreenDrag:
		tprev[e.index] = touches.get(e.index, e.position - e.relative)
		touches[e.index] = e.position

func _unhandled_input(e: InputEvent) -> void:
	# (b48) a full-screen panel of the logic UI is open (ui.gd sets the flag): swipes and pinches there scroll the panel,
	# never the map under it (Link 11-13: lướt trong popup mà zoom cả màn hình)
	if bool(get_tree().get_meta("ui_modal", false)):
		if e is InputEventMouseButton and e.button_index == MOUSE_BUTTON_LEFT and not e.pressed:
			mdrag = false
		return
	if e is InputEventScreenDrag:
		var prev: Vector2 = tprev.get(e.index, e.position - e.relative)
		if touches.size() >= 2:
			var ks := touches.keys()
			var ia: int = ks[0]
			var ib: int = ks[1]
			if e.index == ia or e.index == ib:
				var other: Vector2 = touches[ib] if e.index == ia else touches[ia]
				var d0 := prev.distance_to(other)
				var ep: Vector2 = e.position
				var d1 := ep.distance_to(other)
				var c0 := (prev + other) / 2
				var c1 := (ep + other) / 2
				if d0 > 1.0:
					_zoom_at(c0, zoom * d1 / d0)
				cam -= (c1 - c0) / zoom
		else:
			cam -= e.relative / zoom
	elif e is InputEventMouseButton:
		if e.button_index == MOUSE_BUTTON_LEFT:
			mdrag = e.pressed
		elif e.pressed and e.button_index == MOUSE_BUTTON_WHEEL_UP:
			_zoom_at(e.position, zoom * 1.15)
		elif e.pressed and e.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			_zoom_at(e.position, zoom / 1.15)
	elif e is InputEventMouseMotion and mdrag:
		cam -= e.relative / zoom
	elif e is InputEventMagnifyGesture:
		_zoom_at(e.position, zoom * e.factor)
	elif e is InputEventPanGesture:
		cam += e.delta * 8.0 / zoom


# ---------------------------------------------------------------- (b49) trees that change with the season (web: mai, cao su)
# The pictures are the split exports in godot/ (caylang/caosu, kieng/mai, 9 px/unit, tools/ssprep.py -> n/ss.wasm + n/ss.json).
# Cao su (scenery kinds 31-34 = seed 0-3): look by season [green, green, turning, bare], frame = seed + 4*look; look 0 is the
# village's own picture. Mai (objects 104, 141): frame = seed + 4*season (xuân gold flowers, hạ green, thu yellow, mùa khô bare
# with buds); hạ is the object's own picture.
var ss_meta := {}
var ss_sea := -1
var ss_busy := 0
var ss_tex := {}
var cs_base := {}    # kind -> [full, v, atlas rect] of look 0
func _ss_tick() -> void:
	if sc_data.is_empty() or ss_busy > 0:
		return
	if ss_meta.is_empty():
		ss_busy = 1
		_fetch("n/ss.json?v=1", func(b: PackedByteArray):
			ss_busy = 0
			var m = JSON.parse_string(b.get_string_from_utf8())
			ss_meta = m if m is Dictionary else {"bad": true})
		return
	if ss_meta.has("bad"):
		return
	var sea: int = int(troi.get("season", 1)) if troi.has("season") else 1
	if sea == ss_sea:
		return
	for js in ss_meta["cs"]["j"]:
		if not sc_full.has(int(js)):
			return   # the village's own cao su pictures first (else they would land over this season's later)
	# every picture this season needs, loaded first; then all of it changes in one frame
	var need := []
	var look: int = [0, 0, 1, 2][sea]
	for js in ss_meta["cs"]["j"]:
		if look > 0:
			need.append("cs" + str(int(ss_meta["cs"]["j"][js]) + 4 * look))
	for jo in ss_meta["mai"]["o"]:
		if sea != 1:
			need.append("mai" + str(int(ss_meta["mai"]["o"][jo][0]) + 4 * sea))
	var miss := []
	for nm in need:
		if not ss_tex.has(nm):
			miss.append(nm)
	if miss.size() > 0:
		ss_busy = miss.size()
		for nm in miss:
			var nmx: String = nm
			_fetch_in("ss", nmx, func(b):
				var img := Image.new()
				if img.load_webp_from_buffer(b) == OK:
					img.generate_mipmaps()
					ss_tex[nmx] = ImageTexture.create_from_image(img)
				else:
					ss_tex[nmx] = null
				ss_busy -= 1)
		return
	ss_sea = sea
	_ss_apply(sea, look)
func _ss_apply(sea: int, look: int) -> void:
	var V: Array = sc_data["v"]
	for js in ss_meta["cs"]["j"]:
		var j := int(js)
		if not sc_full.has(j):
			continue
		if not cs_base.has(j):
			cs_base[j] = [sc_full[j], V[j].duplicate(), sc_arect.get(j)]
		var nv: Array
		if look == 0:
			sc_full[j] = cs_base[j][0]
			nv = cs_base[j][1].duplicate()
			if cs_base[j][2] != null:
				sc_arect[j] = cs_base[j][2]
		else:
			var nm := "cs" + str(int(ss_meta["cs"]["j"][js]) + 4 * look)
			var t: Texture2D = ss_tex.get(nm)
			if t == null:
				continue
			var f: Array = ss_meta["cs"]["f"][str(int(ss_meta["cs"]["j"][js]) + 4 * look)]
			nv = [float(f[0]), float(f[1]), float(f[2]), float(f[3])]
			sc_full[j] = [t, Vector2(nv[2] / t.get_width(), nv[3] / t.get_height())]
			sc_arect.erase(j)   # not in the far atlas: the full picture (mipmapped) at every zoom
		var d := Vector2(float(nv[0]) - float(V[j][0]), float(nv[1]) - float(V[j][1]))
		V[j] = nv
		for sp in sc_spr[j]:
			if not sp.has_meta("sw"):
				sp.position += d
		for sp in sc_rall.get(j, []):
			if is_instance_valid(sp):
				sp.position += Vector2(d.x, -d.y)
				sp.texture = sc_full[j][0]
				sp.region_enabled = false
				sp.scale = Vector2(sc_full[j][1].x, -sc_full[j][1].y)
		for sp in sc_spr[j]:
			sp.texture = sc_full[j][0]
			sp.region_enabled = false
			sp.scale = sc_full[j][1]
			if sp.has_meta("sw"):
				sp.offset = Vector2(float(nv[0]) / sc_full[j][1].x, float(nv[1]) / sc_full[j][1].y)
	sc_far = -1
	_sc_mode()
	for jo in ss_meta["mai"]["o"]:
		var j := int(jo)
		if j >= objs.size():
			continue
		var o: Dictionary = objs[j]
		var e: Array = ss_meta["mai"]["o"][jo]
		o.erase("sst")
		o["lev"] = 99
		if not o.has("piv"):
			o["spr"].offset = Vector2.ZERO
		if sea != 1:
			var k := int(e[0]) + 4 * sea
			var t: Texture2D = ss_tex.get("mai" + str(k))
			var f: Array = ss_meta["mai"]["f"][str(k)]
			if t != null:
				o["sst"] = [t, Vector2(float(e[1]) + float(f[0]), float(e[2]) + float(f[1]))]
		if o["spr"].visible:
			_show_obj(o, 0)
	print("season pictures: season ", sea)

# ---------------------------------------------------------------- fallen leaves + footpaths (web NEN2 v777 leaves(), v787 tracks())
# Leaves: every tree drops a few of its own leaves round its trunk; how many by season (web cnt()), which piece by season
# (n/ls<season>.wasm: 8 pieces per tree kind, each its own lossless picture, 8 px per unit as painted). Places, hashes and
# flips come from the game itself (tools/lfprep.py, n/lf.wasm); none on water. Drawn in 512-unit chunks, one atlas built
# in memory so every chunk batches.
const LF_KINDS := ["da", "xoai", "mit", "dieu", "tram", "tre", "chuoi", "dua", "cau", "dudu", "dambut", "bonggiay", "dao", "mai", "caosu",
	"me", "nhan", "chomchom", "buoi", "cam", "mangcut", "saurieng", "man", "thanhlong"]
const LF_SC := 1.25 / 8.0   # world units per piece pixel (web 1.25/6 on its 6 px sheet)
var lf_root: Node2D = null
var lf_chunks := []
var lf_sea := -1
var lf_atl: Texture2D = null
var lf_rect := []     # piece -> [Rect2 normal, Rect2 mirrored, w, h, ax, ay]
var lf_busy := false
# (b72) ?do : counts draw calls with each group hidden for 3 s (all, -UI, -verges, -built/logic, -scenery), then puts all back
var do_on := -1
var do_ph := -1
var do_t := 0
var do_sum := 0.0
var do_n := 0
var do_hid := []
var do_res := []
const DO_NAMES := ["tất cả", "bỏ UI", "bỏ viền đường", "bỏ đồ xây/logic", "bỏ cây cảnh"]
func _do_step() -> void:
	if do_on < 0:
		do_on = 1 if _tflag("__do") else 0
	if do_on != 1 or info.is_empty():
		return
	var now := Time.get_ticks_msec()
	if do_ph < 0:
		do_ph = 0
		do_t = now + 15000   # let it settle first
		return
	if now < do_t:
		pt_drw = "đang đo %s… %s" % [DO_NAMES[do_ph], " · ".join(do_res)]
		if now > do_t - 2500:
			do_sum += Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)
			do_n += 1
		return
	do_res.append("%s %d" % [DO_NAMES[do_ph], round(do_sum / maxf(1.0, do_n))])
	pt_drw = " · ".join(do_res)
	do_sum = 0.0
	do_n = 0
	do_ph += 1
	do_t = now + 3500
	if do_ph >= DO_NAMES.size():
		for n in do_hid:
			if is_instance_valid(n):
				n.visible = true
		do_hid.clear()
		do_on = 2
		pt_drw = "XONG: " + pt_drw
		return
	var scs := {}
	for L in sc_spr:
		for sp in L:
			scs[sp] = true
	if do_ph == 1:
		for n in get_tree().root.get_children():
			for c in n.get_children():
				if c is CanvasLayer and c.layer > 0 and c.visible and c != meter.get_parent():
					c.visible = false
					do_hid.append(c)
			if n is CanvasLayer and n.layer > 0 and n.visible and n != meter.get_parent():
				n.visible = false
				do_hid.append(n)
	for n in obj_root.get_children():
		if not (n is CanvasItem) or not n.visible:
			continue
		var hide := false
		if scs.has(n):
			hide = do_ph == 4
		elif vg_rows.has(n):
			hide = do_ph == 2
		else:
			hide = do_ph == 3
		if hide:
			n.visible = false
			do_hid.append(n)
# (b75) ?do2 : hides each top-level layer alone for 1.5 s and lists the ones whose hiding saves most draw calls
var do2_on := -1
var do2_L := []
var do2_i := -2
var do2_t := 0
var do2_sum := 0.0
var do2_n := 0
var do2_base := 0.0
var do2_res := []
var do2_ms := 0.0
var do2_last := 0
var do2_bms := 0.0
func _do2_name(n: Node) -> String:
	var s := _nname(n)
	if n == obj_root: s = "obj_root"
	elif lev_nodes.has(n): s = "nền mức " + str(lev_nodes.find(n))
	elif n == lf_root: s = "lá"
	elif n == water: s = "sông"
	var z: int = n.z_index if n is CanvasItem else 0
	return "%s(z%d,%d con)" % [s, z, n.get_child_count()]
func _do2_step() -> void:
	if do2_on < 0:
		do2_on = 1 if _tflag("__do2") else 0
	if do2_on != 1 or info.is_empty():
		return
	if do2_i >= 0 and do2_i < do2_L.size() and is_instance_valid(do2_L[do2_i]):
		do2_L[do2_i].visible = false   # ground levels get their visibility set again every frame
	var now := Time.get_ticks_msec()
	if do2_i == -2:
		do2_i = -1
		do2_t = now + 15000
		do2_last = now
		return
	if now < do2_t:
		pt_drw = "đang đo lớp %d/%d" % [do2_i + 1, do2_L.size()]
		if now > do2_t - 1200:
			do2_sum += Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)
			do2_ms += now - do2_last
			do2_n += 1
		do2_last = now
		return
	do2_last = now
	var v := do2_sum / maxf(1.0, do2_n)
	var vms := do2_ms / maxf(1.0, do2_n)
	do2_sum = 0.0
	do2_ms = 0.0
	do2_n = 0
	if do2_i == do2_L.size():
		night_mat.set_shader_parameter("uFast", 0.0)
		do2_res.sort_custom(func(x, y): return x[2] > y[2])
		var o := []
		for i in mini(8, do2_res.size()):
			o.append("%s -%d lệnh -%.1fms" % [do2_res[i][1], round(do2_res[i][0]), do2_res[i][2]])
		pt_drw = "XONG (gốc %d lệnh, %.1f ms/khung; lọc nét đơn giản: -%.1fms): " % [round(do2_base), do2_bms, do2_bms - vms] + " · ".join(o)
		do2_on = 2
		return
	if do2_i == -1:
		do2_base = v
		do2_bms = vms
		for n in get_children():
			if n is CanvasItem and n.visible and n != meter.get_parent():
				do2_L.append(n)
			elif n is CanvasLayer and n.visible and n != meter.get_parent():
				do2_L.append(n)
	else:
		var n = do2_L[do2_i]
		if is_instance_valid(n):
			n.visible = true
			do2_res.append([do2_base - v, _do2_name(n), do2_bms - vms])
	do2_i += 1
	if do2_i >= do2_L.size():
		night_mat.set_shader_parameter("uFast", 1.0)   # last window: everything shown, plain picture lookup
		do2_t = now + 2500
		return
	var m = do2_L[do2_i]
	if is_instance_valid(m):
		m.visible = false
	do2_t = now + 2500
func _tflag(n: String) -> bool:   # test switches (window.__nolf / __notr / __nosw)
	# (b65) also from the address: ?nosky&nohz&nozf&nosort turns the parts off, so Link can read the fps of each
	return OS.has_feature("web") and bool(JavaScriptBridge.eval("!!window." + n + "||new URLSearchParams(location.search).has('" + n.substr(2) + "')"))
func _load_leaves() -> void:
	if _tflag("__nolf"):
		return
	lf_root = Node2D.new()
	lf_root.z_index = -39   # over the ground (-40), under the pond water and everything standing
	lf_root.material = night_mat
	lf_root.modulate = Color(1, 1, 1, 0.96)
	add_child(lf_root)
	_fetch("n/lf.wasm?v=1", func(b: PackedByteArray):
		var nt := b.decode_u32(4)
		var o := 8
		var C := {}
		for t in nt:
			var k := b[o]
			var n4 := b.slice(o + 1, o + 5)
			var nl := b.decode_u16(o + 5)
			o += 7
			for i in nl:
				var x := b.decode_float(o)
				var y := b.decode_float(o + 4)
				var key := Vector2i(floori(x / 512.0), floori(y / 512.0))
				var ch: LeafChunk = C.get(key)
				if ch == null:
					ch = LeafChunk.new()
					ch.main = self
					ch.use_parent_material = true
					C[key] = ch
				ch.xs.append(x)
				ch.ys.append(y)
				ch.jk.append(b[o + 8])
				ch.pc.append(b[o + 9])
				ch.kd.append(k)
				ch.n4.append_array(n4)
				o += 10
		for key in C:
			lf_root.add_child(C[key])
			lf_chunks.append(C[key]))
func _leaf_tick() -> void:
	if lf_root == null:
		return
	lf_root.visible = zoom >= 0.6 and lf_atl != null
	var sea: int = int(troi.get("season", 1)) if troi.has("season") else 1
	if sea != lf_sea and not lf_busy:
		lf_busy = true
		_fetch("n/ls" + str(sea) + ".wasm?v=1", func(b: PackedByteArray):
			lf_busy = false
			var jl := b.decode_u32(0)
			var idx: Array = JSON.parse_string(b.slice(4, 4 + jl).get_string_from_utf8())
			var base := 4 + jl
			var ims := []
			var W := 2048
			var x := 2; var y := 2; var rowh := 0
			var at := []
			for e in idx:
				var im := Image.new()
				im.load_webp_from_buffer(b.slice(base + int(e[4]), base + int(e[4]) + int(e[5])))
				im.convert(Image.FORMAT_RGBA8)
				var mi := im.duplicate()
				mi.flip_x()
				ims.append([im, mi])
				for q in 2:
					if x + im.get_width() + 2 > W:
						x = 2; y += rowh + 2; rowh = 0
					at.append(Vector2i(x, y))
					x += im.get_width() + 2
					rowh = maxi(rowh, im.get_height())
			var H := y + rowh + 2
			var big := Image.create(W, H, false, Image.FORMAT_RGBA8)
			lf_rect.clear()
			for i in idx.size():
				var e: Array = idx[i]
				var a0: Vector2i = at[i * 2]
				var a1: Vector2i = at[i * 2 + 1]
				big.blit_rect(ims[i][0], Rect2i(Vector2i.ZERO, ims[i][0].get_size()), a0)
				big.blit_rect(ims[i][1], Rect2i(Vector2i.ZERO, ims[i][1].get_size()), a1)
				lf_rect.append([Rect2(a0, ims[i][0].get_size()), Rect2(a1, ims[i][1].get_size()), float(e[0]), float(e[1]), float(e[2]), float(e[3])])
			big.generate_mipmaps()
			lf_atl = ImageTexture.create_from_image(big)
			lf_sea = sea
			for ch in lf_chunks:
				ch.queue_redraw())
class LeafChunk extends Node2D:
	var main
	var xs := PackedFloat32Array()
	var ys := PackedFloat32Array()
	var jk := PackedByteArray()
	var pc := PackedByteArray()
	var kd := PackedByteArray()
	var n4 := PackedByteArray()
	func _draw() -> void:
		var atl: Texture2D = main.lf_atl
		if atl == null:
			return
		var se: int = main.lf_sea
		var R: Array = main.lf_rect
		for i in xs.size():
			if jk[i] >= n4[i * 4 + se]:
				continue
			var k: int = kd[i]
			var p: int = pc[i]
			# mai / đào drop flowers only round Tết (pieces 0-3 flowers, 4-7 leaves)
			var fv0 := 4 if (k == 12 or k == 13) and se != 0 else 0
			var pi := k * 8 + (mini(3, (p >> 4) & 7) + 4 if fv0 == 4 else (p & 15))
			var r: Array = R[pi]
			var fl := (p & 128) != 0
			var w: float = r[2] * LF_SC
			var h: float = r[3] * LF_SC
			var x0: float = xs[i] - ((r[2] - r[4]) if fl else r[4]) * LF_SC
			draw_texture_rect_region(atl, Rect2(x0, ys[i] - r[5] * LF_SC, w, h), r[1] if fl else r[0])

# Footpaths: from each house yard to the nearest road or laid path, and on from a path that stops in the grass; the web
# strokes them with the yard's earth 15 / 10 / 6 wide at .28 / .55 / .9 (n/tr.json, world polylines from tools/lfprep.py)
var track_mat: ShaderMaterial = null
func _load_tracks() -> void:
	if _tflag("__notr"):
		track_mat = ShaderMaterial.new()
		return
	track_mat = ShaderMaterial.new()
	track_mat.shader = load("res://track.gdshader")
	_nm(track_mat)
	var gm: ShaderMaterial = ground.material
	track_mat.set_shader_parameter("uRA", gm.get_shader_parameter("uRA"))
	track_mat.set_shader_parameter("oY", gm.get_shader_parameter("oY"))
	var root := Node2D.new()
	root.z_index = -39
	root.material = track_mat
	add_child(root)
	move_child(root, lf_root.get_index() if lf_root != null else get_child_count() - 1)   # under the leaves
	_fetch("n/tr.json?v=1", func(b: PackedByteArray):
		var T = JSON.parse_string(b.get_string_from_utf8())
		if not (T is Array):
			return
		for q in T:
			var P := PackedVector2Array()
			for i in range(0, q.size(), 2):
				P.append(Vector2(q[i], q[i + 1]))
			for wa in [[15.0, 0.28], [10.0, 0.55], [6.0, 0.9]]:
				var l := Line2D.new()
				l.points = P
				l.width = wa[0]
				l.default_color = Color(1, 1, 1, wa[1])
				l.joint_mode = Line2D.LINE_JOINT_ROUND
				l.begin_cap_mode = Line2D.LINE_CAP_ROUND
				l.end_cap_mode = Line2D.LINE_CAP_ROUND
				l.use_parent_material = true
				root.add_child(l))


# ---------------------------------------------------------------- xưởng (logic calls xuong_set(rects) when the workshops change)
# rects = {key: [gx, gy, fw, fd, kind]}: village scenery and decorations whose foot stands on a workshop's tiles are taken
# away while it stands there (and come back when it is moved or removed)
var xg_sig := ""
func _foot_tile(p: Vector2) -> Vector2:
	var dx := p.x - 4268.0
	var dy := p.y - 968.0
	return Vector2((dy / 16.0 + dx / 32.0) / 2.0, (dy / 16.0 - dx / 32.0) / 2.0)
func xuong_set(rects) -> void:
	if not (rects is Dictionary):
		return
	var sig := JSON.stringify(rects)
	if sig == xg_sig:
		return
	xg_sig = sig
	var R := []
	for k in rects:
		var r = rects[k]
		if r is Array and r.size() >= 4:
			R.append(Rect2(float(r[0]), float(r[1]), float(r[2]), float(r[3])))
	var inside := func(p: Vector2) -> bool:
		var t: Vector2 = _foot_tile(p)
		for q in R:
			if t.x >= q.position.x and t.y >= q.position.y and t.x < q.end.x and t.y < q.end.y:
				return true
		return false
	if not sc_data.is_empty():
		var V: Array = sc_data["v"]
		for j in sc_spr.size():
			var v = V[j]
			if v == null or j == 16:
				continue
			for sp in sc_spr[j]:
				var foot: Vector2 = sp.position if sp.has_meta("sw") else sp.position - Vector2(float(v[0]), float(v[1]))
				var on: bool = inside.call(foot)
				if on != bool(sp.get_meta("xg", false)):
					sp.set_meta("xg", on)
					sp.visible = sp.texture != null and _lot_vis(sp)
	for o in objs:
		var foot: Vector2 = o["piv"] if o.has("piv") else Vector2(o["x"] + o["w"] * 0.5, o["y"] + o["h"] * 0.88)
		var on: bool = inside.call(foot)
		if on != o.get("xg", false):
			o["xg"] = on
			if on:
				o["spr"].visible = false
			else:
				o["lev"] = 99   # shown again by the next object pass


# (b51) tổ ong in the tràm/fruit trees, drawn live from the web game's own hive code (aZ): a hanging string, the comb
# (ellipse 5.4 x 9 units, honey colour) with three curved bands, and three bees circling it. Vector, so sharp at any zoom.
class HiveNode extends Node2D:
	var t := 0.0
	func _process(dt: float) -> void:
		t += dt
		queue_redraw()
	func _q(a: Vector2, c: Vector2, b: Vector2) -> PackedVector2Array:
		var p := PackedVector2Array()
		for i in 9:
			var u := i / 8.0
			p.append(a.lerp(c, u).lerp(c.lerp(b, u), u))
		return p
	func _ell(c: Vector2, rx: float, ry: float, n: int) -> PackedVector2Array:
		var p := PackedVector2Array()
		for i in n:
			var a := TAU * i / n
			p.append(c + Vector2(cos(a) * rx, sin(a) * ry))
		return p
	func _draw() -> void:
		draw_line(Vector2(0, -12), Vector2(0, -8), Color("#5a4a3a"), 1.2, true)
		var body := _ell(Vector2.ZERO, 5.4, 9.0, 48)
		draw_colored_polygon(body, Color("#c98a2e"))
		body.append(body[0])
		draw_polyline(body, Color("#c98a2e"), 0.25, true)
		for r in [-1, 0, 1]:
			var y: float = r * 3.5
			draw_polyline(_q(Vector2(-5, y), Vector2(0, y + 1.6), Vector2(5, y)), Color("#8a5a1a"), 0.8, true)
		for r in 3:
			var o := t * 3.0 + r * 2.1
			draw_colored_polygon(_ell(Vector2(cos(o) * 10.0, -2.0 + sin(o * 1.3) * 6.0), 1.3, 1.0, 12), Color("#2a2010"))


# (b52) roads the player lays or digs up (Xây dựng > Mặt đất > Đường), like the web's fg(): g.road[k] first, g.unroad[k]
# = no road there, else the village's own road. The logic calls road_set with the WHOLE g.road / g.unroad every time;
# it is worked out again from the original road map: tier 4 (laid road) of that kind, the 4-side links redone round every
# changed tile (a tile links to any road neighbour, like the original map), the ground shader's road map swapped, and the
# grass verges along road edges rebuilt. Colours never change with the season (Link 11-13 "đường cố định").
#   add = {"x,y": kind}, kind one of dat do cat soi gach da;  rm = ["x,y", ...] original road tiles taken away
var road_orig: Image = null
var road_pend := []
var vg_meta := {}
const ROAD_KIND := ["dat", "do", "cat", "soi", "gach", "da"]
func road_set(add: Dictionary, rm: Array) -> void:
	if road_img == null or sc_root == null or ground == null or sc_data.is_empty():
		road_pend = [add, rm]
		return
	road_pend = []
	if road_orig == null:
		road_orig = road_img.duplicate()
	var im: Image = road_orig.duplicate()
	var N: Array = info["N"]
	var W := im.get_width()
	var H := im.get_height()
	var D4 := [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]
	var ch := {}
	var pix := func(k: String) -> Vector2i:
		var p := k.split(",")
		if p.size() != 2:
			return Vector2i(-1, -1)
		return Vector2i(int(p[0]) - int(N[0]), int(p[1]) - int(N[2]))
	for k in rm:
		var q: Vector2i = pix.call(str(k))
		if q.x < 0 or q.y < 0 or q.x >= W or q.y >= H:
			continue
		var c := im.get_pixel(q.x, q.y)
		im.set_pixel(q.x, q.y, Color8(0, 0, 0, c.a8))
		ch[q] = true
	for k in add.keys():
		var q: Vector2i = pix.call(str(k))
		var kd := ROAD_KIND.find(str(add[k]))
		if kd < 0 or q.x < 0 or q.y < 0 or q.x >= W or q.y >= H:
			continue
		var c := im.get_pixel(q.x, q.y)
		im.set_pixel(q.x, q.y, Color8(4, 0, kd, c.a8))
		ch[q] = true
	var aff := {}
	for q in ch.keys():
		aff[q] = true
		for d in D4:
			aff[q + d] = true
	for q: Vector2i in aff.keys():
		if q.x < 0 or q.y < 0 or q.x >= W or q.y >= H:
			continue
		var c := im.get_pixel(q.x, q.y)
		if c.r8 == 0:
			if c.g8 != 0:
				im.set_pixel(q.x, q.y, Color8(0, 0, c.b8, c.a8))
			continue
		var m: int = c.g8 if not ch.has(q) else 0
		for b in 4:
			var n: Vector2i = q + D4[b]
			if not ch.has(q) and not ch.has(n):
				continue
			var nt: int = im.get_pixel(n.x, n.y).r8 if n.x >= 0 and n.y >= 0 and n.x < W and n.y < H else 0
			if nt > 0:
				m |= 1 << b
			else:
				m &= ~(1 << b)
		im.set_pixel(q.x, q.y, Color8(c.r8, m, c.b8, c.a8))
	road_img = im
	(ground.material as ShaderMaterial).set_shader_parameter("uRD", ImageTexture.create_from_image(im))
	# verges: the old rows go, the new ones go in at their place in the draw order
	for row in vg_rows:
		if is_instance_valid(row):
			row.queue_free()
			sc_root.remove_child(row)
	vg_rows = []
	var kids := sc_root.get_children()
	var keys := PackedFloat32Array()
	var lk := -1.0e9
	for n in kids:
		lk = _zkey(n, lk)
		keys.append(lk)
	var add_rows := _verges(im, vg_meta)
	add_rows.sort_custom(func(a, b): return a[0] > b[0])   # last first, so earlier indexes stay right
	for e in add_rows:
		var row = e[1]
		row.material = night_mat
		row.set_meta("k", e[0])
		row.atl = sc_atl if sc_far == 1 else null
		row.arect = sc_arect
		var i := keys.bsearch(float(e[0]), false)
		sc_root.add_child(row)
		sc_root.move_child(row, mini(i, sc_root.get_child_count() - 1))
		vg_rows.append(row)
	zs_count = -1

# ---- GIFTCODE (Link 11-13 11:00 "làm chỗ nhập giftcode, mã 1tr xu để test") ----
# The page has the input box (window.__ntgq = codes typed, window.__ntgr = answer shown under the box); the game
# checks the code here and adds the reward through the logic autoload (/root/Boot.G). Each save uses a code once (g.gc).
const GIFT := {"VUMUA1TR": {"coins": 1000000}}
func gift_try(code: String) -> String:
	var c := code.strip_edges().to_upper().replace(" ", "")
	var bt = get_node_or_null("/root/Boot")
	if bt == null or not ("G" in bt) or bt.G == null or bt.G.g.is_empty():
		return "Game chưa sẵn sàng, thử lại sau."
	if not GIFT.has(c):
		return "Mã không đúng."
	var g: Dictionary = bt.G.g
	if not g.has("gc") or not (g.gc is Array):
		g["gc"] = []
	if g.gc.has(c):
		return "Mã này làng mày dùng rồi."
	var rw: Dictionary = GIFT[c]
	g.gc.append(c)
	if rw.has("coins"):
		g.coins = int(g.coins) + int(rw.coins)
	bt.G.mark()
	bt.G.save_game()
	var s := "Nhận %s xu!" % _gift_num(int(rw.get("coins", 0)))
	if "ui" in bt and bt.ui != null and bt.ui.has_method("say"):
		bt.ui.say(s)
	return s
func _gift_num(n: int) -> String:
	var s := str(n)
	var o := ""
	while s.length() > 3:
		o = "." + s.substr(s.length() - 3) + o
		s = s.substr(0, s.length() - 3)
	return s + o
func _gift_poll() -> void:
	var c = JavaScriptBridge.eval("(window.__ntgq&&window.__ntgq.length)?String(window.__ntgq.shift()):''")
	if c == null or str(c) == "":
		return
	var r := gift_try(str(c))
	JavaScriptBridge.eval("window.__ntgr=" + JSON.stringify(r) + ";window.__ntgshow&&window.__ntgshow()")


# (b55) things the player built (logic lang_ve: houses, công trình) take the export's own night frame at night, lamps lit,
# like the village's own things (opn). lang_ve keeps its tk "op:<day name>", so it leaves the swapped picture alone.
func _lv_night() -> void:
	var fm = get_node_or_null("Farm")
	if fm == null or fm.get("lang_ve") == null:
		return
	var on := night_cur == 1
	var opn: Dictionary = info.get("opn", {})
	for s in fm.lang_ve.nodes:
		if not (is_instance_valid(s) and s is Sprite2D):
			continue
		var tk: String = s.get_meta("tk", "")
		if not tk.begins_with("op:"):
			continue
		var nm := tk.substr(3)
		var nn = opn.get(nm) if on else null
		var want: String = "" if nn == null else String(nn[0])
		if String(s.get_meta("ntk", "")) == want:
			continue
		if want == "":   # back to the day picture: lang_ve puts it back next frame
			s.set_meta("tk", "")
			s.set_meta("ntk", "")
			s.material = night_mat
			continue
		var tx: Texture2D = op_tex.get(want)
		if tx == null:
			if not op_tex.has(want):
				_op_want(want)
			continue
		var a := op_box(nm)
		if a.size() < 4:
			continue
		var u := float(a[2]) / float(nn[5])
		var w := float(nn[3]) * u
		var ox := float(a[0]) + float(nn[1]) * u
		if s.flip_h:
			ox = -(ox + w)
		var off := Vector2(ox, float(a[1]) + float(nn[2]) * u)
		if s.has_meta("fd"):
			off += s.get_meta("fd")
		var sc := w / float(tx.get_width())
		s.texture = tx
		s.scale = Vector2(sc, sc)
		s.offset = off / sc
		s.material = night_raw
		s.set_meta("ntk", want)


# ---- (b56) DRAW ORDER like the web (Link 11-13 20:11 "cái nào ở ô trước thì hiện đè lên ô sau") ----
# Web BE(): scenery t2, objects So, placed things Hr, plots zE, signs, animals go in one array, sorted by k = gx+gy of
# the thing's foot (= (screen y at the ground - 968) / 16). Godot: obj_root holds all of them; statics carry meta "k";
# the logic's nodes (farm.sortables [node, dk = ground y]) are moved to their k place every frame after the logic runs.
class ZFixer extends Node:
	var m
	func _process(_d: float) -> void:
		var t0 := Time.get_ticks_usec()
		m._zfix()
		m.pt["xếp"] = m.pt.get("xếp", 0.0) + (Time.get_ticks_usec() - t0)
# (b70) time markers: first and last node to run _process each frame -> total script time of the whole tree
class PMark extends Node:
	var m
	var first := true
	func _process(_d: float) -> void:
		var now := Time.get_ticks_usec()
		if first:
			m.pt_t0 = now
			if m.pt_ta > 0:
				m.pt["trước"] = m.pt.get("trước", 0.0) + (now - m.pt_ta)
		else:
			m.pt["tổng"] = m.pt.get("tổng", 0.0) + (now - m.pt_t0)
			m.pt_tc = now
			m._pt_after.call_deferred()
var pt := {}
var pt_t0 := 0
var pt_ta := 0
var pt_tc := 0
var drw := {}        # (b71) redraws per script/class in this window
var drw_on := {}     # instance ids already hooked to "draw"
var pt_drw := ""
func _pt_frame() -> void:
	pt_ta = Time.get_ticks_usec()
func _pt_after() -> void:
	pt["sau"] = pt.get("sau", 0.0) + (Time.get_ticks_usec() - pt_tc)
func _pt_drawn(nm: String) -> void:
	drw[nm] = drw.get(nm, 0) + 1
static func _nname(n: Node) -> String:
	var s = n.get_script()
	if s != null:
		if s.resource_path != "":
			return s.resource_path.get_file()
		var g = s.get_global_name()
		if g != &"":
			return str(g)
		var b = s.get_base_script()
		return n.get_class() + "<" + (b.resource_path.get_file() if b != null and b.resource_path != "" else "lớp trong") + ">"
	return n.get_class()
var pt_shown := ""
var pt_proc := ""
func _pt_add(k: String, t0: int) -> int:
	var t1 := Time.get_ticks_usec()
	pt[k] = pt.get(k, 0.0) + (t1 - t0)
	return t1
# (b70) which scripts keep _process on, and how many nodes of each
func _proc_count() -> String:
	var cnt := {}
	var st := [get_tree().root]
	while not st.is_empty():
		var n: Node = st.pop_back()
		if n.is_processing() or n.is_physics_processing() or n.is_processing_internal():
			var nm: String = _nname(n) + ("*" if n.is_processing_internal() and not n.is_processing() else "")
			cnt[nm] = cnt.get(nm, 0) + 1
		if n is CanvasItem and not drw_on.has(n.get_instance_id()):
			drw_on[n.get_instance_id()] = true
			n.draw.connect(_pt_drawn.bind(_nname(n)))
		for c in n.get_children():
			st.append(c)
	var ks := cnt.keys()
	ks.sort_custom(func(x, y): return cnt[x] > cnt[y])
	var o := []
	for i in mini(6, ks.size()):
		o.append("%s %d" % [ks[i], cnt[ks[i]]])
	return " · ".join(o)
func _drw_text(frames: int) -> String:
	var ks := drw.keys()
	ks.sort_custom(func(x, y): return drw[x] > drw[y])
	var o := []
	for i in mini(6, ks.size()):
		o.append("%s %.1f" % [ks[i], drw[ks[i]] / maxf(1.0, frames)])
	drw.clear()
	return " · ".join(o)
var zs_ready := false
var zs_count := -1
var zs_keys := PackedFloat32Array()
var zs_nodes := []
func _zsort_all() -> void:
	var kids := obj_root.get_children()
	var L := []
	var last := -1.0e9
	for i in kids.size():
		var n: Node = kids[i]
		var kf: float = _zkey(n, last)
		last = kf
		L.append([kf, i, n])
	L.sort_custom(func(a, b): return a[0] < b[0] or (a[0] == b[0] and a[1] < b[1]))
	for i in L.size():
		var n: Node = L[i][2]
		if obj_root.get_child(i) != n:
			obj_root.move_child(n, i)
	zs_ready = true
	zs_count = -1
var zf_off := -1
func _zfix() -> void:
	if zf_off < 0:
		zf_off = 1 if _tflag("__nozf") else 0
	if zf_off == 1 or not zs_ready:
		return
	var fm = get_node_or_null("Farm")
	if fm == null or not ("sortables" in fm):
		return
	var S: Array = fm.sortables
	var mine := {}
	var L := []
	for e in S:
		var n = e[0]
		if is_instance_valid(n) and n.get_parent() == obj_root:
			mine[n] = true
			L.append([(float(e[1]) - 968.0) / 16.0, n])
	if obj_root.get_child_count() != zs_count:
		zs_count = obj_root.get_child_count()
		zs_keys = PackedFloat32Array()
		zs_nodes = []
		var last := -1.0e9
		for n in obj_root.get_children():
			if mine.has(n):
				continue
			var kf: float = _zkey(n, last)
			last = kf
			zs_keys.append(kf)
			zs_nodes.append(n)
	L.sort_custom(func(a, b): return a[0] < b[0])
	var pt := -1
	var pn: Node = null
	for e in L:
		var n: Node = e[1]
		n.set_meta("zk", e[0])   # NOT "k": the logic's lang_ve keeps its frame name ("d0") in meta "k"
		var t := zs_keys.bsearch(e[0], false)
		var nxt: Node = zs_nodes[t] if t < zs_nodes.size() else null
		var prv: Node = zs_nodes[t - 1] if t > 0 else null
		var idx := n.get_index()
		var ok := (prv == null or prv.get_index() < idx) and (nxt == null or nxt.get_index() > idx)
		if ok and pt == t and pn != null and pn.get_index() > idx:
			ok = false
		if not ok:
			if nxt == null:
				obj_root.move_child(n, -1)
			else:
				var ni := nxt.get_index()
				obj_root.move_child(n, ni if idx > ni else ni - 1)
		pt = t
		pn = n


# ---- (b59) SKY = web bG(t) (Link 11-13 20:18 "đường chân trời là núi với mặt trời mặt trăng sáng tối như logic web") ----
# Screen space, css px (x dpr): gradient Le.skyA -> Le.skyB over the screen; night: 46 twinkling stars Me(n,7/9) in the top
# 42 %, moon = disc #f6efd0 r17 cut by a skyA disc r15 at (+6,-4) + faint halo r30; day: sun glow radial 4..70 + disc
# #fff2b0 r13; sun/moon at (.84 W, min(60, .12 H)). 4 clouds (4 circles as one shape) drifting right at 6/4/5/3.5 px/s.
# Colours come from the logic's palette (troi st.pal = web OO(night, season)); the mountains are the village's own.
class SkyBG extends Node2D:
	var main
	var cloud := {}
	var glow: GradientTexture2D = null
	func _process(_d: float) -> void:
		queue_redraw()
	func _shape(d: float) -> PackedVector2Array:
		if cloud.has(d):
			return cloud[d]
		var C := [[0.0, 0.0, 14.0], [16.0, -7.0, 17.0], [34.0, 0.0, 14.0], [17.0, 3.0, 15.0]]
		var poly := PackedVector2Array()
		for c in C:
			var pc := PackedVector2Array()
			for i in 40:
				var a := TAU * i / 40.0
				pc.append(Vector2(c[0] * d + cos(a) * c[2] * d, c[1] * d + sin(a) * c[2] * d))
			if poly.is_empty():
				poly = pc
			else:
				var m := Geometry2D.merge_polygons(poly, pc)
				if m.size() > 0:
					poly = m[0]
		cloud[d] = poly
		return poly
	func _draw() -> void:
		var dpr: float = main.dpr
		var vs: Vector2 = get_viewport_rect().size / dpr
		var di := vs.x
		var Ti := vs.y
		var st: Dictionary = main.troi
		var night: bool = bool(st.get("night", main._night_on()))
		var pal = st.get("pal", null)
		var cA := Color("#07122a") if night else Color("#8fd0f5")
		var cB := Color("#1a3a3d") if night else Color("#eaf6e4")
		if pal is Dictionary:
			cA = Color(String(pal.get("skyA", cA.to_html(false))))
			cB = Color(String(pal.get("skyB", cB.to_html(false))))
		var t := Time.get_ticks_msec() / 1000.0
		draw_set_transform(Vector2.ZERO, 0.0, Vector2(dpr, dpr))
		draw_polygon(PackedVector2Array([Vector2(0, 0), Vector2(di, 0), Vector2(di, Ti), Vector2(0, Ti)]),
			PackedColorArray([cA, cA, cB, cB]))
		var l := di * 0.84
		var c := minf(60.0, Ti * 0.12)
		if night:
			for n in 46:
				var e: float = main.me_hash(n, 7) * di
				var r: float = main.me_hash(n, 9) * Ti * 0.42
				var al := 0.35 + 0.65 * (0.5 + 0.5 * sin(t * 1.4 + n * 2.1))
				var z := 2.0 if n % 5 == 0 else 1.4
				draw_rect(Rect2(e, r, z, z), Color(1.0, 0.965, 0.847, al))
			draw_circle(Vector2(l, c), 17.0, Color("#f6efd0"))
			draw_circle(Vector2(l + 6, c - 4), 15.0, cA)
			draw_circle(Vector2(l, c), 30.0, Color(246 / 255.0, 239 / 255.0, 208 / 255.0, 0.07))
		else:
			if glow == null:
				var g := Gradient.new()
				# radial 4 -> 70 px: offsets on 0..1 of radius 70 (4/70 = .057, .3 stop at 4 + .3 * 66 = 23.8 -> .34)
				g.offsets = PackedFloat32Array([0.057, 0.34, 1.0])
				g.colors = PackedColorArray([Color(1.0, 244 / 255.0, 190 / 255.0, 0.95), Color(1.0, 236 / 255.0, 150 / 255.0, 0.45), Color(1.0, 236 / 255.0, 150 / 255.0, 0.0)])
				glow = GradientTexture2D.new()
				glow.gradient = g
				glow.fill = GradientTexture2D.FILL_RADIAL
				glow.fill_from = Vector2(0.5, 0.5)
				glow.fill_to = Vector2(1.0, 0.5)
				glow.width = 256
				glow.height = 256
			draw_texture_rect(glow, Rect2(l - 70, c - 70, 140, 140), false)
			draw_circle(Vector2(l, c), 13.0, Color("#fff2b0"))
		var S := [[0.1, 0.1, 1.0, 6.0], [0.38, 0.2, 0.7, 4.0], [0.62, 0.07, 0.85, 5.0], [0.9, 0.22, 0.6, 3.5]]
		var fc := Color(120 / 255.0, 150 / 255.0, 190 / 255.0, 0.28) if night else Color(1, 1, 1, 0.88)
		for h in S:
			var p := fposmod(h[0] * (di + 160.0) + t * h[3], di + 160.0) - 80.0
			var d: float = h[2]
			var v: float = h[1] * Ti
			draw_set_transform(Vector2(p, v) * dpr, 0.0, Vector2(dpr, dpr))
			draw_colored_polygon(_shape(d), fc)
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


# ---- (b60) HORIZON = web TH.hz(t0, t1) (index.html TH module): the ground above y = xf + HZL (350) is cleared (ground
# shader discards) so bG shows; 3 mountain ranges mtn() (xf = 360 base, sine ridges, shaded faces valley->peak, ridge
# lines on the falling slopes, haze on the far range), clipped to y < 350; then 3 tree-line rows with bush tops and palms
# along y = 351. Colours: web m(day, night) and Le.grassA (troi pal). The massif by the river is the village's hill.
class Horizon extends Node2D:
	# (b64) Link 11-13 21:12 "fps tụt xuống 1": the b60 horizon was ONE canvas item with ~3600 circles + ~2800 antialiased
	# lines, drawn every frame whatever was on screen. Now: 1 node per 512 px of map width (Godot skips the ones off
	# screen), each tree-line row is ONE polygon (top edge = ridge and bush tops merged), palms = 2 multiline calls.
	var main
	var sig := ""
	const XF := 360.0
	const HZL := -10.0
	const CW := 512.0
	var night := false
	var ga := Color("#99cc56")
	var parts := []
	# (b64, Link 21:13 "vẽ ra ảnh đi rồi gắn lên") each 512 px part is drawn ONCE into a picture (SubViewport, 2 px per
	# world px), kept as a texture on a plain Sprite2D; redrawn only when day/night or the season's grass colour changes.
	const Y0 := 165.0
	const Y1 := 365.0
	const S := 2.0
	var svp: SubViewport = null
	var bq := []          # parts still to draw into pictures
	var busy := false
	func _process(_d: float) -> void:
		if parts.is_empty():
			svp = SubViewport.new()
			svp.size = Vector2i(int(CW * S), int((Y1 - Y0) * S))
			svp.transparent_bg = true
			svp.disable_3d = true
			svp.render_target_update_mode = SubViewport.UPDATE_DISABLED
			add_child(svp)
			var t1: float = float(main.info["DW"]) + 300.0
			var x := -300.0
			while x < t1:
				var sp := Sprite2D.new()
				sp.centered = false
				sp.position = Vector2(x, Y0)
				sp.scale = Vector2(1.0 / S, 1.0 / S)
				sp.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
				add_child(sp)
				parts.append([x, sp])
				x += CW
		var st: Dictionary = main.troi
		var nt := bool(st.get("night", main._night_on()))
		var gs := "#99cc56"
		var pal = st.get("pal", null)
		if pal is Dictionary:
			gs = String(pal.get("grassA", gs))
		var k := str(nt) + gs
		if k != sig and not busy:
			sig = k
			night = nt
			ga = Color(gs)
			bq = parts.duplicate()
		if not busy and bq.size() > 0:
			_bake(bq.pop_front())
	func _bake(e: Array) -> void:
		busy = true
		var x0: float = e[0]
		var c := HzPart.new()
		c.h = self
		c.x0 = x0
		c.x1 = x0 + CW
		c.scale = Vector2(S, S)
		c.position = -Vector2(x0, Y0) * S
		svp.add_child(c)
		svp.render_target_update_mode = SubViewport.UPDATE_ONCE
		await RenderingServer.frame_post_draw
		await RenderingServer.frame_post_draw
		var img := svp.get_texture().get_image()
		c.queue_free()
		if img != null and not img.is_empty():
			img.generate_mipmaps()
			e[1].texture = ImageTexture.create_from_image(img)
		busy = false
	static func ml(a: Color, b: Color, t: float) -> Color:
		return Color(a.r * (1.0 - t) + b.r * t, a.g * (1.0 - t) + b.g * t, a.b * (1.0 - t) + b.b * t, 1.0)
	func m(d: String, n: String) -> Color:
		return Color(n if night else d)
	static func sm(x: float) -> float:
		return x * x * (3.0 - 2.0 * x)
	func vn(x: float, y: float) -> float:
		var x0 := floori(x)
		var y0 := floori(y)
		var fx := sm(x - x0)
		var fy := sm(y - y0)
		var a: float = main.me_hash(x0 + 911, y0 + 37)
		var b: float = main.me_hash(x0 + 912, y0 + 37)
		var c: float = main.me_hash(x0 + 911, y0 + 38)
		var d: float = main.me_hash(x0 + 912, y0 + 38)
		return a + (b - a) * fx + (c - a) * fy + (a - b - c + d) * fx * fy
	static func quad(p0: Vector2, c: Vector2, p1: Vector2, out: PackedVector2Array, n := 12) -> void:
		for i in range(1, n + 1):
			var t := float(i) / n
			out.append(p0 * (1 - t) * (1 - t) + c * 2 * (1 - t) * t + p1 * t * t)
	static func cubic(p0: Vector2, c1: Vector2, c2: Vector2, p1: Vector2, out: PackedVector2Array, n := 16) -> void:
		for i in range(1, n + 1):
			var t := float(i) / n
			var u := 1.0 - t
			out.append(p0 * u * u * u + c1 * 3 * u * u * t + c2 * 3 * u * t * t + p1 * t * t * t)
	static func seg(pts: PackedVector2Array, out: PackedVector2Array) -> void:   # polyline -> line pairs for draw_multiline
		for i in pts.size() - 1:
			out.append(pts[i])
			out.append(pts[i + 1])
	const ML := [
		["#b5d3df", "#1b3448", "#a3c2d3", "#162c40", Color(1, 1, 1, 0.7), 118.0, 38.0, 0.012, 0.031, 0.5, 0.22],
		["#9fc9a8", "#1f4538", "#8cb898", "#1a3b30", Color(0.941, 1, 0.922, 0.55), 78.0, 26.0, 0.017, 0.043, 2.1, 0.0],
		["#80b86f", "#255c3a", "#70a862", "#1f5032", Color(0.922, 1, 0.824, 0.5), 46.0, 16.0, 0.024, 0.06, 4.0, 0.0]]
	static func ph(Q: Array, x2: float) -> float:
		return Q[5] + Q[6] * sin(x2 * Q[7] + Q[9]) + Q[6] * 0.6 * sin(x2 * Q[8] + Q[9] * 2.0)
	func draw_part(ci: Node2D, x0: float, x1: float) -> void:
		var cy := XF + HZL
		var box := PackedVector2Array([Vector2(x0, -10000), Vector2(x1, -10000), Vector2(x1, cy), Vector2(x0, cy)])
		ci.draw_rect(Rect2(x0, cy - 2, x1 - x0, 2), ml(ga, Color("#3d4a2a" if night else "#b6ad5a"), 0.45))
		var y0 := XF
		var st := 4.0
		var xa := floorf((x0 - 8) / st) * st
		var xb := x1 + 8
		for Q in ML:
			var path := PackedVector2Array([Vector2(xa, y0 + 34)])
			var x := xa
			while x <= xb:
				path.append(Vector2(x, y0 - ph(Q, x)))
				x += st
			path.append(Vector2(xb, y0 + 34))
			var mclip := Geometry2D.intersect_polygons(path, box)
			for q in mclip:
				ci.draw_colored_polygon(q, m(Q[0], Q[1]))
			var shc := m(Q[2], Q[3])
			var xv = null
			x = floorf((x0 - 400) / st) * st
			while x <= x1 + 400:
				var h0 := ph(Q, x - st)
				var h1 := ph(Q, x)
				var h2 := ph(Q, x + st)
				if h1 <= h0 and h1 < h2:
					xv = x
				if h1 >= h0 and h1 > h2 and xv != null:
					var xp := x
					var w: float = xp - xv
					if xp > x0 - 40 and xv < x1 + 40 and w > 30:
						var F := PackedVector2Array([Vector2(xv + w * 0.5, y0 + 40)])
						quad(F[0], Vector2(xv + w * 0.08, y0 - ph(Q, xv) * 0.5), Vector2(xv, y0 - ph(Q, xv) + 1), F)
						var xx: float = xv
						while xx <= xp:
							F.append(Vector2(xx, y0 - ph(Q, xx) - 2))
							xx += st
						var fx: float = xv + w * 0.38
						var yt: float = y0 - ph(Q, xp)
						cubic(F[F.size() - 1], Vector2(xp - w * 0.12, yt + (y0 - yt) * 0.35), Vector2(fx + w * 0.1, y0 - (y0 - yt) * 0.1), Vector2(fx, y0 + 40), F)
						for q in mclip:
							for r in Geometry2D.intersect_polygons(F, q):
								ci.draw_colored_polygon(r, shc)
					xv = null
				x += st
			var rc: Color = Color(0.627, 0.706, 0.863, 0.12) if night else Q[4]
			var lines := PackedVector2Array()
			x = floorf(x0 / st) * st
			while x < x1:
				if ph(Q, x + st) < ph(Q, x) - 0.02:
					lines.append(Vector2(x, y0 - ph(Q, x) + 0.8))
					lines.append(Vector2(x + st, y0 - ph(Q, x + st) + 0.8))
				x += st
			if lines.size() > 1:
				ci.draw_multiline(lines, rc, 1.4)
			if Q[10] > 0.0:
				var ya: float = y0 - Q[5] * 0.4
				var hcol := Color(0.078, 0.141, 0.227) if night else Color(0.91, 0.949, 0.941)
				var band := PackedVector2Array([Vector2(x0, ya), Vector2(x1, ya), Vector2(x1, cy), Vector2(x0, cy)])
				for q in mclip:
					for r in Geometry2D.intersect_polygons(q, band):
						var cols := PackedColorArray()
						for v in r:
							cols.append(Color(hcol, clampf((v.y - ya) / (y0 + 20 - ya), 0.0, 1.0) * Q[10]))
						ci.draw_polygon(r, cols)
		# the tree line: each row = one polygon, its top edge the ridge and the bush tops merged (web: path + arcs, one fill)
		var yb := XF + HZL + 1
		var R := [
			[Color("#1f4636") if night else ml(ml(Color("#5f9a58"), Color("#cfe4dc"), 0.12), ga, 0.1), 24.0, 7.0, 9.0, 9.0, 0.22, 1, 1.3],
			[Color("#1a402c") if night else ml(Color("#4a8240"), ga, 0.12), 15.0, 5.0, 7.0, 8.0, 0.12, 2, 1.5],
			[ml(ga, Color("#0c1a10" if night else "#356628"), 0.62), 6.0, 2.0, 5.0, 6.0, 0.0, 3, 0.0]]
		for k in R.size():
			var Q: Array = R[k]
			var stp: float = Q[4]
			var sd: int = Q[6]
			var ja := floori((x0 - 20) / stp)
			var jb := ceili((x1 + 20) / stp)
			var HJ := {}
			var RR := {}
			for j in range(ja - 2, jb + 3):
				HJ[j] = Q[1] + Q[2] * (vn(j / 6.0 + sd * 10, sd) - 0.5) * 2.0 + Q[2] * 0.6 * (main.me_hash(j, sd * 31) - 0.5)
				RR[j] = Q[3] * (0.6 + 0.5 * main.me_hash(j + 3, sd))
			var top := PackedVector2Array()
			var x := x0
			while x <= x1 + 0.01:
				var jf := x / stp
				var j0 := floori(jf)
				var tt := jf - j0
				var yr: float = yb - (HJ[j0] * (1.0 - tt) + HJ[j0 + 1] * tt) * 0.8
				for j in [j0 - 1, j0, j0 + 1, j0 + 2]:
					var dx: float = x - j * stp
					var r: float = RR[j]
					if absf(dx) < r:
						var yc: float = yb - HJ[j] + r * 0.6 - sqrt(r * r - dx * dx)
						yr = minf(yr, yc)
				top.append(Vector2(x, yr))
				x += 1.0
			top.append(Vector2(x1, yb + 2))
			top.append(Vector2(x0, yb + 2))
			var col: Color = Q[0]
			ci.draw_colored_polygon(top, col)
			if k == 2:
				ci.draw_rect(Rect2(x0, yb - 1.5, x1 - x0, 3.5), Color(0, 0, 0, 0.25) if night else Color(0.157, 0.235, 0.078, 0.22))
			if Q[5] > 0.0:
				var trunks := PackedVector2Array()
				var leaves := PackedVector2Array()
				for j3 in range(ceili(x0 / stp), ceili(x1 / stp)):
					if main.me_hash(j3 + 51, sd * 13) > Q[5]:
						continue
					var px: float = j3 * stp
					var hb: float = HJ[j3] * 0.7
					var HH: float = hb + 14 + 16 * main.me_hash(j3, 77 + sd)
					var lean: float = (main.me_hash(j3, 5 + sd) - 0.5) * 8
					var tx := px + lean
					var ty := yb - HH
					var tr := PackedVector2Array([Vector2(px, yb - hb)])
					quad(tr[0], Vector2(px + lean * 0.2, yb - (hb + HH) / 2), Vector2(tx, ty), tr, 8)
					seg(tr, trunks)
					for f in 7:
						var an: float = -PI / 2 + (f - 3) * 0.52 + (main.me_hash(j3, f) - 0.5) * 0.2
						var ln: float = 8 + 2 * sd + 3 * main.me_hash(f, j3)
						var e := Vector2(tx + cos(an) * ln, ty + sin(an) * ln * 0.7 + ln * 0.45)
						var lf := PackedVector2Array([Vector2(tx, ty)])
						quad(lf[0], Vector2(tx + cos(an) * ln * 0.6, ty + sin(an) * ln * 0.7 - 2), e, lf, 6)
						seg(lf, leaves)
				if trunks.size() > 1:
					ci.draw_multiline(trunks, col, Q[7] + 0.3)
				if leaves.size() > 1:
					ci.draw_multiline(leaves, col, Q[7])
class HzPart extends Node2D:
	var h
	var x0 := 0.0
	var x1 := 0.0
	func _draw() -> void:
		h.draw_part(self, x0, x1)

# (b63) draw key of an obj_root child: "zk" (the logic's nodes, set by _zfix), else a numeric "k" (scenery, objects,
# verges); a string "k" is the logic's frame name, not a key (b56-62 overwrote it: built houses/pens lost their picture)
static func _zkey(n: Node, last: float) -> float:
	if n.has_meta("zk"):
		return float(n.get_meta("zk"))
	if n.has_meta("k"):
		var v = n.get_meta("k")
		if v is float or v is int:
			return float(v)
	return last
