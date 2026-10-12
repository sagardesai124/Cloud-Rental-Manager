import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:three_zero_two_property/screens/Rental/Properties/moveout/lease_end_decision.dart';
import 'package:three_zero_two_property/screens/Rental/Properties/moveout/lease_end_decision_box.dart';

/// The question box behaves like the web's LeaseEndDecision.jsx: Yes shows
/// the end date (defaulting to the latest move-out) and, for an early end, the
/// reason list; "Other" asks for words; No clears the date.

Future<List<LeaseEndAnswer>> _pump(WidgetTester tester,
    {LeaseEndAnswer start = const LeaseEndAnswer()}) async {
  final changes = <LeaseEndAnswer>[];
  var value = start;
  await tester.pumpWidget(MaterialApp(
    home: Scaffold(
      body: SingleChildScrollView(
        child: StatefulBuilder(
          builder: (context, setState) => LeaseEndDecisionBox(
            value: value,
            onChanged: (next) {
              changes.add(next);
              setState(() => value = next);
            },
            leaseStartDate: '2026-10-01',
            leaseEndDate: '2027-09-30',
            selectedMoveOutDates: const ['2026-10-05'],
          ),
        ),
      ),
    ),
  ));
  return changes;
}

void main() {
  testWidgets('shows the web question and both answers', (tester) async {
    await _pump(tester);
    expect(
        find.text(
            'This move-out leaves no tenant on the lease. Does it end the lease?'),
        findsOneWidget);
    expect(find.text('Yes, the lease ends on'), findsOneWidget);
    // No DateProvider in this test, so the term shows as stored.
    expect(find.text('No, the tenant remains responsible through 2027-09-30'),
        findsOneWidget);
    expect(find.byKey(const Key('lease-end-date')), findsNothing);
  });

  testWidgets('Yes defaults the date to the latest move-out and asks why',
      (tester) async {
    final changes = await _pump(tester);
    await tester.tap(find.byKey(const Key('lease-end-yes')));
    await tester.pump();
    expect(changes.last.endsLease, isTrue);
    expect(changes.last.endsOn, '2026-10-05');
    expect(find.text('2026-10-05'), findsOneWidget);
    expect(find.text('Reason the lease ends before 2027-09-30'),
        findsOneWidget);
    expect(find.text('Choose a reason'), findsOneWidget);
  });

  testWidgets('Other asks for words and keeps them', (tester) async {
    final changes = await _pump(tester,
        start: const LeaseEndAnswer(
            endsLease: true, endsOn: '2026-10-05', reason: 'other'));
    await tester.enterText(
        find.byKey(const Key('lease-end-reason-text')), 'bought out');
    await tester.pump();
    expect(changes.last.reason, 'other');
    expect(changes.last.reasonText, 'bought out');
  });

  testWidgets('ending on the term end needs no reason', (tester) async {
    await _pump(tester,
        start: const LeaseEndAnswer(endsLease: true, endsOn: '2027-09-30'));
    expect(find.byKey(const Key('lease-end-reason')), findsNothing);
  });

  testWidgets('No clears the end date', (tester) async {
    final changes = await _pump(tester,
        start: const LeaseEndAnswer(endsLease: true, endsOn: '2026-10-05'));
    await tester.tap(find.byKey(const Key('lease-end-no')));
    await tester.pump();
    expect(changes.last.endsLease, isFalse);
    expect(changes.last.endsOn, '');
    expect(find.byKey(const Key('lease-end-date')), findsNothing);
  });
}
