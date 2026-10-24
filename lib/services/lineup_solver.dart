/// Optimal assignment (Hungarian algorithm) for picking a line-up: every
/// slot gets the player that maximises the total team score, so a 96-rated
/// centre-back is never parked at right-back just because a slot was
/// filled first.
abstract final class LineupSolver {
  /// [score] has one row per slot and one column per candidate
  /// (rows <= columns). Returns the chosen column for every row.
  static List<int> assign(List<List<double>> score) {
    final n = score.length;
    if (n == 0) return [];
    final m = score.first.length;
    assert(n <= m);
    var maxScore = double.negativeInfinity;
    for (final row in score) {
      for (final v in row) {
        if (v > maxScore) maxScore = v;
      }
    }
    // Minimisation form, 1-based arrays as in the classic e-maxx version.
    double cost(int i, int j) => maxScore - score[i - 1][j - 1];
    final u = List<double>.filled(n + 1, 0), v = List<double>.filled(m + 1, 0);
    final p = List<int>.filled(m + 1, 0), way = List<int>.filled(m + 1, 0);
    for (var i = 1; i <= n; i++) {
      p[0] = i;
      var j0 = 0;
      final minv = List<double>.filled(m + 1, double.infinity);
      final used = List<bool>.filled(m + 1, false);
      do {
        used[j0] = true;
        final i0 = p[j0];
        var delta = double.infinity;
        var j1 = 0;
        for (var j = 1; j <= m; j++) {
          if (used[j]) continue;
          final cur = cost(i0, j) - u[i0] - v[j];
          if (cur < minv[j]) {
            minv[j] = cur;
            way[j] = j0;
          }
          if (minv[j] < delta) {
            delta = minv[j];
            j1 = j;
          }
        }
        for (var j = 0; j <= m; j++) {
          if (used[j]) {
            u[p[j]] += delta;
            v[j] -= delta;
          } else {
            minv[j] -= delta;
          }
        }
        j0 = j1;
      } while (p[j0] != 0);
      do {
        final j1 = way[j0];
        p[j0] = p[j1];
        j0 = j1;
      } while (j0 != 0);
    }
    final result = List<int>.filled(n, -1);
    for (var j = 1; j <= m; j++) {
      if (p[j] != 0) result[p[j] - 1] = j - 1;
    }
    return result;
  }
}
