import 'dart:convert';
import 'dart:math';
import 'package:flutter/foundation.dart';
import '../data/initial_database.dart';
import '../models/player.dart';
import 'zip_writer.dart';

/// Editable copy of the data files behind the /editor page. Works on the
/// raw JSON so exported files can be dropped straight into assets/data.
class DbEditor extends ChangeNotifier {
  /// League manifest entries open in the editor (id, name, clubsFile…).
  List<Map<String, dynamic>> leagues = [];

  /// Every manifest entry; world leagues join [leagues] once opened.
  List<Map<String, dynamic>> _manifestLeagues = [];
  List<Map<String, dynamic>> get closedLeagues => [for (final l in _manifestLeagues) if (!leagues.contains(l)) l];
  final Map<String, Map<String, dynamic>> _docs = {}; // file → document
  final Set<String> dirty = {};
  bool loaded = false;
  List<String> _shared = [];

  Future<void> load() async {
    final manifest = await InitialDatabase.readFile('league.json');
    _docs.clear();
    _docs['league.json'] = manifest;
    // The manifest's own league maps, so league edits land in league.json.
    _manifestLeagues = (manifest['leagues'] as List).cast<Map<String, dynamic>>();
    _shared = [manifest['templatesFile'] as String, manifest['namesFile'] as String];
    leagues = [];
    for (final l in _manifestLeagues) {
      // World leagues are big: they open on request (or when already edited).
      if (l['lazy'] == true && !InitialDatabase.overrides.containsKey(l['clubsFile'])) continue;
      await _open(l);
    }
    dirty.clear();
    loaded = true;
    notifyListeners();
  }

  Future<void> _open(Map<String, dynamic> l) async {
    for (final f in [l['clubsFile'] as String, l['playersFile'] as String]) {
      _docs[f] = await InitialDatabase.readFile(f);
    }
    leagues.add(l);
  }

  /// Opens a world league for editing.
  Future<void> openLeague(String id) async {
    final l = _manifestLeagues.firstWhere((l) => l['id'] == id);
    if (leagues.contains(l)) return;
    await _open(l);
    notifyListeners();
  }

  Map<String, dynamic> _league(String id) => leagues.firstWhere((l) => l['id'] == id);
  List<Map<String, dynamic>> _clubList(String leagueId) =>
      (_docs[_league(leagueId)['clubsFile']]!['clubs'] as List).cast<Map<String, dynamic>>();
  List<Map<String, dynamic>> _playerList(String leagueId) =>
      (_docs[_league(leagueId)['playersFile']]!['players'] as List).cast<Map<String, dynamic>>();

  void _touch(String leagueId, {bool clubs = false, bool players = false}) {
    final l = _league(leagueId);
    if (clubs) dirty.add(l['clubsFile']);
    if (players) dirty.add(l['playersFile']);
    notifyListeners();
  }

  List<Map<String, dynamic>> clubs(String leagueId) => _clubList(leagueId);

  String leagueOfClub(String clubId) =>
      leagues.firstWhere((l) => _clubList(l['id']).any((c) => c['id'] == clubId))['id'];

  Map<String, dynamic> club(String clubId) =>
      _clubList(leagueOfClub(clubId)).firstWhere((c) => c['id'] == clubId);

  /// Squad of a club in squad order.
  List<Map<String, dynamic>> squad(String clubId) {
    final leagueId = leagueOfClub(clubId);
    final byId = {for (final p in _playerList(leagueId)) p['id']: p};
    return [
      for (final id in (club(clubId)['squadIds'] as List))
        if (byId[id] != null) byId[id]!,
    ];
  }

  /// Every player, for search: (league, club, player).
  Iterable<(String, Map<String, dynamic>, Map<String, dynamic>)> allPlayers() sync* {
    for (final l in leagues) {
      final id = l['id'] as String;
      final byId = {for (final p in _playerList(id)) p['id']: p};
      for (final c in _clubList(id)) {
        for (final pid in (c['squadIds'] as List)) {
          final p = byId[pid];
          if (p != null) yield (id, c, p);
        }
      }
    }
  }

  void updatePlayer(String clubId, Map<String, dynamic> player) {
    final leagueId = leagueOfClub(clubId);
    final list = _playerList(leagueId);
    final i = list.indexWhere((p) => p['id'] == player['id']);
    if (i >= 0) list[i] = player;
    _touch(leagueId, players: true);
  }

  void updateClub(Map<String, dynamic> club) {
    final leagueId = leagueOfClub(club['id']);
    final list = _clubList(leagueId);
    final i = list.indexWhere((c) => c['id'] == club['id']);
    if (i >= 0) list[i] = club;
    _touch(leagueId, clubs: true);
  }

  /// A unique id in the data's style: club prefix + initial + surname.
  String newPlayerId(String clubId, String name) {
    final slug = name.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]+'), '');
    final base = '${clubId}_${slug.isEmpty ? 'player' : slug}';
    final taken = {for (final (_, _, p) in allPlayers()) p['id']};
    var id = base;
    for (var n = 2; taken.contains(id); n++) {
      id = '$base$n';
    }
    return id;
  }

  /// Adds [player] (its id is assigned here) to the club's squad.
  Map<String, dynamic> addPlayer(String clubId, Map<String, dynamic> player) {
    final leagueId = leagueOfClub(clubId);
    player['id'] = newPlayerId(clubId, '${player['name']}');
    _playerList(leagueId).add(player);
    (club(clubId)['squadIds'] as List).add(player['id']);
    _touch(leagueId, clubs: true, players: true);
    return player;
  }

  /// Why a player cannot leave [clubId] (null when he can).
  String? leaveBlocker(String clubId) =>
      (club(clubId)['squadIds'] as List).length <= 18 ? 'squad' : null;

  void _detach(String clubId, String playerId) {
    final c = club(clubId);
    (c['squadIds'] as List).remove(playerId);
    (c['benchIds'] as List).remove(playerId);
    final xi = c['startingLineupIds'] as List;
    final slot = xi.indexOf(playerId);
    if (slot >= 0) {
      // Keep a valid XI: the first squad player not already picked fills in.
      final bench = c['benchIds'] as List;
      final spare = (c['squadIds'] as List).firstWhere(
        (id) => !xi.contains(id) && !bench.contains(id),
        orElse: () => bench.isNotEmpty ? bench.first : null,
      );
      if (spare != null) {
        bench.remove(spare);
        xi[slot] = spare;
      }
    }
  }

  /// Moves a player between clubs (and leagues).
  void transfer(String playerId, String fromClubId, String toClubId) {
    if (fromClubId == toClubId) return;
    final fromLeague = leagueOfClub(fromClubId), toLeague = leagueOfClub(toClubId);
    final player = _playerList(fromLeague).firstWhere((p) => p['id'] == playerId);
    _detach(fromClubId, playerId);
    if (fromLeague != toLeague) {
      _playerList(fromLeague).remove(player);
      _playerList(toLeague).add(player);
    }
    (club(toClubId)['squadIds'] as List).add(playerId);
    _touch(fromLeague, clubs: true, players: true);
    _touch(toLeague, clubs: true, players: true);
  }

  void deletePlayer(String playerId, String clubId) {
    final leagueId = leagueOfClub(clubId);
    _detach(clubId, playerId);
    _playerList(leagueId).removeWhere((p) => p['id'] == playerId);
    _touch(leagueId, clubs: true, players: true);
  }

  /// Every data file in one ZIP (league.json, each league's clubs and
  /// players, names and templates): unzip it into assets/data.
  Future<Uint8List> exportZip() async {
    final zip = ZipWriter();
    for (final f in _docs.keys) {
      zip.addText(f, fileJson(f));
    }
    for (final f in _shared) {
      zip.addText(f, '${const JsonEncoder.withIndent('  ').convert(await InitialDatabase.readFile(f))}\n');
    }
    return zip.build();
  }

  /// Why a league is not offered in the game yet (null when playable).
  String? leagueWarning(String leagueId) {
    final n = clubs(leagueId).length;
    return n < 4 || n.isOdd ? 'clubs' : null;
  }

  static String _slug(String s) => s.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]+'), '');

  /// Adds an empty league with its own data files.
  String addLeague({required String name, required String country, int tier = 1, double economy = 0.5}) {
    var id = _slug(name).isEmpty ? 'league' : _slug(name);
    if (id.length > 8) id = id.substring(0, 8);
    final base = id;
    for (var n = 2; _manifestLeagues.any((l) => l['id'] == id); n++) {
      id = '$base$n';
    }
    final clubsFile = 'clubs_$id.json', playersFile = 'players_$id.json';
    final entry = <String, dynamic>{
      'id': id,
      'name': name,
      'country': country,
      'clubsFile': clubsFile,
      'playersFile': playersFile,
      'tier': tier,
      'economy': economy,
    };
    _manifestLeagues.add(entry);
    leagues.add(entry);
    _docs[clubsFile] = {'schemaVersion': 2, 'clubs': <Map<String, dynamic>>[]};
    _docs[playersFile] = {'schemaVersion': 2, 'players': <Map<String, dynamic>>[]};
    dirty.addAll(['league.json', clubsFile, playersFile]);
    notifyListeners();
    return id;
  }

  Map<String, dynamic> _copyMap(Map<String, dynamic> m) => jsonDecode(jsonEncode(m)) as Map<String, dynamic>;

  /// Any existing map of the kind, used as a complete template.
  Map<String, dynamic> _templateClub() =>
      _copyMap(leagues.map((l) => clubs(l['id'] as String)).firstWhere((c) => c.isNotEmpty).first);
  Map<String, dynamic> _templatePlayer() => _copyMap(
    leagues
        .map((l) => _playerList(l['id'] as String))
        .firstWhere((p) => p.isNotEmpty)
        .firstWhere((p) => p['mainPosition'] != 'GK'),
  );

  /// Adds a club built from [fields] (name, colours, crest…) with a
  /// generated 23-man squad around [strength] OVR.
  Map<String, dynamic> addClub(String leagueId, Map<String, dynamic> fields, {int strength = 70}) {
    final club = _templateClub()..addAll(fields);
    var id = '${leagueId}_${_slug('${fields['shortName']}')}';
    final base = id;
    for (var n = 2; leagues.any((l) => clubs(l['id'] as String).any((c) => c['id'] == id)); n++) {
      id = '$base$n';
    }
    club['id'] = id;
    final rnd = Random(id.hashCode);
    final players = _generateSquad(id, strength, rnd);
    _playerList(leagueId).addAll(players);
    club
      ..['squadIds'] = [for (final p in players) p['id']]
      ..['startingLineupIds'] = [for (final p in players.take(11)) p['id']]
      ..['benchIds'] = [for (final p in players.skip(11).take(9)) p['id']];
    clubs(leagueId).add(club);
    _touch(leagueId, clubs: true, players: true);
    return club;
  }

  static const _squadShape = [
    'GK', 'CB', 'CB', 'LB', 'RB', 'DMF', 'CMF', 'AMF', 'LWF', 'RWF', 'CF', // first XI
    'GK', 'CB', 'CB', 'LB', 'RB', 'DMF', 'CMF', 'CMF', 'AMF', 'LWF', 'CF', 'GK',
  ];

  List<Map<String, dynamic>> _generateSquad(String clubId, int strength, Random rnd) {
    final pools = InitialDatabase.namePools;
    final template = _templatePlayer();
    final used = <String>{};
    final out = <Map<String, dynamic>>[];
    for (final (i, pos) in _squadShape.indexed) {
      final pool = pools[rnd.nextInt(pools.length)];
      final first = pool['firstNames'] as List, last = pool['lastNames'] as List;
      var name = '';
      do {
        name = '${first[rnd.nextInt(first.length)]} ${last[rnd.nextInt(last.length)]}';
      } while (!used.add(name));
      final target = (strength + (i < 11 ? 2 : -3) + rnd.nextInt(7) - 3).clamp(45, 92);
      final age = 18 + rnd.nextInt(16);
      final p = _copyMap(template)
        ..remove('face')
        ..remove('playingStyle')
        ..remove('traits');
      p
        ..['id'] = '${clubId}_${_slug(name)}'
        ..['name'] = name
        ..['shortName'] = '${name.split(' ').first[0]}. ${name.split(' ').last}'
        ..['age'] = age
        ..['nationality'] = pool['nationality']
        ..['countryFlag'] = pool['flag']
        ..['number'] = i < 11 ? i + 1 : i + 2
        ..['mainPosition'] = pos
        ..['altPositions'] = <String>[]
        ..['preferredFoot'] = rnd.nextInt(4) == 0 ? 'left' : 'right'
        ..['weakFoot'] = 2 + rnd.nextInt(3)
        ..['stats'] = _stats(pos, target, rnd)
        ..['marketValue'] = Player.valuation(target, age, target + 4)
        ..['contract'] = {
          'contractYears': 1 + rnd.nextInt(4),
          'weeklyWage': max(2000, ((target - 50) * (target - 50) * 90 / 1000).round() * 1000),
          'releaseClause': 0,
        };
      out.add(p);
    }
    return out;
  }

  static const _groups = {
    'attack': ['attackingAwareness', 'finishing', 'heading', 'kickingPower', 'curl', 'setPieceTaking'],
    'technique': ['ballControl', 'dribbling', 'tightPossession', 'lowPass', 'loftedPass'],
    'defence': ['defensiveAwareness', 'defensiveEngagement', 'tackling', 'aggression'],
    'physical': ['speed', 'acceleration', 'jumping', 'physicalContact', 'balance', 'stamina'],
    'gk': ['gkAwareness', 'gkCatching', 'gkParrying', 'gkReflexes', 'gkReach'],
  };

  static Map<String, int> _stats(String pos, int target, Random rnd) {
    final keeper = pos == 'GK';
    final attacker = {'CF', 'SS', 'LWF', 'RWF'}.contains(pos);
    final defender = {'CB', 'LB', 'RB'}.contains(pos);
    int shift(String group) => switch (group) {
      'gk' => keeper ? 2 : -60,
      'attack' => keeper ? -30 : attacker ? 3 : defender ? -14 : -3,
      'technique' => keeper ? -25 : defender ? -7 : 2,
      'defence' => keeper ? -30 : attacker ? -22 : defender ? 4 : -4,
      _ => keeper ? -12 : 0,
    };
    return {
      for (final g in _groups.entries)
        for (final k in g.value) k: (target + shift(g.key) + rnd.nextInt(11) - 5).clamp(40, 95),
    };
  }

  /// Pretty JSON of an edited file, as bundled assets are written.
  String fileJson(String file) => '${const JsonEncoder.withIndent('  ').convert(_docs[file])}\n';

  /// Saves edits on this device: new careers use the edited database.
  Future<void> saveLocally() async {
    await InitialDatabase.saveOverrides({for (final f in dirty) f: jsonEncode(_docs[f])});
    dirty.clear();
    notifyListeners();
  }

  /// Files edited so far (saved or not) on this device, for export.
  Set<String> get editedFiles => {...InitialDatabase.overrides.keys, ...dirty};

  Future<void> discardAll() async {
    await InitialDatabase.clearOverrides();
    await load();
  }
}
