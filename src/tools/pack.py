# Turns a Godot web export folder into files an artifact can serve.
# usage: python3 pack.py EXPORT_DIR SITE_DIR "Title"
#  - index.wasm -> engine.wasm (gzip bytes; the page unpacks it while it downloads)
#  - index.pck  -> pck_<n>.wasm, raw slices of at most 14 MB (artifacts serve no .pck and cap binaries at 15 MB)
#  - index.js, the audio worklets: copied
#  - index.html: our own shell (the publisher wraps it; no <html>/<head>)
import sys, os, gzip, json, shutil, re
E, S, TITLE = sys.argv[1], sys.argv[2], sys.argv[3]
os.makedirs(S, exist_ok=True)
for f in os.listdir(S):
    if f.startswith('pck_'): os.remove(os.path.join(S, f))
raw = open(f'{E}/index.wasm', 'rb').read()
open(f'{S}/engine.wasm', 'wb').write(gzip.compress(raw, 9, mtime=0))
pck = open(f'{E}/index.pck', 'rb').read()
CH = 14 * 1024 * 1024
n = max(1, -(-len(pck) // CH))
for i in range(n): open(f'{S}/pck_{i}.wasm', 'wb').write(pck[i * CH:(i + 1) * CH])
for f in ['index.js', 'index.audio.worklet.js', 'index.audio.position.worklet.js']: shutil.copy(f'{E}/{f}', f'{S}/{f}')
# Godot sizes the canvas css box with Math.floor(width/dpr) px: at a fractional dpr (PC 1.3, phone 4.25) the box is a
# fraction of a pixel smaller than the drawing, so the browser resamples the WHOLE frame = everything soft (Link 11-13
# "có cái lớp đéo gì làm mờ ảnh à"). Exact css size instead: drawing pixels land 1:1 on screen pixels.
_j = open(f'{S}/index.js').read()
_a = 'const csw=`${Math.floor(width/scale)}px`;const csh=`${Math.floor(height/scale)}px`;if(canvas.style.width!==csw||canvas.style.height!==csh||canvas.width!==width||canvas.height!==height){canvas.width=width;canvas.height=height;canvas.style.width=csw;canvas.style.height=csh;'
_b = 'const csw=(width/scale)+"px";const csh=(height/scale)+"px";if(canvas.__csw!==csw||canvas.__csh!==csh||canvas.width!==width||canvas.height!==height){canvas.width=width;canvas.height=height;canvas.style.width=csw;canvas.style.height=csh;canvas.__csw=csw;canvas.__csh=csh;'
assert _j.count(_a) == 1
open(f'{S}/index.js', 'w').write(_j.replace(_a, _b))
cfg = json.loads(re.search(r'const GODOT_CONFIG = (\{.*?\});', open(f'{E}/index.html').read(), re.S).group(1))
cfg['ensureCrossOriginIsolationHeaders'] = False
shell = open(os.path.join(os.path.dirname(os.path.abspath(__file__)), 'shell.html')).read()
import zlib
shell = shell.replace('__BUILD__', format(zlib.crc32(pck), '08x')).replace('__EV__', format(zlib.crc32(raw), '08x'))
shell = shell.replace('__JV__', format(zlib.crc32(open(f'{S}/index.js','rb').read()), '08x'))
shell = shell.replace('__TITLE__', TITLE).replace('__CFG__', json.dumps(cfg)).replace('__NPCK__', str(n)).replace('__WASM__', str(len(raw))).replace('__PCK__', str(len(pck)))
open(f'{S}/index.html', 'w').write(shell)
tot = 0
for f in sorted(os.listdir(S)):
    z = os.path.getsize(f'{S}/{f}'); tot += z; print(f, z)
print('total MB', round(tot / 1e6, 1), 'files', len(os.listdir(S)))
