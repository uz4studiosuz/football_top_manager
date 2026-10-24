import 'package:flutter/material.dart';
import '../models/player.dart';
import '../services/game_state.dart';
import 'widgets.dart';

/// OVR badge: exact for known players, a scouting range ("72–80") otherwise.
class ScoutedOvr extends StatelessWidget {
  final Player player;
  final double size;
  const ScoutedOvr(this.player, {super.key, this.size = 30});
  @override
  Widget build(BuildContext context) {
    final (lo, hi) = GameState().ovrRange(player);
    if (lo == hi) return ValueBadge(player.ovr, size: size);
    return Container(
      height: size,
      padding: const EdgeInsets.symmetric(horizontal: 8),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: AppColors.surfaceAlt,
        borderRadius: BorderRadius.circular(size * 0.25),
        border: Border.all(color: AppColors.line),
      ),
      child: Text('$lo–$hi', style: TextStyle(fontSize: size * 0.38, fontWeight: FontWeight.w800, color: AppColors.ink2)),
    );
  }
}
