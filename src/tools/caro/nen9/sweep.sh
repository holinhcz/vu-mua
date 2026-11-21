#!/bin/bash
# chụp game ở nhiều cỡ màn, ghép 1 ảnh
G=/home/user/Godot_v4.5.1-stable_linux.x86_64; O=/tmp/claude-0/sweep; rm -rf $O; mkdir -p $O
SZ="320x568 390x844 412x915 768x1024 800x1280 899x910 1024x768 1000x600 1247x880 1366x768 1920x920 2560x1080"
for sz in $SZ; do
  (cd /home/user/cocaro && timeout 400 xvfb-run -a -s "-screen 0 2600x1400x24" $G --rendering-driver opengl3 --path . --resolution $sz --write-movie $O/m_$sz.png --fixed-fps 10 --quit-after 25 -- --q=3 "$@" >/dev/null 2>&1; mv $O/m_${sz}00000024.png $O/$sz.png; rm -f $O/m_*) &
  while [ $(jobs -r | wc -l) -ge 2 ]; do sleep 1; done
done; wait
python3 - <<'PY'
from PIL import Image, ImageDraw
import os
O='/tmp/claude-0/sweep'; S="320x568 390x844 412x915 768x1024 800x1280 899x910 1024x768 1000x600 1247x880 1366x768 1920x920 2560x1080".split()
H=420; ims=[]
for s in S:
    p=f'{O}/{s}.png'
    if not os.path.exists(p): print('missing',s); continue
    im=Image.open(p).convert('RGB'); im=im.resize((max(1,int(im.width*H/im.height)),H)); d=ImageDraw.Draw(im); d.rectangle((0,0,90,18),fill='black'); d.text((4,3),s,fill='white'); ims.append(im)
rows=[[]]; w=0
for im in ims:
    if w+im.width>2400: rows.append([]); w=0
    rows[-1].append(im); w+=im.width+8
c=Image.new('RGB',(2400,len(rows)*(H+8)),'white'); y=0
for r in rows:
    x=0
    for im in r: c.paste(im,(x,y)); x+=im.width+8
    y+=H+8
c.save(O+'/sheet.jpg',quality=88); print(c.size)
PY
