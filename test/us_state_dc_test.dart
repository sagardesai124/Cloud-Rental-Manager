import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:three_zero_two_property/constant/constant.dart';
import 'package:three_zero_two_property/widgets/tenant_pets_vehicles_section.dart';
import 'package:three_zero_two_property/widgets/us_state_dropdown.dart';

// Web added District of Columbia to every State dropdown (usStates.js,
// commit e370745fc). The app's shared list — and every State field built on
// it — must match.
void main() {
  test('District of Columbia sits between Delaware and Florida', () {
    final i = kUsStateNames.indexOf('District of Columbia');
    expect(i, greaterThan(0));
    expect(kUsStateNames[i - 1], 'Delaware');
    expect(kUsStateNames[i + 1], 'Florida');
    expect(kUsStateNames.length, 51);
  });

  test('DC code and name both resolve to the dropdown label', () {
    expect(canonicalUsStateName('DC'), 'District of Columbia');
    expect(canonicalUsStateName('dc'), 'District of Columbia');
    expect(canonicalUsStateName('district of columbia'),
        'District of Columbia');
    expect(canonicalUsStateName('Delaware'), 'Delaware');
    expect(canonicalUsStateName('FL'), 'Florida');
  });

  test('Tenant Vehicle State field offers District of Columbia', () {
    final field = kTenantVehicleFields
        .firstWhere((f) => f.key == 'state');
    expect(field.options, contains('District of Columbia'));
  });

  Widget host(TextEditingController c, {ValueChanged<String>? onChanged}) =>
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: SizedBox(
              width: 200,
              child: UsStateDropdown(controller: c, onChanged: onChanged),
            ),
          ),
        ),
      );

  testWidgets(
      'shared State dropdown lists DC after Delaware and saves the full name',
      (tester) async {
    final c = TextEditingController();
    String? picked;
    await tester.pumpWidget(host(c, onChanged: (v) => picked = v));

    await tester.tap(find.byType(UsStateDropdown));
    await tester.pumpAndSettle();

    await tester.scrollUntilVisible(find.text('District of Columbia'), 60,
        scrollable: find.byType(Scrollable).last);
    await tester.pumpAndSettle();
    // The popup really offers it (order is covered by the list test above).
    final dc = find.text('District of Columbia').last;
    expect(dc, findsOneWidget);

    await tester.tap(dc);
    await tester.pumpAndSettle();

    expect(c.text, 'District of Columbia');
    expect(picked, 'District of Columbia');
    expect(find.text('District of Columbia'), findsOneWidget);
  });

  testWidgets('a stored "DC" value pre-selects District of Columbia',
      (tester) async {
    final c = TextEditingController(text: 'DC');
    await tester.pumpWidget(host(c));
    await tester.pumpAndSettle();
    expect(find.text('District of Columbia'), findsOneWidget);
  });
}
