extends RefCounted
# Rebuilds a piece of the web game's UI from its layout snapshot (ui/snap/*.json: the browser's
# measured boxes + computed CSS + SVG of every element), so Godot shows exactly what the web shows.
# Returns the root Box; `ids` maps "#id", ".class" (first) and ".class*" (all) to Boxes for the
# code that drives them.

const Css = preload("res://ui/css.gd")
const Box = preload("res://ui/box.gd")

static var _cache := {}

static func load_snap(name: String) -> Dictionary:
	if not _cache.has(name):
		_cache[name] = JSON.parse_string(FileAccess.get_file_as_string("res://ui/snap/" + name + ".json"))
	return _cache[name]

const KEYS := ["background-color", "background-image", "background-size", "background-position", "background-repeat", "border-radius", "box-shadow", "border-top", "border-right", "border-bottom", "border-left", "opacity", "overflow", "backdrop-filter"]

static func _skip(k: String, v: String) -> bool:
	if v == "" or v == "none" or v == "rgba(0, 0, 0, 0)" or v == "0px" or v == "visible" or v == "normal":
		return true
	if k == "opacity" and v == "1":
		return true
	if (k == "background-size" and (v == "auto" or v == "auto auto")) or (k == "background-position" and v == "0% 0%") or (k == "background-repeat" and v == "repeat"):
		return true
	if k.begins_with("border-") and k != "border-radius" and (v.begins_with("0px") or v.find("none") >= 0):
		return true
	return false

static func css_of(n: Dictionary) -> String:
	var c: Dictionary = n.css
	var s := ""
	for k in KEYS:
		var v: String = c.get(k, "")
		if not _skip(k, v):
			s += k + ":" + v + ";"
	return s

static func shadows_txt(s: String, z: float) -> Array:
	var out := []
	if s == "" or s == "none":
		return out
	for part in Css.split_top(s):
		var ci := part.find(")")
		var col := Css.color(part.substr(0, ci + 1))
		var n := []
		for t in part.substr(ci + 1).split(" ", false):
			n.append(Css.px(t))
		while n.size() < 3:
			n.append(0.0)
		out.append({"o": Vector2(n[0], n[1]) * z, "b": n[2] * z, "c": col})
	return out

static func drop_shadow(f: String, z: float):
	# css filter: drop-shadow(rgba(...) ox oy blur) -> {c, o, b} or null
	var i := f.find("drop-shadow(")
	if i < 0:
		return null
	var s := f.substr(i + 12)
	var ci := s.find(")")
	var col := Css.color(s.substr(0, ci + 1))
	var n := []
	for t in s.substr(ci + 1).split(" ", false):
		n.append(Css.px(t.trim_suffix(")")))
	while n.size() < 3:
		n.append(0.0)
	return {"c": col, "o": Vector2(n[0], n[1]) * z, "b": n[2] * z}

static func _rot(tf: String) -> float:
	if not tf.begins_with("matrix("):
		return 0.0
	var m := tf.substr(7, tf.length() - 8).split(",")
	var ang := atan2(float(m[1]), float(m[0]))
	return ang if absf(ang) > 0.035 else 0.0

static func _unturn(R: Array, ang: float) -> Array:
	# the browser rect of a turned element is the bounds of the turned box: find the box itself
	var c := absf(cos(ang))
	var sn := absf(sin(ang))
	var W: float = R[2]
	var H: float = R[3]
	var det := c * c - sn * sn
	var bw := W / (c + sn)
	var bh := H / (c + sn)
	if absf(det) > 0.05:
		bw = (W * c - H * sn) / det
		bh = (H * c - W * sn) / det
	return [float(R[0]) + (W - bw) * 0.5, float(R[1]) + (H - bh) * 0.5, bw, bh]

static func build(n: Dictionary, origin: Vector2, ids: Dictionary, fsh = null) -> Control:
	var b: Control = Box.new()
	var R: Array = n.r
	var z := float(n.get("z", 1.0))
	var c: Dictionary = n.css
	var rot := _rot(c.get("transform", "none"))
	if rot != 0.0:
		R = _unturn(R, rot)
	b.z = z
	b.style(css_of(n), z)
	b.place(Rect2(float(R[0]) - origin.x, float(R[1]) - origin.y, R[2], R[3]))
	if rot != 0.0:
		b.pivot_offset = b.size * 0.5
		b.rotation = rot
	b.set_meta("snap", n)
	if n.has("svg"):
		_svg(b, n.svg, R, fsh if fsh != null else drop_shadow(c.get("filter", "none"), z))
	if n.tag == "img":
		var src: String = n.get("src", "")
		if src == "pearl":
			# sen đỏ (sh()): hình ngọc trong khung 64, như svg <image> ở dưới
			b.pic(Css.image("res://ui/img/pearl.webp"), Rect2(0, 0, R[2], R[3]))
		elif src.find("xui") >= 0:
			b.pic(Css.image("res://ui/img/coin.webp"), Rect2(0, 0, R[2], R[3]))
	# an icon put in front of the text by a css ::before (Kho tabs: basket/leaf/pot)
	var icon := {}
	var bef: Dictionary = n.get("::before", {})
	if bef.get("pos", "") == "static" and bef.get("dsp", "") != "none" and (String(bef.get("bgi", "none")).begins_with("url(") or String(bef.get("mask", "none")).begins_with("url(")) and String(bef.get("w", "auto")).ends_with("px"):
		icon = bef
	if n.has("text") or not icon.is_empty():
		_text(b, n, R, z, icon)
	var order := []
	for pe in ["::before", "::after"]:
		if n.has(pe) and not (pe == "::before" and not icon.is_empty()):
			if c.get("display", "") == "flex" and c.get("flex-direction", "row") == "row":
				n[pe]["_flexrow"] = true
			var pb = _pseudo(b, n[pe], R, z, pe)
			if pb != null:
				order.append([_zi(n[pe].get("pos", "static"), String(n[pe].get("zi", "auto"))), -1 if pe == "::before" else 100000, pb])
	if n.id != "":
		ids["#" + n.id] = b
	for cl in String(n.cls).split(" ", false):
		var key := "." + cl
		if not ids.has(key):
			ids[key] = b
		var lk := key + "*"
		if not ids.has(lk):
			ids[lk] = []
		ids[lk].append(b)
	# a wrapper with a drop-shadow filter (Kho corner flowers) hands it to its svg
	var pass_sh = drop_shadow(c.get("filter", "none"), z)
	var i := 0
	for k in n.get("kids", []):
		var kb := build(k, Vector2(R[0], R[1]), ids, pass_sh if k.has("svg") else null)
		order.append([_zi(k.css.get("position", "static"), k.css.get("z-index", "auto")), i, kb])
		i += 1
	# css paint order: z-index of positioned kids, then document order
	order.sort_custom(func(a, bb): return a[0] < bb[0] or (a[0] == bb[0] and a[1] < bb[1]))
	for o in order:
		b.add(o[2])
	return b

static func _zi(pos: String, zi: String) -> float:
	# css paint order: in-flow boxes, then positioned ones (z-index auto/0) in tree order, then z > 0
	if pos == "static" or pos == "":
		return 0.0
	if zi == "auto" or zi == "" or float(zi) == 0.0:
		return 0.5
	return float(zi)

static func _text(b: Control, n: Dictionary, R: Array, z: float, icon: Dictionary) -> void:
	var c: Dictionary = n.css
	var s: String = n.get("text", "")
	var fs := Css.px(c.get("font-size", "15px")) * z
	var fw := int(c.get("font-weight", "400"))
	var col := Css.color(c.get("color", "rgb(0,0,0)"))
	var al: String = c.get("text-align", "center")
	if al == "start" or al == "left":
		al = "left"
	elif al == "end" or al == "right":
		al = "right"
	else:
		al = "center"
	var pl := Css.px(c.get("padding-left", "0px")) * z
	var pr := Css.px(c.get("padding-right", "0px")) * z
	var W: float = R[2]
	var H: float = R[3]
	var tr := Rect2(pl, 0, W - pl - pr, H)
	var tw: float = Box.text_w(s, fs, fw)
	var measured := n.has("tr")
	if measured:
		# where the browser put the text (flex gaps, icons, padding all done already)
		var q: Array = n.tr
		tr = Rect2(float(q[0]) - float(R[0]), float(q[1]) - float(R[1]), float(q[2]), float(q[3]))
		# keep the line box height so the font sits like the browser's line
		tr = Rect2(tr.position.x, tr.position.y + tr.size.y * 0.5 - H * 0.5, tr.size.x, H) if tr.size.y < H * 0.9 and tr.size.y < fs * 2.0 else tr
	if not icon.is_empty():
		# [icon][margin][text], centred in the content box like the inline flow does
		var iw := Css.px(icon.w) * z
		var ih := Css.px(icon.h) * z
		var mr := Css.px(icon.get("mr", "0px")) * z
		var total := iw + mr + tw
		var ax := 0.5 if al == "center" else (1.0 if al == "right" else 0.0)
		var x0 := pl + (W - pl - pr - total) * ax
		if measured and s != "":
			var fg := Css.px(c.get("gap", "0px")) * z if String(c.get("gap", "normal")).ends_with("px") else 0.0
			x0 = tr.position.x - mr - fg - iw
		var gap := 0.0
		var kids0: Array = n.get("kids", [])
		if s == "" and kids0.size() > 0:
			# icon then a text span (Kho chips): the icon sits at the padding edge
			x0 = pl
		var ib: Control = Box.new()
		var msk: String = icon.get("mask", "none")
		if msk.begins_with("url("):
			# css mask + background colour: the mask svg painted in that colour
			var mcol := Css.color(icon.get("bg", "rgb(0,0,0)"))
			var hx := "#" + mcol.to_html(false)
			var svg := Css.url_svg(msk).replace("\"#000\"", "\"" + hx + "\"").replace("'#000'", "'" + hx + "'").replace("\"black\"", "\"" + hx + "\"")
			ib.style("", z)
			ib.place(Rect2(x0, (H - ih) * 0.5, iw, ih))
			ib.pic(Css.svg_tex(svg, iw, ih), Rect2(0, 0, iw, ih))
		else:
			ib.style("background-image:" + String(icon.bgi) + ";background-size:" + String(icon.get("bgs", "contain")) + ";background-position:" + String(icon.get("bgp", "50% 50%")) + ";background-repeat:no-repeat;", z)
			ib.place(Rect2(x0, (H - ih) * 0.5, iw, ih))
		b.add(ib)
		if not measured:
			tr = Rect2(x0 + iw + mr + gap, 0, tw + 2.0, H)
			al = "left"
	elif measured:
		pass
	else:
		# text that shares the box with child pictures (button "Mở ô đất · 12 [xu]")
		var kids: Array = n.get("kids", [])
		if kids.size() > 0 and al == "center" and s != "":
			var kx := 1e9
			var kw := 0.0
			for k in kids:
				kx = minf(kx, float(k.r[0]) - float(R[0]))
				kw += float(k.r[2])
			var gap := 6.0 * z
			var total := tw + gap + kw
			var x0: float = (W - total) * 0.5
			if kx > W * 0.5:
				tr = Rect2(x0, 0, tw, H)
			else:
				tr = Rect2(kx + kw + gap, 0, tw, H)
			al = "left"
	if s == "":
		return
	# wrap like the browser did: several lines there, or (not measured) too wide for the box
	var wrap: bool = c.get("white-space", "normal") == "normal" and ((measured and n.tr[3] > fs * 1.7) or (not measured and tw > tr.size.x + 1.0))
	b.text(s, tr, fs, fw, col, al, shadows_txt(c.get("text-shadow", "none"), 1.0), wrap)
	b.set_meta("ti", b.texts.size() - 1)

static func _svg(b: Control, sv: String, R: Array, sh) -> void:
	if sv.find("<image") >= 0:
		# picture inside the svg (64 box): sen đỏ pearl at x 7.9 y 8.9 w 48.3, xu coin at x 11 y 10 w 42
		var q := float(R[2]) / 64.0
		var mm := RegEx.create_from_string('<image[^>]*\\bx="([0-9.]+)"[^>]*\\by="([0-9.]+)"[^>]*width="([0-9.]+)"[^>]*height="([0-9.]+)"').search(sv)
		var ir := Rect2(7.9, 8.9, 48.3, 48.3)
		if mm != null:
			ir = Rect2(float(mm.get_string(1)), float(mm.get_string(2)), float(mm.get_string(3)), float(mm.get_string(4)))
		var pic := "res://ui/img/coin.webp" if absf(ir.position.x - 11.0) < 0.5 else "res://ui/img/pearl.webp"
		b.pic(Css.image(pic), Rect2(ir.position * q, ir.size * q), Color.WHITE, sh)
		return
	var stx := _svg_texts(sv)
	var t := Css.svg_tex(stx.svg, R[2], R[3])
	if t != null:
		b.pic(t, Rect2(0, 0, R[2], R[3]), Color.WHITE, sh)
	for e in stx.list:
		var vb: Vector2 = stx.vb
		var q: float = float(R[2]) / vb.x
		var efs: float = e.fs * q
		var ew: float = Box.text_w(e.s, efs, e.w) + 4.0
		var ex: float = e.x * q - (ew * 0.5 if e.anchor == "middle" else (ew if e.anchor == "end" else 0.0))
		var f := Css.font(e.w)
		var fsp := int(round(efs * Css.K))
		var asc := f.get_ascent(fsp) / Css.K
		var lh := f.get_height(fsp) / Css.K
		b.text(e.s, Rect2(ex, e.y * q - asc, ew, lh), efs, e.w, e.col)

static func _pseudo(b: Control, p: Dictionary, R: Array, z: float, which: String):
	var content: String = p.get("content", "")
	if p.get("dsp", "") == "none":
		return null
	var W: float = R[2]
	var H: float = R[3]
	# css triangles (border trick) under the speech labels: draw a small down arrow
	var bt: String = p.get("bt", "")
	if content == "\"\"" and bt.find("6px solid") >= 0:
		var col := Css.color(p.get("btc", "rgb(251, 246, 234)"))
		b.set_meta("arrow", {"x": W * 0.5, "y": H, "w": 6.0 * z, "c": col})
		b.redraw()
		return null
	var s := ""
	if content.length() > 2 and content.begins_with("\""):
		s = content.substr(1, content.length() - 2)
	if s != "":
		if s.strip_edges() == "":
			return null
		# an emoji in front of the text ("🎯 Thu hoạch..."): part of the same line
		if which == "::before" and Css.emoji(s.unicode_at(0)) != null and b.has_meta("ti"):
			var t0: Dictionary = b.texts[b.get_meta("ti")]
			# the measured text box was the text node only: the emoji sits in front of it
			var pw: float = Box.text_w(s, t0.size, t0.w)
			var rc: Rect2 = t0.rect
			if t0.al == "center":
				t0.rect = Rect2(rc.position.x - pw * 0.5, rc.position.y, rc.size.x + pw, rc.size.y)
			elif t0.al == "right":
				t0.rect = Rect2(rc.position.x, rc.position.y, rc.size.x + pw, rc.size.y)
			else:
				t0.rect = Rect2(rc.position.x - pw, rc.position.y, rc.size.x + pw, rc.size.y)
			t0.s = s + t0.s
			b.set_meta("prefix", s)
			return null
		if s.begins_with(" ·"):
			b.set_meta("suffix", s)
			if b.has_meta("ti"):
				var t1: Dictionary = b.texts[b.get_meta("ti")]
				t1.s += s
			return null
	elif content != "\"\"":
		return null
	var pos: String = p.get("pos", "static")
	if pos == "static" and s == "":
		# đường kẻ sau tiêu đề trong hàng flex (h3::after của .sysx, ...): nằm sát mép phải, giữa theo chiều dọc
		var lh := _plen(p.get("h", "auto"), z)
		if which != "::after" or not p.get("_flexrow", false) or lh <= 0.0 or lh > 3.0 * z or _plen(p.get("w", "auto"), z) <= 0.0:
			return null
		p = p.duplicate()
		p.right = "0px"
		p.top = str((H - lh) * 0.5 / z) + "px"
	var fs := Css.px(p.get("fs", "12px")) * z
	var fw := int(p.get("fw", "700"))
	var tw: float = Box.text_w(s, fs, fw) if s != "" else 0.0
	var pw := _plen(p.get("w", "auto"), z)
	var ph := _plen(p.get("h", "auto"), z)
	var l := _plen(p.get("left", "auto"), z)
	var rr := _plen(p.get("right", "auto"), z)
	var t := _plen(p.get("top", "auto"), z)
	var bo := _plen(p.get("bottom", "auto"), z)
	# computed width/height are the content box: add the padding back (box-sizing content-box)
	var pd := [0.0, 0.0, 0.0, 0.0]   # top right bottom left
	var pds: PackedStringArray = String(p.get("pd", "")).split(" ", false)
	if pds.size() > 0:
		var v := []
		for q in pds:
			v.append(Css.px(q) * z)
		pd = [v[0], v[1 % v.size()], v[2 % v.size()] if v.size() > 2 else v[0], v[3] if v.size() > 3 else v[1 % v.size()]]
	var cb: bool = p.get("bxs", "content-box") != "border-box"
	if pw < 0.0:
		pw = (W - l - rr) if l > -9000.0 and rr > -9000.0 else tw + 8.0 * z
	elif cb:
		pw += pd[1] + pd[3]
	if ph < 0.0:
		ph = (H - t - bo) if t > -9000.0 and bo > -9000.0 else fs * 1.25
	elif cb:
		ph += pd[0] + pd[2]
	var x := l if l > -9000.0 else (W - rr - pw if rr > -9000.0 else 0.0)
	var y := t if t > -9000.0 else (H - bo - ph if bo > -9000.0 else 0.0)
	var tf: String = p.get("transform", "none")
	var rot := 0.0
	if tf.begins_with("matrix("):
		var m := tf.substr(7, tf.length() - 8).split(",")
		x += float(m[4]) * z
		y += float(m[5]) * z
		rot = _rot(tf)
	var st := ""
	for kv in [["background-color", "bg"], ["background-image", "bgi"], ["background-size", "bgs"], ["background-position", "bgp"], ["background-repeat", "bgr"], ["border-radius", "br"], ["box-shadow", "bs"], ["opacity", "op"]]:
		var v: String = p.get(kv[1], "")
		if not _skip(kv[0], v):
			st += kv[0] + ":" + v + ";"
	var bdr: String = p.get("bdr", "")
	if bdr != "" and not _skip("border-top", bdr):
		for k in ["border-top", "border-right", "border-bottom", "border-left"]:
			st += k + ":" + bdr + ";"
	var bx: Control = Box.new()
	bx.style(st, z)
	bx.place(Rect2(x, y, pw, ph))
	if rot != 0.0:
		bx.pivot_offset = bx.size * 0.5
		bx.rotation = rot
	if s != "":
		bx.text(s, Rect2(pd[3], pd[0], pw - pd[1] - pd[3], ph - pd[0] - pd[2]), fs, fw, Css.color(p.get("color", "rgb(0,0,0)")))
	return bx

static func _plen(v: String, z: float) -> float:
	# a pseudo element's computed length, css px * zoom; auto -> -9999
	if v == "auto" or v == "" or not v.ends_with("px"):
		return -9999.0
	return Css.px(v) * z

static func _svg_texts(svg: String) -> Dictionary:
	# ThorVG has no fonts: take <text> out of the svg and draw it with Nunito
	var list := []
	var vb := Css.svg_aspect(svg)
	var re := RegEx.new()
	re.compile("<text([^>]*)>([^<]*)</text>")
	var ra := RegEx.new()
	ra.compile("([a-z-]+)=\"([^\"]*)\"")
	for m in re.search_all(svg):
		var at := {}
		for a in ra.search_all(m.get_string(1)):
			at[a.get_string(1)] = a.get_string(2)
		list.append({"s": m.get_string(2).xml_unescape(), "x": float(at.get("x", "0")), "y": float(at.get("y", "0")), "fs": float(String(at.get("font-size", "12")).trim_suffix("px")), "w": int(at.get("font-weight", "400")), "col": Css.color(at.get("fill", "rgb(0,0,0)")), "anchor": at.get("text-anchor", "start")})
	return {"svg": re.sub(svg, "", true), "list": list, "vb": vb}

# ---------------------------------------------------------------- templates
static func moved(n: Dictionary, d: Vector2) -> Dictionary:
	# a copy of a snapshot element moved by d (css px): one captured card/button used for every item
	var c: Dictionary = n.duplicate(true)
	_move(c, d)
	return c

static func _move(n: Dictionary, d: Vector2) -> void:
	n.r = [float(n.r[0]) + d.x, float(n.r[1]) + d.y, n.r[2], n.r[3]]
	if n.has("tr"):
		n.tr = [float(n.tr[0]) + d.x, float(n.tr[1]) + d.y, n.tr[2], n.tr[3]]
	for k in n.get("kids", []):
		_move(k, d)

static func find(n: Dictionary, cls: String, tag := "") -> Dictionary:
	# first element (depth first) whose class list has cls (and tag when given)
	if (cls == "" or String(n.get("cls", "")).split(" ").has(cls)) and (tag == "" or n.tag == tag):
		return n
	for k in n.get("kids", []):
		var f := find(k, cls, tag)
		if not f.is_empty():
			return f
	return {}

static func remove(n: Dictionary, cls: String) -> void:
	var L: Array = n.get("kids", [])
	for i in range(L.size() - 1, -1, -1):
		if String(L[i].get("cls", "")).split(" ").has(cls):
			L.remove_at(i)
		else:
			remove(L[i], cls)
