# Makes the river bank crisp: the game lays see-through bands along the water's edge (a wet-mud stroke, a pale
# shallows band). Cut out, they become a half-see-through smear over the water. Wide see-through areas (not the thin
# soft edge of a leaf) that are not shadows are pushed to fully solid or fully water.
import numpy as np
from scipy import ndimage as nd
def crisp(rgb, a):
    T = (a > .03) & (a < .97)
    st = nd.generate_binary_structure(2, 1)
    wide = nd.binary_opening(T, st, iterations=2)
    wide = nd.binary_dilation(wide, st, iterations=1) & T
    lum = rgb @ np.array([.3, .59, .11], np.float32)
    wide &= lum > 90           # dark see-through = a shadow on the water: keep it soft
    t = np.clip((a - .3) / .3, 0, 1); t = t * t * (3 - 2 * t)
    a2 = a.copy(); a2[wide] = t[wide]
    return a2
