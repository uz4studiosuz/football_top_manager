"""Assigns eFootball-style playing styles to real players (PlayerPlayingStyles.md).

Players not listed keep the attribute-derived style chosen at runtime.
Run from the project root:  python -I tool/playing_styles.py
"""
import json
from pathlib import Path

PLAYERS = Path(__file__).resolve().parent.parent / 'assets' / 'data' / 'players.json'

STYLES = {
    # Real Madrid
    'rma_mbappe': 'goalPoacher', 'rma_vinicius': 'prolificWinger', 'rma_bellingham': 'holePlayer',
    'rma_rodrygo': 'roamingFlank', 'rma_valverde': 'boxToBox', 'rma_camavinga': 'boxToBox',
    'rma_tchouameni': 'anchorMan', 'rma_militao': 'buildUp', 'rma_rudiger': 'destroyer',
    'rma_carvajal': 'attackingFullBack', 'rma_courtois': 'defensiveGoalkeeper', 'rma_modric': 'orchestrator',
    'rma_brahim': 'creativePlaymaker', 'rma_endrick': 'advancedStriker', 'rma_mendy': 'defensiveFullBack',
    'rma_lunin': 'defensiveGoalkeeper', 'rma_guler': 'creativePlaymaker', 'rma_ceballos': 'orchestrator',
    'rma_vazquez': 'attackingFullBack', 'rma_alaba': 'buildUp', 'rma_fgarcia': 'attackingFullBack',
    'rma_asencio': 'buildUp', 'rma_fgonzalez': 'defensiveGoalkeeper',
    # Manchester City
    'mci_haaland': 'goalPoacher', 'mci_rodri': 'orchestrator', 'mci_debruyne': 'creativePlaymaker',
    'mci_foden': 'roamingFlank', 'mci_bernardo': 'roamingFlank', 'mci_doku': 'prolificWinger',
    'mci_gvardiol': 'attackingFullBack', 'mci_dias': 'buildUp', 'mci_akanji': 'buildUp',
    'mci_walker': 'defensiveFullBack', 'mci_ederson': 'attackingGoalkeeper', 'mci_gundogan': 'holePlayer',
    'mci_kovacic': 'boxToBox', 'mci_savinho': 'prolificWinger', 'mci_stones': 'buildUp',
    'mci_ortega': 'defensiveGoalkeeper', 'mci_marmoush': 'advancedStriker', 'mci_khusanov': 'destroyer',
    'mci_ake': 'buildUp', 'mci_lewis': 'attackingFullBack', 'mci_nunes': 'boxToBox',
    'mci_grealish': 'roamingFlank', 'mci_bobb': 'roamingFlank',
    # Arsenal
    'ars_saka': 'prolificWinger', 'ars_odegaard': 'creativePlaymaker', 'ars_rice': 'boxToBox',
    'ars_saliba': 'buildUp', 'ars_gabriel': 'extraFrontman', 'ars_havertz': 'deepLyingForward',
    'ars_martinelli': 'prolificWinger', 'ars_merino': 'boxToBox', 'ars_white': 'defensiveFullBack',
    'ars_timber': 'attackingFullBack', 'ars_raya': 'attackingGoalkeeper', 'ars_trossard': 'roamingFlank',
    'ars_jesus': 'dummyRunner', 'ars_jorginho': 'orchestrator', 'ars_calafiori': 'attackingFullBack',
    'ars_partey': 'destroyer', 'ars_sterling': 'prolificWinger', 'ars_kiwior': 'buildUp',
    'ars_tomiyasu': 'defensiveFullBack', 'ars_tierney': 'attackingFullBack', 'ars_nwaneri': 'creativePlaymaker',
    'ars_skelly': 'attackingFullBack', 'ars_neto': 'defensiveGoalkeeper',
    # Barcelona
    'fcb_yamal': 'prolificWinger', 'fcb_lewandowski': 'foxInTheBox', 'fcb_raphinha': 'prolificWinger',
    'fcb_pedri': 'creativePlaymaker', 'fcb_gavi': 'boxToBox', 'fcb_dejong': 'orchestrator',
    'fcb_kounde': 'defensiveFullBack', 'fcb_cubarsi': 'buildUp', 'fcb_araujo': 'destroyer',
    'fcb_balde': 'attackingFullBack', 'fcb_terstegen': 'attackingGoalkeeper', 'fcb_olmo': 'holePlayer',
    'fcb_ferran': 'advancedStriker', 'fcb_fermin': 'holePlayer', 'fcb_christensen': 'buildUp',
    'fcb_penya': 'defensiveGoalkeeper', 'fcb_szczesny': 'defensiveGoalkeeper', 'fcb_inigo': 'buildUp',
    'fcb_ericgarcia': 'buildUp', 'fcb_casado': 'anchorMan', 'fcb_ansu': 'advancedStriker',
    'fcb_gmartin': 'attackingFullBack', 'fcb_pauvictor': 'foxInTheBox',
    # Bayern
    'bay_kane': 'deepLyingForward', 'bay_musiala': 'holePlayer', 'bay_kimmich': 'orchestrator',
    'bay_sane': 'prolificWinger', 'bay_gnabry': 'prolificWinger', 'bay_davies': 'attackingFullBack',
    'bay_kim': 'destroyer', 'bay_upamecano': 'buildUp', 'bay_pavlovic': 'orchestrator',
    'bay_boey': 'attackingFullBack', 'bay_neuer': 'attackingGoalkeeper', 'bay_coman': 'crossSpecialist',
    'bay_muller': 'dummyRunner', 'bay_palhinha': 'destroyer', 'bay_tel': 'advancedStriker',
    'bay_guerreiro': 'attackingFullBack', 'bay_goretzka': 'boxToBox', 'bay_laimer': 'boxToBox',
    'bay_ito': 'buildUp', 'bay_dier': 'buildUp', 'bay_zaragoza': 'roamingFlank',
    'bay_wanner': 'creativePlaymaker', 'bay_ulreich': 'defensiveGoalkeeper',
    # PSG
    'psg_dembele': 'roamingFlank', 'psg_barcola': 'prolificWinger', 'psg_hakimi': 'attackingFullBack',
    'psg_vitinha': 'orchestrator', 'psg_marquinhos': 'buildUp', 'psg_nuno': 'attackingFullBack',
    'psg_pacho': 'destroyer', 'psg_zaire': 'boxToBox', 'psg_fabian': 'orchestrator',
    'psg_kolo': 'targetMan', 'psg_donnarumma': 'defensiveGoalkeeper', 'psg_asensio': 'creativePlaymaker',
    'psg_lee': 'creativePlaymaker', 'psg_neves': 'boxToBox', 'psg_beraldo': 'buildUp',
    'psg_safonov': 'defensiveGoalkeeper', 'psg_kvara': 'roamingFlank', 'psg_doue': 'prolificWinger',
    'psg_ramos': 'goalPoacher', 'psg_lhernandez': 'buildUp', 'psg_kimpembe': 'destroyer',
    'psg_mayulu': 'boxToBox', 'psg_tenas': 'defensiveGoalkeeper',
    # Inter
    'int_lautaro': 'advancedStriker', 'int_thuram': 'targetMan', 'int_barella': 'boxToBox',
    'int_calhanoglu': 'orchestrator', 'int_mkhitaryan': 'holePlayer', 'int_dimarco': 'crossSpecialist',
    'int_bastoni': 'buildUp', 'int_acerbi': 'destroyer', 'int_pavard': 'buildUp',
    'int_dumfries': 'fullBackFinisher', 'int_sommer': 'defensiveGoalkeeper', 'int_taremi': 'foxInTheBox',
    'int_frattesi': 'holePlayer', 'int_zielinski': 'creativePlaymaker', 'int_augusto': 'attackingFullBack',
    'int_martinez': 'defensiveGoalkeeper', 'int_devrij': 'buildUp', 'int_bisseck': 'extraFrontman',
    'int_darmian': 'defensiveFullBack', 'int_asllani': 'orchestrator', 'int_zalewski': 'crossSpecialist',
    'int_arnautovic': 'targetMan', 'int_correa': 'deepLyingForward',
    # Liverpool
    'liv_salah': 'prolificWinger', 'liv_vandijk': 'buildUp', 'liv_alexander_arnold': 'attackingFullBack',
    'liv_diaz': 'prolificWinger', 'liv_macallister': 'orchestrator', 'liv_szoboszlai': 'holePlayer',
    'liv_gravenberch': 'anchorMan', 'liv_nunez': 'goalPoacher', 'liv_robertson': 'crossSpecialist',
    'liv_konate': 'destroyer', 'liv_alisson': 'attackingGoalkeeper', 'liv_jota': 'foxInTheBox',
    'liv_gakpo': 'roamingFlank', 'liv_jones': 'boxToBox', 'liv_elliott': 'creativePlaymaker',
    'liv_kelleher': 'defensiveGoalkeeper', 'liv_chiesa': 'prolificWinger', 'liv_endo': 'anchorMan',
    'liv_gomez': 'buildUp', 'liv_tsimikas': 'crossSpecialist', 'liv_quansah': 'buildUp',
    'liv_bradley': 'attackingFullBack', 'liv_doak': 'prolificWinger',
}


def main():
    doc = json.loads(PLAYERS.read_text(encoding='utf8'))
    for p in doc['players']:
        if p['id'] in STYLES:
            p['playingStyle'] = STYLES[p['id']]
    PLAYERS.write_text(json.dumps(doc, ensure_ascii=False, indent=2) + '\n', encoding='utf8')
    print('styled', sum(1 for p in doc['players'] if 'playingStyle' in p))


if __name__ == '__main__':
    main()
