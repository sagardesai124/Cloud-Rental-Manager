import 'app_date_format.dart';

/// Default dates for a lease renewal, as web (Client/src/utils/renewalTerm.js,
/// live on staging): the renewal starts the day AFTER the current term ends
/// and runs a full year from there (start + 1 year - 1 day), so a term ending
/// 2026-08-31 renews 2026-09-01 to 2027-08-31. A term that has already lapsed
/// renews from today instead. Starting on the end date itself overlaps the
/// previous term, which the server refuses ("Lease has already been renewed
/// for the given date range.").

/// The day the current term runs out: the latest end date among the lease's
/// renewals, else the lease's own end date (web's currentTermEnd).
DateTime? renewalTermEnd({
  String? leaseEndDate,
  Iterable<String?> renewalEndDates = const [],
}) {
  DateTime? latest;
  for (final value in renewalEndDates) {
    final end = AppDateFormat.parseCalendarDate(value);
    if (end != null && (latest == null || end.isAfter(latest))) latest = end;
  }
  return latest ?? AppDateFormat.parseCalendarDate(leaseEndDate);
}

/// Web's defaultRenewalTerm; null when [termEnd] is unknown. [today] is for
/// tests.
({DateTime start, DateTime end})? defaultRenewalTerm(DateTime? termEnd,
    {DateTime? today}) {
  if (termEnd == null) return null;
  final now = today ?? DateTime.now();
  final todayDay = DateTime(now.year, now.month, now.day);
  final end = DateTime(termEnd.year, termEnd.month, termEnd.day);
  final start = end.isBefore(todayDay)
      ? todayDay
      : DateTime(end.year, end.month, end.day + 1);
  final yearOn = _addYear(start);
  return (
    start: start,
    end: DateTime(yearOn.year, yearOn.month, yearOn.day - 1),
  );
}

/// The days a Renew Lease calendar offers, like web's DatePicker minDate
/// (LeaseSummaryTab, live on staging): Lease Start from the day after the
/// lease's end date, Lease End from the day after the start date ([after] is
/// that day). It opens on the box's date ([shown]) kept inside the range,
/// else on today.
({DateTime first, DateTime last, DateTime initial}) renewPickerRange(
    String shown,
    {DateTime? after,
    DateTime? today}) {
  final last = DateTime(2101);
  var first = after == null
      ? DateTime(2000)
      : DateTime(after.year, after.month, after.day + 1);
  if (first.isAfter(last)) first = last;
  final now = today ?? DateTime.now();
  var initial = renewBoxDay(shown) ?? DateTime(now.year, now.month, now.day);
  if (initial.isBefore(first)) initial = first;
  if (initial.isAfter(last)) initial = last;
  return (first: first, last: last, initial: initial);
}

/// A date box's day (shown in the company's date format, or yyyy-MM-dd), or
/// null when the box is empty or unreadable.
DateTime? renewBoxDay(String shown) {
  final api = AppDateFormat.parseToApi(shown);
  return api == null ? null : DateTime.tryParse(api);
}

/// moment's add(1, "year"): Feb 29 becomes Feb 28.
DateTime _addYear(DateTime date) {
  final lastDay = DateTime(date.year + 1, date.month + 1, 0).day;
  return DateTime(
      date.year + 1, date.month, date.day > lastDay ? lastDay : date.day);
}
