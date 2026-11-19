/// Leasing → Leases → lease → Lease History, Admin and Staff, like web
/// staging (components/RentRollDetail/LeaseSummaryTab.jsx): the search box
/// (filterLeaseHistory), the page sizes and "All" (CommonPagination) and the
/// description as web shows it (formatDaysInText + formatCurrencyInText).
library;

import 'package:intl/intl.dart';

import '../Model/history_item_model.dart';
import 'app_date_format.dart';

/// Web's hint in the Lease History search box.
const String leaseHistorySearchHint = 'Search type, action, or description';

/// Web's messages when there is nothing to list.
const String leaseHistoryEmptyMessage = 'No history available for this lease';
const String leaseHistoryNoMatchMessage = 'No history matches your search';

/// Web's page sizes, after "All".
const List<int> leaseHistoryPageSizes = [5, 10, 25, 50, 100];

/// The page size chosen on Lease History, remembered like web's per-screen
/// page-size preference ("All" is not remembered).
const String leaseHistoryPageSizeKey = 'page_size_lease_history';

// A stored day inside prose ("2026-10-09" or "10/9/2026") as a whole token,
// not the date part of a timestamp — web's DAY_IN_TEXT.
final RegExp _dayInText = RegExp(
    r'(^|[^\d/-])(\d{4}-\d{2}-\d{2}|\d{1,2}/\d{1,2}/\d{4})(?![\d/-]|[T ]\d)');

DateTime? _parseStoredDay(String token) {
  for (final pattern in const ['yyyy-MM-dd', 'M/d/yyyy']) {
    try {
      return DateFormat(pattern).parseStrict(token);
    } catch (_) {}
  }
  return null;
}

/// Stored days quoted inside a description, rewritten in the app's date
/// format, like web's formatDaysInText (moment's format, so a custom format
/// with the day of the year shows as on web). A token that doesn't parse is
/// left as written.
String formatDaysInText(String text, String datePattern) =>
    text.replaceAllMapped(_dayInText, (m) {
      final day = _parseStoredDay(m[2]!);
      return day == null
          ? m[0]!
          : '${m[1]}${AppDateFormat.format(day, datePattern)}';
    });

// "$" + optional minus + digits + at most 2 decimals — web's AMOUNT_IN_TEXT.
final RegExp _amountInText = RegExp(
    r'(^|[^\w$])(-?)\$(-?)(\d{1,3}(?:,\d{3})+|\d+)(\.\d{1,2})?(?!\d|,\d|\.\d)');
final NumberFormat _usd = NumberFormat('#,##0.00', 'en_US');

/// Every dollar amount inside a description as $#,###.##, negatives in
/// parentheses, like web's formatCurrencyInText.
String formatCurrencyInText(String text) =>
    text.replaceAllMapped(_amountInText, (m) {
      final n = double.tryParse('${m[4]!.replaceAll(',', '')}${m[5] ?? ''}');
      if (n == null) return m[0]!;
      final negative =
          ((m[2] ?? '').isNotEmpty || (m[3] ?? '').isNotEmpty) && n != 0;
      final money = '\$${_usd.format(n)}';
      return '${m[1]}${negative ? '($money)' : money}';
    });

/// A Lease History description as web shows it.
String leaseHistoryShownDescription(String description, String datePattern) =>
    formatCurrencyInText(formatDaysInText(description, datePattern));

/// Web's filterLeaseHistory: an empty search lists everything; otherwise a
/// row is kept when its category, type, action, description (as shown),
/// who made the change or the date shown contains the search, ignoring
/// upper and lower case.
bool leaseHistoryMatches(
  HistoryItem item,
  String search, {
  required String shownDate,
  required String datePattern,
}) {
  if (search.isEmpty) return true;
  final q = search.toLowerCase();
  bool has(String text) => text.toLowerCase().contains(q);
  return has(item.category) ||
      has(item.type) ||
      has(item.action) ||
      has(leaseHistoryShownDescription(item.description, datePattern)) ||
      has(item.username) ||
      has(shownDate);
}
