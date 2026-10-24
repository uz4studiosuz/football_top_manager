import 'dart:convert';
import 'package:flutter/services.dart';
import '../models/club.dart';

/// One playable competition from the asset manifest.
class LeagueInfo {
  final String id, name, country;
  const LeagueInfo(this.id, this.name, this.country);
}

/// Separate versioned assets are joined by IDs once, then copied per career.
class InitialDatabase {
  static Map<String, List<Map<String, dynamic>>>? _leagues;
  static final List<LeagueInfo> leagues = [];
  static List<Map<String, dynamic>> _custom = [];
  static List<Map<String, dynamic>> _names = [];
  static List<Map<String, dynamic>> get customSquadTemplates =>
      _custom.map((m) => Map<String, dynamic>.from(m)).toList();
  static List<Map<String, dynamic>> get namePools =>
      _names.map((m) => Map<String, dynamic>.from(m)).toList();
  static Future<Map<String, dynamic>> _read(String file) async =>
      jsonDecode(await rootBundle.loadString('assets/data/$file'))
          as Map<String, dynamic>;

  static Future<void> load() async {
    if (_leagues != null) return;
    final manifest = await _read('league.json');
    if (manifest['schemaVersion'] != 2) {
      throw const FormatException('Unsupported league schema');
    }
    final shared = await Future.wait([
      _read(manifest['templatesFile']),
      _read(manifest['namesFile']),
    ]);
    final entries = (manifest['leagues'] as List?) ??
        [
          {
            'id': 'super',
            'name': manifest['name'],
            'clubsFile': manifest['clubsFile'],
            'playersFile': manifest['playersFile'],
          },
        ];
    final loaded = <String, List<Map<String, dynamic>>>{};
    leagues.clear();
    for (final raw in entries) {
      final e = Map<String, dynamic>.from(raw);
      final files = await Future.wait([_read(e['clubsFile']), _read(e['playersFile'])]);
      loaded[e['id']] = _join(files[0], files[1]);
      leagues.add(LeagueInfo(e['id'], e['name'], e['country'] ?? ''));
    }
    _custom = (shared[0]['slots'] as List).map((r) => Map<String, dynamic>.from(r)).toList();
    _names = (shared[1]['pools'] as List).map((r) => Map<String, dynamic>.from(r)).toList();
    _leagues = loaded;
  }

  static List<Map<String, dynamic>> _join(Map<String, dynamic> clubsDoc, Map<String, dynamic> playersDoc) {
    final players = <String, Map<String, dynamic>>{};
    for (final raw in playersDoc['players'] as List) {
      final p = Map<String, dynamic>.from(raw);
      if (players.containsKey(p['id'])) {
        throw FormatException('Duplicate player ${p['id']}');
      }
      players[p['id']] = p;
    }
    final joined = <Map<String, dynamic>>[];
    final owners = <String>{};
    final clubIds = <String>{};
    for (final raw in clubsDoc['clubs'] as List) {
      final c = Map<String, dynamic>.from(raw);
      if (!clubIds.add(c['id'])) {
        throw FormatException('Duplicate club ${c['id']}');
      }
      c['squad'] = (c['squadIds'] as List).map((id) {
        if (!players.containsKey(id) || !owners.add(id)) {
          throw FormatException('Invalid ownership $id');
        }
        return players[id]!;
      }).toList();
      final club = Club.fromMap(c);
      final ids = club.squad.map((p) => p.id).toSet();
      if (club.startingLineupIds.length != 11 ||
          club.startingLineupIds.toSet().length != 11 ||
          !club.startingLineupIds.every(ids.contains) ||
          !club.benchIds.every(ids.contains) ||
          club.benchIds.any(club.startingLineupIds.contains)) {
        throw FormatException('Invalid lineup ${club.id}');
      }
      joined.add(c);
    }
    return joined;
  }

  static List<Club> getClubs(String leagueId) {
    final raw = _leagues?[leagueId];
    if (raw == null) throw StateError('Load database first ($leagueId)');
    return raw.map((m) => Club.fromMap(jsonDecode(jsonEncode(m)))).toList();
  }

  static List<Club> getSuperLeagueClubs() => getClubs('super');

  static String leagueName(String id) =>
      leagues.where((l) => l.id == id).firstOrNull?.name ?? 'Super League';

  /// League a seeded club belongs to (custom clubs report null).
  static String? leagueOf(String clubId) {
    for (final e in (_leagues ?? {}).entries) {
      if (e.value.any((c) => c['id'] == clubId)) return e.key;
    }
    return null;
  }
}
