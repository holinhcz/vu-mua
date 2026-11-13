# Cây cao su (rubber tree), v624

Kit: `caosu.py` (imports `../chuoi/chuoi.py` for the camera, sun, night tones and the thin same-colour edge).

A tree is a small 3D model painted in flat game tones:
- straight grey trunk with lichen patches and a red-soil-stained foot;
- the tapping panel facing the viewer: renewed bark, old cut lines, the fresh cut with a white latex line,
  the guide groove, the metal spout, a wire round the trunk and a white cup with latex in it;
- a fork into 2-3 limbs, side branches that stay inside an upright egg-shaped crown, short spurs that fill holes;
- tufts of long-stalked three-leaflet leaves; inner wood sits in leaf shade; crown underside darker.

Seasons: frame = seed (0-3) + 4 x look; look 0 green (game spring, summer), 1 turning (autumn: each tree has one
main colour, limbs lean to it or a neighbour of it), 2 bare (winter: twigs and a few dry leaves; the game adds snow).

Commands:
- preview: `python3 caosu.py 0,1,2,3,4,5,6,7,8,9,10,11 [n] tag` writes /tmp/claude-0/g/caosu_tag.png
- sheet: `python3 caosu.py atlas OUTDIR atlas.json` (writes OUTDIR/caosu.webp, 12 frames day + night)
- game: `python3 patch_caosu.py index.html atlas.json out.html [dbg.html]` hooks plants.caosu (rubber
  plantation and the wild rubber trees). It reads the season variable from the old draw and is re-runnable.

Note: webp files written to /mnt/project-files get C2PA metadata appended (about 5.7 KB); publish the sheet from a
local copy made by the atlas command.

## v808 (2026-11-07) one merged soft shade under rubber trees
Link: "mấy cái hình tròn đè lên nhau nham nhở". The baked shadow disc of each tree overlapped its neighbours in the rows
(every overlap twice as dark, hard edges). Now:
- sheet without shadow: `NOSH=1 python3 caosu.py atlas OUTDIR atlas.json` -> OUTDIR/caosu.webp + atlas_sh.json (shadow
  ellipse per frame, world units from the tree anchor). Published as img/caosu_b.webp (new name so browsers don't keep the old).
- `python3 patch_caosu.py in.html atlas.json t.html` (block now has A.shf(seed) = frame name), then
  `python3 patch_bong.py t.html atlas_sh.json out.html`: ground pass (before Nj in mz) unions all rubber-tree shadow
  ellipses (Uv scenery, So wild, Hr planted) into 4 ring paths (1.6/1.3/1.05/.8 x radius) filled once each: soft edge,
  no extra darkness where trees touch. Names in the block are cs*-prefixed (RG/RA are game globals!).

## v810 (2026-11-07) no ground shade under rubber trees
Link still saw round patches on the ground and the road ("Xoá ????"). patch_bongxoa.py removes the v808 CSB block:
rubber trees now have no ground shade at all. Do not run patch_bong.py again.
