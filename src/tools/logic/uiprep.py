# web game SVG exports -> files Godot's SVG reader (ThorVG) draws the same: rgba() split into rgb + opacity
import json,base64,re,sys,os
S='/tmp/claude-0/-home-user/ec30a73d-a632-5817-a52f-4d1a59b285b5/scratchpad'
O=S+'/proj/ui/svg/'
def L(p):
    d=json.load(open(p)); return json.loads(d) if isinstance(d,str) else d
def fix(s):
    def rep(m):
        attr,r,g,b,a=m.group(1),m.group(2),m.group(3),m.group(4),m.group(5)
        op={'fill':'fill-opacity','stroke':'stroke-opacity','stop-color':'stop-opacity'}[attr]
        return '%s="rgb(%s,%s,%s)" %s="%s"'%(attr,r,g,b,op,a)
    # drop the copied *-opacity defaults first (they are 1), then split rgba
    s=re.sub(r' (fill|stroke|stop)-opacity="1"','',s)
    s=re.sub(r'(fill|stroke|stop-color)="rgba\((\d+), ?(\d+), ?(\d+), ?([\d.]+)\)"',rep,s)
    s=re.sub(r' stop-color="rgb\(0, 0, 0\)"(?=[^>]*>)(?!</stop)','',s) if '<stop' not in s else s
    return s
if __name__=='__main__':
    os.makedirs(O,exist_ok=True)
    for f in sys.argv[1:]:
        d=L(f)
        for k,v in d.items():
            if not isinstance(v,str) or not v.startswith('<svg'): continue
            open(O+k+'.svg','w').write(fix(v))
        print(f,len(d))
