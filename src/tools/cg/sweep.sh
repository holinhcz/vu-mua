#!/bin/bash
S=/tmp/claude-0/-home-user/c46a4d67-6106-5dcd-a49e-cc63e127ea0f/scratchpad; Q=$S/cgr; O=$S/fr; rm -rf $O; mkdir -p $O
SZ=${1:-"360x860 412x915 412x735 411x722 474x696 640x904 768x1024 860x1000 1000x860 1024x768 904x640 1440x900 1600x900 1980x900"}
for sz in $SZ; do
  timeout 120 xvfb-run -a -s "-screen 0 2600x1400x24" $S/gd/Godot_v4.5.1-stable_linux.x86_64 --path $Q --rendering-driver opengl3 --resolution $sz -- k=1 "cmd=3:shot_m_$sz;3.5:start_1;7:shot_p_$sz;7.5:quit" > /dev/null 2>&1
  mv $Q/shots/m_$sz.png $Q/shots/p_$sz.png $O/ 2>/dev/null
done
python3 - "$SZ" <<'PY'
import sys
from PIL import Image, ImageDraw
O='/tmp/claude-0/-home-user/c46a4d67-6106-5dcd-a49e-cc63e127ea0f/scratchpad/fr'
for pre in ['m','p']:
    H=460; ims=[]
    for s in sys.argv[1].split():
        try: im=Image.open(f'{O}/{pre}_{s}.png').convert('RGB')
        except Exception: continue
        im=im.resize((max(1,int(im.width*H/im.height)),H)); d=ImageDraw.Draw(im); d.rectangle((0,0,84,16),fill='black'); d.text((3,2),s,fill='white'); ims.append(im)
    rows=[[]]; w=0
    for im in ims:
        if w+im.width>2400: rows.append([]); w=0
        rows[-1].append(im); w+=im.width+8
    c=Image.new('RGB',(2400,len(rows)*(H+8)),'white'); y=0
    for r in rows:
        x=0
        for im in r: c.paste(im,(x,y)); x+=im.width+8
        y+=H+8
    c.save(f'{O}/sheet_{pre}.jpg',quality=88)
PY
ls $O | wc -l
