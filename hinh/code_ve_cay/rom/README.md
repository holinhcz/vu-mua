# Đống rơm (haystack), v640

Kit: `rom.py`, class `Rom` (helpers from `../co`, camera, sun, night and the thin same-colour edge from
`../chuoi/chuoi.py`). Draw it with `python3 rom.py 0,1,2,3 [n] tag` (writes /tmp/claude-0/g/rom_tag.png) or
`python3 rom.py atlas OUTDIR OUTDIR/rom.json` (write locally, then copy: webp written straight to /mnt/project-files
gets C2PA metadata appended). Into the game with `python3 patch_rom.py index.html OUTDIR out.html [dbg.html]`
(re-runnable, replaces its own block, clears cached `phaystack*` sprites when the sheet loads).

A cây rơm as the delta keeps it in the yard for the buffalo, built round a wooden pole:
- the body is a solid of revolution (a little lumpy and leaning): pulled in at the foot where straw has been taken,
  bulging out under the middle, a rounded bell up to the pole; painted with smooth straw shading by the sun, the
  foot and the overhang in shade;
- ~900 straws lie down its slope over that, a tone lighter or darker than the straw under them, loose straws stick
  out all round the edge and hang off the bulge over the foot; a thin edge a shade darker runs down both sides;
- twisted straw ropes bind it, a little out of level, pinching the straw in and sinking into it at the sides:
  2 on seeds 0 and 2, 3 on seeds 1 and 3, as the old stack had;
- a small straw cap tied round the pole at the top, the pole's cut end showing;
- loose straw on the ground round the foot, the ground shadow under everything.
Sizes follow the old stack's scale per seed (1, .92, 1.06, .84). Frames d0-d3 (plants.haystack, seed & 3), n0-n3 at
night; sheet `img/rom.webp`, table `atlas.json`. Before/after picture: `../../xem/rom-truoc-sau.jpg`.
