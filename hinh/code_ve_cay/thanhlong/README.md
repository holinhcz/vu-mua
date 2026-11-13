# Cây thanh long (dragon fruit), v642

Kit: `thanhlong.py`, class `ThanhLong` (helpers from `../co`; camera, sun, night and the thin same-colour edge from
`../chuoi/chuoi.py`). About the old plant's size: frames reach x -37..40, top -60 game units.

Built the way the delta grows it (Bình Thuận / Long An style):
- a square concrete post with chamfered corners and a few stains; the old stems climb it and are tied on with black
  rubber strips;
- on top, shape 0: an old tyre; shape 1: a concrete cross. The stems spill over it and hang down all round like a
  green fountain (17-20 long stems plus side shoots and 3 young upright shoots); everything is sorted piece by piece,
  so stems lying on the tyre or cross show on top and the ones behind go behind;
- every stem is a three-ribbed cactus stem: two wings with wavy edges and a ridge between them, a pinch at each
  joint, small areoles in the notches;
- ripe (x1): 7-8 pink fruits with green-tipped scales hanging off the bends, spread round the front;
- not ripe (x0): 2 big white flowers, 2 long buds and 3 small green fruits with red tips.

Follows the game's "k2" fruit-tree scheme: frame key = shape digit + ripe digit, the game picks ((t>>1)&1, t&1).
Frames d00 d01 d10 d11 by day, n00..n11 at night, in `img/k2_thanhlong.webp`, table `atlas.json`.

Commands:
- preview: `python3 thanhlong.py 0,1,2,3 [n] tag` writes /tmp/claude-0/g/thanhlong_tag.png
- sheet: `python3 thanhlong.py atlas OUTDIR OUTDIR/atlas.json` (write locally, then copy: webp written straight to
  /mnt/project-files gets C2PA metadata appended)
- game: `python3 patch_thanhlong.py index.html atlas.json out.html [dbg.html]` (re-runnable, replaces its own block;
  hooks plants.ft_thanhlong; clears cached `pft_thanhlong*` sprites when the sheet loads).

Before/after picture: `../../xem/thanhlong-truoc-sau.jpg` (old, new by day, new at night, then a 4K zoom).
