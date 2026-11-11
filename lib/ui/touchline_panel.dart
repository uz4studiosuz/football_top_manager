import 'package:flutter/material.dart';
import '../services/touchline_orders.dart';
import '../l10n/l10n.dart';
import '../screens/widgets/team_instructions_view.dart';
import 'widgets.dart';

class TouchlinePanel extends StatelessWidget {
  final Set<String> selected;
  final ValueChanged<String> onToggle;
  final VoidCallback onReset;
  const TouchlinePanel({
    super.key,
    required this.selected,
    required this.onToggle,
    required this.onReset,
  });
  @override
  Widget build(BuildContext context) => DefaultTabController(
    length: 2,
    child: Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 8, 4),
          child: Row(
            children: [
              Icon(Icons.campaign_outlined, color: AppColors.teal),
              const SizedBox(width: 10),
              Expanded(
                child: Text(tr('Murabbiy ko‘rsatmalari'), style: AppText.h3),
              ),
              IconButton(
                tooltip: tr('Yopish'),
                onPressed: () => Navigator.pop(context),
                icon: const Icon(Icons.close),
              ),
            ],
          ),
        ),
        Row(
          children: [
            Expanded(
              child: TabBar(
                labelPadding: const EdgeInsets.symmetric(horizontal: 8),
                tabs: [
                  Tab(text: tr('Jamoa')),
                  Tab(
                    child: FittedBox(child: Text(tr('Individual ko‘rsatma'))),
                  ),
                ],
              ),
            ),
            TextButton.icon(
              onPressed: onReset,
              icon: const Icon(Icons.restart_alt, size: 17),
              label: Text(tr('Tiklash')),
            ),
          ],
        ),
        Expanded(
          child: TabBarView(
            children: [
              ListView.separated(
                padding: const EdgeInsets.symmetric(vertical: 8),
                itemCount: TouchlineOrder.values.length,
                separatorBuilder: (_, _) => Divider(
                  height: 1,
                  color: AppColors.line.withValues(alpha: .45),
                ),
                itemBuilder: (context, i) {
                  final order = TouchlineOrder.values[i],
                      active = selected.contains(order.id);
                  return Material(
                    color: active ? AppColors.primarySoft : Colors.transparent,
                    child: ListTile(
                      minVerticalPadding: 12,
                      leading: Container(
                        width: 38,
                        height: 38,
                        decoration: BoxDecoration(
                          color: AppColors.bg,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Icon(
                          order.icon,
                          color: active ? AppColors.teal : AppColors.ink,
                          size: 22,
                        ),
                      ),
                      title: Text(order.label, style: AppText.bodyStrong),
                      onTap: () => onToggle(order.id),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (active)
                            Icon(
                              Icons.check_circle,
                              color: AppColors.teal,
                              size: 18,
                            ),
                          IconButton(
                            tooltip: order.description,
                            icon: Icon(
                              Icons.info_outline,
                              color: AppColors.ink3,
                              size: 20,
                            ),
                            onPressed: () => showDialog<void>(
                              context: context,
                              builder: (context) => AlertDialog(
                                title: Text(order.label),
                                content: Text(order.description),
                                actions: [
                                  TextButton(
                                    onPressed: () => Navigator.pop(context),
                                    child: Text(tr('Yopish')),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
              const IndividualInstructionsView(),
            ],
          ),
        ),
      ],
    ),
  );
}
