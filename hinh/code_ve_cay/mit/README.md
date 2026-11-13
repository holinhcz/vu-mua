# Cây mít (jackfruit tree), v637

Kit: `mit.py`. Class `Mit` extends `Xoai` from `../xoai/xoai.py` (itself built on the banyan kit `../da`): it reuses
the clump crown (every clump a shell of leaf rosettes, nothing lining the inside, so thin spots show branches and what
is behind), the tube wood and the baked ground shadow. `../chuoi/chuoi.py` gives the camera, sun, night tones and the
thin same-colour edge. About the old tree's size (old bb [-40,-80,40,20]; new frames reach x -43..47, top -80).

Link asked for 2 shapes seen from the front, so it follows the game's "k2" fruit-tree scheme (the k2_xoai, k2_dieu,
k2_dudu, k2_dua, k2_chuoi sheets made in another chat): frame key = shape digit + ripe digit, the game picks
((t>>1)&1, t&1).
- shape 0: a young upright tree. One straight trunk that runs on up as the leader; branches leave it in tiers almost
  level and turn up into their clumps; a tall rounded crown (5 lower clumps on 6 slots with the front slot left empty
  so the trunk shows, 4 middle, 2 top).
- shape 1: an older tree. A thick trunk that splits low (0.72) into two leaders that spread left and right; a wide dome.
- leaves: thick glossy dark oval leaves with a short point, 4-6 per twig end, pointing down the slope of the crown so
  they lie over each other like scales; a few fresh lighter-green leaves on top.
- fruit (cauliflory): straight off the trunk and the big limbs, on short thick stalks, front half only, never touching
  the ground. Unripe (x0): 3 small bright green fruits. Ripe (x1): 4 big yellow-green fruits, one still greener.
  Lumpy oblong shape with a knobbly outline and a staggered grid of small bumps.

Frames: d00 d01 d10 d11 by day, n00..n11 at night, in img/k2_mit.webp.

Commands:
- preview: `python3 mit.py 0,1,2,3 [n] tag` writes /tmp/claude-0/g/mit_tag.png
- sheet: `python3 mit.py atlas OUTDIR atlas.json` (write to a local folder, then copy: webp written straight to
  /mnt/project-files gets C2PA metadata appended)
- game: `python3 patch_mit.py index.html atlas.json out.html [dbg.html]` (re-runnable, replaces its own block; hooks
  plants.jackfruit and plants.ft_mit; clears cached `pjackfruit*` and `pft_mit*` sprites). Its image variable is `MJ`
  (the mai block already uses `MI`; the patcher finds its own block by that name).

Before/after picture: `../../xem/mit-truoc-sau.jpg`.
