import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:three_zero_two_property/Model/lease.dart';
import 'package:three_zero_two_property/widgets/tenant_pets_vehicles_section.dart';

void main() {
  group('payload', () {
    test('pet row uses web keys, trims, drops blank rows', () {
      final filled = TenantSubdocRow.pet()
        ..text['name']!.text = '  Rex '
        ..text['weight']!.text = '40'
        ..select['sex'] = 'Male';
      final blank = TenantSubdocRow.pet();
      final out = tenantSubdocPayload([filled, blank]);
      expect(out.length, 1);
      expect(out.first.keys.toList(), [
        'name', 'type', 'breed', 'color', 'weight', 'height', 'age',
        'sex', 'neutered', 'declawed'
      ]);
      expect(out.first['name'], 'Rex');
      expect(out.first['sex'], 'Male');
      expect(out.first['neutered'], '');
    });

    test('vehicle row uses web keys and full state name', () {
      final v = TenantSubdocRow.vehicle()
        ..text['make_model']!.text = 'Honda Civic'
        ..select['state'] = 'California';
      final out = tenantSubdocPayload([v]);
      expect(out.first.keys.toList(),
          ['make_model', 'year', 'color', 'license_plate', 'state']);
      expect(out.first['state'], 'California');
    });

    test('hydrate from server json skips blank and non-map rows', () {
      final rows = tenantSubdocRowsFromJson([
        {'name': 'Rex', 'sex': 'Male', '_id': 'x'},
        {'name': ''},
        'junk',
      ], kTenantPetFields);
      expect(rows.length, 1);
      expect(rows.first.text['name']!.text, 'Rex');
      expect(rows.first.select['sex'], 'Male');
      expect(tenantSubdocRowsFromJson(null, kTenantPetFields), isEmpty);
    });

    test('lease TenantData sends pets/vehicles only when set', () {
      expect(TenantData().toJson().containsKey('pets'), isFalse);
      final j = TenantData(pets: [
        {'name': 'Rex'}
      ], vehicles: const []).toJson();
      expect(j['pets'], [
        {'name': 'Rex'}
      ]);
      expect(j['vehicles'], isEmpty);
    });
  });

  group('widget', () {
    Widget host(List<TenantSubdocRow> rows, {bool vehicles = false}) =>
        MaterialApp(
          home: Scaffold(
            body: StatefulBuilder(
              builder: (context, setState) => SingleChildScrollView(
                child: vehicles
                    ? TenantSubdocSection.vehicles(
                        rows: rows, onChanged: () => setState(() {}))
                    : TenantSubdocSection.pets(
                        rows: rows, onChanged: () => setState(() {})),
              ),
            ),
          ),
        );

    testWidgets('empty state, add, remove keeps other row text',
        (tester) async {
      final rows = <TenantSubdocRow>[];
      await tester.pumpWidget(host(rows));
      expect(find.textContaining('No pets added.'), findsOneWidget);

      await tester.tap(find.text('Add Pet'));
      await tester.pump();
      await tester.tap(find.text('Add Pet'));
      await tester.pump();
      expect(find.text('Pet #1'), findsOneWidget);
      expect(find.text('Pet #2'), findsOneWidget);
      expect(find.text('Full Grown Height'), findsNWidgets(2));
      expect(find.text('Spayed / Neutered'), findsNWidgets(2));

      rows[1].text['name']!.text = 'Second';
      await tester.pump();
      await tester.tap(find.byIcon(Icons.delete_outline).first);
      await tester.pumpAndSettle();
      expect(rows.length, 1);
      expect(find.text('Pet #2'), findsNothing);
      expect(find.text('Second'), findsOneWidget);
    });

    testWidgets('vehicle state keeps an unknown saved value', (tester) async {
      final rows = [
        TenantSubdocRow.vehicle({'state': 'Puerto Rico'})
      ];
      await tester.pumpWidget(host(rows, vehicles: true));
      expect(find.text('Vehicle #1'), findsOneWidget);
      expect(find.text('Puerto Rico'), findsOneWidget);
      expect(tenantSubdocPayload(rows).first['state'], 'Puerto Rico');
    });
  });
}
