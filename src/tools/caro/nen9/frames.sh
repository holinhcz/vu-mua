#!/bin/bash
G=/home/user/Godot_v4.5.1-stable_linux.x86_64; O=/tmp/claude-0/fr; rm -rf $O; mkdir -p $O
SZ=${1:-"360x860 412x915 412x735 474x696 640x904 768x1024 860x1000 1000x860 1024x768 904x640 1440x900 1600x900 1980x900"}
for sz in $SZ; do
  (cd /home/user/cocaro && timeout 400 xvfb-run -a -s "-screen 0 2600x1400x24" $G --rendering-driver opengl3 --path . --resolution $sz --write-movie $O/m_$sz.png --fixed-fps 10 --quit-after 25 -- --q=3 --demo >/dev/null 2>&1; mv $O/m_${sz}00000024.png $O/$sz.png; rm -f $O/m_*)
done
python3 - "$SZ" <<'PY'
import sys
from PIL import Image, ImageDraw
O='/tmp/claude-0/fr'; H=420; ims=[]
for s in sys.argv[1].split():
    im=Image.open(f'{O}/{s}.png').convert('RGB'); im=im.resize((max(1,int(im.width*H/im.height)),H)); d=ImageDraw.Draw(im); d.rectangle((0,0,80,16),fill='black'); d.text((3,2),s,fill='white'); ims.append(im)
rows=[[]]; w=0
for im in ims:
    if w+im.width>2400: rows.append([]); w=0
    rows[-1].append(im); w+=im.width+8
c=Image.new('RGB',(2400,len(rows)*(H+8)),'white'); y=0
for r in rows:
    x=0
    for im in r: c.paste(im,(x,y)); x+=im.width+8
    y+=H+8
c.save(O+'/sheet.jpg',quality=88)
PY
