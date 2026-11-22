#!/bin/bash
# Ô ăn quan bản chơi riêng: export pck từ bản chép của src/oaq, gộp ui/img + ui/font (thô, .gdignore), đặt vào <main>/oaq/
# dùng: build_web.sh <godot> <thư mục làm việc> <thư mục main>
set -e
GD=$1; W=$2; MAIN=$3; SRC=$(cd "$(dirname "$0")/../.." && pwd)
mkdir -p "$MAIN/oaq"; rm -rf "$W/oqs"; cp -r "$SRC/oaq" "$W/oqs"
cd "$W/oqs"; "$GD" --headless --path . --import > imp.log 2>&1 || true
"$GD" --headless --path . --export-pack Web "$W/oq.pck" > exp.log 2>&1
grep -iE "SCRIPT ERROR|Parse Error" exp.log && exit 1
cd "$SRC/tools" && python3 - "$W/oq.pck" "$W/oqs/" "$MAIN/oaq/oq.pck" <<'PY'
import os, sys
from merge_logic import read_pck, write_pck, _rank
hdr, L = read_pck(open(sys.argv[1], 'rb').read()); F = dict(L); root = sys.argv[2]
for d in ['ui/img', 'ui/font']:
    for dp, dn, fn in os.walk(root + d):
        for f in fn:
            if f == '.gdignore' or f.endswith('.import'): continue
            p = os.path.join(dp, f); F[os.path.relpath(p, root)] = open(p, 'rb').read()
open(sys.argv[3], 'wb').write(write_pck(hdr, sorted(F.items(), key=lambda e: (_rank(e[0]), e[0]))))
PY
cd "$MAIN/oaq"
cp "$SRC/shell/oaq_index.html" index.html
cp ../cocaro/index.audio.worklet.js ../cocaro/index.audio.position.worklet.js .
O=$(grep -o "PCK=[0-9]*" index.html | cut -d= -f2); OB=$(grep -o "B='[0-9a-f]*'" index.html)
SZ=$(stat -c %s oq.pck); H=$(md5sum oq.pck | cut -c1-8)
sed -i "s/$O/$SZ/g; s/$OB/B='$H'/" index.html
echo "$H" > ver.txt
ls -la oq.pck; grep -o "PCK=[0-9]*,B='[0-9a-f]*'" index.html
