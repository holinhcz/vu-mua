#!/bin/bash
# render UI snapshots natively and compare with the web screenshot: ut.sh SNAPS webshot y0 y1
S=/tmp/claude-0/-home-user/ec30a73d-a632-5817-a52f-4d1a59b285b5/scratchpad
cd $S/uit && SNAP=$1 timeout 90 xvfb-run -a -s "-screen 0 1100x1900x24" $S/gd/godot --path . --rendering-driver opengl3 > run.log 2>&1
grep -E "SCRIPT|ERROR:|at: " run.log | grep -v "status < 0" | head
cd $S && python3 -c "
from PIL import Image
a=Image.open('uit/out.png'); b=Image.open('test/$2')
y0,y1=$3,$4
w=Image.new('RGB',(a.width+b.width,a.height),'white'); w.paste(b,(0,0)); w.paste(a,(b.width,0)); w=w.crop((0,y0,w.width,y1)); w.resize((w.width*${5:-2}//3,w.height*${5:-2}//3)).save('cmp.png')
"
