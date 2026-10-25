"""Hand-picked playing styles for well-known Premier League players.

Players not listed get the attribute-derived style chosen at runtime.
Run from the project root:  python -I tool/epl_styles.py
"""
import json
from pathlib import Path

PLAYERS = Path(__file__).resolve().parent.parent / 'assets' / 'data' / 'players_epl.json'

STYLES = {
    # Manchester City
    'epl_mci_gdonnarumma': 'defensiveGoalkeeper', 'epl_mci_rdias': 'destroyer', 'epl_mci_jgvardiol': 'attackingFullBack',
    'epl_mci_jstones': 'buildUp', 'epl_mci_akhusanov': 'destroyer', 'epl_mci_mnunes': 'attackingFullBack',
    'epl_mci_rlewis': 'fullBackFinisher', 'epl_mci_raïtnouri': 'attackingFullBack', 'epl_mci_rodri': 'orchestrator',
    'epl_mci_treijnders': 'boxToBox', 'epl_mci_bsilva': 'roamingFlank', 'epl_mci_mkovačić': 'boxToBox',
    'epl_mci_ngonzález': 'anchorMan', 'epl_mci_rcherki': 'creativePlaymaker', 'epl_mci_pfoden': 'holePlayer',
    'epl_mci_jdoku': 'roamingFlank', 'epl_mci_savinho': 'prolificWinger', 'epl_mci_ehaaland': 'goalPoacher',
    'epl_mci_omarmoush': 'advancedStriker', 'epl_mci_asemenyo': 'prolificWinger', 'epl_mci_mguehi': 'buildUp',
    # Arsenal
    'epl_ars_draya': 'attackingGoalkeeper', 'epl_ars_wsaliba': 'buildUp', 'epl_ars_gabriel': 'extraFrontman',
    'epl_ars_jtimber': 'defensiveFullBack', 'epl_ars_rcalafiori': 'attackingFullBack', 'epl_ars_bwhite': 'defensiveFullBack',
    'epl_ars_mlewisskelly': 'attackingFullBack', 'epl_ars_drice': 'boxToBox', 'epl_ars_mzubimendi': 'anchorMan',
    'epl_ars_mødegaard': 'creativePlaymaker', 'epl_ars_mmerino': 'holePlayer', 'epl_ars_eeze': 'creativePlaymaker',
    'epl_ars_bsaka': 'prolificWinger', 'epl_ars_nmadueke': 'roamingFlank', 'epl_ars_gmartinelli': 'prolificWinger',
    'epl_ars_ltrossard': 'roamingFlank', 'epl_ars_vgyökeres': 'goalPoacher', 'epl_ars_khavertz': 'deepLyingForward',
    'epl_ars_gjesus': 'dummyRunner',
    # Liverpool
    'epl_liv_alisson': 'attackingGoalkeeper', 'epl_liv_vvandijk': 'buildUp', 'epl_liv_ikonaté': 'destroyer',
    'epl_liv_jfrimpong': 'attackingFullBack', 'epl_liv_mkerkez': 'attackingFullBack', 'epl_liv_arobertson': 'attackingFullBack',
    'epl_liv_rgravenberch': 'boxToBox', 'epl_liv_amacallister': 'orchestrator', 'epl_liv_dszoboszlai': 'boxToBox',
    'epl_liv_wendō': 'destroyer', 'epl_liv_fwirtz': 'creativePlaymaker', 'epl_liv_msalah': 'prolificWinger',
    'epl_liv_cgakpo': 'roamingFlank', 'epl_liv_aisak': 'advancedStriker', 'epl_liv_hekitiké': 'dummyRunner',
    # Chelsea
    'epl_che_rsánchez': 'attackingGoalkeeper', 'epl_che_lcolwill': 'buildUp', 'epl_che_wfofana': 'destroyer',
    'epl_che_tchalobah': 'buildUp', 'epl_che_rjames': 'attackingFullBack', 'epl_che_mgusto': 'attackingFullBack',
    'epl_che_mcucurella': 'defensiveFullBack', 'epl_che_mcaicedo': 'destroyer', 'epl_che_efernández': 'boxToBox',
    'epl_che_rlavia': 'anchorMan', 'epl_che_cpalmer': 'creativePlaymaker', 'epl_che_pneto': 'prolificWinger',
    'epl_che_estêvão': 'prolificWinger', 'epl_che_agarnacho': 'roamingFlank', 'epl_che_jpedro': 'holePlayer',
    'epl_che_ldelap': 'targetMan',
    # Manchester United
    'epl_mun_mdeligt': 'buildUp', 'epl_mun_lyoro': 'buildUp', 'epl_mun_lmartínez': 'destroyer',
    'epl_mun_hmaguire': 'extraFrontman', 'epl_mun_ddalot': 'attackingFullBack', 'epl_mun_lshaw': 'attackingFullBack',
    'epl_mun_bfernandes': 'creativePlaymaker', 'epl_mun_casemiro': 'destroyer', 'epl_mun_mugarte': 'anchorMan',
    'epl_mun_kmainoo': 'boxToBox', 'epl_mun_bmbeumo': 'prolificWinger', 'epl_mun_mcunha': 'holePlayer',
    'epl_mun_amad': 'roamingFlank', 'epl_mun_bšeško': 'targetMan',
    # Newcastle
    'epl_new_npope': 'defensiveGoalkeeper', 'epl_new_sbotman': 'buildUp', 'epl_new_fschär': 'extraFrontman',
    'epl_new_dburn': 'defensiveFullBack', 'epl_new_ktrippier': 'crossSpecialist', 'epl_new_tlivramento': 'attackingFullBack',
    'epl_new_bguimarães': 'orchestrator', 'epl_new_stonali': 'boxToBox', 'epl_new_joelinton': 'destroyer',
    'epl_new_agordon': 'prolificWinger', 'epl_new_hbarnes': 'roamingFlank', 'epl_new_jmurphy': 'crossSpecialist',
    'epl_new_nwoltemade': 'targetMan', 'epl_new_ywissa': 'advancedStriker',
    # Tottenham
    'epl_tot_gvicario': 'defensiveGoalkeeper', 'epl_tot_cromero': 'destroyer', 'epl_tot_mvandeven': 'buildUp',
    'epl_tot_pporro': 'attackingFullBack', 'epl_tot_dudogie': 'attackingFullBack', 'epl_tot_jpalhinha': 'destroyer',
    'epl_tot_rbentancur': 'boxToBox', 'epl_tot_psarr': 'boxToBox', 'epl_tot_ybissouma': 'anchorMan',
    'epl_tot_xsimons': 'holePlayer', 'epl_tot_jmaddison': 'creativePlaymaker', 'epl_tot_mkudus': 'roamingFlank',
    'epl_tot_richarlison': 'advancedStriker', 'epl_tot_dsolanke': 'deepLyingForward', 'epl_tot_dkulusevski': 'roamingFlank',
    # Aston Villa
    'epl_avl_emartínez': 'defensiveGoalkeeper', 'epl_avl_ekonsa': 'buildUp', 'epl_avl_ptorres': 'buildUp',
    'epl_avl_tmings': 'destroyer', 'epl_avl_mcash': 'attackingFullBack', 'epl_avl_ldigne': 'crossSpecialist',
    'epl_avl_bkamara': 'destroyer', 'epl_avl_ytielemans': 'orchestrator', 'epl_avl_jmcginn': 'boxToBox',
    'epl_avl_mrogers': 'holePlayer', 'epl_avl_jsancho': 'roamingFlank', 'epl_avl_owatkins': 'advancedStriker',
}

doc = json.loads(PLAYERS.read_text(encoding='utf8'))
ids = {p['id'] for p in doc['players']}
missing = [k for k in STYLES if k not in ids]
assert not missing, missing
for p in doc['players']:
    if p['id'] in STYLES:
        p['playingStyle'] = STYLES[p['id']]
PLAYERS.write_text(json.dumps(doc, ensure_ascii=False, indent=2) + '\n', encoding='utf8')
print(f'tagged {len(STYLES)} players')
