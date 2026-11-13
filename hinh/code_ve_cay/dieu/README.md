# Cây điều (cashew tree), v625

Kit: `dieu.py` (imports `../chuoi/chuoi.py` for the camera, sun, night tones and the thin same-colour edge).

A tree is a small 3D model painted in flat game tones:
- short grey-brown trunk with a few bark furrows, forking into 3-4 crooked limbs that spread wide;
- side branches stay inside a broad low dome; short spurs grow into holes so the crown reads full;
- rosettes of big oval (obovate) leaves with a pale midrib, a few light-green new flushes on top;
- cashew apples (red or yellow, pear-shaped, lit side, shade side, one gloss spot) with the grey-olive kidney nut
  hanging under each, on the near, lower part of the crown and drawn in front of the leaves;
- the planted tree before fruit carries pink and cream flower sprays instead.

Frames: d0-d3 decor trees with fruit (plants.dieu, seed&3); d4 planted tree in flower, d5 planted tree with ripe fruit
(plants.ft_dieu, t&1). n0-n5 the same at night.

Commands:
- preview: `python3 dieu.py 0,1,2,3,4,5 [n] tag` writes /tmp/claude-0/g/dieu_tag.png
- sheet: `python3 dieu.py atlas OUTDIR atlas.json` (writes OUTDIR/dieu.webp); write the sheet to a local folder and
  copy it, since webp files written straight to /mnt/project-files get C2PA metadata appended
- game: `python3 patch_dieu.py index.html atlas.json out.html [dbg.html]` (re-runnable, replaces its own block)
