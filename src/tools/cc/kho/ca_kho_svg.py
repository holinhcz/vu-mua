# Icon Kho (ui/svg/kh/<id>.svg, khung 64) cho 10 loài cá câu cá mới vô Kho vườn (Link 11-23 "nối đủ").
# Cùng kiểu với ca_ro.svg / ca_lang.svg của vườn: đuôi, thân, bụng sáng, vây lưng, mắt trắng; thêm nét riêng từng loài.
# python3 ca_kho_svg.py <src/godot/ui/svg/kh>
import sys, os
OUT = sys.argv[1]
ST = 'stroke="rgb(0,0,0)" stroke-opacity="0.3" stroke-width="1.3px" stroke-linejoin="round"'
def tail(c, d="M44 34L59 23L55.500 34L59 45Z"):
    return f'<path d="{d}" fill="{c}" stroke="rgb(0,0,0)" stroke-opacity="0.25" stroke-width="1.2px" stroke-linejoin="round"></path>'
def body(c, d="M9 34Q19 21 37 23.500Q45 26 46 34Q45 42 37 44.500Q19 47 9 34Z"):
    return f'<path d="{d}" fill="{c}" {ST}></path>'
def belly(c, d="M12 37Q24 45 40 41Q30 46 17 43Z"):
    return f'<path d="{d}" fill="{c}" opacity="0.8" stroke="none"></path>'
def dorsal(c, d="M23 24Q30 14 39 24Z"):
    return f'<path d="{d}" fill="{c}" stroke="rgb(0,0,0)" stroke-opacity="0.22"></path>'
def eye(x=17, y=31, r=2.6):
    return f'<circle cx="{x}" cy="{y}" r="{r}" fill="rgb(255, 255, 255)" stroke="none"></circle><circle cx="{x - .5}" cy="{y}" r="{r / 2}" fill="rgb(23, 18, 14)" stroke="none"></circle>'
def line(d, c, w=1.6, o=1.0):
    return f'<path d="{d}" stroke="{c}" stroke-opacity="{o}" stroke-width="{w}px" fill="none" stroke-linecap="round"></path>'
def dot(x, y, r, c, o=1.0):
    return f'<circle cx="{x}" cy="{y}" r="{r}" fill="{c}" opacity="{o}" stroke="none"></circle>'
def svg(parts):
    return '<svg viewBox="0 0 64 64" aria-hidden="true" focusable="false" xmlns="http://www.w3.org/2000/svg">' + ''.join(parts) + '</svg>'

F = {}
# sặc rằn: thân bầu ô liu, sọc chéo sẫm
F['ca_sac'] = svg([tail('rgb(122, 120, 70)'), body('rgb(140, 138, 80)', "M9 34Q18 20 36 22Q46 25 47 34Q46 43 36 46Q18 48 9 34Z"),
    belly('rgb(214, 206, 150)'), dorsal('rgb(122, 120, 70)', "M21 23Q31 12 42 25Z"),
    line("M22 24L28 44M29 23L35 45M36 24L41 43", 'rgb(60,58,30)', 2.2, .5), eye()])
# mè vinh: thân cao bạc, vây + đuôi đỏ cam
F['ca_mevinh'] = svg([tail('rgb(226, 92, 52)'), body('rgb(196, 204, 210)', "M9 34Q17 17 35 19Q46 23 47 34Q46 45 35 49Q17 51 9 34Z"),
    belly('rgb(246, 247, 248)', "M12 38Q24 48 41 43Q30 50 17 46Z"), dorsal('rgb(226, 92, 52)', "M20 21Q29 8 42 22Z"),
    '<path d="M27 47L31 55L35 47Z" fill="rgb(226, 92, 52)" stroke="none"></path>',
    line("M22 26Q25 34 22 42M30 24Q33 34 30 45M38 25Q41 34 38 43", 'rgb(110,120,130)', 1.4, .45), eye()])
# chốt: thân thon vàng nâu, râu
F['ca_chot'] = svg([tail('rgb(150, 120, 60)'), body('rgb(176, 146, 80)', "M7 34Q18 26 38 26.500Q46 28 46 34Q46 40 38 41.500Q18 42 7 34Z"),
    belly('rgb(232, 214, 160)', "M11 36Q24 42 40 39Q30 43 16 41Z"), dorsal('rgb(110, 86, 40)', "M22 27Q27 16 33 27Z"),
    line("M9 32L2 28M9 35L1 37M10 36L4 42", 'rgb(90, 70, 34)', 1.3), eye(15, 32, 2.3)])
# he đỏ đuôi: bạc, đuôi đỏ viền đen, vây đỏ
F['ca_he'] = svg([tail('rgb(220, 54, 40)'), line("M57 24L59 23M57 44L59 45", 'rgb(30,20,20)', 2.4),
    body('rgb(206, 210, 200)'), belly('rgb(246, 244, 236)'), dorsal('rgb(220, 54, 40)'),
    '<path d="M26 44L29 51L33 44Z" fill="rgb(220, 54, 40)" stroke="none"></path>',
    line("M24 27Q27 34 24 41M31 26Q34 34 31 42M38 27Q40 34 38 41", 'rgb(140,140,120)', 1.3, .45), eye()])
# thát lát cườm: dài như lưỡi dao, lưng gù, hàng chấm đen viền trắng
F['ca_thatlat'] = svg([tail('rgb(120, 128, 136)', "M48 36L59 31L57 37L59 43Z"),
    body('rgb(150, 158, 166)', "M5 30Q12 19 26 22Q40 28 50 36Q40 44 24 44Q10 43 5 30Z"),
    belly('rgb(226, 230, 232)', "M10 36Q24 45 46 38Q30 47 15 43Z"), dorsal('rgb(120, 128, 136)', "M17 21Q21 15 25 21Z")]
    + [dot(x, y, 2.2, 'rgb(250,250,250)') + dot(x, y, 1.3, 'rgb(30,30,34)') for x, y in ((24, 39), (30, 40), (36, 40), (42, 39))] + [eye(11, 28, 2.3)])
# bống tượng: đầu to, nâu đốm sẫm
F['ca_bong'] = svg([tail('rgb(112, 84, 52)', "M45 34L58 25L55 34L58 43Z"),
    body('rgb(140, 108, 70)', "M6 33Q12 21 30 23Q45 26 47 34Q45 42 30 45Q12 46 6 33Z"),
    belly('rgb(210, 190, 150)', "M10 37Q24 46 41 41Q30 47 15 43Z"), dorsal('rgb(112, 84, 52)', "M26 24Q30 17 35 25Z"),
    dot(25, 31, 2.6, 'rgb(70,50,28)', .7), dot(33, 29, 2.2, 'rgb(70,50,28)', .7), dot(38, 35, 2.4, 'rgb(70,50,28)', .7), dot(29, 38, 2, 'rgb(70,50,28)', .7),
    eye(13, 30, 2.8)])
# lóc bông: lóc sẫm, dài, đốm cam viền đen
F['ca_locbong'] = svg([tail('rgb(48, 62, 44)'), body('rgb(64, 84, 56)', "M4 34Q16 26 38 27.500Q50 29 57 34Q50 39 38 40.500Q16 42 4 34Z"),
    belly('rgb(190, 200, 160)', "M8 36Q24 42 44 39Q28 44 13 41Z"), '<path d="M14 28Q34 22 48 30Z" fill="rgb(48, 62, 44)" stroke="none"></path>']
    + [dot(x, y, 2.6, 'rgb(30,36,26)') + dot(x, y, 1.6, 'rgb(236, 140, 50)') for x, y in ((22, 33), (31, 32), (40, 34))] + [eye(11, 32, 2.4)])
# chình bông: thân lươn to, vàng nâu đốm
F['ca_chinh'] = svg([line("M8 40C14 24 26 46 34 33S48 16 56 25", 'rgb(110, 92, 40)', 11),
    line("M8 40C14 24 26 46 34 33S48 16 56 25", 'rgb(200, 170, 80)', 6, .85),
    dot(16, 33, 1.6, 'rgb(90,70,30)'), dot(25, 39, 1.6, 'rgb(90,70,30)'), dot(33, 34, 1.6, 'rgb(90,70,30)'), dot(41, 25, 1.6, 'rgb(90,70,30)'),
    dot(54, 23, 1.7, 'rgb(17,17,17)')])
# cá hô: to xám, đầu lớn, vảy
F['ca_ho'] = svg([tail('rgb(96, 104, 110)', "M45 34L60 21L56 34L60 47Z"),
    body('rgb(120, 130, 136)', "M5 34Q13 18 34 19Q47 23 48 34Q47 45 34 49Q13 50 5 34Z"),
    belly('rgb(220, 222, 218)', "M9 38Q24 49 43 43Q30 51 15 46Z"), dorsal('rgb(96, 104, 110)', "M20 20Q30 9 42 22Z"),
    line("M14 25Q18 34 14 43", 'rgb(60,66,70)', 1.6, .55),
    line("M24 25Q27 34 24 44M31 23Q34 34 31 46M38 24Q41 34 38 44", 'rgb(70,78,84)', 1.3, .4), eye(11, 31, 2.8)])
# tra dầu: cá tra khổng lồ, xám không vảy, vây lưng nhọn, râu ngắn
F['ca_tradau'] = svg([tail('rgb(86, 96, 104)', "M45 34L60 22L56 34L60 46Z"),
    body('rgb(110, 122, 132)', "M5 35Q14 24 36 24.500Q47 27 48 34Q47 41 36 44Q14 46 5 35Z"),
    belly('rgb(226, 230, 232)', "M9 38Q24 46 43 41Q30 48 15 44Z"), '<path d="M24 25L30 13L33 25Z" fill="rgb(86, 96, 104)" stroke="rgb(0,0,0)" stroke-opacity="0.22"></path>',
    line("M7 36L2 40M7 34L2 31", 'rgb(60,66,72)', 1.2), eye(12, 32, 2.4)])

for k, v in F.items():
    open(os.path.join(OUT, k + '.svg'), 'w').write(v)
print(len(F))
