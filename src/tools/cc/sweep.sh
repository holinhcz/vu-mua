#!/bin/bash
# Chụp Câu cá ở 15 cỡ màn (14 cỡ của cờ gánh + điện thoại ngang 915x412), ghép 1 tấm.
# bash sweep.sh [OUT.jpg] ["WxH WxH ..."]   (project thử /home/claude/ccq, Godot /home/claude/gd)
OUT=${1:-/tmp/claude-0/cc_sweep.jpg}
SZ=${2:-"360x860 412x915 412x735 411x722 474x696 640x904 768x1024 860x1000 1000x860 1024x768 904x640 915x412 1440x900 1600x900 1980x900"}
X=${CMDX:-}   # lệnh thêm trước khi chụp, vd CMDX="2:fillbasket;2.5:shop;"
Q=/home/claude/ccq; G=/home/claude/gd/Godot_v4.5.1-stable_linux.x86_64; D=/home/claude/cc_shots/w
for sz in $SZ; do
  rm -f $D/s_$sz.png
  timeout 150 xvfb-run -a -s "-screen 0 2600x1400x24" $G --path $Q --rendering-driver opengl3 --resolution $sz -- k=1 "cmd=1:hour_12;1.2:start;${X}5:shot_s_$sz;5.5:quit" > /dev/null 2>&1
done
python3 - "$SZ" "$OUT" "$D" <<'PY'
import sys
from PIL import Image, ImageDraw
D=sys.argv[3]; H=460; ims=[]
for s in sys.argv[1].split():
    try: im=Image.open(f'{D}/s_{s}.png').convert('RGB')
    except Exception: print('thiếu', s); continue
    im=im.resize((max(1,int(im.width*H/im.height)),H), Image.LANCZOS); d=ImageDraw.Draw(im); d.rectangle((0,0,84,16),fill='black'); d.text((3,2),s,fill='white'); ims.append(im)
rows=[[]]; w=0
for im in ims:
    if w+im.width>2400: rows.append([]); w=0
    rows[-1].append(im); w+=im.width+8
c=Image.new('RGB',(2400,len(rows)*(H+8)),'white'); y=0
for r in rows:
    x=0
    for im in r: c.paste(im,(x,y)); x+=im.width+8
    y+=H+8
c.save(sys.argv[2],quality=88); print(len(ims), c.size)
PY
