import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:three_zero_two_property/Model/LeaseLedgerModel.dart';
import 'package:three_zero_two_property/services/app_date_format.dart';
import 'package:three_zero_two_property/services/renewal_term.dart';

/// Web's renewal default (Client/src/utils/renewalTerm.js, live on staging)
/// and the refund date default (LeaseFinancialTab: the payment's entry date).
void main() {
  DateTime d(int y, int m, int day) => DateTime(y, m, day);

  group('parseCalendarDate (web DATE_FORMATS, no timezone shift)', () {
    test('YYYY-MM-DD, with or without a time part', () {
      expect(AppDateFormat.parseCalendarDate('2026-08-31'), d(2026, 8, 31));
      expect(AppDateFormat.parseCalendarDate('2026-08-31T00:00:00.000Z'),
          d(2026, 8, 31));
    });
    test('MM/DD/YYYY and M/D/YYYY', () {
      expect(AppDateFormat.parseCalendarDate('08/31/2026'), d(2026, 8, 31));
      expect(AppDateFormat.parseCalendarDate('8/1/2026'), d(2026, 8, 1));
    });
    test('day-first only when asked (refund legacy values)', () {
      expect(AppDateFormat.parseCalendarDate('31/08/2026'), isNull);
      expect(AppDateFormat.parseCalendarDate('31/08/2026', dayFirstToo: true),
          d(2026, 8, 31));
    });
    test('not a date → null', () {
      for (final v in [null, '', 'At Will', '2026-02-30', '13/45/2026']) {
        expect(AppDateFormat.parseCalendarDate(v), isNull, reason: '$v');
      }
    });
  });

  group('renewalTermEnd (web currentTermEnd)', () {
    test('no renewals → the lease end', () {
      expect(renewalTermEnd(leaseEndDate: '2026-08-31'), d(2026, 8, 31));
    });
    test('the LATEST renewal end, whatever the order', () {
      expect(
          renewalTermEnd(leaseEndDate: '2025-08-31', renewalEndDates: [
            '2027-08-31',
            '2026-08-31',
            '',
          ]),
          d(2027, 8, 31));
    });
    test('nothing readable → null', () {
      expect(renewalTermEnd(leaseEndDate: ''), isNull);
    });
  });

  group('defaultRenewalTerm (web, today = 2026-08-25)', () {
    final today = d(2026, 8, 25);
    test('the day after the term ends, for a year (web example)', () {
      final t = defaultRenewalTerm(d(2026, 8, 31), today: today)!;
      expect(t.start, d(2026, 9, 1));
      expect(t.end, d(2027, 8, 31));
    });
    test('a term ending today still starts tomorrow', () {
      final t = defaultRenewalTerm(today, today: today)!;
      expect(t.start, d(2026, 8, 26));
      expect(t.end, d(2027, 8, 25));
    });
    test('a lapsed term renews from today', () {
      final t = defaultRenewalTerm(d(2026, 8, 1), today: today)!;
      expect(t.start, today);
      expect(t.end, d(2027, 8, 24));
    });
    test('leap day start: moment add(1, "year") → Feb 28, minus a day', () {
      final t = defaultRenewalTerm(d(2028, 2, 28), today: today)!;
      expect(t.start, d(2028, 2, 29));
      expect(t.end, d(2029, 2, 27));
    });
    test('unknown term end → no default', () {
      expect(defaultRenewalTerm(null, today: today), isNull);
    });
  });

  group('renewPickerRange (web DatePicker minDate)', () {
    final today = d(2026, 10, 29);
    tearDown(() => AppDateFormat.set(kDefaultAppDateFormat));
    test('Lease Start: from the day after the lease end, opens on the box', () {
      AppDateFormat.set('MM/dd/yyyy');
      final r = renewPickerRange('02/07/2027',
          after: d(2027, 2, 6), today: today);
      expect(r.first, d(2027, 2, 7));
      expect(r.initial, d(2027, 2, 7));
      expect(r.last, d(2101, 1, 1));
    });
    test('a box date before the first day opens on the first day', () {
      AppDateFormat.set('MM/dd/yyyy');
      final r = renewPickerRange('01/01/2027',
          after: d(2027, 2, 6), today: today);
      expect(r.initial, d(2027, 2, 7));
    });
    test('empty box opens on today (inside the range)', () {
      final r = renewPickerRange('', after: d(2026, 1, 1), today: today);
      expect(r.first, d(2026, 1, 2));
      expect(r.initial, today);
    });
    test('no bound → any day from 2000, as before', () {
      expect(renewPickerRange('', today: today).first, d(2000, 1, 1));
    });
    test('renewBoxDay reads the company format and yyyy-MM-dd', () {
      AppDateFormat.set('dd/MMM/yyyy');
      expect(renewBoxDay('07/Feb/2027'), d(2027, 2, 7));
      expect(renewBoxDay('2027-02-07'), d(2027, 2, 7));
      expect(renewBoxDay(''), isNull);
    });
  });

  group('Refund Date default: the payment\'s own date', () {
    test('first entry date, like web (entry[0].date)', () {
      expect(Data(entry: [Entry(date: '2026-10-05')]).paymentDate,
          '2026-10-05');
      expect(Data(entry: []).paymentDate, isNull);
      expect(Data().paymentDate, isNull);
    });
    test('the three refund dialogs pre-fill from it', () {
      for (final path in [
        'lib/screens/Leasing/RentalRoll/Financial.dart',
        'lib/StaffModule/screen/Leasing/RentalRoll/Financial.dart',
        'lib/StaffModule/screen/Rental/Tenants/Payments/Tenant_payments.dart',
      ]) {
        final code = File(path).readAsStringSync();
        expect(
            code,
            contains('AppDateFormat.parseCalendarDate(data.paymentDate,'),
            reason: path);
        // Today when an entry carries no date.
        expect(
            RegExp(r'parseCalendarDate\(data\.paymentDate,\s*dayFirstToo: true\) \?\?\s*DateTime\.now\(\)\)')
                .hasMatch(code),
            isTrue,
            reason: '$path falls back to today');
      }
    });
  });
}
