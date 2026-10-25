import 'dart:math';
import '../data/initial_database.dart';
import '../models/club.dart';
import '../models/player.dart';

/// The football world outside the career's pyramid: the leagues the scouts
/// have opened, as a transfer market.
///
/// Only four small things are saved with the career (opened countries,
/// scouting trips, players who left their clubs, seasons passed); squads are
/// rebuilt from the data files and aged by [seasons], so a save stays small
/// however many countries are opened, and nothing is simulated round by
/// round.
class WorldMarket {
  /// Countries the scouts have reported on (Uzbek names, as in the manifest).
  final Set<String> countries = {};

  /// Scouting trips under way: country → round the report arrives.
  final Map<String, int> missions = {};

  /// World players who moved to the user's club; they never reappear in
  /// their data-file squad.
  final Set<String> gone = {};

  /// Seasons played since the data files' season (players age and develop).
  int seasons = 0;

  /// Loaded clubs by league, and each league's country.
  final Map<String, List<Club>> _clubs = {};
  final Map<String, String> _country = {};

  /// Clubs of reported countries (pending trips stay hidden).
  Iterable<Club> get clubs sync* {
    for (final e in _clubs.entries) {
      if (countries.contains(_country[e.key])) yield* e.value;
    }
  }

  Club? club(String id) {
    for (final list in _clubs.values) {
      for (final c in list) {
        if (c.id == id) return c;
      }
    }
    return null;
  }

  /// League of a loaded world club (null when not in the world market).
  String? leagueOf(String clubId) {
    for (final e in _clubs.entries) {
      if (e.value.any((c) => c.id == clubId)) return e.key;
    }
    return null;
  }

  /// Countries scouts can travel to: every league outside [pyramid].
  static List<String> destinations(Set<String> pyramid) {
    final out = <String>{
      for (final l in InitialDatabase.leagues)
        if (!pyramid.contains(l.id) && l.country.isNotEmpty) l.country,
    };
    return out.toList();
  }

  static List<LeagueInfo> leaguesOf(String country, Set<String> pyramid) => [
    for (final l in InitialDatabase.leagues)
      if (l.country == country && !pyramid.contains(l.id)) l,
  ];

  /// Loads [country]'s leagues (except the career's own [pyramid]); [prepare]
  /// picks each club's lineup.
  Future<void> loadCountry(String country, Set<String> pyramid, void Function(Club) prepare) async {
    for (final l in leaguesOf(country, pyramid)) {
      if (_clubs.containsKey(l.id)) continue;
      await InitialDatabase.ensureLeague(l.id);
      final clubs = InitialDatabase.getClubs(l.id);
      _clubs[l.id] = clubs;
      _country[l.id] = country;
      for (final c in clubs) {
        age(c, seasons, Random(c.id.hashCode ^ seasons));
        for (final p in List.of(c.squad)) {
          if (gone.contains(p.id)) _drop(c, p);
        }
        prepare(c);
      }
    }
  }

  /// Rebuilds every loaded league (a new season, or a new career pyramid).
  Future<void> reload(Set<String> pyramid, void Function(Club) prepare) async {
    final wanted = {...countries, ...missions.keys};
    _clubs.clear();
    _country.clear();
    for (final c in wanted) {
      await loadCountry(c, pyramid, prepare);
    }
  }

  void reset() {
    countries.clear();
    missions.clear();
    gone.clear();
    seasons = 0;
    _clubs.clear();
    _country.clear();
  }

  static void _drop(Club c, Player p) {
    c.squad.remove(p);
    c.startingLineupIds.remove(p.id);
    c.benchIds.remove(p.id);
  }

  /// [seasons] summers of development for a club fresh from the data files:
  /// youngsters grow, veterans decline, the oldest retire.
  static void age(Club c, int seasons, Random rnd) {
    for (var s = 0; s < seasons; s++) {
      for (final p in List.of(c.squad)) {
        develop(p, rnd);
        if (p.age >= 37 && c.squad.length > 18 && rnd.nextDouble() < 0.7) _drop(c, p);
      }
    }
  }

  /// One summer for one player (also used for the career's own clubs).
  static void develop(Player p, Random rnd) {
    final before = p.ovr;
    p.age++;
    final minutes = p.seasonMinutes;
    final rating = p.averageRating ?? 6.6;
    int delta;
    if (p.age <= 21) {
      delta = 1 + rnd.nextInt(4) + (minutes > 700 ? 1 : 0) + (rating > 7.2 ? 1 : 0);
    } else if (p.age <= 24) {
      delta = rnd.nextInt(4) + (minutes > 900 ? 1 : 0);
    } else if (p.age <= 28) {
      delta = rnd.nextInt(3) - 1 + (rating > 7.3 ? 1 : 0);
    } else if (p.age <= 31) {
      delta = -rnd.nextInt(3);
    } else {
      delta = -1 - rnd.nextInt(3);
    }
    if (before + delta > p.potential) delta = max(0, p.potential - before);
    final m = p.stats.toMap().map((k, v) => MapEntry(k, v as int));
    const physical = {'speed', 'acceleration', 'stamina', 'jumping'};
    final keeper = p.mainPosition.isGoalkeeper;
    for (final k in m.keys.toList()) {
      final isGk = k.startsWith('gk');
      if (isGk != keeper && delta > 0) continue;
      var change = delta + (rnd.nextInt(3) - 1);
      if (p.age >= 30 && physical.contains(k)) change -= 1 + rnd.nextInt(2);
      m[k] = (m[k]! + change).clamp(40, 99);
    }
    p.stats = PlayerStats.fromMap(m);
    p.marketValue = Player.valuation(p.ovr, p.age, p.potential);
  }

  Map<String, dynamic> toMap() => {
    'c': countries.toList(),
    'm': missions,
    'g': gone.toList(),
    's': seasons,
  };

  void restore(Map<String, dynamic>? m) {
    reset();
    if (m == null) return;
    countries.addAll(List<String>.from(m['c'] ?? const []));
    missions.addAll(Map<String, int>.from(m['m'] ?? {}));
    gone.addAll(List<String>.from(m['g'] ?? const []));
    seasons = m['s'] ?? 0;
  }
}
