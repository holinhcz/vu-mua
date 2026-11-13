import re, os
S = '/tmp/claude-0/-home-user/ec30a73d-a632-5817-a52f-4d1a59b285b5/scratchpad/proj/ui/'
T = lambda x: x.replace('    ', '\t')  # blocks below are written with 4 spaces per indent level

def rep(s, old, new):
    old, new = T(old), T(new)
    assert old in s, old[:80]
    return s.replace(old, new)

p = S + 'box.gd'; s = open(p).read()
s = rep(s, """        for li in lines.size():
            var pos := Vector2(rr.position.x * k, y0 + li * lh)
            for s in t.sh:
                var c: Color = s.c
                if s.b > 0.0:
                    c.a *= 0.6
                _fg.draw_string(f, pos + s.o * k, lines[li], al, rr.size.x * k, fs, c)
            _fg.draw_string(f, pos, lines[li], al, rr.size.x * k, fs, t.col)""",
"""        for li in lines.size():
            # no clipping: Godot's draw_string cuts text wider than `width`, so place it ourselves
            var lw := f.get_string_size(lines[li], HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
            var ax := 0.0 if al == HORIZONTAL_ALIGNMENT_LEFT else (1.0 if al == HORIZONTAL_ALIGNMENT_RIGHT else 0.5)
            var pos := Vector2(rr.position.x * k + (rr.size.x * k - lw) * ax, y0 + li * lh)
            for s in t.sh:
                var c: Color = s.c
                if s.b > 0.0:
                    c.a *= 0.6
                _fg.draw_string(f, pos + s.o * k, lines[li], HORIZONTAL_ALIGNMENT_LEFT, -1, fs, c)
            _fg.draw_string(f, pos, lines[li], HORIZONTAL_ALIGNMENT_LEFT, -1, fs, t.col)""")
s = rep(s, """                var ts: String = css.get("background-size", "")
                var tw := w
                var th := h
                var tile := 0
                if ts.ends_with("px") or ts.find("px ") >= 0:
                    var a := ts.split(" ", false)
                    tw = Css.px(a[0]) * z
                    th = Css.px(a[1] if a.size() > 1 else a[0]) * z
                    tile = 1
                var t := Css.svg_tex(svg, tw, th)
                if t != null:
                    M.set_shader_parameter("tex", t)
                    M.set_shader_parameter("tex_rect", Vector4(0, 0, tw, th))""",
"""                var ts: String = _layer(css.get("background-size", ""), li)
                var tp: String = _layer(css.get("background-position", ""), li)
                var trp: String = _layer(css.get("background-repeat", "repeat"), li)
                var tw := w
                var th := h
                if ts.find("px") >= 0:
                    var a := ts.split(" ", false)
                    tw = Css.px(a[0]) * z
                    th = Css.px(a[1] if a.size() > 1 else a[0]) * z
                var tile := 0 if trp.begins_with("no-repeat") else 1
                var ox := 0.0
                var oy := 0.0
                if tp != "":
                    var pa := Css.split_top(tp, " ")
                    ox = _bgpos(pa[0], w - tw)
                    oy = _bgpos(pa[1] if pa.size() > 1 else "50%", h - th)
                var t := Css.svg_tex(svg, tw, th)
                if t != null:
                    M.set_shader_parameter("tex", t)
                    M.set_shader_parameter("tex_rect", Vector4(ox, oy, tw, th))""")
s = rep(s, "# ---------------------------------------------------------------- content", """func _layer(v: String, i: int) -> String:
    var a := Css.split_top(v)
    if a.size() == 0:
        return ""
    return a[mini(i, a.size() - 1)]

func _bgpos(v: String, free: float) -> float:
    # css background-position on one axis: P%, Npx or calc(P% +- Npx); free = box - picture
    v = v.strip_edges()
    if v.begins_with("calc("):
        var a := v.substr(5, v.length() - 6).split(" ", false)
        var r := _bgpos(a[0], free)
        var i := 1
        while i + 1 < a.size():
            var q := _bgpos(a[i + 1], free)
            r += q if a[i] == "+" else -q
            i += 2
        return r
    if v.ends_with("%"):
        return float(v.trim_suffix("%")) / 100.0 * free
    return Css.px(v) * z

# ---------------------------------------------------------------- content""")
open(p, 'w').write(s)

p = S + 'snap.gd'; s = open(p).read()
s = rep(s, '''for k in ["background-color", "background-image", "background-size",''', '''for k in ["background-color", "background-image", "background-size", "background-position", "background-repeat",''')
s = rep(s, '''        if k == "border-top" and v.begins_with("0px"):''', '''        if (k == "background-size" and v == "auto") or (k == "background-position" and v == "0% 0%") or (k == "background-repeat" and v == "repeat"):
            continue
        if k == "border-top" and v.begins_with("0px"):''')
s = rep(s, '''    if n.has("svg"):
        var t := Css.svg_tex(n.svg, R[2], R[3])
        if t != null:
            b.pic(t, Rect2(0, 0, R[2], R[3]))''', '''    if n.has("svg"):
        var sv: String = n.svg
        if sv.find("<image") >= 0:
            # the sen đỏ pearl is a picture inside the svg (x 7.9 y 8.9 w 48.3 of 64)
            var q := float(R[2]) / 64.0
            b.pic(Css.image("res://ui/pearl.webp"), Rect2(7.9 * q, 8.9 * q, 48.3 * q, 48.3 * q))
        else:
            var stx := _svg_texts(sv)
            var t := Css.svg_tex(stx.svg, R[2], R[3])
            if t != null:
                b.pic(t, Rect2(0, 0, R[2], R[3]))
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
                b.text(e.s, Rect2(ex, e.y * q - asc, ew, lh), efs, e.w, e.col)''')
s += T('''
static func _svg_texts(svg: String) -> Dictionary:
    # ThorVG has no fonts: take <text> out of the svg and draw it with Nunito
    var list := []
    var vb := Vector2(64, 64)
    var vi := svg.find("viewBox=\\"")
    if vi >= 0:
        var v := svg.substr(vi + 9, svg.find("\\"", vi + 9) - vi - 9).split(" ", false)
        if v.size() == 4:
            vb = Vector2(float(v[2]), float(v[3]))
    var re := RegEx.new()
    re.compile("<text([^>]*)>([^<]*)</text>")
    var ra := RegEx.new()
    ra.compile("([a-z-]+)=\\"([^\\"]*)\\"")
    for m in re.search_all(svg):
        var at := {}
        for a in ra.search_all(m.get_string(1)):
            at[a.get_string(1)] = a.get_string(2)
        list.append({"s": m.get_string(2).xml_unescape(), "x": float(at.get("x", "0")), "y": float(at.get("y", "0")), "fs": float(String(at.get("font-size", "12")).trim_suffix("px")), "w": int(at.get("font-weight", "400")), "col": Css.color(at.get("fill", "rgb(0,0,0)")), "anchor": at.get("text-anchor", "start")})
    return {"svg": re.sub(svg, "", true), "list": list, "vb": vb}
''')
open(p, 'w').write(s)
print("ok")
