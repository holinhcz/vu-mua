# Bông giấy / hoa giấy (bougainvillea bush), v627

Kit: `bonggiay.py` (imports `../chuoi/chuoi.py` for the camera, sun, night tones and the thin same-colour edge, and
`hull` from `../dambut/dambut.py`). Drawn at KU x0.82 so the bush keeps about the old size in the game.

A bush is a small 3D model painted in flat game tones:
- three woody stems twisting round each other out of one foot and splaying into the crown;
- a lumpy dome of small heart-shaped leaves with a dark inner mass behind them;
- big masses of papery three-bract clusters over the top and front, each with tiny cream flowers in the middle;
- 2-3 long arching canes drooping out of the sides with bracts and leaves along them;
- a few fallen bracts on the ground in front.

Frames: d0-d3 (plants.bougainvillea, seed&3 = colour: magenta, pink, orange, white), n0-n3 at night.

Commands:
- preview: `python3 bonggiay.py 0,1,2,3 [n] tag` writes /tmp/claude-0/g/bonggiay_tag.png
- sheet: `python3 bonggiay.py atlas OUTDIR atlas.json` (write to a local folder, then copy: webp written straight to
  /mnt/project-files gets C2PA metadata appended)
- game: `python3 patch_bonggiay.py index.html atlas.json out.html [dbg.html]` (re-runnable, replaces its own block)
