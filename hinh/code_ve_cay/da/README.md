# Cây đa (village banyan), v630

Kit: `da.py` (imports `../chuoi/chuoi.py` for the camera, sun, night tones and the thin same-colour edge, and `hull`
from `../dambut/dambut.py`). About the old tree's size (crown about ±68 game units wide, top about 120 up).

A banyan is a small 3D model painted in flat game tones:
- a massive trunk of 5-6 stems grown into each other, twisting a little, each bending out into a main limb, flared foot;
- 7 surface roots snaking over the ground (the ones toward the viewer and the incense stand kept short);
- a crown of leaf clumps in tiers (7 round the bottom with a notch in front so the trunk shows, 5 in the middle, 2-3 on
  top); each clump is a dark inner mass covered with glossy oval leaves, lit on top, darker underneath, and casts a
  little shade on the clumps and wood behind it (ATOP, never on the ground);
- a curtain of thin aerial roots in bundles under the crown (front of the trunk kept clear), 2-3 grown into pillar roots;
- the red cloth tied round the trunk with a knot and two tails; a stone incense stand with a bowl and three burning
  sticks (left or right by seed & 1; the tips glow at night).
The ground shadow is drawn last under everything (DEST_OVER).

Frames: d0-d3 (plants.banyan, seed&3), n0-n3 at night. No seasons (evergreen; the engine adds its own winter snow).

Commands:
- preview: `python3 da.py 0,1,2,3 [n] tag` writes /tmp/claude-0/g/da_tag.png
- sheet: `python3 da.py atlas OUTDIR atlas.json` (write to a local folder, then copy: webp written straight to
  /mnt/project-files gets C2PA metadata appended)
- game: `python3 patch_da.py index.html atlas.json out.html [dbg.html]` (re-runnable, replaces its own block)
