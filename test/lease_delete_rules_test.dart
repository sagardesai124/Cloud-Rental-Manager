import 'package:flutter_test/flutter_test.dart';
import 'package:three_zero_two_property/screens/Leasing/RentalRoll/lease_delete_rules.dart';

/// The lease-delete rule and dialog copy, matched to web (RentRoll.jsx
/// `leaseHasStarted` / `deleteTenant`, development-2.2): a lease has started
/// once its start date is today or earlier; an unreadable date counts as
/// started, as on web and the server (LeaseService.leaseHasStarted).
void main() {
  final today = DateTime(2026, 10, 7, 15, 30); // time of day must not matter

  group('hasStarted', () {
    test('a future start date has not started', () {
      expect(LeaseDeleteRules.hasStarted('2026-10-08', today: today), isFalse);
      expect(LeaseDeleteRules.hasStarted('2032-06-02', today: today), isFalse);
    });

    test('today counts as started (web: !start.isAfter(today, "day"))', () {
      expect(LeaseDeleteRules.hasStarted('2026-10-07', today: today), isTrue);
    });

    test('a past start date has started, even if the lease has ended', () {
      expect(LeaseDeleteRules.hasStarted('2026-02-01', today: today), isTrue);
      expect(LeaseDeleteRules.hasStarted('2025-01-24', today: today), isTrue);
    });

    test('accepts the web date formats', () {
      expect(LeaseDeleteRules.hasStarted('10/08/2026', today: today), isFalse);
      expect(LeaseDeleteRules.hasStarted('1/5/2026', today: today), isTrue);
      expect(
          LeaseDeleteRules.hasStarted('2026-10-08T00:00:00.000Z', today: today),
          isFalse);
    });

    test('an unreadable or missing date counts as started', () {
      expect(LeaseDeleteRules.hasStarted(null, today: today), isTrue);
      expect(LeaseDeleteRules.hasStarted('', today: today), isTrue);
      expect(LeaseDeleteRules.hasStarted('At Will', today: today), isTrue);
    });
  });

  group('dialog copy matches web', () {
    test('not started', () {
      expect(LeaseDeleteRules.title(false), 'Are you sure?');
      expect(LeaseDeleteRules.description(false),
          'Once deleted, you will not be able to recover this lease!');
      expect(LeaseDeleteRules.confirmLabel(false), 'Delete');
    });

    test('started (admin override)', () {
      expect(LeaseDeleteRules.title(true), 'This lease has already started');
      expect(LeaseDeleteRules.description(true), contains('reason you give is recorded'));
      expect(LeaseDeleteRules.description(true), contains("payments can't be deleted"));
      expect(LeaseDeleteRules.confirmLabel(true), 'Override and delete');
      expect(LeaseDeleteRules.staffStartedMessage,
          'This lease has already started. Only an admin can delete it.');
    });
  });
}
