import 'package:flutter/material.dart';
import '../services/game_state.dart';
import '../ui/face_avatar.dart';
import 'widgets/player_detail_view.dart';

class SquadScreen extends StatelessWidget {
  const SquadScreen({super.key});
  @override
  Widget build(BuildContext context) {
    final game = GameState();
    return Scaffold(
      appBar: AppBar(title: const Text('Futbolchilar')),
      body: ListenableBuilder(
        listenable: game,
        builder: (context, _) => ListView(
          children: [
            Padding(
              padding: const EdgeInsets.all(20),
              child: Text(
                '${game.userClub.squad.length} futbolchi  ·  Asosiy va zaxira tarkib',
                style: const TextStyle(color: Color(0xFF637184)),
              ),
            ),
            for (final p in game.userClub.squad)
              Container(
                color: Colors.white,
                child: Material(
                  color: Colors.transparent,
                  child: ListTile(
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 7,
                    ),
                    leading: FaceAvatar(
                      config: p.face,
                      size: 44,
                      shirt: game.userClub.primaryColor,
                    ),
                    title: Text(
                      p.name,
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                    subtitle: Text(
                      '${p.mainPosition.code}  ·  ${p.age} yosh  ·  ${p.currentStamina}% tayyor',
                    ),
                    trailing: Text(
                      '${p.ovr}',
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF1769E0),
                      ),
                    ),
                    onTap: () => PlayerDetailView.show(
                      context,
                      player: p,
                      club: game.userClub,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
