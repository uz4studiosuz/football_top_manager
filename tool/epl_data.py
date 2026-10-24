"""Builds the men's Premier League 2025/26 seed (20 clubs x 23 players).

Squads are written from public knowledge of the 2025/26 season; ratings are
game estimates. Attributes come from the same positional generator as
expand_squads.py, so OVR lands on the listed value.
Run from the project root:  python -I tool/epl_data.py
"""
import json
import random
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
from expand_squads import generate, value  # noqa: E402

DATA = Path(__file__).resolve().parent.parent / 'assets' / 'data'

FLAGS = {
    'Angliya': '🏴', 'Ispaniya': '🇪🇸', 'Fransiya': '🇫🇷', 'Braziliya': '🇧🇷', 'Portugaliya': '🇵🇹',
    'Germaniya': '🇩🇪', 'Niderlandiya': '🇳🇱', 'Belgiya': '🇧🇪', 'Argentina': '🇦🇷', 'Urugvay': '🇺🇾',
    'Kolumbiya': '🇨🇴', 'Ekvador': '🇪🇨', 'Shotlandiya': '🏴', 'Uels': '🏴', 'Irlandiya': '🇮🇪',
    'Shimoliy Irlandiya': '🇬🇧', 'Norvegiya': '🇳🇴', 'Daniya': '🇩🇰', 'Shvetsiya': '🇸🇪',
    'Shveysariya': '🇨🇭', 'Avstriya': '🇦🇹', 'Xorvatiya': '🇭🇷', 'Serbiya': '🇷🇸', 'Polsha': '🇵🇱',
    'Chexiya': '🇨🇿', 'Vengriya': '🇭🇺', 'Ukraina': '🇺🇦', 'Turkiya': '🇹🇷', 'Italiya': '🇮🇹',
    'Gana': '🇬🇭', 'Nigeriya': '🇳🇬', 'Senegal': '🇸🇳', 'Kamerun': '🇨🇲', 'Kot-d’Ivuar': '🇨🇮',
    'Mali': '🇲🇱', 'Marokash': '🇲🇦', 'Jazoir': '🇩🇿', 'Misr': '🇪🇬', 'Tunis': '🇹🇳',
    'Yaponiya': '🇯🇵', 'Janubiy Koreya': '🇰🇷', 'AQSH': '🇺🇸', 'Kanada': '🇨🇦', 'Meksika': '🇲🇽',
    'Paragvay': '🇵🇾', 'Yamayka': '🇯🇲', 'Gvineya': '🇬🇳', 'KDR': '🇨🇩', 'Burkina-Faso': '🇧🇫',
    'Zimbabve': '🇿🇼', 'Avstraliya': '🇦🇺', 'Gruziya': '🇬🇪', 'O‘zbekiston': '🇺🇿',
    'Slovakiya': '🇸🇰', 'Sloveniya': '🇸🇮', 'Albaniya': '🇦🇱', 'Kosovo': '🇽🇰', 'Gretsiya': '🇬🇷',
    'Finlandiya': '🇫🇮', 'Islandiya': '🇮🇸', 'Venesuela': '🇻🇪', 'Gabon': '🇬🇦', 'Zambiya': '🇿🇲',
    'Gaiti': '🇭🇹', 'Bosniya': '🇧🇦',
}

# Each line: name | short | pos | age | nationality | ovr | number | foot
CLUBS = {
    'epl_ars': dict(
        name='Arsenal', short='ARS', city='London', nickname='The Gunners', founded=1886, rep=91,
        stadium='Emirates Stadium', capacity=60704, budget=140, colors=(0xFFDB0007, 0xFFFFFFFF, 0xFFE8C46A),
        crest=dict(shape='heater', pattern='solid', primaryColor=0xFFDB0007, secondaryColor=0xFFFFFFFF,
                   trimColor=0xFFE8C46A, monogram='AFC', emblem='cannon'),
        tactics=('f433', 'highPressing', 4, 4),
        squad='''
David Raya|D. Raya|GK|30|Ispaniya|86|1|R
Kepa Arrizabalaga|Kepa|GK|31|Ispaniya|79|13|R
Tommy Setford|T. Setford|GK|19|Angliya|62|35|R
William Saliba|W. Saliba|CB|25|Fransiya|89|2|R
Gabriel Magalhães|Gabriel|CB|28|Braziliya|87|6|L
Jurriën Timber|J. Timber|RB|24|Niderlandiya|84|12|R
Riccardo Calafiori|R. Calafiori|LB|24|Italiya|82|33|L
Piero Hincapié|P. Hincapié|CB|23|Ekvador|82|5|L
Cristhian Mosquera|C. Mosquera|CB|21|Ispaniya|77|3|R
Ben White|B. White|RB|28|Angliya|82|4|R
Myles Lewis-Skelly|M. Lewis-Skelly|LB|19|Angliya|77|49|L
Declan Rice|D. Rice|CMF|27|Angliya|88|41|R
Martin Zubimendi|M. Zubimendi|DMF|26|Ispaniya|86|36|R
Martin Ødegaard|M. Ødegaard|AMF|27|Norvegiya|87|8|L
Mikel Merino|M. Merino|CMF|29|Ispaniya|83|23|L
Christian Nørgaard|C. Nørgaard|DMF|32|Daniya|79|16|R
Eberechi Eze|E. Eze|AMF|27|Angliya|84|10|R
Bukayo Saka|B. Saka|RWF|24|Angliya|88|7|L
Noni Madueke|N. Madueke|RWF|23|Angliya|80|20|L
Gabriel Martinelli|G. Martinelli|LWF|24|Braziliya|81|11|R
Leandro Trossard|L. Trossard|LWF|31|Belgiya|80|19|R
Viktor Gyökeres|V. Gyökeres|CF|27|Shvetsiya|86|14|R
Kai Havertz|K. Havertz|CF|26|Germaniya|82|29|L
'''),
    'epl_avl': dict(
        name='Aston Villa', short='AVL', city='Birmingham', nickname='The Villans', founded=1874, rep=84,
        stadium='Villa Park', capacity=42640, budget=70, colors=(0xFF670E36, 0xFF95BFE5, 0xFFF4C430),
        crest=dict(shape='shield', pattern='halves', primaryColor=0xFF95BFE5, secondaryColor=0xFF670E36,
                   trimColor=0xFFF4C430, monogram='AVFC', stars=1, emblem='lion'),
        tactics=('f4231', 'possession', 4, 3),
        squad='''
Emiliano Martínez|E. Martínez|GK|33|Argentina|85|23|R
Marco Bizot|M. Bizot|GK|35|Niderlandiya|74|40|R
Joe Gauci|J. Gauci|GK|25|Avstraliya|66|18|R
Ezri Konsa|E. Konsa|CB|28|Angliya|82|4|R
Pau Torres|P. Torres|CB|29|Ispaniya|82|14|L
Tyrone Mings|T. Mings|CB|33|Angliya|78|5|L
Victor Lindelöf|V. Lindelöf|CB|31|Shvetsiya|77|3|R
Matty Cash|M. Cash|RB|28|Polsha|80|2|R
Lucas Digne|L. Digne|LB|32|Fransiya|78|12|L
Ian Maatsen|I. Maatsen|LB|23|Niderlandiya|78|22|L
Andrés García|A. García|RB|22|Ispaniya|72|16|R
Boubacar Kamara|B. Kamara|DMF|26|Fransiya|83|44|R
Amadou Onana|A. Onana|DMF|24|Belgiya|82|24|R
Youri Tielemans|Y. Tielemans|CMF|28|Belgiya|83|8|R
John McGinn|J. McGinn|CMF|31|Shotlandiya|81|7|L
Ross Barkley|R. Barkley|AMF|32|Angliya|76|6|R
Lamare Bogarde|L. Bogarde|DMF|21|Niderlandiya|70|26|R
Morgan Rogers|M. Rogers|AMF|23|Angliya|83|27|R
Jadon Sancho|J. Sancho|LWF|25|Angliya|79|19|R
Emiliano Buendía|E. Buendía|RWF|28|Argentina|77|10|R
Ollie Watkins|O. Watkins|CF|30|Angliya|84|11|R
Evann Guessand|E. Guessand|CF|24|Kot-d’Ivuar|77|29|R
Harvey Elliott|H. Elliott|RWF|22|Angliya|78|9|L
'''),
    'epl_bou': dict(
        name='AFC Bournemouth', short='BOU', city='Bournemouth', nickname='The Cherries', founded=1899, rep=74,
        stadium='Vitality Stadium', capacity=11307, budget=55, colors=(0xFFDA291C, 0xFF000000, 0xFFFFFFFF),
        crest=dict(shape='badge', pattern='verticalStripes', primaryColor=0xFFDA291C, secondaryColor=0xFF000000,
                   trimColor=0xFFFFFFFF, monogram='AFCB'),
        tactics=('f4231', 'highPressing', 4, 4),
        squad='''
Đorđe Petrović|Đ. Petrović|GK|26|Serbiya|79|1|R
Will Dennis|W. Dennis|GK|25|Angliya|65|40|R
Fraser Forster|F. Forster|GK|37|Angliya|70|13|R
Marcos Senesi|M. Senesi|CB|28|Argentina|79|5|L
Bafodé Diakité|B. Diakité|CB|24|Fransiya|78|18|R
Veljko Milosavljević|V. Milosavljević|CB|18|Serbiya|69|44|R
James Hill|J. Hill|CB|23|Angliya|70|23|R
Adam Smith|A. Smith|RB|34|Angliya|73|15|R
Álex Jiménez|Á. Jiménez|RB|20|Ispaniya|73|20|R
Adrien Truffert|A. Truffert|LB|24|Fransiya|77|3|L
Julio Soler|J. Soler|LB|20|Argentina|69|33|L
Tyler Adams|T. Adams|DMF|26|AQSH|79|12|R
Lewis Cook|L. Cook|CMF|28|Angliya|77|4|R
Alex Scott|A. Scott|CMF|22|Angliya|76|8|R
Ryan Christie|R. Christie|CMF|30|Shotlandiya|75|10|R
Marcus Tavernier|M. Tavernier|LMF|26|Angliya|77|16|L
Justin Kluivert|J. Kluivert|AMF|26|Niderlandiya|79|19|R
Antoine Semenyo|A. Semenyo|RWF|26|Gana|82|24|R
David Brooks|D. Brooks|RWF|28|Uels|74|7|L
Amine Adli|A. Adli|LWF|25|Marokash|76|21|L
Ben Gannon-Doak|B. Gannon-Doak|RWF|20|Shotlandiya|72|11|R
Evanilson|Evanilson|CF|26|Braziliya|79|9|R
Eli Junior Kroupi|E. Kroupi|CF|19|Fransiya|72|22|R
'''),
    'epl_bre': dict(
        name='Brentford', short='BRE', city='London', nickname='The Bees', founded=1889, rep=72,
        stadium='Gtech Community Stadium', capacity=17250, budget=50, colors=(0xFFE30613, 0xFFFFFFFF, 0xFF140E0D),
        crest=dict(shape='roundel', pattern='pinstripes', primaryColor=0xFFE30613, secondaryColor=0xFFFFFFFF,
                   trimColor=0xFF140E0D, monogram='B', emblem='star', ringText='BRENTFORD FC', ringColor=0xFF140E0D),
        tactics=('f433', 'longBallCounter', 3, 3),
        squad='''
Caoimhín Kelleher|C. Kelleher|GK|27|Irlandiya|80|1|R
Hákon Valdimarsson|H. Valdimarsson|GK|24|Islandiya|70|12|R
Ellery Balcombe|E. Balcombe|GK|26|Angliya|64|21|R
Nathan Collins|N. Collins|CB|24|Irlandiya|79|22|R
Ethan Pinnock|E. Pinnock|CB|32|Yamayka|76|5|L
Kristoffer Ajer|K. Ajer|CB|27|Norvegiya|76|20|R
Sepp van den Berg|S. van den Berg|CB|23|Niderlandiya|77|4|R
Aaron Hickey|A. Hickey|RB|23|Shotlandiya|74|2|R
Michael Kayode|M. Kayode|RB|21|Italiya|74|33|R
Rico Henry|R. Henry|LB|28|Angliya|74|3|L
Keane Lewis-Potter|K. Lewis-Potter|LB|24|Angliya|75|23|R
Jordan Henderson|J. Henderson|CMF|35|Angliya|77|6|R
Vitaly Janelt|V. Janelt|DMF|27|Germaniya|76|27|L
Mathias Jensen|M. Jensen|CMF|29|Daniya|76|8|R
Yehor Yarmoliuk|Y. Yarmoliuk|CMF|21|Ukraina|73|18|R
Mikkel Damsgaard|M. Damsgaard|AMF|25|Daniya|78|24|L
Antoni Milambo|A. Milambo|AMF|20|Niderlandiya|72|10|R
Kevin Schade|K. Schade|LWF|23|Germaniya|77|7|R
Dango Ouattara|D. Ouattara|RWF|23|Burkina-Faso|77|19|R
Reiss Nelson|R. Nelson|LWF|25|Angliya|73|11|R
Fábio Carvalho|F. Carvalho|AMF|23|Portugaliya|72|14|L
Igor Thiago|I. Thiago|CF|24|Braziliya|78|9|R
Gustavo Nunes|G. Nunes|RWF|20|Braziliya|69|17|R
'''),
    'epl_bha': dict(
        name='Brighton & Hove Albion', short='BHA', city='Brighton', nickname='The Seagulls', founded=1901, rep=78,
        stadium='Amex Stadium', capacity=31876, budget=70, colors=(0xFF0057B8, 0xFFFFFFFF, 0xFFFFCD00),
        crest=dict(shape='roundel', pattern='solid', primaryColor=0xFFFFFFFF, secondaryColor=0xFF0057B8,
                   trimColor=0xFF0057B8, monogram='BHA', emblem='bird', ringText='BRIGHTON & HOVE ALBION',
                   ringColor=0xFF0057B8),
        tactics=('f4231', 'possession', 4, 4),
        squad='''
Bart Verbruggen|B. Verbruggen|GK|23|Niderlandiya|80|1|R
Jason Steele|J. Steele|GK|35|Angliya|70|23|R
Tom McGill|T. McGill|GK|25|Kanada|64|38|R
Lewis Dunk|L. Dunk|CB|34|Angliya|78|5|R
Jan Paul van Hecke|J. van Hecke|CB|25|Niderlandiya|79|6|R
Olivier Boscagli|O. Boscagli|CB|28|Fransiya|76|21|L
Adam Webster|A. Webster|CB|30|Angliya|74|4|R
Joël Veltman|J. Veltman|RB|33|Niderlandiya|74|34|R
Mats Wieffer|M. Wieffer|RB|26|Niderlandiya|77|27|R
Ferdi Kadıoğlu|F. Kadıoğlu|LB|26|Turkiya|78|24|L
Maxim De Cuyper|M. De Cuyper|LB|25|Belgiya|77|29|L
Carlos Baleba|C. Baleba|DMF|21|Kamerun|81|17|R
Pascal Groß|P. Groß|CMF|34|Germaniya|76|13|R
Jack Hinshelwood|J. Hinshelwood|CMF|20|Angliya|74|41|R
Yasin Ayari|Y. Ayari|CMF|22|Shvetsiya|75|26|R
James Milner|J. Milner|CMF|39|Angliya|70|20|R
Georginio Rutter|G. Rutter|AMF|23|Fransiya|78|10|R
Kaoru Mitoma|K. Mitoma|LWF|28|Yaponiya|80|22|R
Yankuba Minteh|Y. Minteh|RWF|21|Gaiti|77|11|L
Solly March|S. March|RWF|31|Angliya|74|7|L
Diego Gómez|D. Gómez|AMF|22|Paragvay|75|8|R
Danny Welbeck|D. Welbeck|CF|35|Angliya|75|18|R
Stefanos Tzimas|S. Tzimas|CF|20|Gretsiya|72|9|R
'''),
    'epl_bur': dict(
        name='Burnley', short='BUR', city='Burnley', nickname='The Clarets', founded=1882, rep=66,
        stadium='Turf Moor', capacity=21744, budget=35, colors=(0xFF6C1D45, 0xFF99D6EA, 0xFFEDE04A),
        crest=dict(shape='shield', pattern='halves', primaryColor=0xFF6C1D45, secondaryColor=0xFF99D6EA,
                   trimColor=0xFFEDE04A, monogram='BFC', emblem='lion'),
        tactics=('f4231', 'longBall', 2, 2),
        squad='''
Martin Dúbravka|M. Dúbravka|GK|36|Slovakiya|74|1|R
Max Weiß|M. Weiß|GK|21|Germaniya|66|13|R
Václav Hladký|V. Hladký|GK|35|Chexiya|64|32|R
Maxime Estève|M. Estève|CB|23|Fransiya|75|5|L
Axel Tuanzebe|A. Tuanzebe|CB|27|KDR|72|6|R
Hjalmar Ekdal|H. Ekdal|CB|27|Shvetsiya|71|18|R
Joe Worrall|J. Worrall|CB|28|Angliya|71|4|R
Kyle Walker|K. Walker|RB|35|Angliya|76|2|R
Oliver Sonne|O. Sonne|RB|25|Daniya|69|26|R
Quilindschy Hartman|Q. Hartman|LB|24|Niderlandiya|72|3|L
Lucas Pires|L. Pires|LB|24|Braziliya|69|23|L
Josh Cullen|J. Cullen|DMF|29|Irlandiya|73|24|R
Josh Laurent|J. Laurent|CMF|30|Angliya|71|29|R
Lesley Ugochukwu|L. Ugochukwu|DMF|21|Fransiya|72|8|R
Florentino Luís|Florentino|DMF|26|Portugaliya|74|16|R
Hannibal Mejbri|H. Mejbri|AMF|22|Tunis|72|28|R
Jaidon Anthony|J. Anthony|LWF|26|Angliya|73|11|R
Loum Tchaouna|L. Tchaouna|RWF|22|Fransiya|72|17|L
Marcus Edwards|M. Edwards|RWF|27|Angliya|71|10|L
Jacob Bruun Larsen|J. Bruun Larsen|LWF|27|Daniya|70|7|R
Zian Flemming|Z. Flemming|CF|27|Niderlandiya|72|19|R
Lyle Foster|L. Foster|CF|25|Kanada|71|9|R
Armando Broja|A. Broja|CF|24|Albaniya|72|27|R
'''),
    'epl_che': dict(
        name='Chelsea', short='CHE', city='London', nickname='The Blues', founded=1905, rep=89,
        stadium='Stamford Bridge', capacity=40343, budget=150, colors=(0xFF034694, 0xFFFFFFFF, 0xFFDBA111),
        crest=dict(shape='roundel', pattern='solid', primaryColor=0xFF034694, secondaryColor=0xFF034694,
                   trimColor=0xFFDBA111, monogram='CFC', emblem='lion', ringText='CHELSEA FOOTBALL CLUB',
                   ringColor=0xFF034694),
        tactics=('f4231', 'possession', 4, 4),
        squad='''
Robert Sánchez|R. Sánchez|GK|28|Ispaniya|80|1|R
Filip Jørgensen|F. Jørgensen|GK|23|Daniya|75|12|R
Gaga Slonina|G. Slonina|GK|21|AQSH|66|44|R
Levi Colwill|L. Colwill|CB|22|Angliya|82|6|L
Wesley Fofana|W. Fofana|CB|25|Fransiya|80|29|R
Trevoh Chalobah|T. Chalobah|CB|26|Angliya|80|23|R
Tosin Adarabioyo|T. Adarabioyo|CB|28|Angliya|77|4|R
Jorrel Hato|J. Hato|LB|19|Niderlandiya|77|21|L
Benoît Badiashile|B. Badiashile|CB|24|Fransiya|77|5|L
Reece James|R. James|RB|26|Angliya|84|24|R
Malo Gusto|M. Gusto|RB|22|Fransiya|79|27|R
Marc Cucurella|M. Cucurella|LB|27|Ispaniya|82|3|L
Moisés Caicedo|M. Caicedo|DMF|24|Ekvador|87|25|R
Enzo Fernández|E. Fernández|CMF|24|Argentina|85|8|R
Roméo Lavia|R. Lavia|DMF|22|Belgiya|78|45|R
Andrey Santos|A. Santos|CMF|21|Braziliya|76|17|R
Cole Palmer|C. Palmer|AMF|23|Angliya|88|10|L
Pedro Neto|P. Neto|RWF|25|Portugaliya|82|7|L
Estêvão|Estêvão|RWF|18|Braziliya|80|41|L
Jamie Gittens|J. Gittens|LWF|21|Angliya|78|11|R
Alejandro Garnacho|A. Garnacho|LWF|21|Argentina|79|49|R
João Pedro|J. Pedro|CF|24|Braziliya|83|20|R
Liam Delap|L. Delap|CF|22|Angliya|78|9|R
'''),
    'epl_cry': dict(
        name='Crystal Palace', short='CRY', city='London', nickname='The Eagles', founded=1905, rep=76,
        stadium='Selhurst Park', capacity=25486, budget=55, colors=(0xFF1B458F, 0xFFC4122E, 0xFFFFFFFF),
        crest=dict(shape='oval', pattern='halves', primaryColor=0xFF1B458F, secondaryColor=0xFFC4122E,
                   trimColor=0xFFFFFFFF, monogram='CPFC', emblem='bird'),
        tactics=('f343', 'quickCounter', 3, 3),
        squad='''
Dean Henderson|D. Henderson|GK|28|Angliya|80|1|R
Walter Benítez|W. Benítez|GK|32|Argentina|76|44|R
Remi Matthews|R. Matthews|GK|31|Angliya|62|31|R
Marc Guéhi|M. Guéhi|CB|25|Angliya|84|6|R
Maxence Lacroix|M. Lacroix|CB|25|Fransiya|80|5|R
Chris Richards|C. Richards|CB|25|AQSH|76|26|R
Jaydee Canvot|J. Canvot|CB|19|Fransiya|70|23|R
Chadi Riad|C. Riad|CB|22|Marokash|72|34|R
Daniel Muñoz|D. Muñoz|RB|29|Kolumbiya|81|2|R
Tyrick Mitchell|T. Mitchell|LB|26|Angliya|78|3|L
Borna Sosa|B. Sosa|LB|27|Xorvatiya|73|24|L
Nathaniel Clyne|N. Clyne|RB|34|Angliya|70|17|R
Adam Wharton|A. Wharton|CMF|21|Angliya|80|20|L
Jefferson Lerma|J. Lerma|DMF|30|Kolumbiya|77|8|R
Daichi Kamada|D. Kamada|CMF|29|Yaponiya|77|18|R
Will Hughes|W. Hughes|CMF|30|Angliya|74|19|L
Cheick Doucouré|C. Doucouré|DMF|25|Mali|74|28|R
Yéremy Pino|Y. Pino|RWF|23|Ispaniya|78|10|R
Ismaïla Sarr|I. Sarr|RWF|27|Senegal|79|7|R
Justin Devenny|J. Devenny|AMF|22|Shimoliy Irlandiya|71|55|R
Romain Esse|R. Esse|LWF|20|Angliya|71|11|L
Jean-Philippe Mateta|J. Mateta|CF|28|Fransiya|81|14|R
Eddie Nketiah|E. Nketiah|CF|26|Angliya|74|9|R
'''),
    'epl_eve': dict(
        name='Everton', short='EVE', city='Liverpool', nickname='The Toffees', founded=1878, rep=78,
        stadium='Hill Dickinson Stadium', capacity=52888, budget=60, colors=(0xFF003399, 0xFFFFFFFF, 0xFFF0C800),
        crest=dict(shape='shield', pattern='solid', primaryColor=0xFF003399, secondaryColor=0xFFFFFFFF,
                   trimColor=0xFFFFFFFF, monogram='EFC', emblem='tower'),
        tactics=('f4231', 'longBallCounter', 3, 3),
        squad='''
Jordan Pickford|J. Pickford|GK|32|Angliya|83|1|L
Mark Travers|M. Travers|GK|26|Irlandiya|70|12|R
Tom King|T. King|GK|31|Uels|63|31|R
James Tarkowski|J. Tarkowski|CB|33|Angliya|79|6|R
Jarrad Branthwaite|J. Branthwaite|CB|23|Angliya|80|32|L
Michael Keane|M. Keane|CB|33|Angliya|75|5|R
Jake O'Brien|J. O'Brien|CB|24|Irlandiya|74|15|R
Séamus Coleman|S. Coleman|RB|37|Irlandiya|70|23|R
Nathan Patterson|N. Patterson|RB|24|Shotlandiya|72|2|R
Vitalii Mykolenko|V. Mykolenko|LB|26|Ukraina|76|16|L
Adam Aznou|A. Aznou|LB|19|Marokash|68|19|L
Idrissa Gueye|I. Gueye|DMF|36|Senegal|76|27|R
James Garner|J. Garner|CMF|24|Angliya|77|37|R
Tim Iroegbunam|T. Iroegbunam|DMF|22|Angliya|72|42|R
Merlin Röhl|M. Röhl|CMF|23|Germaniya|71|34|R
Carlos Alcaraz|C. Alcaraz|AMF|23|Argentina|73|24|R
Kiernan Dewsbury-Hall|K. Dewsbury-Hall|CMF|27|Angliya|77|22|R
Jack Grealish|J. Grealish|LWF|30|Angliya|80|18|R
Iliman Ndiaye|I. Ndiaye|LWF|25|Senegal|79|10|R
Dwight McNeil|D. McNeil|LMF|26|Angliya|76|7|L
Tyler Dibling|T. Dibling|RWF|19|Angliya|74|20|L
Thierno Barry|T. Barry|CF|23|Fransiya|75|11|R
Beto|Beto|CF|27|Portugaliya|74|9|R
'''),
    'epl_ful': dict(
        name='Fulham', short='FUL', city='London', nickname='The Cottagers', founded=1879, rep=74,
        stadium='Craven Cottage', capacity=29600, budget=45, colors=(0xFFFFFFFF, 0xFF000000, 0xFFCC0000),
        crest=dict(shape='shield', pattern='hoops', primaryColor=0xFFFFFFFF, secondaryColor=0xFF000000,
                   trimColor=0xFF000000, monogram='FFC'),
        tactics=('f4231', 'possession', 3, 3),
        squad='''
Bernd Leno|B. Leno|GK|33|Germaniya|81|1|R
Benjamin Lecomte|B. Lecomte|GK|35|Fransiya|69|23|R
Steven Benda|S. Benda|GK|27|Germaniya|65|17|R
Joachim Andersen|J. Andersen|CB|29|Daniya|79|5|R
Calvin Bassey|C. Bassey|CB|26|Nigeriya|77|3|L
Issa Diop|I. Diop|CB|28|Fransiya|74|31|R
Jorge Cuenca|J. Cuenca|CB|26|Ispaniya|72|15|L
Kenny Tete|K. Tete|RB|30|Niderlandiya|75|2|R
Timothy Castagne|T. Castagne|RB|30|Belgiya|75|21|R
Antonee Robinson|A. Robinson|LB|28|AQSH|80|33|L
Ryan Sessegnon|R. Sessegnon|LB|25|Angliya|72|30|L
Sander Berge|S. Berge|DMF|27|Norvegiya|77|16|R
Saša Lukić|S. Lukić|CMF|29|Serbiya|75|20|R
Harrison Reed|H. Reed|DMF|30|Angliya|73|6|R
Tom Cairney|T. Cairney|CMF|34|Shotlandiya|72|10|L
Andreas Pereira|A. Pereira|AMF|29|Braziliya|77|18|R
Emile Smith Rowe|E. Smith Rowe|AMF|25|Angliya|77|32|R
Alex Iwobi|A. Iwobi|LWF|29|Nigeriya|78|17|R
Harry Wilson|H. Wilson|RWF|28|Uels|77|8|L
Samuel Chukwueze|S. Chukwueze|RWF|26|Nigeriya|76|11|L
Adama Traoré|A. Traoré|RWF|29|Ispaniya|74|7|R
Raúl Jiménez|R. Jiménez|CF|34|Meksika|76|7|R
Rodrigo Muniz|R. Muniz|CF|24|Braziliya|76|9|R
'''),
    'epl_lee': dict(
        name='Leeds United', short='LEE', city='Leeds', nickname='The Whites', founded=1919, rep=72,
        stadium='Elland Road', capacity=37608, budget=45, colors=(0xFFFFFFFF, 0xFF1D428A, 0xFFFFCD00),
        crest=dict(shape='circle', pattern='chevron', primaryColor=0xFFFFFFFF, secondaryColor=0xFF1D428A,
                   trimColor=0xFFFFCD00, monogram='LUFC'),
        tactics=('f4231', 'highPressing', 4, 4),
        squad='''
Lucas Perri|L. Perri|GK|28|Braziliya|76|1|R
Karl Darlow|K. Darlow|GK|35|Uels|69|26|R
Illan Meslier|I. Meslier|GK|25|Fransiya|72|16|L
Pascal Struijk|P. Struijk|CB|26|Niderlandiya|75|5|L
Joe Rodon|J. Rodon|CB|28|Uels|75|6|R
Jaka Bijol|J. Bijol|CB|26|Sloveniya|77|15|R
Sebastiaan Bornauw|S. Bornauw|CB|26|Belgiya|71|23|R
Jayden Bogle|J. Bogle|RB|25|Angliya|74|2|R
James Justin|J. Justin|RB|27|Angliya|73|24|R
Gabriel Gudmundsson|G. Gudmundsson|LB|26|Shvetsiya|73|3|L
Sam Byram|S. Byram|LB|32|Angliya|69|25|R
Ethan Ampadu|E. Ampadu|DMF|25|Uels|76|4|R
Anton Stach|A. Stach|CMF|27|Germaniya|76|18|R
Ilia Gruev|I. Gruev|DMF|25|Bosniya|72|44|R
Sean Longstaff|S. Longstaff|CMF|28|Angliya|73|8|R
Ao Tanaka|A. Tanaka|CMF|27|Yaponiya|74|22|R
Brenden Aaronson|B. Aaronson|AMF|25|AQSH|74|11|R
Noah Okafor|N. Okafor|LWF|25|Shveysariya|75|19|R
Daniel James|D. James|RWF|28|Uels|74|7|L
Willy Gnonto|W. Gnonto|LWF|22|Italiya|72|29|R
Jack Harrison|J. Harrison|LWF|29|Angliya|72|20|R
Dominic Calvert-Lewin|D. Calvert-Lewin|CF|28|Angliya|75|9|R
Lukas Nmecha|L. Nmecha|CF|27|Germaniya|72|14|R
'''),
    'epl_liv': dict(
        name='Liverpool', short='LIV', city='Liverpool', nickname='The Reds', founded=1892, rep=93,
        stadium='Anfield', capacity=61276, budget=150, colors=(0xFFC8102E, 0xFF00B2A9, 0xFFF6EB61),
        crest=dict(shape='heater', pattern='solid', primaryColor=0xFFC8102E, secondaryColor=0xFF00B2A9,
                   trimColor=0xFFF6EB61, monogram='LFC', emblem='bird'),
        tactics=('f4231', 'highPressing', 4, 5),
        squad='''
Alisson Becker|Alisson|GK|33|Braziliya|88|1|R
Giorgi Mamardashvili|G. Mamardashvili|GK|25|Gruziya|81|25|R
Freddie Woodman|F. Woodman|GK|28|Angliya|64|28|R
Virgil van Dijk|V. van Dijk|CB|34|Niderlandiya|89|4|R
Ibrahima Konaté|I. Konaté|CB|26|Fransiya|84|5|R
Joe Gomez|J. Gomez|CB|28|Angliya|79|2|R
Giovanni Leoni|G. Leoni|CB|19|Italiya|72|15|R
Jeremie Frimpong|J. Frimpong|RB|24|Niderlandiya|82|30|R
Conor Bradley|C. Bradley|RB|22|Shimoliy Irlandiya|78|12|R
Milos Kerkez|M. Kerkez|LB|22|Vengriya|81|6|L
Andrew Robertson|A. Robertson|LB|31|Shotlandiya|81|26|L
Ryan Gravenberch|R. Gravenberch|DMF|23|Niderlandiya|86|38|R
Alexis Mac Allister|A. Mac Allister|CMF|26|Argentina|86|10|R
Dominik Szoboszlai|D. Szoboszlai|CMF|25|Vengriya|85|8|R
Curtis Jones|C. Jones|CMF|24|Angliya|79|17|R
Wataru Endō|W. Endō|DMF|32|Yaponiya|76|3|R
Florian Wirtz|F. Wirtz|AMF|22|Germaniya|88|7|R
Mohamed Salah|M. Salah|RWF|33|Misr|89|11|L
Cody Gakpo|C. Gakpo|LWF|26|Niderlandiya|83|18|R
Federico Chiesa|F. Chiesa|RWF|28|Italiya|77|14|R
Rio Ngumoha|R. Ngumoha|LWF|17|Angliya|70|73|L
Alexander Isak|A. Isak|CF|26|Shvetsiya|88|9|R
Hugo Ekitiké|H. Ekitiké|CF|23|Fransiya|84|22|R
'''),
    'epl_mci': dict(
        name='Manchester City', short='MCI', city='Manchester', nickname='The Citizens', founded=1880, rep=94,
        stadium='Etihad Stadium', capacity=53400, budget=160, colors=(0xFF6CABDD, 0xFF1C2C5B, 0xFFF4C430),
        crest=dict(shape='roundel', pattern='solid', primaryColor=0xFF6CABDD, secondaryColor=0xFF1C2C5B,
                   trimColor=0xFFF4C430, monogram='MC', emblem='ship', ringText='MANCHESTER CITY',
                   ringColor=0xFF1C2C5B),
        tactics=('f4231', 'possession', 4, 4),
        squad='''
Gianluigi Donnarumma|G. Donnarumma|GK|26|Italiya|88|25|R
James Trafford|J. Trafford|GK|23|Angliya|78|1|L
Stefan Ortega|S. Ortega|GK|33|Germaniya|78|18|R
Rúben Dias|R. Dias|CB|28|Portugaliya|87|3|R
Joško Gvardiol|J. Gvardiol|CB|23|Xorvatiya|86|24|L
John Stones|J. Stones|CB|31|Angliya|82|5|R
Abdukodir Khusanov|A. Khusanov|CB|21|O‘zbekiston|78|45|R
Nathan Aké|N. Aké|CB|30|Niderlandiya|81|6|L
Matheus Nunes|M. Nunes|RB|27|Portugaliya|80|27|R
Rico Lewis|R. Lewis|RB|21|Angliya|78|82|R
Rayan Aït-Nouri|R. Aït-Nouri|LB|24|Jazoir|81|21|L
Rodri|Rodri|DMF|29|Ispaniya|89|16|R
Tijjani Reijnders|T. Reijnders|CMF|27|Niderlandiya|85|4|R
Bernardo Silva|B. Silva|CMF|31|Portugaliya|85|20|L
Mateo Kovačić|M. Kovačić|CMF|31|Xorvatiya|81|8|R
Nico González|N. González|DMF|23|Ispaniya|79|14|R
Rayan Cherki|R. Cherki|AMF|22|Fransiya|82|10|R
Phil Foden|P. Foden|AMF|25|Angliya|86|47|L
Jérémy Doku|J. Doku|LWF|23|Belgiya|83|11|R
Savinho|Savinho|RWF|21|Braziliya|80|26|L
Oscar Bobb|O. Bobb|RWF|22|Norvegiya|74|52|L
Erling Haaland|E. Haaland|CF|25|Norvegiya|91|9|L
Omar Marmoush|O. Marmoush|CF|26|Misr|83|7|R
'''),
    'epl_mun': dict(
        name='Manchester United', short='MUN', city='Manchester', nickname='The Red Devils', founded=1878, rep=90,
        stadium='Old Trafford', capacity=74310, budget=120, colors=(0xFFDA291C, 0xFFFBE122, 0xFF000000),
        crest=dict(shape='shield', pattern='solid', primaryColor=0xFFDA291C, secondaryColor=0xFFFBE122,
                   trimColor=0xFFFBE122, monogram='MU', emblem='trident'),
        tactics=('f343', 'quickCounter', 3, 4),
        squad='''
Senne Lammens|S. Lammens|GK|23|Belgiya|78|31|R
André Onana|A. Onana|GK|29|Kamerun|79|24|R
Altay Bayındır|A. Bayındır|GK|27|Turkiya|74|1|R
Matthijs de Ligt|M. de Ligt|CB|26|Niderlandiya|82|4|R
Leny Yoro|L. Yoro|CB|20|Fransiya|79|15|R
Lisandro Martínez|L. Martínez|CB|27|Argentina|82|6|L
Harry Maguire|H. Maguire|CB|32|Angliya|77|5|R
Ayden Heaven|A. Heaven|CB|19|Angliya|71|26|L
Noussair Mazraoui|N. Mazraoui|RB|28|Marokash|79|3|R
Diogo Dalot|D. Dalot|RB|26|Portugaliya|79|2|R
Luke Shaw|L. Shaw|LB|30|Angliya|78|23|L
Patrick Dorgu|P. Dorgu|LB|21|Daniya|76|13|L
Bruno Fernandes|B. Fernandes|AMF|31|Portugaliya|86|8|R
Casemiro|Casemiro|DMF|33|Braziliya|79|18|R
Manuel Ugarte|M. Ugarte|DMF|24|Urugvay|78|25|R
Kobbie Mainoo|K. Mainoo|CMF|20|Angliya|79|37|R
Mason Mount|M. Mount|AMF|26|Angliya|77|7|R
Bryan Mbeumo|B. Mbeumo|RWF|26|Kamerun|83|19|L
Matheus Cunha|M. Cunha|AMF|26|Braziliya|83|10|R
Amad Diallo|Amad|RWF|23|Kot-d’Ivuar|80|16|L
Benjamin Šeško|B. Šeško|CF|22|Sloveniya|80|30|R
Joshua Zirkzee|J. Zirkzee|CF|24|Niderlandiya|75|11|L
Chido Obi|C. Obi|CF|18|Daniya|67|32|R
'''),
    'epl_new': dict(
        name='Newcastle United', short='NEW', city='Newcastle', nickname='The Magpies', founded=1892, rep=86,
        stadium="St James' Park", capacity=52305, budget=110, colors=(0xFF241F20, 0xFFFFFFFF, 0xFF41B6E6),
        crest=dict(shape='roundel', pattern='verticalStripes', primaryColor=0xFFFFFFFF, secondaryColor=0xFF241F20,
                   trimColor=0xFF41B6E6, monogram='NUFC', emblem='tower', ringText='NEWCASTLE UNITED',
                   ringColor=0xFF241F20),
        tactics=('f433', 'highPressing', 4, 4),
        squad='''
Nick Pope|N. Pope|GK|33|Angliya|82|22|R
Aaron Ramsdale|A. Ramsdale|GK|27|Angliya|78|32|R
John Ruddy|J. Ruddy|GK|38|Angliya|62|26|R
Sven Botman|S. Botman|CB|25|Niderlandiya|81|4|L
Fabian Schär|F. Schär|CB|33|Shveysariya|79|5|R
Dan Burn|D. Burn|CB|33|Angliya|78|33|L
Malick Thiaw|M. Thiaw|CB|24|Germaniya|79|12|R
Jamaal Lascelles|J. Lascelles|CB|32|Angliya|72|6|R
Kieran Trippier|K. Trippier|RB|35|Angliya|77|2|R
Tino Livramento|T. Livramento|RB|23|Angliya|80|21|R
Lewis Hall|L. Hall|LB|21|Angliya|78|3|L
Bruno Guimarães|B. Guimarães|CMF|27|Braziliya|86|39|R
Sandro Tonali|S. Tonali|DMF|25|Italiya|84|8|R
Joelinton|Joelinton|CMF|29|Braziliya|81|7|R
Jacob Ramsey|J. Ramsey|CMF|24|Angliya|77|41|R
Joe Willock|J. Willock|CMF|26|Angliya|75|28|R
Lewis Miley|L. Miley|CMF|19|Angliya|73|67|R
Anthony Gordon|A. Gordon|LWF|24|Angliya|83|10|R
Harvey Barnes|H. Barnes|LWF|28|Angliya|78|11|R
Jacob Murphy|J. Murphy|RWF|30|Angliya|77|23|R
Anthony Elanga|A. Elanga|RWF|23|Shvetsiya|79|20|R
Nick Woltemade|N. Woltemade|CF|23|Germaniya|81|27|R
Yoane Wissa|Y. Wissa|CF|29|KDR|80|9|R
'''),
    'epl_nfo': dict(
        name='Nottingham Forest', short='NFO', city='Nottingham', nickname='Forest', founded=1865, rep=76,
        stadium='City Ground', capacity=30404, budget=60, colors=(0xFFDD0000, 0xFFFFFFFF, 0xFFFFFFFF),
        crest=dict(shape='circle', pattern='solid', primaryColor=0xFFDD0000, secondaryColor=0xFFFFFFFF,
                   trimColor=0xFFFFFFFF, monogram='NFFC', stars=2, emblem='tree'),
        tactics=('f4231', 'quickCounter', 3, 3),
        squad='''
Matz Sels|M. Sels|GK|33|Belgiya|80|26|R
John Victor|J. Victor|GK|29|Braziliya|73|13|R
Angus Gunn|A. Gunn|GK|29|Shotlandiya|70|1|R
Murillo|Murillo|CB|23|Braziliya|81|5|L
Nikola Milenković|N. Milenković|CB|28|Serbiya|81|31|R
Morato|Morato|CB|24|Braziliya|74|4|L
Willy Boly|W. Boly|CB|34|Kot-d’Ivuar|71|30|R
Neco Williams|N. Williams|RB|24|Uels|78|3|R
Ola Aina|O. Aina|RB|29|Nigeriya|77|34|R
Oleksandr Zinchenko|O. Zinchenko|LB|28|Ukraina|76|35|L
Nicolò Savona|N. Savona|RB|22|Italiya|73|37|R
Elliot Anderson|E. Anderson|CMF|23|Angliya|82|8|R
Ibrahim Sangaré|I. Sangaré|DMF|28|Kot-d’Ivuar|77|6|R
Nicolás Domínguez|N. Domínguez|CMF|27|Argentina|75|16|R
Douglas Luiz|D. Luiz|CMF|27|Braziliya|78|12|R
James McAtee|J. McAtee|AMF|23|Angliya|75|24|L
Morgan Gibbs-White|M. Gibbs-White|AMF|25|Angliya|83|10|R
Callum Hudson-Odoi|C. Hudson-Odoi|LWF|25|Angliya|77|7|R
Dan Ndoye|D. Ndoye|RWF|25|Shveysariya|78|14|R
Omari Hutchinson|O. Hutchinson|RWF|22|Yamayka|76|21|L
Arnaud Kalimuendo|A. Kalimuendo|CF|23|Fransiya|76|15|R
Chris Wood|C. Wood|CF|34|Avstraliya|79|11|R
Taiwo Awoniyi|T. Awoniyi|CF|28|Nigeriya|72|9|R
'''),
    'epl_sun': dict(
        name='Sunderland', short='SUN', city='Sunderland', nickname='The Black Cats', founded=1879, rep=68,
        stadium='Stadium of Light', capacity=49000, budget=50, colors=(0xFFEB172B, 0xFFFFFFFF, 0xFF000000),
        crest=dict(shape='shield', pattern='verticalStripes', primaryColor=0xFFEB172B, secondaryColor=0xFFFFFFFF,
                   trimColor=0xFF000000, monogram='SAFC', emblem='lion'),
        tactics=('f4231', 'longBallCounter', 3, 3),
        squad='''
Robin Roefs|R. Roefs|GK|22|Niderlandiya|74|22|R
Anthony Patterson|A. Patterson|GK|25|Angliya|70|1|R
Simon Moore|S. Moore|GK|35|Angliya|62|21|R
Omar Alderete|O. Alderete|CB|28|Paragvay|74|15|L
Daniel Ballard|D. Ballard|CB|26|Shimoliy Irlandiya|73|5|R
Nordi Mukiele|N. Mukiele|CB|27|Fransiya|75|20|R
Luke O'Nien|L. O'Nien|CB|30|Angliya|69|13|R
Dennis Cirkin|D. Cirkin|LB|23|Angliya|69|3|L
Reinildo Mandava|Reinildo|LB|31|Gvineya|74|17|L
Trai Hume|T. Hume|RB|23|Shimoliy Irlandiya|72|32|R
Arthur Masuaku|A. Masuaku|LB|31|KDR|71|26|L
Granit Xhaka|G. Xhaka|CMF|33|Shveysariya|80|34|L
Noah Sadiki|N. Sadiki|DMF|20|KDR|72|27|R
Habib Diarra|H. Diarra|CMF|21|Senegal|73|19|R
Enzo Le Fée|E. Le Fée|AMF|25|Fransiya|74|28|L
Dan Neil|D. Neil|CMF|23|Angliya|71|24|R
Chris Rigg|C. Rigg|AMF|18|Angliya|70|11|R
Chemsdine Talbi|C. Talbi|RWF|20|Marokash|71|7|L
Simon Adingra|S. Adingra|LWF|23|Kot-d’Ivuar|74|24|R
Bertrand Traoré|B. Traoré|RWF|30|Burkina-Faso|72|25|L
Wilson Isidor|W. Isidor|CF|25|Fransiya|74|18|R
Eliezer Mayenda|E. Mayenda|CF|20|Ispaniya|69|12|R
Brian Brobbey|B. Brobbey|CF|23|Niderlandiya|73|9|R
'''),
    'epl_tot': dict(
        name='Tottenham Hotspur', short='TOT', city='London', nickname='Spurs', founded=1882, rep=87,
        stadium='Tottenham Hotspur Stadium', capacity=62850, budget=110, colors=(0xFFFFFFFF, 0xFF132257, 0xFF132257),
        crest=dict(shape='oval', pattern='solid', primaryColor=0xFFFFFFFF, secondaryColor=0xFF132257,
                   trimColor=0xFF132257, monogram='THFC', emblem='bird'),
        tactics=('f433', 'highPressing', 4, 4),
        squad='''
Guglielmo Vicario|G. Vicario|GK|29|Italiya|82|1|R
Antonín Kinský|A. Kinský|GK|22|Chexiya|72|31|R
Brandon Austin|B. Austin|GK|26|Angliya|62|40|R
Cristian Romero|C. Romero|CB|27|Argentina|85|17|R
Micky van de Ven|M. van de Ven|CB|24|Niderlandiya|84|37|L
Radu Drăgușin|R. Drăgușin|CB|23|Gretsiya|75|6|R
Kevin Danso|K. Danso|CB|27|Avstriya|76|4|R
Pedro Porro|P. Porro|RB|26|Ispaniya|82|23|R
Djed Spence|D. Spence|RB|25|Angliya|76|24|R
Destiny Udogie|D. Udogie|LB|23|Italiya|79|13|L
Ben Davies|B. Davies|LB|32|Uels|73|33|L
João Palhinha|J. Palhinha|DMF|30|Portugaliya|82|6|R
Rodrigo Bentancur|R. Bentancur|CMF|28|Urugvay|79|30|R
Pape Matar Sarr|P. Sarr|CMF|23|Senegal|79|29|R
Yves Bissouma|Y. Bissouma|DMF|29|Mali|76|8|R
Archie Gray|A. Gray|CMF|19|Angliya|75|14|R
Lucas Bergvall|L. Bergvall|CMF|19|Shvetsiya|76|15|R
Xavi Simons|X. Simons|AMF|22|Niderlandiya|83|7|R
James Maddison|J. Maddison|AMF|29|Angliya|81|10|R
Mohammed Kudus|M. Kudus|RWF|25|Gana|82|20|L
Brennan Johnson|B. Johnson|RWF|24|Uels|79|22|R
Mathys Tel|M. Tel|LWF|20|Fransiya|76|11|R
Richarlison|Richarlison|CF|28|Braziliya|77|9|R
'''),
    'epl_whu': dict(
        name='West Ham United', short='WHU', city='London', nickname='The Hammers', founded=1895, rep=78,
        stadium='London Stadium', capacity=62500, budget=55, colors=(0xFF7A263A, 0xFF1BB1E7, 0xFFF3D459),
        crest=dict(shape='shield', pattern='solid', primaryColor=0xFF7A263A, secondaryColor=0xFF1BB1E7,
                   trimColor=0xFFF3D459, monogram='WHU', emblem='hammers'),
        tactics=('f4231', 'quickCounter', 3, 3),
        squad='''
Alphonse Areola|A. Areola|GK|32|Fransiya|79|23|R
Mads Hermansen|M. Hermansen|GK|25|Daniya|76|1|R
Łukasz Fabiański|Ł. Fabiański|GK|40|Polsha|70|22|R
Max Kilman|M. Kilman|CB|28|Angliya|78|3|L
Jean-Clair Todibo|J. Todibo|CB|25|Fransiya|77|25|R
Konstantinos Mavropanos|K. Mavropanos|CB|27|Gretsiya|76|15|R
Igor Julio|I. Julio|CB|27|Braziliya|73|26|L
Aaron Wan-Bissaka|A. Wan-Bissaka|RB|27|KDR|78|29|R
Kyle Walker-Peters|K. Walker-Peters|RB|28|Angliya|75|2|R
El Hadji Malick Diouf|M. Diouf|LB|20|Senegal|74|12|L
Ollie Scarles|O. Scarles|LB|20|Angliya|68|30|L
Tomáš Souček|T. Souček|CMF|30|Chexiya|77|28|R
Mateus Fernandes|M. Fernandes|CMF|21|Portugaliya|75|18|R
Edson Álvarez|E. Álvarez|DMF|28|Meksika|77|19|R
Guido Rodríguez|G. Rodríguez|DMF|31|Argentina|74|24|R
Freddie Potts|F. Potts|CMF|22|Angliya|68|32|R
Lucas Paquetá|L. Paquetá|AMF|28|Braziliya|81|10|L
Jarrod Bowen|J. Bowen|RWF|28|Angliya|82|20|L
Crysencio Summerville|C. Summerville|LWF|24|Niderlandiya|76|7|R
Luis Guilherme|L. Guilherme|RWF|19|Braziliya|69|17|L
Niclas Füllkrug|N. Füllkrug|CF|32|Germaniya|76|11|R
Callum Wilson|C. Wilson|CF|33|Angliya|74|9|R
Callum Marshall|C. Marshall|CF|21|Shimoliy Irlandiya|68|21|R
'''),
    'epl_wol': dict(
        name='Wolverhampton Wanderers', short='WOL', city='Wolverhampton', nickname='Wolves', founded=1877, rep=72,
        stadium='Molineux Stadium', capacity=31750, budget=45, colors=(0xFFFDB913, 0xFF231F20, 0xFF231F20),
        crest=dict(shape='badge', pattern='solid', primaryColor=0xFFFDB913, secondaryColor=0xFF231F20,
                   trimColor=0xFF231F20, monogram='WWFC', emblem='wolf'),
        tactics=('f343', 'longBallCounter', 3, 3),
        squad='''
José Sá|J. Sá|GK|32|Portugaliya|79|1|R
Sam Johnstone|S. Johnstone|GK|32|Angliya|74|31|R
Dan Bentley|D. Bentley|GK|32|Angliya|66|25|R
Toti Gomes|Toti|CB|26|Portugaliya|76|24|L
Emmanuel Agbadou|E. Agbadou|CB|28|Kot-d’Ivuar|75|18|R
Santiago Bueno|S. Bueno|CB|27|Urugvay|73|4|R
Ladislav Krejčí|L. Krejčí|CB|26|Chexiya|74|37|L
Yerson Mosquera|Y. Mosquera|CB|24|Kolumbiya|73|14|R
Matt Doherty|M. Doherty|RB|33|Irlandiya|72|2|R
Jackson Tchatchoua|J. Tchatchoua|RB|24|Kamerun|73|38|R
Hugo Bueno|H. Bueno|LB|23|Ispaniya|72|3|L
David Møller Wolfe|D. Wolfe|LB|23|Norvegiya|72|5|L
André|André|DMF|24|Braziliya|77|7|R
João Gomes|J. Gomes|CMF|24|Braziliya|79|8|R
Jean-Ricner Bellegarde|J. Bellegarde|AMF|27|Gaiti|74|27|R
Marshall Munetsi|M. Munetsi|CMF|29|Zimbabve|74|5|R
Tommy Doyle|T. Doyle|CMF|24|Angliya|70|20|R
Rodrigo Gomes|R. Gomes|RWF|22|Portugaliya|72|11|R
Hee-chan Hwang|H. Hwang|LWF|29|Janubiy Koreya|74|11|R
Fer López|F. López|AMF|21|Ispaniya|72|17|R
Jørgen Strand Larsen|J. Strand Larsen|CF|25|Norvegiya|78|9|R
Tolu Arokodare|T. Arokodare|CF|25|Nigeriya|73|19|R
Sam Johnstone II|E. González|CF|19|Ispaniya|65|39|R
'''),
}


# ---------------------------------------------------------------- 2026.db
DB_CLUB = {
    'epl_ars': 'Arsenal', 'epl_avl': 'Aston Villa', 'epl_bou': 'Bournemouth', 'epl_bre': 'Brentford',
    'epl_bha': 'Brighton', 'epl_bur': 'Burnley', 'epl_che': 'Chelsea', 'epl_cry': 'Crystal Palace',
    'epl_eve': 'Everton', 'epl_ful': 'Fulham', 'epl_lee': 'Leeds United', 'epl_liv': 'Liverpool',
    'epl_mci': 'Man. City', 'epl_mun': 'Manchester United', 'epl_new': 'Newcastle United',
    'epl_nfo': 'Nottingham Forest', 'epl_sun': 'Sunderland', 'epl_tot': 'Tottenham',
    'epl_whu': 'West Ham United', 'epl_wol': 'Wolves',
}
BAD = chr(0xFFFD)  # accents lost in the database
COACH_FIX = {f'R{BAD}ben Amorim': 'Rúben Amorim', f'R{BAD}gis Le Bris': 'Régis Le Bris',
             f'Fabian H{BAD}rzeler': 'Fabian Hürzeler', f'Nuno Esp{BAD}rito Santo': 'Nuno Espírito Santo',
             f'V{BAD}tor Pereira': 'Vítor Pereira'}
# Database skill id -> (Uzbek label, attribute boosts)
SKILLS = {
    1: ('Ushlash', ['gkCatching']), 2: ('Refleks', ['gkReflexes']),
    3: ('Oldindan sezish', ['defensiveAwareness', 'attackingAwareness']),
    4: ('Havo o‘yini', ['heading', 'jumping']), 5: ('Joy tanlash', ['defensiveAwareness', 'gkAwareness']),
    6: ('Otbor', ['tackling']), 7: ('Qo‘riqlash', ['defensiveAwareness']),
    8: ('To‘p qaytaruvchi', ['defensiveEngagement']), 9: ('Zarba', ['finishing']),
    10: ('Bosh bilan o‘yin', ['heading']), 11: ('Kuch', ['physicalContact']),
    12: ('Gavdali', ['physicalContact', 'balance']), 13: ('Tezlik', ['speed']),
    14: ('Chaqqonlik', ['acceleration', 'balance']), 15: ('Ijodkorlik', ['lowPass', 'ballControl']),
    16: ('Paslar', ['lowPass', 'loftedPass']), 17: ('Chidamlilik', ['stamina']),
    18: ('Jarima zarbalari', ['setPieceTaking', 'curl']), 19: ('Dribling', ['dribbling']),
    20: ('Texnika', ['ballControl', 'tightPossession']), 21: ('Liderlik', []),
    22: ('Agressivlik', ['aggression']), 23: ('O‘yinni o‘qish', ['attackingAwareness']),
    24: ('To‘p nazorati', ['ballControl']), 25: ('Harakatchanlik', ['acceleration']),
}
DB_POS = {
    'Portero': 'GK', 'Defensa Central': 'CB', f'Defensa Central L{BAD}bero': 'CB',
    'Mediocampista Defensivo': 'DMF', 'Mediocampista Ofensivo': 'AMF', 'Mediocampista Central': 'CMF',
    'Centro Delantero': 'CF', 'Delantero Media Punta': 'SS',
}
DB_NAT = {
    'Inglaterra': 'Angliya', f'Espa{BAD}a': 'Ispaniya', 'Francia': 'Fransiya', 'Brasil': 'Braziliya',
    'Alemania': 'Germaniya', f'Pa{BAD}ses Bajos': 'Niderlandiya', f'B{BAD}lgica': 'Belgiya',
    'Argentina': 'Argentina', 'Portugal': 'Portugaliya', 'Escocia': 'Shotlandiya', 'Gales': 'Uels',
    'Irlanda': 'Irlandiya', 'Irlanda del Norte': 'Shimoliy Irlandiya', 'Noruega': 'Norvegiya',
    'Dinamarca': 'Daniya', 'Suecia': 'Shvetsiya', 'Italia': 'Italiya', 'Ghana': 'Gana',
    'Nigeria': 'Nigeriya', 'Senegal': 'Senegal', 'Jamaica': 'Yamayka', 'Estados Unidos': 'AQSH',
    'Colombia': 'Kolumbiya', 'Ecuador': 'Ekvador', 'Uruguay': 'Urugvay', 'Marruecos': 'Marokash',
    'Costa de Marfil': 'Kot-d’Ivuar', f'Camer{BAD}n': 'Kamerun', 'Australia': 'Avstraliya',
}


def norm(text):
    import unicodedata
    for a, b in (('ø', 'o'), ('Ø', 'O'), ('ł', 'l'), ('đ', 'd'), ('æ', 'ae'), ('ß', 'ss'), ('ı', 'i')):
        text = text.replace(a, b)
    t = unicodedata.normalize('NFKD', text)
    return ''.join(ch for ch in t if ch.isalpha() or ch == BAD).lower()


def _same(a, b):
    return len(a) == len(b) and all(x == y or x == BAD for x, y in zip(a, b))


def matches(db_name, name, short, loose=False):
    """Database names lose accents (U+FFFD); compare letter by letter.
    [loose] (same club only) also accepts a surname or nickname match, so
    "Benjamin White" finds "Ben White" and "John" finds "John Victor"."""
    a = norm(db_name)
    if loose:
        mine = name.split()
        tokens = [norm(t) for t in mine + short.replace('.', ' ').split()]
        parts = db_name.split()
        if len(parts) == 1 and any(_same(a, t) for t in tokens if len(t) > 2):
            return True
        last = norm(parts[-1])
        if len(last) > 3 and _same(last, norm(mine[-1])):
            return True
    for cand in (name, short, name.split()[-1], short.split()[-1]):
        if _same(a, norm(cand)):
            return True
    parts = db_name.split()
    if len(parts) == 1:
        return False
    full = norm(name)
    if len(a) >= 8 and len(full) > len(a) and _same(a, full[-len(a):]):
        return True  # "Smith Rowe" vs "Emile Smith Rowe"
    last, first = norm(parts[-1]), norm(parts[0])
    mine = name.split()
    return (len(last) > 3 and _same(last, norm(mine[-1]))
            and _same(first, norm(mine[0])))


def fix_coach(name):
    for k, v in COACH_FIX.items():
        if _same(norm(name), norm(k)) or _same(norm(k), norm(name)):
            return v
    return name


def load_db(path):
    import sqlite3
    if not Path(path).exists():
        return None
    c = sqlite3.connect(f'file:{path}?mode=ro', uri=True)
    c.text_factory = lambda b: b.decode('utf-8', 'replace')
    out = {}
    for cid, dbname in DB_CLUB.items():
        row = c.execute('select equid, equi_entid from eq_equipos where equi_nombre=? and equi_paid=185',
                        (dbname,)).fetchone()
        if not row:
            continue
        coach = c.execute('select en_nombre from eq_entrenadores where entid=?', (row[1],)).fetchone()
        players = c.execute(
            """select j.jug_nombre, j.jug_edad, j.jug_estatura, j.jug_poder, p.pos_nombre, j.jug_numero,
                      j.jug_perfil, n.nombre, j.jug_habilidad_A, j.jug_habilidad_B
               from jug_jugadores j join eq_equipos_jugadores e on e.eqju_jugid=j.jugid
               join jug_posiciones p on p.posid=j.jug_posid join paises n on n.paid=j.jug_paid
               where e.eqju_equid=? order by j.jug_poder desc""", (row[0],)).fetchall()
        name = coach[0] if coach else ''
        out[cid] = {'coach': fix_coach(name), 'players': players}
    return out


def wage_for(ovr, rep):
    base = max(15000, int(((ovr - 58) ** 2.2) * 180))
    return int(base * (0.6 + rep / 200) / 1000) * 1000


def main():
    rnd = random.Random(2026)
    db = load_db(sys.argv[1] if len(sys.argv) > 1 else
                 str(Path.home() / 'Downloads' / 'Telegram Desktop' / '2026.db'))
    print('database', 'found' if db else 'not found (hand-written squads only)')
    players, clubs = [], []
    squads = {}
    for cid, c in CLUBS.items():
        rows = [r.split('|') for r in c['squad'].strip().splitlines()]
        assert len(rows) == 23, (cid, len(rows))
        squads[cid] = rows
    moved = []
    for cid in CLUBS:
        for dbr in (db or {}).get(cid, {'players': []})['players']:
            if any(matches(dbr[0], r[0], r[1], loose=True) for r in squads[cid]):
                continue
            for other, rows in squads.items():
                if other == cid:
                    continue
                hit = next((r for r in rows if matches(dbr[0], r[0], r[1])), None)
                if hit and len(squads[cid]) < 28 and len(rows) > 20:
                    rows.remove(hit)
                    squads[cid].append(hit)
                    moved.append(f'{hit[0]}: {other} -> {cid}')
                    break
    print('moved by database:', moved)
    for cid, c in CLUBS.items():
        rows = squads[cid]
        info = (db or {}).get(cid, {'coach': '', 'players': []})
        extra = []
        for dbr in info['players']:
            if any(matches(dbr[0], r[0], r[1], loose=True) for r in rows) or any(
                    matches(dbr[0], r[0], r[1]) for sq in squads.values() for r in sq):
                continue
            pos = DB_POS.get(dbr[4])
            if dbr[4] == 'Defensa Lateral':
                pos = 'LB' if dbr[6] == 'I' else 'RB'
            elif dbr[4] == 'Mediocampista Extremo':
                pos = 'LMF' if dbr[6] == 'I' else 'RMF'
            elif dbr[4] == 'Delantero Extremo':
                pos = 'RWF' if dbr[6] == 'I' else 'LWF'
            nat = DB_NAT.get(dbr[7])
            if pos and nat and BAD not in dbr[0] and dbr[3] >= 62 and len(rows) + len(extra) < 27:
                parts = dbr[0].split()
                short = dbr[0] if len(parts) == 1 else f"{parts[0][0]}. {' '.join(parts[1:])}"
                extra.append([dbr[0], short, pos, str(dbr[1]), nat, str(min(84, dbr[3] + 3)),
                              str(dbr[5]), 'L' if dbr[6] == 'I' else 'R'])
        rows = rows + extra
        ids, used = [], set()
        for name, short, pos, age, nat, ovr, num, foot in rows:
            if nat not in FLAGS:
                raise SystemExit(f'unknown nationality {nat}')
            key = ''.join(ch for ch in short.lower() if ch.isalnum())[:14] or name.lower()[:10]
            pid = f'{cid}_{key}'
            while pid in used:
                pid += 'x'
            used.add(pid)
            num = int(num)
            target, age = int(ovr), int(age)
            dbr = next((d for d in info['players'] if matches(d[0], name, short, loose=True)), None)
            stats = generate(pos, target, rnd)
            traits, height = [], None
            if dbr:
                height = dbr[2]
                for sid in (dbr[8], dbr[9]):
                    if sid in SKILLS:
                        label, keys = SKILLS[sid]
                        traits.append(label)
                        for k in keys:
                            stats[k] = min(99, stats[k] + 3)
                if height and pos != 'GK':
                    bonus = round((height - 182) / 4)
                    for k in ('heading', 'jumping'):
                        stats[k] = max(40, min(99, stats[k] + bonus))
            players.append({
                'id': pid, 'name': name, 'shortName': short, 'age': age, 'nationality': nat,
                'countryFlag': FLAGS[nat], 'number': num, 'mainPosition': pos, 'altPositions': [],
                'preferredFoot': 'left' if foot == 'L' else 'right', 'weakFoot': rnd.choice([2, 3, 3, 4]),
                'stats': stats,
                **({'height': height} if height else {}),
                **({'traits': traits} if traits else {}),
                'contract': {'contractYears': rnd.choice([1, 2, 3, 3, 4, 5]),
                             'weeklyWage': wage_for(target, c['rep']), 'releaseClause': 0},
                'marketValue': value(target, age),
            })
            ids.append(pid)
        # Starting XI = best player per slot of the default formation; rest bench/reserves.
        clubs.append({
            'id': cid, 'name': c['name'], 'shortName': c['short'],
            'primaryColor': c['colors'][0], 'secondaryColor': c['colors'][1], 'accentColor': c['colors'][2],
            'stadiumName': c['stadium'], 'stadiumCapacity': c['capacity'],
            'city': c['city'], 'nickname': c['nickname'], 'founded': c['founded'], 'reputation': c['rep'],
            'transferBudget': c['budget'] * 1000000,
            'wageBudget': 0,  # filled below
            'ticketPrice': 35 + c['rep'] // 2,
            'tactics': {'formation': c['tactics'][0], 'playstyle': c['tactics'][1],
                        'defensiveLine': c['tactics'][2], 'attackingIntensity': c['tactics'][3]},
            'crest': {'stars': 0, 'crown': False, 'emblem': 'monogram', **c['crest']},
            'managerName': info['coach'],
            'startingLineupIds': ids[:11], 'benchIds': ids[11:20], 'squadIds': ids,
        })
        wages = sum(p['contract']['weeklyWage'] for p in players if p['id'] in ids)
        clubs[-1]['wageBudget'] = int(wages * 1.2 / 100000) * 100000
    from epl_faces import apply as apply_faces
    apply_faces(players)
    (DATA / 'players_epl.json').write_text(
        json.dumps({'schemaVersion': 2, 'players': players}, ensure_ascii=False, indent=2) + '\n', encoding='utf8')
    (DATA / 'clubs_epl.json').write_text(
        json.dumps({'schemaVersion': 2, 'clubs': clubs}, ensure_ascii=False, indent=2) + '\n', encoding='utf8')
    print('clubs', len(clubs), 'players', len(players))


if __name__ == '__main__':
    main()
