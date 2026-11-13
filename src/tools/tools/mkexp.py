# (b51) write a kit's sheet (atlas.json {name:[sx,sy,w,h,ox,oy,gw,gh]} + sheet png) into godot/<grp>/<name>/ as one PNG per frame
# + atlas.json {px_per_unit, frames{file,w,h,ox,oy,gw,gh}} like final9.py, plus README.  Lossless PNG only.
# usage: python3 mkexp.py SHEET.png ATLAS.json OUTDIR "readme text"
import sys, json, os
from PIL import Image
sh, aj, out, txt = sys.argv[1:5]
A = json.load(open(aj)); S = Image.open(sh).convert('RGBA')
os.makedirs(out, exist_ok=True); F = {}
for k, v in A.items():
    im = S.crop((v[0], v[1], v[0] + v[2], v[1] + v[3])); im.save(out + '/' + k + '.png', optimize=True)
    F[k] = {'file': k + '.png', 'w': v[2], 'h': v[3], 'ox': v[4], 'oy': v[5], 'gw': v[6], 'gh': v[7]}
json.dump({'px_per_unit': 9, 'frames': F}, open(out + '/atlas.json', 'w'), indent=1)
open(out + '/README.md', 'w').write(txt + '\natlas.json: ox,oy = góc trên trái so với neo (tâm ô, đơn vị game), gw,gh = cỡ vẽ (đơn vị game). Godot: offset=(ox,oy), scale=1/9.\n')
print(out, len(F))
