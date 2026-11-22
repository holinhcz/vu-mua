from PIL import Image
import numpy as np, json
D='/home/user/vu-mua/src/cocaro/ui/img/caro/nen/'
L=json.load(open(D+'layout.json'))
c=np.zeros((640,800))
for i in range(4):
  im=Image.open(D+'xoai%d.webp'%i).getchannel('A'); im=np.array(im.resize((im.width//9,im.height//9),Image.BOX)); w=L['mango_wins'][i]
  x,y=int(w[0])+40,int(w[1])+40; h,ww=im.shape; h=min(h,640-y); ww=min(ww,800-x)
  c[y:y+h,x:x+ww]=np.maximum(c[y:y+h,x:x+ww],im[:h,:ww])
a=c>60
pr=[]
for r in range(0,640,16):
  cols=np.nonzero(a[r:r+16].any(0))[0]
  pr.append(int(cols.max())-40+2 if len(cols) else -40)
while pr and pr[-1]==-40: pr.pop()
print(len(pr), pr)
