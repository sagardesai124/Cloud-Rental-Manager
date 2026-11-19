import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:three_zero_two_property/provider/dateProvider.dart';

/// Pending Leases (Admin and Staff share Pending_lease.dart) forced Lease
/// Start / Lease End to MM/dd/yyyy. Web (PendingLeases.jsx formatDate) uses
/// `moment(raw, DATE_FORMATS).format(themes.format || "YYYY-MM-DD")` and
/// shows "N/A" for missing or invalid dates.
void main() {
  String fmt(String? raw, String intl) =>
      DateProvider.webDate(raw, dateFormat: intl);

  test('QA 1: YYYY-MM-DD shows 2026-01-15, not 01/15/2026', () {
    expect(fmt('2026-01-15', 'yyyy-MM-dd'), '2026-01-15');
    expect(fmt('2026-01-15T00:00:00.000Z', 'yyyy-MM-dd'), '2026-01-15');
  });

  test('QA 2: DD-MM-YYYY follows the new format', () {
    expect(fmt('2026-01-15', 'dd-MM-yyyy'), '15-01-2026');
    expect(fmt('2027-01-14', 'dd-MM-yyyy'), '14-01-2027');
  });

  test('other web formats and stored shapes', () {
    expect(fmt('2026-01-15', 'MM/dd/yyyy'), '01/15/2026');
    expect(fmt('2026-01-15', 'yyyy-MMM-dd'), '2026-Jan-15');
    expect(fmt('2026-01-15', 'dd/MMM/yyyy'), '15/Jan/2026');
    expect(fmt('01/15/2026', 'yyyy-MM-dd'), '2026-01-15');
    expect(fmt('1/5/2026', 'yyyy-MM-dd'), '2026-01-05');
  });

  test('ISO timestamp keeps its calendar day (no time-zone shift)', () {
    expect(fmt('2026-01-15T23:30:00.000Z', 'yyyy-MM-dd'), '2026-01-15');
  });

  test('missing or invalid dates show N/A, like web', () {
    for (final raw in [null, '', '   ', 'null', 'At Will', 'garbage',
        '2026-13-01', '2026-02-30']) {
      expect(fmt(raw, 'yyyy-MM-dd'), 'N/A', reason: 'raw=$raw');
    }
  });

  test('screen uses the company format, not a fixed MM/dd/yyyy', () {
    final src = File('lib/screens/Leasing/Pending_lease/Pending_lease.dart')
        .readAsStringSync();
    expect(src.contains("DateFormat('MM/dd/yyyy')"), isFalse);
    expect(src.contains('dateProvider.formatWebDate(raw)'), isTrue);
  });
}
