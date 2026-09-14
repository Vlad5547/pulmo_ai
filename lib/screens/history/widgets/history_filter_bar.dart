import 'package:flutter/material.dart';

enum HistoryFilter {
  all('All'),
  findings('Findings'),
  clear('Clear');

  const HistoryFilter(this.label);

  final String label;
}

/// Segmented filter over the stored analyses, with a count per bucket.
class HistoryFilterBar extends StatelessWidget {
  const HistoryFilterBar({
    super.key,
    required this.selected,
    required this.counts,
    required this.onChanged,
  });

  final HistoryFilter selected;
  final Map<HistoryFilter, int> counts;
  final ValueChanged<HistoryFilter> onChanged;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          for (final filter in HistoryFilter.values)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: ChoiceChip(
                selected: filter == selected,
                onSelected: (_) => onChanged(filter),
                label: Text('${filter.label} · ${counts[filter] ?? 0}'),
                showCheckmark: false,
              ),
            ),
        ],
      ),
    );
  }
}
