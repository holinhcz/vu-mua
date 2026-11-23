#!/bin/bash
G=/tmp/claude-0/gd/Godot_v4.5.1-stable_linux.x86_64; O=/tmp/claude-0/sw; rm -rf $O; mkdir -p $O; cd /tmp/claude-0/tsq
for sz in 338x610 360x860 412x915 412x735 411x722 474x696 640x904 768x1024 860x1000 1000x860 1024x768 904x640 1440x900 1600x900 1980x900; do
 timeout 120 xvfb-run -a -s "-screen 0 2600x1400x24" $G --path . --rendering-driver opengl3 --resolution $sz -- k=1 "cmd=1.5:shot_m_$sz;2:ai_1;2.3:demo_20;2.6:tapn_21;3.0:shot_p_$sz;3.4:quit" 2>&1 | grep -E "SCRIPT ERROR|Parse" | head -3
 mv shots/m_$sz.png shots/p_$sz.png $O/ 2>/dev/null
done
cd $O && python3 - <<'PY'
from PIL import Image, ImageDraw
S="338x610 360x860 412x915 412x735 411x722 474x696 640x904 768x1024 860x1000 1000x860 1024x768 904x640 1440x900 1600x900 1980x900".split()
for pre in ['m','p']:
    H=460; ims=[]
    for s in S:
        try: im=Image.open(f'{pre}_{s}.png').convert('RGB')
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
    c.save(f'sheet_{pre}.jpg',quality=88)
PY
