# Bụi cỏ (wild grass tuft), v638

Kit: `co.py`, class `BuiCo`. Also holds the pieces the wild bush (`../buicay`) and the reeds (`../lau`) share:
`blade()` (a grass blade as a ribbon folded along its midrib, never dipping into the soil), `ground_shadow()`, the
`Plant` base (items sorted by depth, ground shadow drawn last under everything with DEST_OVER) and the
render / atlas / preview helpers. Camera, sun, night tones and the thin same-colour edge come from `../chuoi/chuoi.py`.

A tuft is an upright fan of 38-46 broad pointed blades from one crown at the soil: the outer ones longer, leaning out
and arching over, the heart standing straight up, the blades deep in the tuft darker, 1-2 old straw-coloured blades.
Seeds 1 and 3 carry 2-3 thin stalks with nodding bristly foxtail heads (cỏ đuôi chồn). About the old tuft's size
(±30 game units wide, ~32 tall without the foxtails).

Frames d0-d3 (plants.tallgrass, seed & 3), n0-n3 at night; sheet `img/co.webp`, table `atlas.json`.

Commands:
- preview: `python3 co.py 0,1,2,3 [n] tag` writes /tmp/claude-0/g/co_tag.png
- sheet: `python3 co.py atlas OUTDIR OUTDIR/co.json` (write locally, then copy: webp written straight to
  /mnt/project-files gets C2PA metadata appended)
- game: `python3 patch_wild.py index.html OUTDIR out.html [dbg.html]` wires all three wild plants (tallgrass,
  wildbush, reed) at once; OUTDIR must hold co.json, buicay.json and lau.json. Re-runnable (replaces its own block),
  clears cached `ptallgrass*`, `pwildbush*`, `preed*` sprites when a sheet loads.

Before/after picture for all three: `../../xem/co-bui-lau-truoc-sau.jpg`.
