S = '/tmp/claude-0/-home-user/ec30a73d-a632-5817-a52f-4d1a59b285b5/scratchpad/proj/ui/'
T = lambda x: x.replace('    ', '\t')

def rep(s, old, new):
    old, new = T(old), T(new)
    assert old in s, old[:80]
    return s.replace(old, new)

p = S + 'box.gd'; s = open(p).read()
s = rep(s, '''static func text_w(s: String, fsize: float, weight: int) -> float:
    return Css.font(weight).get_string_size(s, HORIZONTAL_ALIGNMENT_LEFT, -1, int(round(fsize * Css.K))).x / Css.K
''', '''static func text_w(s: String, fsize: float, weight: int) -> float:
    return _line_w(s, Css.font(weight), int(round(fsize * Css.K))) / Css.K

# emoji are pictures (ui/emo/<hex>.webp, the browser's colour emoji); everything else is Nunito
static func _runs(s: String) -> Array:
    var out := []
    var cur := ""
    for ch in s:
        var o := ch.unicode_at(0)
        if o == 0xfe0f:
            continue
        if Css.emoji(o) != null:
            if cur != "":
                out.append(cur)
                cur = ""
            out.append(o)
        else:
            cur += ch
    if cur != "":
        out.append(cur)
    return out

static func _line_w(s: String, f: Font, fs: int) -> float:
    var w := 0.0
    for r in _runs(s):
        if r is int:
            w += fs * 1.18
        else:
            w += f.get_string_size(r, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
    return w

func _draw_line(f: Font, pos: Vector2, s: String, fs: int, col: Color, shadow: bool) -> void:
    var x := pos.x
    for r in _runs(s):
        if r is int:
            var e := fs * 1.18
            if not shadow:
                _fg.draw_texture_rect(Css.emoji(r), Rect2(x + fs * 0.04, pos.y - fs * 0.92, fs * 1.1, fs * 1.1), false, Color(1, 1, 1, col.a))
            x += e
        else:
            _fg.draw_string(f, Vector2(x, pos.y), r, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, col)
            x += f.get_string_size(r, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
''')
s = rep(s, '''            var lw := f.get_string_size(lines[li], HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x''',
           '''            var lw := _line_w(lines[li], f, fs)''')
s = rep(s, '''                _fg.draw_string(f, pos + s.o * k, lines[li], HORIZONTAL_ALIGNMENT_LEFT, -1, fs, c)
            _fg.draw_string(f, pos, lines[li], HORIZONTAL_ALIGNMENT_LEFT, -1, fs, t.col)''',
'''                _draw_line(f, pos + s.o * k, lines[li], fs, c, true)
            _draw_line(f, pos, lines[li], fs, t.col, false)''')
s = rep(s, '''        if cur != "" and f.get_string_size(t, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x > w:''',
           '''        if cur != "" and _line_w(t, f, fs) > w:''')
open(p, 'w').write(s)

p = S + 'css.gd'; s = open(p).read()
s = rep(s, '''static func image(path: String) -> Texture2D:''', '''static var _emo := {}
static func emoji(code: int) -> Texture2D:
    if code < 0x2190:
        return null
    if not _emo.has(code):
        var path := "res://ui/emo/%x.webp" % code
        _emo[code] = image(path) if FileAccess.file_exists(path) else null
    return _emo[code]

static func image(path: String) -> Texture2D:''')
open(p, 'w').write(s)

p = S + 'snap.gd'; s = open(p).read()
s = rep(s, '''        if s.strip_edges() == "" or s.unicode_at(0) > 0x2000 and s.unicode_at(0) != 0x00d7 and s.find("×") < 0 and s.unicode_at(0) > 0x1f000:
            return''', '''        if s.strip_edges() == "":
            return
        # an emoji in front of the text ("🎯 Thu hoạch..."): part of the same line
        if which == "::before" and Css.emoji(s.unicode_at(0)) != null and b.has_meta("ti"):
            var t0: Dictionary = b.texts[b.get_meta("ti")]
            t0.s = s + t0.s
            return''')
open(p, 'w').write(s)
print('ok')
