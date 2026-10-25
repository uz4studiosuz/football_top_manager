import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import '../services/game_state.dart';
import '../services/save_service.dart';
import '../ui/browser_files_stub.dart' if (dart.library.js_interop) '../ui/browser_files_web.dart';
import '../ui/widgets.dart';
import '../l10n/l10n.dart';
import 'main_navigation_screen.dart';
import 'onboarding_screen.dart';

/// Three careers side by side, plus exporting / importing a career file.
class SaveSlotsScreen extends StatefulWidget {
  const SaveSlotsScreen({super.key});
  @override
  State<SaveSlotsScreen> createState() => _SaveSlotsScreenState();
}

class _SaveSlotsScreenState extends State<SaveSlotsScreen> {
  late Future<List<Map<String, dynamic>?>> _slots = _read();

  Future<List<Map<String, dynamic>?>> _read() async {
    await SaveService.save();
    return [for (var i = 0; i < SaveService.slotCount; i++) await SaveService.meta(i)];
  }

  void _snack(String t) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(t)));

  Future<void> _open(int slot, Map<String, dynamic>? meta) async {
    await SaveService.setActiveSlot(slot);
    if (!mounted) return;
    if (meta != null && await SaveService.load()) {
      if (!mounted) return;
      Navigator.of(context).pushAndRemoveUntil(MaterialPageRoute<void>(builder: (_) => const MainNavigationScreen()), (_) => false);
    } else {
      GameState().resetCareer();
      if (!mounted) return;
      Navigator.of(context).pushAndRemoveUntil(MaterialPageRoute<void>(builder: (_) => OnboardingScreen()), (_) => false);
    }
  }

  Future<void> _delete(int slot) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(trf('{0}-slot o‘chirilsinmi?', [slot + 1])),
        content: Text(tr('Bu karyerani qaytarib bo‘lmaydi.')),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(tr('Yo‘q'))),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: Text(tr('O‘chirish'))),
        ],
      ),
    );
    if (ok != true) return;
    await SaveService.clearSlot(slot);
    setState(() => _slots = _read());
  }

  Future<void> _export() async {
    final game = GameState();
    await downloadBytes(
      'ftm27_${game.userClub.shortName.toLowerCase()}_${game.seasonLabel.replaceAll('/', '-')}.json',
      Uint8List.fromList(utf8.encode(SaveService.exportCareer())),
      'application/json',
    );
    _snack(tr('Karyera fayli yuklab olindi.'));
  }

  Future<void> _import() async {
    final bytes = await pickFileBytes('.json');
    if (bytes == null) return;
    final ok = await SaveService.importCareer(utf8.decode(bytes, allowMalformed: true));
    if (!mounted) return;
    if (!ok) {
      _snack(tr('Bu fayl karyera emas yoki buzilgan.'));
      return;
    }
    Navigator.of(context).pushAndRemoveUntil(MaterialPageRoute<void>(builder: (_) => const MainNavigationScreen()), (_) => false);
  }

  Widget _slot(int i, Map<String, dynamic>? meta) => Padding(
    padding: const EdgeInsets.only(bottom: 10),
    child: AppCard(
      color: i == SaveService.activeSlot ? AppColors.primarySoft : AppColors.surface,
      child: Row(
        children: [
          CircleAvatar(child: Text('${i + 1}')),
          const SizedBox(width: 12),
          Expanded(
            child: meta == null
                ? Text(tr('Bo‘sh slot'), style: AppText.bodyStrong)
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('${meta['club']}', style: AppText.bodyStrong),
                      Text(
                        '${meta['league'] ?? ''} · ${meta['season'] ?? ''} · ${trf('{0}-tur', [meta['round'] ?? 1])}',
                        style: AppText.caption,
                      ),
                      if (meta['manager'] != null) Text('${meta['manager']}', style: AppText.caption),
                    ],
                  ),
          ),
          if (i == SaveService.activeSlot)
            Text(tr('Hozirgi'), style: AppText.caption.copyWith(color: AppColors.primary, fontWeight: FontWeight.w700))
          else ...[
            if (meta != null) IconButton(tooltip: tr('O‘chirish'), onPressed: () => _delete(i), icon: const Icon(Icons.delete_outline)),
            FilledButton.tonal(
              onPressed: () => _open(i, meta),
              child: Text(meta == null ? tr('Yangi karyera') : tr('Ochish')),
            ),
          ],
        ],
      ),
    ),
  );

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: Text(tr('Saqlash slotlari'))),
    body: PageWidth(
      maxWidth: 720,
      child: FutureBuilder<List<Map<String, dynamic>?>>(
        future: _slots,
        builder: (context, snap) {
          if (!snap.hasData) return const Center(child: CircularProgressIndicator());
          final slots = snap.data!;
          return ListView(
            padding: const EdgeInsets.all(12),
            children: [
              for (var i = 0; i < slots.length; i++) _slot(i, slots[i]),
              const SizedBox(height: 8),
              AppCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SectionHeader(tr('Boshqa qurilmaga ko‘chirish'), icon: Icons.sync_alt_rounded),
                    Text(
                      tr('Karyerani fayl sifatida yuklab oling va boshqa qurilmada import qiling (joriy slotga yoziladi).'),
                      style: AppText.small,
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(
                          child: FilledButton.icon(onPressed: _export, icon: const Icon(Icons.download_rounded), label: Text(tr('Eksport'))),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: OutlinedButton.icon(onPressed: _import, icon: const Icon(Icons.upload_rounded), label: Text(tr('Import'))),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    ),
  );
}
