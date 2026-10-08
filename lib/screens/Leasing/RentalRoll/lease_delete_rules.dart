/// Who may delete a lease, and how — the web rules (RentRoll.jsx
/// `leaseHasStarted` / `deleteTenant`, owner rules 2026-10-04), which the
/// server enforces in LeaseService.deleteLease:
///   - not started yet  → an admin, or staff with Lease delete, with a reason;
///   - already started  → an admin only, as a recorded override with a reason;
///   - with payments    → never; the server says so and the message is shown.
///
/// Shared by the Admin and Staff lease lists so the two can't drift apart.
class LeaseDeleteRules {
  LeaseDeleteRules._();

  /// A lease has started once its start date is today or earlier. An
  /// unreadable date counts as started — the conservative answer, as on the
  /// web and the server. Only the date part is compared, never the time.
  static bool hasStarted(String? startDate, {DateTime? today}) {
    final raw = (startDate ?? '').trim();
    if (raw.isEmpty) return true;
    final parsed = _parseDate(raw);
    if (parsed == null) return true;
    final now = today ?? DateTime.now();
    final startDay = DateTime(parsed.year, parsed.month, parsed.day);
    final todayDay = DateTime(now.year, now.month, now.day);
    return !startDay.isAfter(todayDay);
  }

  /// The formats the web accepts for a lease start date.
  static DateTime? _parseDate(String raw) {
    final text = raw.length > 10 && raw.contains('T') ? raw.substring(0, 10) : raw;
    final iso = DateTime.tryParse(text);
    if (iso != null) return iso;
    // MM/DD/YYYY or M/D/YYYY
    final us = RegExp(r'^(\d{1,2})/(\d{1,2})/(\d{4})$').firstMatch(text);
    if (us != null) {
      return DateTime(
          int.parse(us.group(3)!), int.parse(us.group(1)!), int.parse(us.group(2)!));
    }
    return null;
  }

  /// Shown to staff who tap Delete on a started lease (web `showWarning`).
  static const String staffStartedMessage =
      'This lease has already started. Only an admin can delete it.';

  /// Dialog copy, by whether the lease has started (web swal title/text/button).
  static String title(bool started) =>
      started ? 'This lease has already started' : 'Are you sure?';

  static String description(bool started) => started
      ? 'Only an admin can delete a lease that has started, and the reason '
          'you give is recorded. A lease with payments can\'t be deleted. '
          'Once deleted, the lease can\'t be recovered.'
      : 'Once deleted, you will not be able to recover this lease!';

  static String confirmLabel(bool started) =>
      started ? 'Override and delete' : 'Delete';
}
