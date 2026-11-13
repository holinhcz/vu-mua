def i32(v):
    v = int(v) & 0xffffffff
    return v - (1 << 32) if v >= 1 << 31 else v
def Me(t, a):
    n = i32(float(t) * 374761393.0 + float(a) * 668265263.0)
    u = n & 0xffffffff
    n = i32(float(i32(n ^ (u >> 13))) * 1274126177.0)
    u = n & 0xffffffff
    return ((n ^ (u >> 16)) & 0xffffffff) / 4294967295.0
