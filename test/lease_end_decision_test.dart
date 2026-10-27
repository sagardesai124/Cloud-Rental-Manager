import 'package:flutter_test/flutter_test.dart';
import 'package:three_zero_two_property/constant/constant.dart';
import 'package:three_zero_two_property/screens/Rental/Properties/moveout/lease_end_decision.dart';

/// The lease-end question's rules (web 2.2 owner rule 2026-10-07): asked only
/// when a move-out leaves nobody on a fixed-term lease; an early end needs a
/// reason; the payload the server receives. Same cases as the web's
/// Client/src/utils/moveoutLeaseEnd.test.js.

const _type = 'Fixed';
const _start = '2026-10-01';
const _end = '2027-09-30';

bool _ask(List<String> active, List<String> selected,
        {String date = '2026-10-05',
        String? leaseType = _type,
        String? leaseEnd = _end}) =>
    shouldAskLeaseEnd(
      leaseType: leaseType,
      leaseEndDate: leaseEnd,
      activeTenantIds: active,
      selectedTenantIds: selected,
      selectedMoveOutDates: selected.map((_) => date),
    );

String _error(LeaseEndAnswer answer, {bool ask = true}) =>
    leaseEndValidationError(
      ask: ask,
      answer: answer,
      leaseStartDate: _start,
      leaseEndDate: _end,
      selectedMoveOutDates: const ['2026-10-05'],
    );

void main() {
  // These cases are about the question itself, whatever server the build uses.
  setUpAll(() => debugLeaseEndQuestionEnabled = true);
  tearDownAll(() => debugLeaseEndQuestionEnabled = null);

  test('isMonthToMonthLease matches the server rule', () {
    expect(
        isMonthToMonthLease(
            leaseType: 'At-will(month to month)', endDate: '2027-01-01'),
        isTrue);
    expect(isMonthToMonthLease(leaseType: 'Fixed', endDate: '2060-12-31'),
        isTrue);
    expect(
        isMonthToMonthLease(leaseType: 'Fixed', endDate: 'At Will'), isTrue);
    expect(isMonthToMonthLease(leaseType: 'Fixed', endDate: ''), isTrue);
    expect(isMonthToMonthLease(leaseType: 'Fixed', endDate: _end), isFalse);
    expect(isMonthToMonthLease(leaseType: 'Fixed', endDate: '12/31/2027'),
        isFalse);
    expect(
        isMonthToMonthLease(
            leaseType: 'Fixed', isMonthToMonth: true, endDate: _end),
        isTrue);
  });

  group('asked on every server (staging runs 2.2 now, like web)', () {
    late String savedUrl;
    setUp(() {
      savedUrl = Api_url;
      debugLeaseEndQuestionEnabled = null;
    });
    tearDown(() {
      Api_url = savedUrl;
      debugLeaseEndQuestionEnabled = true;
    });

    test('staging build: asked, like staging web', () {
      Api_url = 'https://staging.cloudrentalmanager.com';
      expect(leaseEndQuestionEnabled, isTrue);
      expect(_ask(['A'], ['A']), isTrue);
    });
    test('production and newdev builds: asked', () {
      Api_url = 'https://saas.cloudrentalmanager.com';
      expect(_ask(['A'], ['A']), isTrue);
      Api_url = 'https://newdev.cloudrentalmanager.com';
      expect(_ask(['A'], ['A']), isTrue);
    });
  });

  group('shouldAskLeaseEnd', () {
    test('asks when every active tenant moves out of a fixed term past the move-out',
        () {
      expect(_ask(['A', 'B'], ['A', 'B']), isTrue);
      expect(_ask(['A'], ['A'], date: '10/05/2026'), isTrue);
    });

    test('not for a partial move-out, month-to-month, or a move-out after the term',
        () {
      expect(_ask(['A', 'B'], ['A']), isFalse);
      expect(_ask(['A'], ['A'], leaseType: 'At-will(month to month)'),
          isFalse);
      expect(_ask(['A'], ['A'], date: '2027-10-15'), isFalse);
      expect(_ask([], ['A']), isFalse);
      expect(_ask(['A'], ['A'], leaseType: null, leaseEnd: null), isFalse);
    });

    test("asks on the term's last day too (the answer then needs no reason)",
        () {
      expect(_ask(['A'], ['A'], date: _end), isTrue);
    });
  });

  group('leaseEndValidationError', () {
    test('requires an answer when asked, none when not', () {
      expect(_error(const LeaseEndAnswer()), contains('ends the lease'));
      expect(_error(const LeaseEndAnswer(), ask: false), '');
      expect(_error(const LeaseEndAnswer(endsLease: false)), '');
    });

    test("an early end needs a reason, and 'other' needs words", () {
      expect(_error(const LeaseEndAnswer(endsLease: true, endsOn: '2026-10-05')),
          contains('reason'));
      expect(
          _error(const LeaseEndAnswer(
              endsLease: true,
              endsOn: '2026-10-05',
              reason: 'other',
              reasonText: ' ')),
          contains('why'));
      expect(
          _error(const LeaseEndAnswer(
              endsLease: true, endsOn: '2026-10-05', reason: 'military_orders')),
          '');
      expect(_error(const LeaseEndAnswer(endsLease: true, endsOn: _end)), '');
    });

    test('keeps the end date inside the lease', () {
      expect(
          _error(const LeaseEndAnswer(
              endsLease: true, endsOn: '2026-09-01', reason: 'eviction')),
          contains('before it started'));
      expect(
          _error(const LeaseEndAnswer(
              endsLease: true, endsOn: '2027-10-01', reason: 'eviction')),
          contains('after its written term'));
    });

    test('an empty end date falls back to the latest move-out', () {
      expect(_error(const LeaseEndAnswer(endsLease: true)), contains('reason'));
    });
  });

  group('buildLeaseEndPayload', () {
    test('sends what the server expects, end date defaulting to the latest move-out',
        () {
      expect(
          buildLeaseEndPayload(
              ask: false,
              answer: const LeaseEndAnswer(endsLease: true),
              selectedMoveOutDates: const ['2026-10-05']),
          isNull);
      expect(
          buildLeaseEndPayload(
              ask: true,
              answer: const LeaseEndAnswer(),
              selectedMoveOutDates: const ['2026-10-05']),
          isNull);
      expect(
          buildLeaseEndPayload(
              ask: true,
              answer: const LeaseEndAnswer(endsLease: false),
              selectedMoveOutDates: const ['2026-10-05']),
          {'ends_lease': false});
      expect(
          buildLeaseEndPayload(
              ask: true,
              answer: const LeaseEndAnswer(endsLease: true, reason: 'eviction'),
              selectedMoveOutDates: const ['10/05/2026', '10/05/2026']),
          {'ends_lease': true, 'ends_on': '2026-10-05', 'reason': 'eviction'});
      expect(
          buildLeaseEndPayload(
              ask: true,
              answer: const LeaseEndAnswer(
                  endsLease: true,
                  endsOn: '2026-09-30',
                  reason: 'other',
                  reasonText: 'lease bought out'),
              selectedMoveOutDates: const ['2026-10-05']),
          {
            'ends_lease': true,
            'ends_on': '2026-09-30',
            'reason': 'other: lease bought out'
          });
    });

    test('latestMoveOutDate normalizes mixed formats', () {
      expect(latestMoveOutDate(const ['10/05/2026', '2026-10-31', '']),
          '2026-10-31');
    });
  });

  group('showMoveControls (web LeaseTenantsTab.jsx)', () {
    final today = DateTime(2026, 10, 10);
    bool show(String? start, String? end, {bool? evicted}) =>
        showMoveControls(
            leaseStartDate: start,
            leaseEndDate: end,
            isEvicted: evicted,
            today: today);

    test('hidden once the lease has expired', () {
      expect(show('2025-02-24', '2025-04-29'), isFalse);
      expect(show('2025-02-24', '2026-10-09'), isFalse);
    });
    test('shown while running, on its last day, or before it starts', () {
      expect(show('2026-02-01', '2027-02-28'), isTrue);
      expect(show('2026-02-01', '2026-10-10'), isTrue);
      expect(show('2027-04-02', '2028-04-02'), isTrue);
    });
    test('hidden when evicted', () {
      expect(show('2026-02-01', '2027-02-28', evicted: true), isFalse);
    });
    test('missing or unreadable dates keep the buttons (web getStatus "")', () {
      expect(show('', '2025-04-29'), isTrue);
      expect(show('2025-02-24', 'At Will'), isTrue);
      expect(show('2025-02-24', null), isTrue);
    });
    test('Move In after a notice, Move out before', () {
      expect(hasMoveOutNotice('2025-04-29'), isTrue);
      expect(hasMoveOutNotice(''), isFalse);
      expect(hasMoveOutNotice(null), isFalse);
    });
  });

  test('leaseEndNormDate rejects impossible dates and keeps the date part', () {
    expect(leaseEndNormDate('2026-02-30'), '');
    expect(leaseEndNormDate('2026-10-05T00:00:00.000Z'), '2026-10-05');
    expect(leaseEndNormDate('1/2/2027'), '2027-01-02');
    expect(leaseEndNormDate('not a date'), '');
  });
}
