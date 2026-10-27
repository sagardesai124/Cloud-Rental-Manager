import 'package:flutter/foundation.dart';

/// The lease-end question asked when a move-out leaves no tenant on a
/// fixed-term lease (web 2.2 owner rule 2026-10-07: a tenant moving out does
/// not end the lease; the property manager's decision does).
///
/// Port of the web's Client/src/utils/moveoutLeaseEnd.js — same rules, same
/// messages. The server mirrors the month-to-month and reason rules in
/// Server/utils/leaseMoveout.js. Older servers ignore `leaseEnd`.

/// The question needs the 2.2 server, which reads `leaseEnd`. Every server
/// the app points at (staging, production, newdev) runs 2.2 now, and staging
/// web asks it too (QA, 2026-10-23), so every build asks.
bool get leaseEndQuestionEnabled => debugLeaseEndQuestionEnabled ?? true;

/// Tests set this to force the question on or off; null = on.
@visibleForTesting
bool? debugLeaseEndQuestionEnabled;

class LeaseEndReason {
  final String value;
  final String label;
  const LeaseEndReason(this.value, this.label);
}

const List<LeaseEndReason> leaseEndReasons = [
  LeaseEndReason('eviction', "Eviction (the sheriff's date)"),
  LeaseEndReason('military_orders', 'Military orders'),
  LeaseEndReason('accepted_notice', 'Notice to vacate accepted'),
  LeaseEndReason('released_from_renewal', 'Released from a renewal'),
  LeaseEndReason('mutual_agreement', 'Mutual agreement'),
  LeaseEndReason('other', 'Other (say why)'),
];

/// Far-future end dates mean "no fixed term" (month-to-month sentinel).
const String _openEndedFrom = '2060-01-01';

const Set<String> _monthToMonthTypes = {
  'at-will(month to month)',
  'at-will',
  'month to month',
  'month-to-month',
  'mtm',
};

/// [d] as yyyy-MM-dd, or '' when it is not a date. Accepts the formats the
/// web accepts (yyyy-MM-dd with an optional time part, MM/dd/yyyy, M/d/yyyy).
/// Callers pass move-out dates already converted with reverseFormatDate.
String leaseEndNormDate(String? d) {
  final s = (d ?? '').trim();
  if (s.isEmpty) return '';
  int? y, m, day;
  final iso = RegExp(r'^(\d{4})-(\d{1,2})-(\d{1,2})').firstMatch(s);
  final us = RegExp(r'^(\d{1,2})/(\d{1,2})/(\d{4})$').firstMatch(s);
  if (iso != null) {
    y = int.parse(iso.group(1)!);
    m = int.parse(iso.group(2)!);
    day = int.parse(iso.group(3)!);
  } else if (us != null) {
    m = int.parse(us.group(1)!);
    day = int.parse(us.group(2)!);
    y = int.parse(us.group(3)!);
  } else {
    return '';
  }
  if (m < 1 || m > 12 || day < 1 || day > 31) return '';
  final dt = DateTime(y, m, day);
  if (dt.month != m || dt.day != day) return ''; // e.g. 2026-02-30
  return '${y.toString().padLeft(4, '0')}-${m.toString().padLeft(2, '0')}-'
      '${day.toString().padLeft(2, '0')}';
}

/// Mirrors the web: At-will types, "At Will", blank, unparseable or sentinel
/// end dates all mean month-to-month (no fixed term to honour).
bool isMonthToMonthLease({
  String? leaseType,
  bool? isMonthToMonth,
  String? endDate,
}) {
  final type = (leaseType ?? '').trim().toLowerCase();
  if (_monthToMonthTypes.contains(type)) return true;
  if (isMonthToMonth == true) return true;
  final raw = (endDate ?? '').trim();
  if (raw.isEmpty) return true;
  if (raw.toLowerCase() == 'at will') return true;
  final end = leaseEndNormDate(raw);
  if (end.isEmpty) return true;
  return end.compareTo(_openEndedFrom) >= 0;
}

/// The latest of the selected tenants' move-out dates, as yyyy-MM-dd.
String latestMoveOutDate(Iterable<String?> moveOutDates) {
  final dates = moveOutDates
      .map(leaseEndNormDate)
      .where((d) => d.isNotEmpty)
      .toList()
    ..sort();
  return dates.isEmpty ? '' : dates.last;
}

/// Ask the question only when this move-out leaves nobody on the lease AND
/// the lease has a written fixed term running past the move-out. A partial
/// move-out leaves the lease running with the remaining tenants; a
/// month-to-month tenancy simply ends at the recorded move-out.
///
/// [activeTenantIds]: tenants still on the lease (not yet moved out).
bool shouldAskLeaseEnd({
  required String? leaseType,
  bool? isMonthToMonth,
  required String? leaseEndDate,
  required Iterable<String?> activeTenantIds,
  required Iterable<String?> selectedTenantIds,
  required Iterable<String?> selectedMoveOutDates,
}) {
  if (!leaseEndQuestionEnabled) return false;
  if (isMonthToMonthLease(
      leaseType: leaseType,
      isMonthToMonth: isMonthToMonth,
      endDate: leaseEndDate)) {
    return false;
  }
  final active =
      activeTenantIds.where((id) => id != null && id.isNotEmpty).toList();
  final selected = selectedTenantIds
      .where((id) => id != null && id.isNotEmpty)
      .toSet();
  if (active.isEmpty || selected.isEmpty) return false;
  if (!active.every(selected.contains)) return false;
  final latest = latestMoveOutDate(selectedMoveOutDates);
  final end = leaseEndNormDate(leaseEndDate);
  if (latest.isEmpty || end.isEmpty) return false;
  return end.compareTo(latest) >= 0;
}

/// The manager's answer. [endsLease] is null until a choice is made.
@immutable
class LeaseEndAnswer {
  final bool? endsLease;

  /// yyyy-MM-dd, or '' for "the latest move-out date".
  final String endsOn;
  final String reason;
  final String reasonText;

  const LeaseEndAnswer({
    this.endsLease,
    this.endsOn = '',
    this.reason = '',
    this.reasonText = '',
  });

  LeaseEndAnswer copyWith({
    bool? endsLease,
    String? endsOn,
    String? reason,
    String? reasonText,
  }) =>
      LeaseEndAnswer(
        endsLease: endsLease ?? this.endsLease,
        endsOn: endsOn ?? this.endsOn,
        reason: reason ?? this.reason,
        reasonText: reasonText ?? this.reasonText,
      );
}

/// The message to show when the answer is missing or incomplete, or '' when
/// the move-out can be submitted. When the question is not asked, ''.
String leaseEndValidationError({
  required bool ask,
  required LeaseEndAnswer? answer,
  required String? leaseStartDate,
  required String? leaseEndDate,
  required Iterable<String?> selectedMoveOutDates,
}) {
  if (!ask) return '';
  if (answer == null || answer.endsLease == null) {
    return 'Say whether this move-out ends the lease, or whether the tenant '
        'stays responsible through the lease term.';
  }
  if (answer.endsLease == true) {
    var endsOn = leaseEndNormDate(answer.endsOn);
    if (endsOn.isEmpty) endsOn = latestMoveOutDate(selectedMoveOutDates);
    if (endsOn.isEmpty) return 'Enter the date the lease ends.';
    final start = leaseEndNormDate(leaseStartDate);
    if (start.isNotEmpty && endsOn.compareTo(start) < 0) {
      return 'The lease cannot end before it started.';
    }
    final term = leaseEndNormDate(leaseEndDate);
    if (term.isNotEmpty && endsOn.compareTo(term) > 0) {
      return 'The lease cannot end after its written term.';
    }
    if (term.isNotEmpty && endsOn != term) {
      if (answer.reason.isEmpty) {
        return 'Choose the reason the lease ends before its written term.';
      }
      if (answer.reason == 'other' && answer.reasonText.trim().isEmpty) {
        return 'Say why the lease ends before its written term.';
      }
    }
  }
  return '';
}

/// What the move-out request sends as `leaseEnd`, or null when the question
/// was not asked. `reason` carries the free text for "other".
Map<String, dynamic>? buildLeaseEndPayload({
  required bool ask,
  required LeaseEndAnswer? answer,
  required Iterable<String?> selectedMoveOutDates,
}) {
  if (!ask || answer == null || answer.endsLease == null) return null;
  if (answer.endsLease == false) return {'ends_lease': false};
  final reason = answer.reason == 'other'
      ? 'other: ${answer.reasonText.trim()}'.trim()
      : answer.reason;
  var endsOn = leaseEndNormDate(answer.endsOn);
  if (endsOn.isEmpty) endsOn = latestMoveOutDate(selectedMoveOutDates);
  return {'ends_lease': true, 'ends_on': endsOn, 'reason': reason};
}

/// Whether a lease's tenants get the Move out / Move In buttons. Same rule as
/// the web's LeaseTenantsTab.jsx: none once the lease has expired (today is
/// after its end date) or it was evicted; a missing or unreadable date (an
/// At-will lease) keeps them.
bool showMoveControls({
  required String? leaseStartDate,
  required String? leaseEndDate,
  bool? isEvicted,
  DateTime? today,
}) {
  if (isEvicted == true) return false;
  if ((leaseStartDate ?? '').trim().isEmpty) return true;
  final end = leaseEndNormDate(leaseEndDate);
  if (end.isEmpty) return true;
  final now = today ?? DateTime.now();
  final todayStr = leaseEndNormDate(
      '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}');
  return todayStr.compareTo(end) <= 0;
}

/// Web shows Move In (instead of Move out) once the tenant has a move-out
/// notice on record.
bool hasMoveOutNotice(String? noticeDate) => (noticeDate ?? '').isNotEmpty;
