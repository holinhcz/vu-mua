# pond rim + water plant pictures for the native ground: every frame the game's AOW/CLP/__TS code draws at a pond,
# cut from the game's own sheets into its own file (n/pi/<name>.webp) + pi.json {name: [dx, dy, dw, dh]} (draw rect)
import sys, re, json, os
from PIL import Image
S = sys.argv[1]; s = open(S + '/g/q997.html').read(); out = S + '/gn/n/pi/'; os.makedirs(out, exist_ok=True)
i = s.find('window.CLP=(function(){')
def obj(name, start):
    j = s.find(name + '={', start) + len(name) + 1; d = 0
    for k in range(j, len(s)):
        if s[k] == '{': d += 1
        elif s[k] == '}':
            d -= 1
            if d == 0: return json.loads(s[j:k + 1])
G = obj('G', i); GL = obj('GL', i); GH = obj('GH', i)
fr = {}
for k, f in G.items():
    if k[0] == 'd': fr['co' + k[1:]] = f + ['co2']
for k, f in GL.items():
    if k[0] == 'd': fr['lau' + k[1:]] = f + ['lau2']
for k, f in GH.items():
    if k[0] == 'd' and re.match(r'd(h_sao_nhai|h_dua_can|h_tim|h_cuc_trang)\d$', k): fr[k[1:]] = f
for m in re.finditer(r'"d(lbf?\d|beo\d)":(\[[^\]]*\])', s):
    fr[m.group(1)] = json.loads(m.group(2))
meta = {}; cache = {}
for k, f in sorted(fr.items()):
    sh = f[8]
    if sh not in cache: cache[sh] = Image.open(S + '/g/img/' + sh + '.webp').convert('RGBA')
    cache[sh].crop((f[0], f[1], f[0] + f[2], f[1] + f[3])).save(out + k + '.webp', lossless=True, quality=100, method=6, exact=False)
    meta[k] = [f[4], f[5], f[6], f[7]]
json.dump(meta, open(S + '/gn/n/pi.json', 'w'))
print(len(meta), sorted(meta))
