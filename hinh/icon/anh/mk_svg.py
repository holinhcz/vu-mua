import sys, json, os, base64, io
from PIL import Image
outdir, khdir = sys.argv[1], sys.argv[2]
MAP = {  # mã món trong game <- ảnh cắt
 'qua_xoai':'xoaicat','qua_chomchom':'chomchom','qua_mangcut':'mangcut','qua_buoi':'buoidaxanh','qua_dua':'duabentre',
 'qua_saurieng':'saurieng','qua_thanhlong':'thanhlong','duahau':'duahau','qua_nhan':'nhan','qua_man':'man','qua_dudu':'dudu',
 'qua_mit':'mit','qua_cam':'camsanh','qua_chuoi':'chuoi','qua_dieu':'dieu','qua_me':'me','dau':'dautay',
 'carot':'carot','cai':'caixanh','rau_muong':'raumuong','dien_dien':'bongdiendien','bong_sung':'bongsung','keo_neo':'keoneo',
 'bap':'bap','lua':'lua','khoai':'khoailang','khoai_mon':'khoaimon','dauphong':'dauphong','dau_xanh':'dauxanh','dau_nanh':'daunanh',
 'dau_bap':'daubap','catim':'catim','kho_qua':'khoqua','bido':'bido','bi_dao':'bidao','bau':'bau','muop':'muop','dua_leo':'dualeo','ot':'ot',
 'rau_ram':'rauram','hanh':'hanhla','sa':'sa','dau_rong':'daurong','dau_den':'dauden','gung':'gung','nghe':'nghe',
 'bong_vai':'bongvai','cham':'cham','xa_lach':'xalach','thit_ga':'thitga','trung':'trungga','thit_bo':'thitbo','sua':'suabo',
 'thit_cuu':'thitcuu','len':'longcuu','thit_vit':'thitvit','trung_vit':'trungvit','thit':'thitheo','suon':'suonheo',
 'thit_de':'thitde','sua_de':'suade',
}
for kid, f in MAP.items():
    assert os.path.exists(os.path.join(khdir, kid + '.svg')), kid
    im = Image.open(os.path.join(outdir, f + '.png'))   # 512 gốc (bản 254: trước thu 256)
    b = io.BytesIO(); im.save(b, 'WEBP', quality=92, method=6)
    svg = ('<svg viewBox="0 0 64 64" xmlns="http://www.w3.org/2000/svg"><image x="0" y="0" width="64" height="64" '
           'href="data:image/webp;base64,' + base64.b64encode(b.getvalue()).decode() + '"/></svg>')
    open(os.path.join(khdir, kid + '.svg'), 'w').write(svg)
json.dump(MAP, open(os.path.join(outdir, 'game_map.json'), 'w'), ensure_ascii=False, indent=0)
print(len(MAP))
