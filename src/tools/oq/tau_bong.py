# bóng mờ tàu dừa (Link 11-23 "làm bóng mờ lại"): alpha tàu -> thu 1/6 -> Gaussian blur -> tau_s0/tau_s1.webp
# ảnh trắng, alpha = bóng; game tô màu SHC + alpha thấp. PAD (px ảnh gốc) mỗi bên.
import sys, os
from PIL import Image, ImageFilter
D = sys.argv[1] if len(sys.argv) > 1 else "oaq/ui/img/oq"
PAD, F, R = 60, 6, 4.0
for v in (0, 1):
	im = Image.open(os.path.join(D, "tau%d.webp" % v)).convert("RGBA")
	w, h = im.size
	a = Image.new("L", (w + PAD * 2, h + PAD * 2), 0)
	a.paste(im.getchannel("A"), (PAD, PAD))
	s = a.resize(((w + PAD * 2) // F, (h + PAD * 2) // F), Image.BOX).filter(ImageFilter.GaussianBlur(R))
	s = s.point(lambda x: min(255, int(x * 1.15)))
	out = Image.merge("RGBA", (Image.new("L", s.size, 255),) * 3 + (s,))
	out.save(os.path.join(D, "tau_s%d.webp" % v), "WEBP", lossless=True)
	print(v, s.size)
