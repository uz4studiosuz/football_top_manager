import 'dart:convert';
import 'package:flutter/services.dart';
import '../models/club.dart';

/// Separate versioned assets are joined by IDs once, then copied per career.
class InitialDatabase {
  static List<Map<String, dynamic>>? _clubs;
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
    if (_clubs != null) return;
    final manifest = await _read('league.json');
    if (manifest['schemaVersion'] != 2) {
      throw const FormatException('Unsupported league schema');
    }
    final files = await Future.wait([
      _read(manifest['clubsFile']),
      _read(manifest['playersFile']),
      _read(manifest['templatesFile']),
      _read(manifest['namesFile']),
    ]);
    final players = <String, Map<String, dynamic>>{};
    for (final raw in files[1]['players'] as List) {
      final p = Map<String, dynamic>.from(raw);
      if (players.containsKey(p['id'])) {
        throw FormatException('Duplicate player ${p['id']}');
      }
      players[p['id']] = p;
    }
    final joined = <Map<String, dynamic>>[];
    final owners = <String>{};
    final clubIds = <String>{};
    for (final raw in files[0]['clubs'] as List) {
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
    _custom = (files[2]['slots'] as List)
        .map((r) => Map<String, dynamic>.from(r))
        .toList();
    _names = (files[3]['pools'] as List)
        .map((r) => Map<String, dynamic>.from(r))
        .toList();
    _clubs = joined;
  }

  static List<Club> getSuperLeagueClubs() {
    if (_clubs == null) throw StateError('Load database first');
    return _clubs!.map((m) => Club.fromMap(jsonDecode(jsonEncode(m)))).toList();
  }
}
