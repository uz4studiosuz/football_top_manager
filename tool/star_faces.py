"""Adds look-alike portrait hints (skin, hair, cut, beard) for real players.

Only these four traits are stored; eyes, nose, face shape etc. stay
procedural, so portraits feel familiar without being exact likenesses.
Run from the project root:  python -I tool/star_faces.py
Keys: skin 0 (fair) – 9 (very dark); hair 0 black, 1 dark brown, 2 brown,
3 blonde, 4 grey, 5 auburn; cut 0 crop, 1 side part, 2 quiff, 3 curly top,
4 buzz, 5 bald, 6 waves, 7 afro, 8 long, 9 bun, 10 dreads, 11 mohawk,
12 slick back, 13 fringe; beard 0 none, 1 stubble, 2 short, 3 full,
4 goatee, 5 moustache.
"""
import json
from pathlib import Path

PLAYERS = Path(__file__).resolve().parent.parent / 'assets' / 'data' / 'players.json'

# id: (skin, hair, cut, beard)
FACES = {
    'rma_mbappe': (7, 0, 4, 0), 'rma_vinicius': (8, 0, 6, 1), 'rma_bellingham': (6, 0, 6, 0),
    'rma_rodrygo': (5, 0, 3, 1), 'rma_valverde': (2, 1, 1, 2), 'rma_camavinga': (8, 0, 10, 0),
    'rma_tchouameni': (8, 0, 4, 1), 'rma_militao': (6, 0, 4, 2), 'rma_rudiger': (8, 0, 4, 3),
    'rma_carvajal': (2, 1, 0, 3), 'rma_courtois': (1, 2, 1, 1), 'rma_modric': (1, 2, 8, 1),
    'rma_brahim': (3, 0, 2, 1), 'rma_endrick': (7, 0, 4, 0), 'rma_mendy': (8, 0, 4, 2),
    'rma_lunin': (1, 2, 0, 0), 'rma_guler': (2, 1, 8, 0), 'rma_ceballos': (2, 1, 1, 2),
    'rma_vazquez': (2, 1, 0, 3), 'rma_alaba': (8, 0, 4, 1), 'rma_fgarcia': (2, 1, 0, 1),
    'rma_asencio': (3, 0, 0, 0), 'rma_fgonzalez': (1, 1, 0, 0),
    'mci_haaland': (0, 3, 9, 0), 'mci_rodri': (2, 1, 1, 2), 'mci_debruyne': (0, 5, 1, 1),
    'mci_foden': (1, 1, 4, 1), 'mci_bernardo': (2, 1, 13, 3), 'mci_doku': (9, 0, 4, 0),
    'mci_gvardiol': (1, 1, 0, 1), 'mci_dias': (2, 0, 1, 3), 'mci_akanji': (7, 0, 4, 2),
    'mci_walker': (7, 0, 5, 1), 'mci_ederson': (3, 0, 4, 3), 'mci_gundogan': (3, 0, 1, 3),
    'mci_kovacic': (1, 1, 1, 2), 'mci_savinho': (5, 0, 3, 0), 'mci_stones': (1, 1, 1, 1),
    'mci_ortega': (1, 1, 0, 2), 'mci_marmoush': (4, 0, 3, 2), 'mci_khusanov': (2, 0, 0, 0),
    'mci_ake': (7, 0, 4, 1), 'mci_lewis': (6, 0, 4, 0), 'mci_nunes': (6, 0, 6, 2),
    'mci_grealish': (1, 1, 12, 1), 'mci_bobb': (7, 0, 3, 0),
    'ars_saka': (8, 0, 4, 0), 'ars_odegaard': (1, 2, 1, 1), 'ars_rice': (1, 1, 0, 1),
    'ars_saliba': (9, 0, 4, 2), 'ars_gabriel': (6, 0, 4, 3), 'ars_havertz': (1, 2, 13, 1),
    'ars_martinelli': (3, 1, 3, 0), 'ars_merino': (2, 1, 1, 2), 'ars_white': (1, 2, 0, 3),
    'ars_timber': (7, 0, 6, 0), 'ars_raya': (2, 0, 0, 2), 'ars_trossard': (1, 1, 1, 2),
    'ars_jesus': (6, 0, 4, 1), 'ars_jorginho': (2, 0, 4, 3), 'ars_calafiori': (1, 1, 8, 3),
    'ars_partey': (9, 0, 4, 3), 'ars_sterling': (8, 0, 4, 1), 'ars_kiwior': (0, 2, 0, 1),
    'ars_tomiyasu': (2, 0, 0, 0), 'ars_tierney': (0, 1, 0, 3), 'ars_nwaneri': (8, 0, 3, 0),
    'ars_skelly': (7, 0, 3, 0), 'ars_neto': (3, 0, 4, 3),
    'fcb_yamal': (6, 0, 3, 0), 'fcb_lewandowski': (1, 1, 12, 1), 'fcb_raphinha': (4, 0, 10, 1),
    'fcb_pedri': (2, 1, 13, 0), 'fcb_gavi': (2, 1, 1, 0), 'fcb_dejong': (1, 2, 13, 1),
    'fcb_kounde': (8, 0, 7, 1), 'fcb_cubarsi': (2, 1, 13, 0), 'fcb_araujo': (6, 0, 4, 3),
    'fcb_balde': (9, 0, 4, 0), 'fcb_terstegen': (0, 3, 12, 1), 'fcb_olmo': (2, 1, 1, 2),
    'fcb_ferran': (2, 1, 1, 1), 'fcb_fermin': (3, 0, 13, 0), 'fcb_christensen': (0, 3, 0, 1),
    'fcb_penya': (2, 0, 0, 2), 'fcb_szczesny': (1, 1, 0, 3), 'fcb_inigo': (2, 0, 0, 3),
    'fcb_ericgarcia': (2, 1, 1, 2), 'fcb_casado': (2, 1, 0, 0), 'fcb_ansu': (8, 0, 4, 0),
    'fcb_gmartin': (2, 1, 1, 0), 'fcb_pauvictor': (2, 0, 0, 1),
    'bay_kane': (1, 1, 1, 1), 'bay_musiala': (6, 0, 6, 0), 'bay_kimmich': (0, 2, 1, 0),
    'bay_sane': (8, 0, 4, 3), 'bay_gnabry': (7, 0, 4, 2), 'bay_davies': (9, 0, 4, 0),
    'bay_kim': (2, 0, 0, 0), 'bay_upamecano': (8, 0, 4, 1), 'bay_pavlovic': (1, 1, 0, 0),
    'bay_boey': (7, 0, 4, 0), 'bay_neuer': (0, 3, 0, 0), 'bay_coman': (7, 0, 4, 1),
    'bay_muller': (0, 2, 0, 0), 'bay_palhinha': (2, 0, 0, 3), 'bay_tel': (7, 0, 3, 0),
    'bay_guerreiro': (2, 0, 1, 2), 'bay_goretzka': (1, 1, 1, 3), 'bay_laimer': (1, 1, 0, 2),
    'bay_ito': (2, 0, 0, 0), 'bay_dier': (1, 1, 0, 2), 'bay_zaragoza': (2, 0, 13, 0),
    'bay_wanner': (0, 3, 13, 0), 'bay_ulreich': (0, 2, 0, 0),
    'psg_dembele': (8, 0, 4, 1), 'psg_barcola': (8, 0, 3, 0), 'psg_hakimi': (5, 0, 4, 2),
    'psg_vitinha': (2, 0, 3, 1), 'psg_marquinhos': (3, 0, 1, 3), 'psg_nuno': (8, 0, 4, 0),
    'psg_pacho': (9, 0, 4, 0), 'psg_zaire': (8, 0, 3, 0), 'psg_fabian': (2, 1, 12, 3),
    'psg_kolo': (9, 0, 4, 0), 'psg_donnarumma': (2, 0, 0, 2), 'psg_asensio': (2, 1, 1, 1),
    'psg_lee': (2, 0, 13, 0), 'psg_neves': (3, 0, 3, 0), 'psg_beraldo': (4, 0, 0, 0),
    'psg_safonov': (1, 1, 0, 0), 'psg_kvara': (1, 0, 8, 0), 'psg_doue': (8, 0, 3, 0),
    'psg_ramos': (2, 1, 1, 1), 'psg_lhernandez': (2, 1, 0, 2), 'psg_kimpembe': (8, 0, 4, 3),
    'psg_mayulu': (8, 0, 3, 0), 'psg_tenas': (2, 0, 0, 0),
    'int_lautaro': (3, 0, 4, 3), 'int_thuram': (8, 0, 4, 1), 'int_barella': (2, 0, 1, 2),
    'int_calhanoglu': (2, 0, 12, 3), 'int_mkhitaryan': (2, 0, 4, 3), 'int_dimarco': (2, 0, 0, 2),
    'int_bastoni': (1, 1, 1, 1), 'int_acerbi': (1, 4, 4, 3), 'int_pavard': (1, 2, 9, 2),
    'int_dumfries': (7, 0, 4, 2), 'int_sommer': (1, 1, 0, 1), 'int_taremi': (3, 0, 0, 3),
    'int_frattesi': (2, 1, 1, 2), 'int_zielinski': (1, 1, 1, 1), 'int_augusto': (6, 0, 4, 0),
    'int_martinez': (2, 0, 0, 1), 'int_devrij': (1, 1, 0, 1), 'int_bisseck': (8, 0, 4, 0),
    'int_darmian': (1, 4, 0, 1), 'int_asllani': (2, 0, 1, 0), 'int_zalewski': (1, 1, 1, 0),
    'int_arnautovic': (2, 4, 12, 3), 'int_correa': (3, 0, 0, 3),
    'liv_salah': (5, 0, 7, 3), 'liv_vandijk': (6, 0, 1, 2), 'liv_alexander_arnold': (6, 0, 4, 0),
    'liv_diaz': (6, 0, 3, 1), 'liv_macallister': (1, 5, 0, 1), 'liv_szoboszlai': (0, 3, 12, 0),
    'liv_gravenberch': (8, 0, 10, 0), 'liv_nunez': (4, 0, 3, 3), 'liv_robertson': (0, 1, 0, 2),
    'liv_konate': (9, 0, 4, 2), 'liv_alisson': (2, 1, 1, 3), 'liv_jota': (2, 0, 0, 2),
    'liv_gakpo': (7, 0, 4, 2), 'liv_jones': (1, 1, 1, 0), 'liv_elliott': (1, 1, 13, 0),
    'liv_kelleher': (0, 5, 0, 0), 'liv_chiesa': (2, 1, 1, 2), 'liv_endo': (2, 0, 0, 0),
    'liv_gomez': (7, 0, 4, 1), 'liv_tsimikas': (2, 0, 0, 3), 'liv_quansah': (7, 0, 4, 0),
    'liv_bradley': (1, 1, 0, 0), 'liv_doak': (1, 1, 13, 0),
}


def main():
    doc = json.loads(PLAYERS.read_text(encoding='utf8'))
    for p in doc['players']:
        f = FACES.get(p['id'])
        if f:
            p['face'] = {'skin': f[0], 'hair': f[1], 'cut': f[2], 'beardStyle': f[3]}
    PLAYERS.write_text(json.dumps(doc, ensure_ascii=False, indent=2) + '\n', encoding='utf8')
    print('faces', sum(1 for p in doc['players'] if 'face' in p))


if __name__ == '__main__':
    main()
