# Chậu mai (potted yellow apricot, Ochna integerrima), v629, fixed in v635

Kit: `mai.py` (imports `../chuoi/chuoi.py` for the camera, sun, night tones and the thin same-colour edge).

A potted mai is a small 3D model painted in flat game tones:
- a glazed terracotta pot (bulging profile, incised band with stamped dots, rolled rim, dark foot ring), soil with
  flecks and a few surface roots;
- a thick twisted bonsai trunk with gnarls and moss spots, split low into 3 limbs (leader + 2 side limbs);
- zigzag twigs filling a lumpy dome envelope (limbs only steer once they are inside it, so they never stop as stubs);
- the crown changes with the game season:
  - spring (look 0): 5-petal golden flowers, deep gold palette, orange eye, plus a few young red-green leaves;
  - summer (look 1): green alternate leaves;
  - autumn (look 2): leaves turning yellow-orange;
  - winter (look 3): bare twigs full of green buds (engine adds its snow overlay on top).

Frames: frame = look*4 + seed. d0-d15 by day, n0-n15 at night.
The game picks dr((t&3) + 4*season) where season is the engine variable (spring 0 .. winter 3).

Commands:
- preview: `python3 mai.py 0,1,2,3 [n] tag` writes /tmp/claude-0/g/mai_tag.png
- sheet: `python3 mai.py atlas OUTDIR atlas.json` (write to a local folder, then copy: webp written straight to
  /mnt/project-files gets C2PA metadata appended)
- game: `python3 patch_mai.py index.html atlas.json out.html [dbg.html]` (re-runnable, replaces its own block; finds
  the season variable from the old plants.mai draw)

v635 (Link, after the same fix on the mango): the summer/autumn crown no longer has the dark round mass behind the
leaves (`MASS = False` in mai.py), so thin spots show the twigs and what is behind. Picture:
`../../xem/xoai-mai-thua.jpg`.
