import 'package:flutter/material.dart';

import '../../app/routes.dart';
import '../../app/service_locator.dart';
import '../../models/analysis_record.dart';
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
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Clear history?'),
        content: const Text(
          'All stored analyses will be removed from this device.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Clear'),
          ),
        ],
      ),
    );
    if (confirmed == true && context.mounted) {
      AppServices.of(context).historyRepository.clear();
    }
  }

  @override
  Widget build(BuildContext context) {
    final history = AppServices.of(context).historyRepository;

    return Scaffold(
      appBar: AppBar(
        title: const Text('History'),
        actions: [
          ListenableBuilder(
            listenable: history,
            builder: (context, _) => IconButton(
              tooltip: 'Clear history',
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
                            ? 'No analyses yet'
                            : 'Nothing in this filter',
                        message: all.isEmpty
                            ? 'Every X-ray you analyse is saved here with its '
                                  'verdict, confidence and date.'
                            : 'Try a different filter to see your other '
                                  'studies.',
                        action: all.isEmpty
                            ? FilledButton.icon(
                                onPressed: () => Navigator.pushNamed(
                                  context,
                                  AppRoutes.analyze,
                                ),
                                icon: const Icon(Icons.biotech_outlined),
                                label: const Text('Analyze X-ray'),
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
                            child: AnalysisTile(
                              record: record,
                              onTap: () => Navigator.pushNamed(
                                context,
                                AppRoutes.result,
                                arguments: record,
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
