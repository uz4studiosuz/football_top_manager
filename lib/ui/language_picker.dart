import 'package:flutter/material.dart';
import '../l10n/l10n.dart';
import 'app_theme.dart';

/// First-launch language choice (shown before onboarding).
class LanguageScreen extends StatelessWidget {
  final VoidCallback onDone;
  const LanguageScreen({super.key, required this.onDone});

  @override
  Widget build(BuildContext context) => Scaffold(
    body: SafeArea(
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Icon(Icons.sports_soccer, size: 56, color: AppColors.primary),
                const SizedBox(height: 12),
                const Text(
                  'Football Top Manager 2027',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 6),
                const Text(
                  'Tilni tanlang · Choose language · Выберите язык',
                  textAlign: TextAlign.center,
                  style: AppText.small,
                ),
                const SizedBox(height: 24),
                for (final l in AppLang.values)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: Material(
                      color: AppColors.surface,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                        side: const BorderSide(color: AppColors.line),
                      ),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(14),
                        onTap: () async {
                          await L10n.set(l);
                          onDone();
                        },
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
                          child: Row(
                            children: [
                              _LangBadge(l),
                              const SizedBox(width: 14),
                              Expanded(child: Text(l.nativeName, style: AppText.h3)),
                              const Icon(Icons.chevron_right_rounded, color: AppColors.ink3),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}

/// Segmented language switch for settings screens.
class LanguageSelector extends StatelessWidget {
  const LanguageSelector({super.key});

  @override
  Widget build(BuildContext context) => ValueListenableBuilder<AppLang>(
    valueListenable: L10n.current,
    builder: (context, lang, _) => SegmentedButton<AppLang>(
      showSelectedIcon: false,
      segments: [
        for (final l in AppLang.values) ButtonSegment(value: l, label: Text(l.nativeName)),
      ],
      selected: {lang},
      onSelectionChanged: (s) => L10n.set(s.first),
    ),
  );
}

/// Compact globe button with a language menu (for app bars).
class LanguageButton extends StatelessWidget {
  const LanguageButton({super.key});

  @override
  Widget build(BuildContext context) => PopupMenuButton<AppLang>(
    tooltip: tr('Til'),
    icon: const Icon(Icons.language_rounded),
    onSelected: L10n.set,
    itemBuilder: (_) => [
      for (final l in AppLang.values)
        CheckedPopupMenuItem(value: l, checked: l == L10n.lang, child: Text(l.nativeName)),
    ],
  );
}

/// Two-letter language code badge (flag emoji are unreliable on the web).
class _LangBadge extends StatelessWidget {
  final AppLang lang;
  const _LangBadge(this.lang);
  @override
  Widget build(BuildContext context) => Container(
    width: 40,
    height: 30,
    alignment: Alignment.center,
    decoration: BoxDecoration(color: AppColors.primarySoft, borderRadius: BorderRadius.circular(8)),
    child: Text(
      lang.name.toUpperCase(),
      style: const TextStyle(fontWeight: FontWeight.w800, color: AppColors.primary, letterSpacing: 0.5),
    ),
  );
}
