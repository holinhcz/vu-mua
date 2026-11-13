# Bụi dâm bụt (hibiscus bush), v626

Kit: `dambut.py` (imports `../chuoi/chuoi.py` for the camera, sun, night tones and the thin same-colour edge).

A bush is a small 3D model painted in flat game tones:
- five woody stems out of the ground into a lumpy dome (a few broad bulges so it is not a clipped ball);
- a dark inner mass a little smaller than the leaf surface, so gaps between leaves read as depth;
- clusters of glossy toothed oval leaves turned up to the light, the sun side lighter, inner leaves in shade;
  a few shoots poke out of the top and sides;
- 6-8 big red flowers facing out of the dome: five broad petals in a shallow funnel, crimson eye, faint veins,
  the yellow staminal column with pollen and red stigma pads; a few red spindle buds with a green calyx.

Frames: d0-d3 (plants.hibiscus, seed&3), n0-n3 at night. The game adds its own snow in winter.

Commands:
- preview: `python3 dambut.py 0,1,2,3 [n] tag` writes /tmp/claude-0/g/dambut_tag.png
- sheet: `python3 dambut.py atlas OUTDIR atlas.json` (write to a local folder, then copy: webp written straight to
  /mnt/project-files gets C2PA metadata appended)
- game: `python3 patch_dambut.py index.html atlas.json out.html [dbg.html]` (re-runnable, replaces its own block)
