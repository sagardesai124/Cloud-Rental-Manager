import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:three_zero_two_property/StaffModule/screen/Reports/ReportsMainScreen.dart';

/// Staff → Reports lists Lease Renewal under Lease & Tenant Management, like
/// web (Reports.jsx offers "Lease Renewal Report" to Staff and opens
/// /staff/staffleaserenewalreport) and like the Admin Reports page. Before,
/// only the unused `reportCards` list had it, so Staff could not open it.

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('Staff Reports shows Lease Renewal in Lease & Tenant Management',
      (tester) async {
    SharedPreferences.setMockInitialValues(
        {'token': 'tkn', 'adminId': 'ADMIN-1', 'staff_id': 'STAFF-1',
         'role': 'Staffmember'});
    tester.view.physicalSize = const Size(430, 4000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    final original = FlutterError.onError;
    FlutterError.onError = (details) {
      if (details.exceptionAsString().contains('overflowed')) return;
      original?.call(details);
    };
    try {
      await tester.pumpWidget(const MaterialApp(
        home: Scaffold(body: SingleChildScrollView(child: ReportScreen())),
      ));
      await tester.pump(const Duration(milliseconds: 200));

      final section = find.text('Lease & Tenant Management');
      final renewal = find.text('Lease Renewal');
      expect(section, findsOneWidget);
      expect(renewal, findsOneWidget, reason: 'Lease Renewal offered to Staff');
      final y = (Finder f) => tester.getTopLeft(f).dy;
      expect(y(renewal) > y(section), isTrue, reason: 'inside that section');
      expect(y(renewal) > y(find.text('Delinquent Tenants')), isTrue);
      expect(y(renewal) < y(find.text('Convenience Fee Override')), isTrue,
          reason: 'same place as on the Admin Reports page');
    } finally {
      FlutterError.onError = original;
    }
  });
}
