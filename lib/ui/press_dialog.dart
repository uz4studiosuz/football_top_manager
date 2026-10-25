import 'package:flutter/material.dart';
import '../l10n/l10n.dart';
import '../models/league.dart';
import '../services/game_state.dart';
import '../services/press.dart';
import 'widgets.dart';

/// Runs a press conference (before [f], or after it when [post]): one
/// dialog per question, then the effects and a summary.
Future<void> runPressConference(BuildContext context, Fixture f, {bool post = false}) async {
  final game = GameState();
  final questions = post ? game.postPressFor(f) : game.pressFor(f);
  if (questions == null) return;
  final picked = <(PressQuestion, PressAnswer)>[];
  for (final q in questions) {
    final a = await showDialog<PressAnswer>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => SimpleDialog(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(tr(q.outlet), style: AppText.caption.copyWith(color: AppColors.primary, fontWeight: FontWeight.w700)),
            const SizedBox(height: 4),
            Text(q.question),
          ],
        ),
        children: [
          for (final a in q.answers)
            SimpleDialogOption(
              onPressed: () => Navigator.pop(ctx, a),
              child: Padding(padding: const EdgeInsets.symmetric(vertical: 6), child: Text('“${a.text}”', style: AppText.body)),
            ),
        ],
      ),
    );
    if (a == null || !context.mounted) return;
    picked.add((q, a));
  }
  game.answerPress(f, picked, post: post);
  final morale = picked.fold<int>(0, (s, e) => s + e.$2.morale);
  final fans = picked.fold<int>(0, (s, e) => s + e.$2.fans);
  if (context.mounted) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(trf('Matbuot anjumani tugadi. Jamoa kayfiyati {0}{1}, muxlislar {2}{3}.', [
          morale >= 0 ? '+' : '',
          morale,
          fans >= 0 ? '+' : '',
          fans,
        ])),
      ),
    );
  }
}
