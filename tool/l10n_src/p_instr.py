"""One-off patch: rework individual instructions."""
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent.parent


def patch(rel, pairs):
    p = ROOT / rel
    s = p.read_text(encoding='utf8')
    for a, b in pairs:
        assert s.count(a) == 1, (rel, s.count(a), a[:70])
        s = s.replace(a, b, 1)
    p.write_text(s, encoding='utf8')


patch('lib/models/player.dart', [
    ("""  manMarking('Man Marking', 'Raqibning eng xavfli o‘yinchisini shaxsan qo‘riqlaydi', false),
  tightMarking('Tight Marking', 'Yaqin masofadan bosim: ko‘proq Olib qo‘yish va qoidabuzarlik', false),""",
     """  pressing('Faol pressing', 'To‘p egasiga birinchi bo‘lib boradi: ko‘proq to‘p qaytarish, lekin tez charchaydi', false),
  trackBack('Himoyaga qaytish', 'Hujumchi yoki vinger to‘p yo‘qotilganda himoyaga yordamga qaytadi', false),
  tightMarking('Tight Marking', 'Yaqin masofadan bosim: ko‘proq Olib qo‘yish va qoidabuzarlik', false),"""),
    ("""    instruction: PlayerInstruction.values.byName(
      m['instruction'] ?? 'balanced',
    ),""", """    // "manMarking" was retired: old saves get the closest instruction.
    instruction: PlayerInstruction.values.asNameMap()[m['instruction']] ??
        (m['instruction'] == 'manMarking' ? PlayerInstruction.tightMarking : PlayerInstruction.balanced),"""),
])

patch('lib/services/match_field.dart', [
    ("""    final pressRadius = 0.042 + (_opponent.tactics.pressing - 3) * 0.002;""",
     """    final pressRadius = 0.042 +
        (_opponent.tactics.pressing - 3) * 0.002 +
        (_xi(_opponent)[_nearest(_rivals, ball, _opponent, ignoreKeeper: true)].instruction ==
                PlayerInstruction.pressing
            ? 0.012
            : 0);"""),
    ("""                  (defender.instruction == PlayerInstruction.tightMarking ||
                          defender.instruction == PlayerInstruction.manMarking""",
     """                  (defender.instruction == PlayerInstruction.tightMarking ||
                          defender.instruction == PlayerInstruction.pressing"""),
    ("""            case PlayerInstruction.manMarking:
              final opp = isHome ? away : home;
              final oppXi = _xi(opp);
              var best = -1, bestOvr = -1;
              for (var j = 1; j < 11; j++) {
                if (dismissed.contains(oppXi[j].id)) continue;
                if (oppXi[j].ovr > bestOvr) {
                  bestOvr = oppXi[j].ovr;
                  best = j;
                }
              }
              if (best > 0) target = rivals[best] - Offset(direction * 0.015, 0);""",
     """            case PlayerInstruction.pressing:
              // Closes down the ball when it is near.
              if ((ball - points[i]).distance < 0.2) target = Offset.lerp(target, ball, 0.55)!;
            case PlayerInstruction.trackBack:
              target = Offset.lerp(target, bases[i] - Offset(direction * 0.12, 0), 0.6)!;"""),
    ("""      if (mate.instruction == PlayerInstruction.playmaker) score += 0.08;""",
     """      if (mate.instruction == PlayerInstruction.playmaker) score += 0.08;
      // Runners are found more often going forward; holders get the safe ball.
      if (mate.instruction == PlayerInstruction.makeRuns && progress > 0.05) score += 0.07;
      if (mate.instruction == PlayerInstruction.stayBack && progress > 0.1) score -= 0.05;"""),
])
print('ok')
