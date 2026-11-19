import 'package:flutter_test/flutter_test.dart';
import 'package:three_zero_two_property/Model/schduled_charge.dart';

/// Edit Scheduled Charge must open with the charge's real frequency, like web
/// staging's Manage Charges (`rent_cycle === "Weekly" ? "Weekly" : "Monthly"`).
/// The server treats anything but "Weekly" as Monthly, so a Weekly charge
/// shown as Monthly would be switched and lose its other weekly charges.
void main() {
  group('frequency', () {
    test('lease list: rent_cycle Weekly → Weekly', () {
      final c = ScheduledCharges.fromJson({
        'task_type': 'WEEKLY_CHARGE',
        'charge_type': 'Recurring Charge',
        'rent_cycle': 'Weekly',
        'is_recurring': true,
      });
      expect(c.frequency, 'Weekly');
      expect(c.recurring, isTrue);
    });

    test('all-charges list: no rent_cycle, WEEKLY_CHARGE → Weekly', () {
      final c = ScheduledCharges.fromJson({
        'task_type': 'WEEKLY_CHARGE',
        'charge_type': 'Recurring Charge',
      });
      expect(c.frequency, 'Weekly');
      expect(c.recurring, isTrue);
    });

    test('Monthly charge stays Monthly', () {
      final lease = ScheduledCharges.fromJson(
          {'task_type': 'MONTHLY_CHARGE', 'rent_cycle': 'Monthly'});
      final all = ScheduledCharges.fromJson({'task_type': 'MONTHLY_CHARGE'});
      expect(lease.frequency, 'Monthly');
      expect(all.frequency, 'Monthly');
      expect(all.recurring, isTrue);
    });

    test('one-time charge: not recurring, frequency defaults to Monthly', () {
      final c = ScheduledCharges.fromJson({
        'task_type': 'SCHEDULED_CHARGE',
        'charge_type': 'One Time Charge',
      });
      expect(c.recurring, isFalse);
      expect(c.frequency, 'Monthly');
    });

    test('is_recurring from the server wins when sent', () {
      final c = ScheduledCharges.fromJson({
        'task_type': 'SCHEDULED_CHARGE',
        'charge_type': 'Recurring Charge',
        'is_recurring': false,
      });
      expect(c.recurring, isFalse);
    });
  });
}
