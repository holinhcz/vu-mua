# mái 8460 -> 1 đoạn 3974 px nối khớp đầu-đuôi (lặp dọc liền). Nguồn: co-caro/nen_lossless/mai.webp (8460 cao)
from PIL import Image;import numpy as np,sys
a=np.array(Image.open(sys.argv[1]).convert('RGBA')).astype(float)
y0,H,ov=840,3974,160;X=300   # y0,H tìm bằng sai khác nhỏ nhất; X = vùng tua rơm có alpha
t=a[y0:y0+H].copy();w=(np.arange(ov)/ov)[:,None,None];w=w*w*(3-2*w)
A=a[y0:y0+ov];B=a[y0+H:y0+H+ov];bl=A*w+B*(1-w);t[:ov]=bl
c=int(np.argmin(np.abs(A[:,:X,3]-B[:,:X,3]).sum(1)));t[:c,:X]=B[:c,:X];t[c:ov,:X]=A[c:,:X]
both=(A[:,:X,3]>250)&(B[:,:X,3]>250);t[:ov,:X][both]=bl[:,:X][both]
Image.fromarray(np.clip(t+.5,0,255).astype(np.uint8)).save(sys.argv[2],quality=90,alpha_quality=100,method=6)
