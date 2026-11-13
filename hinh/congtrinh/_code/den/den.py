# Nông Trại Chung: shared night look of the lamps on the 3D building sheets (Link 2026-11-08 15:51:
# "đèn phải phát sáng", lamps small like the kho's, light like the nhà tranh's).
# lampglow() runs on a finished night frame: a white-hot flame core and a small warm halo round each lamp.
import numpy as np
from PIL import Image

GLASS_NIGHT = '#ffa236'          # the glass of a đèn bão at night: lit orange, not pale cream


def lampglow(im, glows, T, OX, OY, BB, PXU, solid_only=False):
    """glows: [(world point (x, y, z) = W3(u, v, z), halo, core)], points at the flame centre of lamps the
    viewer can see. halo: warm light added round the lamp (sigma 4.5 units); core: flame core blend (sigma .55 units).
    solid_only: only touch opaque pixels (a props overlay frame)"""
    if not glows: return im
    a = np.asarray(im).astype(np.float32) / 255.0
    yy, xx = np.mgrid[0:a.shape[0], 0:a.shape[1]]
    rgb = a[..., :3]; al = a[..., 3:4]
    w = (al > 0.99).astype(np.float32) if solid_only else al
    for (p, halo, core) in glows:
        x0 = ((p[0] - p[1]) * 32 / T + OX - BB[0]) * PXU
        y0 = ((p[0] + p[1]) * 16 / T + OY - p[2] - BB[1]) * PXU
        d2 = ((xx - x0) ** 2 + (yy - y0) ** 2) / float(PXU * PXU)
        if halo:
            h = halo * np.exp(-d2 / (2 * 4.5 ** 2))
            rgb = rgb + np.array([1.0, 0.62, 0.25]) * h[..., None] * w
        if core:
            c = core * np.exp(-d2 / (2 * 0.55 ** 2))[..., None] * w
            rgb = rgb * (1 - c) + np.array([1.0, 0.97, 0.82]) * c
    out = np.concatenate([np.clip(rgb, 0, 1), al], -1)
    return Image.fromarray((out * 255 + 0.5).astype(np.uint8), 'RGBA')
