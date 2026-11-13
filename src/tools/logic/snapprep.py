# web UI layout dumps (dj_*.json) -> proj/ui/snap/*.json; SVG colours made readable for Godot
import json,sys,os,re,base64
sys.path.insert(0,os.path.dirname(__file__))
from uiprep import fix
S='/tmp/claude-0/-home-user/ec30a73d-a632-5817-a52f-4d1a59b285b5/scratchpad'
O=S+'/proj/ui/snap/'
os.makedirs(O,exist_ok=True)
def walk(n):
    if 'svg' in n: n['svg']=fix(n['svg'])
    for k in n.get('kids',[]): walk(k)
for name in ['hud','dock','gv','rmg','rmr','lock','kho','kho2','kho3','kho_sel','kho_conf','toast','ord','ord_ok','ord_wait','ord_sw','ord_sen','ord_lack','ord_lack2','ord_after','pc_lv','pc_buy','pc_far','pc_lack','pc_toast','nv_ngay','nv_ngay2','nv_ngay3','nv_tuan','nv_tuan2','nv_tt','nv_tt2','nv_sk','nv_sk_hoi','nv_sk_cho','nv_sk_bt','nv_sk_giup','nv_bdg','lv2','lv5','set','set_rs','set_pop','xf_run','xf_thu','xf_sel','xf2_pd','xf2_four','xf2_full','xf_ask','xf_ask2','bdx','bdx1','bdhelp','bdf','bds','bdm','bdp','bc_cay','bc_qua','bc_qua1','bc_hoaco','bc_nha','bc_chuong','bc_vat','bc_nuoc','bc_duong','bc_nen','bpl','bpl_bad','bpl_mv','bsel','bsel_f','broad','bnen','bmini','bpen','btier','kup_lock','kup_ok','kup_no','kup_max','k3_ok','k3_no','k2_no','k_hard','kfov','kfov2','kfov3','kns_ok','kns_poor','sp_ok','sp_no','sp_lock','sp_ns','sp_max','sp_all','ns_nv','ns_nv0','ns_nv2','ns_dn','ns_dn2']:
    p=S+'/dj_'+name+'.json'
    if not os.path.exists(p): continue
    d=json.load(open(p)); d=json.loads(d) if isinstance(d,str) else d
    for v in d.values():
        for n in v: walk(n)
    json.dump(d,open(O+name+'.json','w'),ensure_ascii=False,separators=(',',':'))
    print(name,os.path.getsize(O+name+'.json'))
pp=S+'/dj_pearl.json'
if os.path.exists(pp):
    d=json.load(open(pp)); d=json.loads(d) if isinstance(d,str) else d
    open(S+'/proj/ui/img/pearl.webp','wb').write(base64.b64decode(d['pearl']))
