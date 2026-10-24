import 'dart:convert';
import 'package:flutter/foundation.dart';
import '../data/initial_database.dart';

/// Editable copy of the data files behind the /editor page. Works on the
/// raw JSON so exported files can be dropped straight into assets/data.
class DbEditor extends ChangeNotifier {
  /// League manifest entries (id, name, clubsFile, playersFile…).
  List<Map<String, dynamic>> leagues = [];
  final Map<String, Map<String, dynamic>> _docs = {}; // file → document
  final Set<String> dirty = {};
  bool loaded = false;

  Future<void> load() async {
    final manifest = await InitialDatabase.readFile('league.json');
    leagues = [
      for (final e in (manifest['leagues'] as List)) Map<String, dynamic>.from(e),
    ];
    _docs.clear();
    for (final l in leagues) {
      for (final f in [l['clubsFile'] as String, l['playersFile'] as String]) {
        _docs[f] = await InitialDatabase.readFile(f);
      }
    }
    dirty.clear();
    loaded = true;
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
