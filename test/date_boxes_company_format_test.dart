import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:intl/intl.dart';
import 'package:three_zero_two_property/constant/constant.dart';
import 'package:three_zero_two_property/services/app_date_format.dart';

/// Renew Lease, Edit Lease (phone pickers), Add Lease (End Date), the
/// Refund Date (Financial) and Staff Payments' refund date now fill their
/// date boxes like web's DatePicker: the company's date format on screen,
/// read back to yyyy-MM-dd on save.
///
/// Before, they wrote "dd-MM-yyyy" (or yyyy-MM-dd). With a custom company
/// format such as MM-DD-YYYY the save read "05-10-2026" back as May 10, so
/// days 1-12 were sent with day and month swapped.

const _screens = [
  'lib/screens/Leasing/RentalRoll/RenewLease.dart',
  'lib/StaffModule/screen/Leasing/RentalRoll/RenewLease.dart',
  'lib/screens/Leasing/RentalRoll/edit_lease.dart',
  'lib/StaffModule/screen/Leasing/RentalRoll/edit_lease.dart',
  'lib/screens/Leasing/RentalRoll/newAddLease.dart',
  'lib/screens/Leasing/RentalRoll/Financial.dart',
  'lib/StaffModule/screen/Leasing/RentalRoll/Financial.dart',
  'lib/StaffModule/screen/Rental/Tenants/Payments/Tenant_payments.dart',
];

/// Every day of a year, plus a leap day.
final _days = [
  for (var d = DateTime(2026, 1, 1);
      d.year == 2026;
      d = DateTime(d.year, d.month, d.day + 1))
    d,
  DateTime(2028, 2, 29),
];

String _api(DateTime d) => DateFormat('yyyy-MM-dd').format(d);

/// The source with // comments dropped, so only live code is checked.
String _code(String path) => File(path)
    .readAsLinesSync()
    .where((l) => !l.trimLeft().startsWith('//'))
    .join('\n');

void main() {
  tearDown(() => AppDateFormat.set(kDefaultAppDateFormat));

  // Presets, then custom formats web accepts (MM-DD-YYYY and DD/MM/YYYY are
  // the ones the old dd-MM-yyyy / MM/dd/yyyy text was misread under).
  for (final format in [
    'MM/dd/yyyy',
    'yyyy-MM-dd',
    'yyyy-MMM-dd',
    'MM-dd-yyyy',
    'dd/MM/yyyy',
    'dd/MMM/yyyy',
    'M/d/yyyy',
    'dd-MM-yyyy',
    'yyyy/MM/dd',
    'dd.MM.yyyy',
  ]) {
    test('company $format: every day a box shows reads back to that day', () {
      AppDateFormat.set(format);
      for (final day in _days) {
        final shown = AppDateFormat.format(day);
        expect(reverseFormatDate(shown), _api(day),
            reason: '$format "$shown" (save via reverseFormatDate)');
        expect(AppDateFormat.parseToApi(shown), _api(day),
            reason: '$format "$shown" (Edit Lease local parse)');
      }
    });
  }

  test('the old dd-MM-yyyy text was misread under a custom MM-DD-YYYY', () {
    AppDateFormat.set('MM-dd-yyyy');
    final oct5 = DateTime(2026, 10, 5);
    expect(reverseFormatDate(DateFormat('dd-MM-yyyy').format(oct5)),
        '2026-05-10',
        reason: 'why the boxes no longer use dd-MM-yyyy');
    expect(reverseFormatDate(AppDateFormat.format(oct5)), '2026-10-05');
  });

  test('Admin Edit Lease reads its Start box in the company format first', () {
    // Picking an End Date works the rent cycle options out from the Start
    // box, which shows the company's date format.
    final code = _code('lib/screens/Leasing/RentalRoll/edit_lease.dart');
    final fn = code.indexOf('String reverseFormatDate(String inputDate) {');
    expect(fn, isNonNegative);
    expect(code.substring(fn, fn + 300),
        contains('AppDateFormat.parseToApi(inputDate)'));
  });

  test('none of these screens fills a date box with dd-MM-yyyy any more', () {
    final handBuilt = RegExp(r"\$\{(pickedDate|endDate)\.day\.toString\(\)"
        r"\.padLeft\(2, '0'\)\}-\$\{\1\.month");
    for (final path in _screens) {
      final code = _code(path);
      // A hand-built "dd-MM-yyyy" string may only remain where it is never
      // shown (the unused formattedEndDate copies in Add/Edit Lease).
      for (final m in handBuilt.allMatches(code)) {
        final line = code.substring(0, m.start).split('\n').last;
        final next = code.substring(m.start).split('\n').first;
        expect('$line$next', isNot(contains('pickedDate')),
            reason: '$path still builds a dd-MM-yyyy picked date');
      }
      expect(code, isNot(contains("DateFormat('dd-MM-yyyy').format(pickedDate)")),
          reason: path);
    }
    // Renew Lease and the refund dates are filled in the company format.
    for (final path in _screens.where((p) => p.endsWith('RenewLease.dart'))) {
      expect(_code(path), isNot(contains('formatDate4(')), reason: path);
      expect(_code(path), contains('AppDateFormat.format(term.start)'),
          reason: path);
      expect(_code(path), contains('AppDateFormat.format(term.end)'),
          reason: path);
    }
    for (final path in _screens.where((p) =>
        p.endsWith('Financial.dart') || p.endsWith('Tenant_payments.dart'))) {
      expect(
          _code(path), contains('_dateController.text = AppDateFormat.format('),
          reason: '$path refund date pre-fill');
    }
  });
}
