import 'package:intl/intl.dart';

import '../l10n/generated/app_localizations.dart';

/// Date / duration helpers.
///
/// Formatting goes through `intl` with the active locale: a date rendered as
/// "14 Sep 2026" in English has to read "14 вер. 2026" in Ukrainian and
/// "14. Sept. 2026" in German, and month abbreviations cannot be hard-coded.
String formatDateTime(DateTime value, String locale) =>
    DateFormat.yMMMd(locale).add_Hm().format(value.toLocal());

String formatDate(DateTime value, String locale) =>
    DateFormat.yMMMd(locale).format(value.toLocal());

/// "3 min ago" and friends, falling back to the absolute date after a week.
String formatRelative(DateTime value, AppL10n l10n, String locale) {
  final diff = DateTime.now().difference(value);
  if (diff.inMinutes < 1) return l10n.timeJustNow;
  if (diff.inMinutes < 60) return l10n.timeMinutesAgo(diff.inMinutes);
  if (diff.inHours < 24) return l10n.timeHoursAgo(diff.inHours);
  if (diff.inDays < 7) return l10n.timeDaysAgo(diff.inDays);
  return formatDate(value, locale);
}

String formatDuration(Duration value) =>
    '${(value.inMilliseconds / 1000).toStringAsFixed(2)} s';
