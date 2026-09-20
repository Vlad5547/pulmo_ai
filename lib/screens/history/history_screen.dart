import 'dart:async';

import 'package:flutter/material.dart';

import '../../app/routes.dart';
import '../../app/service_locator.dart';
import '../../l10n/generated/app_localizations.dart';
import '../../models/analysis_record.dart';
import '../../services/history_repository.dart';
import '../../widgets/analysis_tile.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/responsive_content.dart';
import 'widgets/history_filter_bar.dart';

class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  HistoryFilter _filter = HistoryFilter.all;

  List<AnalysisRecord> _apply(List<AnalysisRecord> records) {
    return switch (_filter) {
      HistoryFilter.all => records,
      HistoryFilter.findings =>
        records.where((r) => r.result.isPositive).toList(),
      HistoryFilter.clear =>
        records.where((r) => !r.result.isPositive).toList(),
    };
  }

  Future<void> _confirmClear(BuildContext context) async {
    final l10n = AppL10n.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.historyClearQuestion),
        content: Text(l10n.historyClearBody),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(l10n.actionCancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(l10n.actionClear),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;
    await AppServices.of(context).historyRepository.clear();
  }

  /// Takes what it needs as arguments rather than looking anything up in a
  /// `BuildContext`.
  ///
  /// `Dismissible.onDismissed` fires while the tile is being removed from the
  /// tree, so its context is on its way to being defunct; resolving an
  /// inherited widget from it is a race that usually works and sometimes
  /// throws.
  Future<void> _delete(
    HistoryRepository history,
    ScaffoldMessengerState messenger,
    AppL10n l10n,
    AnalysisRecord record,
  ) async {
    await history.remove(record.id);
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(content: Text(l10n.historyRemoved(record.imageName))),
      );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppL10n.of(context);
    final history = AppServices.of(context).historyRepository;
    final messenger = ScaffoldMessenger.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.historyTitle),
        actions: [
          ListenableBuilder(
            listenable: history,
            builder: (context, _) => IconButton(
              tooltip: l10n.historyClearTooltip,
              onPressed: history.isEmpty ? null : () => _confirmClear(context),
              icon: const Icon(Icons.delete_sweep_outlined),
            ),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: ListenableBuilder(
        listenable: history,
        builder: (context, _) {
          // "Not read from disk yet" is not the same as "nothing analysed
          // yet": showing the empty state during the read would tell the user
          // their history is gone.
          if (!history.isLoaded) {
            return const Center(child: CircularProgressIndicator());
          }
          final all = history.records;
          final visible = _apply(all);

          return Column(
            children: [
              ResponsiveContent(
                padding: const EdgeInsets.fromLTRB(20, 4, 20, 12),
                child: HistoryFilterBar(
                  selected: _filter,
                  counts: {
                    HistoryFilter.all: all.length,
                    HistoryFilter.findings: all
                        .where((r) => r.result.isPositive)
                        .length,
                    HistoryFilter.clear: all
                        .where((r) => !r.result.isPositive)
                        .length,
                  },
                  onChanged: (filter) => setState(() => _filter = filter),
                ),
              ),
              Expanded(
                child: visible.isEmpty
                    ? EmptyState(
                        icon: all.isEmpty
                            ? Icons.folder_open_outlined
                            : Icons.filter_alt_off_outlined,
                        title: all.isEmpty
                            ? l10n.historyEmptyTitle
                            : l10n.historyFilterEmptyTitle,
                        message: all.isEmpty
                            ? l10n.historyEmptyText
                            : l10n.historyFilterEmptyText,
                        action: all.isEmpty
                            ? FilledButton.icon(
                                onPressed: () => unawaited(
                                  Navigator.pushNamed(
                                    context,
                                    AppRoutes.analyze,
                                  ),
                                ),
                                icon: const Icon(Icons.biotech_outlined),
                                label: Text(l10n.analyzeTitle),
                              )
                            : null,
                      )
                    : ListView.separated(
                        padding: EdgeInsets.zero,
                        itemCount: visible.length,
                        separatorBuilder: (_, _) => const SizedBox.shrink(),
                        itemBuilder: (context, index) {
                          final record = visible[index];
                          return ResponsiveContent(
                            padding: EdgeInsets.fromLTRB(
                              20,
                              0,
                              20,
                              index == visible.length - 1 ? 24 : 10,
                            ),
                            child: Dismissible(
                              key: ValueKey(record.id),
                              direction: DismissDirection.endToStart,
                              background: const _DeleteBackground(),
                              onDismissed: (_) => unawaited(
                                _delete(history, messenger, l10n, record),
                              ),
                              child: AnalysisTile(
                                record: record,
                                onTap: () => unawaited(
                                  Navigator.pushNamed(
                                    context,
                                    AppRoutes.result,
                                    arguments: record,
                                  ),
                                ),
                              ),
                            ),
                          );
                        },
                      ),
              ),
            ],
          );
        },
      ),
    );
  }
}

/// Red "delete" strip revealed when a history entry is swiped away.
class _DeleteBackground extends StatelessWidget {
  const _DeleteBackground();

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Container(
      decoration: BoxDecoration(
        color: colors.errorContainer,
        borderRadius: BorderRadius.circular(18),
      ),
      alignment: Alignment.centerRight,
      padding: const EdgeInsets.only(right: 22),
      child: Icon(Icons.delete_outline, color: colors.onErrorContainer),
    );
  }
}
