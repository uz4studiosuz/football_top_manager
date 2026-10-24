import 'dart:convert';
import 'dart:math';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/club.dart';
import '../l10n/l10n.dart';

/// One playable competition from the asset manifest. Leagues sharing a
/// [pyramid] exchange clubs every summer: the bottom [relegate] go down,
/// the top [promote] plus the play-off winner ([playoffFrom]–[playoffTo])
/// go up. [economy] scales TV money, sponsorship, prizes and running costs.
class LeagueInfo {
  final String id, _name, country;

  /// Display name in the interface language.
  String get name => tr(_name);
  final String? pyramid;
  final int tier, promote, relegate, playoffFrom, playoffTo;
  final double economy;

  /// Country flag, club count and average club strength from the manifest,
  /// so league lists can be shown before a league's files are loaded.
  final String flag;
  final int clubCount, level;

  /// Loaded on demand ([InitialDatabase.ensureLeague]) instead of at start-up.
  final bool lazy;
  const LeagueInfo(
    this.id,
    this._name,
    this.country, {
    this.pyramid,
    this.tier = 1,
    this.promote = 0,
    this.relegate = 0,
    this.playoffFrom = 0,
    this.playoffTo = 0,
    this.economy = 1,
    this.flag = '',
    this.clubCount = 0,
    this.level = 0,
    this.lazy = false,
  });

  bool get hasPlayoff => playoffTo > playoffFrom;

  factory LeagueInfo.fromMap(Map<String, dynamic> e) {
    final playoff = (e['playoff'] as List?)?.cast<int>() ?? const [0, 0];
    return LeagueInfo(
      e['id'],
      e['name'],
      e['country'] ?? '',
      pyramid: e['pyramid'],
      tier: e['tier'] ?? 1,
      promote: e['promote'] ?? 0,
      relegate: e['relegate'] ?? 0,
      playoffFrom: playoff[0],
      playoffTo: playoff[1],
      economy: (e['economy'] as num? ?? 1).toDouble(),
      flag: e['flag'] ?? '',
      clubCount: e['clubs'] ?? 0,
      level: e['level'] ?? 0,
      lazy: e['lazy'] == true,
    );
  }
}

/// Separate versioned assets are joined by IDs once, then copied per career.
class InitialDatabase {
  static Map<String, List<Map<String, dynamic>>>? _leagues;
  static final List<LeagueInfo> leagues = [];
  static List<Map<String, dynamic>> _custom = [];
  static List<Map<String, dynamic>> _names = [];

  /// Look-alike portrait hints from the data files (player id → partial face).
  static final Map<String, Map<String, dynamic>> faceHints = {};
  static List<Map<String, dynamic>> get customSquadTemplates =>
      _custom.map((m) => Map<String, dynamic>.from(m)).toList();
  static List<Map<String, dynamic>> get namePools =>
      _names.map((m) => Map<String, dynamic>.from(m)).toList();

  /// A name pool picked by how many real players the nation has (square
  /// root, so small nations still appear); [prefer] is chosen [preferShare]
  /// of the time when it has a pool.
  static Map<String, dynamic> randomPool(Random rnd, {String? prefer, double preferShare = 0.7}) {
    if (prefer != null && rnd.nextDouble() < preferShare) {
      final own = _names.where((p) => p['nationality'] == prefer).firstOrNull;
      if (own != null) return own;
    }
    double w(Map<String, dynamic> p) => sqrt(((p['weight'] as num?) ?? 30) + 20);
    var x = rnd.nextDouble() * _names.fold(0.0, (t, p) => t + w(p));
    for (final p in _names) {
      x -= w(p);
      if (x <= 0) return p;
    }
    return _names.last;
  }
  /// Data files edited in the /editor page (file name → JSON), stored on
  /// this device and used instead of the bundled assets.
  static const overridesKey = 'ftm27_db_overrides_v1';
  static Map<String, String> overrides = {};

  static Future<Map<String, dynamic>> _read(String file) async =>
      _expand(jsonDecode(overrides[file] ?? await rootBundle.loadString('assets/data/$file')) as Map<String, dynamic>);

  /// World league files store a player's attributes as a list (in
  /// [statKeys] order) to stay small; everything else sees the usual map.
  static Map<String, dynamic> _expand(Map<String, dynamic> doc) {
    final players = doc['players'];
    if (players is List) {
      for (final p in players) {
        final stats = (p as Map)['stats'];
        if (stats is List) p['stats'] = {for (var i = 0; i < statKeys.length && i < stats.length; i++) statKeys[i]: stats[i]};
      }
    }
    return doc;
  }

  static const statKeys = [
    'attackingAwareness', 'ballControl', 'dribbling', 'tightPossession', 'lowPass', 'loftedPass',
    'finishing', 'heading', 'setPieceTaking', 'curl', 'defensiveAwareness', 'defensiveEngagement',
    'tackling', 'aggression', 'gkAwareness', 'gkCatching', 'gkParrying', 'gkReflexes', 'gkReach',
    'speed', 'acceleration', 'kickingPower', 'jumping', 'physicalContact', 'balance', 'stamina',
  ];

  /// A data file as the game sees it (editor input).
  static Future<Map<String, dynamic>> readFile(String file) => _read(file);

  /// The bundled version of a data file, ignoring local edits.
  static Future<Map<String, dynamic>> readBundled(String file) async =>
      jsonDecode(await rootBundle.loadString('assets/data/$file')) as Map<String, dynamic>;

  static Future<void> _loadOverrides() async {
    try {
      final raw = (await SharedPreferences.getInstance()).getString(overridesKey);
      overrides = raw == null ? {} : Map<String, String>.from(jsonDecode(raw));
    } catch (_) {
      overrides = {};
    }
  }

  /// Saves edited files and reloads the database for the next career.
  static Future<void> saveOverrides(Map<String, String> files) async {
    overrides = {...overrides, ...files};
    try {
      await (await SharedPreferences.getInstance()).setString(overridesKey, jsonEncode(overrides));
    } catch (_) {}
    await reload();
  }

  static Future<void> clearOverrides() async {
    overrides = {};
    try {
      await (await SharedPreferences.getInstance()).remove(overridesKey);
    } catch (_) {}
    await reload();
  }

  static Future<void> reload() async {
    _leagues = null;
    _entries.clear();
    faceHints.clear();
    await load(keepOverrides: true);
  }

  static Future<void>? _loading;

  /// Loads the manifest once; overlapping calls share the same load (two
  /// running at once used to list every league twice).
  static Future<void> load({bool keepOverrides = false}) {
    if (_leagues != null) return Future.value();
    return _loading ??= _load(keepOverrides).whenComplete(() => _loading = null);
  }

  static Future<void> _load(bool keepOverrides) async {
    if (!keepOverrides) await _loadOverrides();
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
    _entries.clear();
    for (final raw in entries) {
      final e = Map<String, dynamic>.from(raw);
      // An edited copy of a world league counts as loaded right away.
      if (e['lazy'] == true && !overrides.containsKey(e['clubsFile'])) {
        _entries[e['id']] = e;
        leagues.add(LeagueInfo.fromMap(e));
        continue;
      }
      final joined = await _readLeague(e);
      if (joined == null) continue;
      loaded[e['id']] = joined;
      leagues.add(LeagueInfo.fromMap(e));
    }
    _custom = (shared[0]['slots'] as List).map((r) => Map<String, dynamic>.from(r)).toList();
    _names = (shared[1]['pools'] as List).map((r) => Map<String, dynamic>.from(r)).toList();
    _leagues = loaded;
  }

  /// Manifest entries of world leagues that are not loaded yet.
  static final Map<String, Map<String, dynamic>> _entries = {};

  static Future<List<Map<String, dynamic>>?> _readLeague(Map<String, dynamic> e) async {
    // World leagues keep clubs and players in one file.
    final same = e['clubsFile'] == e['playersFile'];
    final files = await Future.wait([_read(e['clubsFile']), if (!same) _read(e['playersFile'])]);
    final joined = _join(files[0], files.last);
    // A league needs an even number of clubs (at least 4) to be played.
    if (joined.length < 4 || joined.length.isOdd) return null;
    return joined;
  }

  static bool isLoaded(String id) => _leagues?.containsKey(id) ?? false;

  /// Loads a world league's files the first time it is needed.
  static Future<void> ensureLeague(String id) async {
    if (isLoaded(id)) return;
    final e = _entries[id];
    if (e == null) return;
    final joined = await _readLeague(e);
    if (joined == null) throw FormatException('Invalid league $id');
    _leagues![id] = joined;
    _entries.remove(id);
  }

  /// [id] and every league of its pyramid.
  static Future<void> ensurePyramid(String id) async {
    for (final l in pyramidOf(id)) {
      await ensureLeague(l.id);
    }
  }

  static List<Map<String, dynamic>> _join(Map<String, dynamic> clubsDoc, Map<String, dynamic> playersDoc) {
    final players = <String, Map<String, dynamic>>{};
    for (final raw in playersDoc['players'] as List) {
      final p = Map<String, dynamic>.from(raw);
      if (players.containsKey(p['id'])) {
        throw FormatException('Duplicate player ${p['id']}');
      }
      players[p['id']] = p;
      if (p['face'] != null) faceHints[p['id']] = Map<String, dynamic>.from(p['face']);
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

  static String leagueName(String id) => info(id).name;

  static LeagueInfo info(String id) =>
      leagues.where((l) => l.id == id).firstOrNull ?? const LeagueInfo('super', 'Super League', '');

  /// Every league of [id]'s pyramid, top tier first (just [id] if none).
  static List<LeagueInfo> pyramidOf(String id) {
    final me = info(id);
    if (me.pyramid == null) return [me];
    return leagues.where((l) => l.pyramid == me.pyramid).toList()
      ..sort((a, b) => a.tier.compareTo(b.tier));
  }

  /// League a seeded club belongs to (custom clubs report null).
  static String? leagueOf(String clubId) {
    // World club ids start with their league id ("es64_1_123").
    for (final id in _entries.keys) {
      if (clubId.startsWith('${id}_')) return id;
    }
    for (final e in (_leagues ?? {}).entries) {
      if (e.value.any((c) => c['id'] == clubId)) return e.key;
    }
    return null;
  }
}
