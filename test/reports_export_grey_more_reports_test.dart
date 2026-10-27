import 'dart:convert';

import 'package:connectivity_plus_platform_interface/connectivity_plus_platform_interface.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:three_zero_two_property/StaffModule/repository/staffpermission_provider.dart';
import 'package:three_zero_two_property/StaffModule/screen/Reports/ReportScreens/CompletedWorkOrders.dart'
    as staff_completed;
import 'package:three_zero_two_property/StaffModule/screen/Reports/ReportScreens/ExpiringLeases.dart'
    as staff_expiring;
import 'package:three_zero_two_property/StaffModule/screen/Reports/ReportScreens/OpenWorkOrders.dart'
    as staff_open;
import 'package:three_zero_two_property/StaffModule/screen/Reports/ReportScreens/Recurring_Payments_Configuration_table.dart'
    as staff_recurring;
import 'package:three_zero_two_property/StaffModule/screen/Reports/ReportScreens/RentRollReport.dart'
    as staff_rentroll;
import 'package:three_zero_two_property/provider/dateProvider.dart';
import 'package:three_zero_two_property/provider/notification_provider.dart';
import 'package:three_zero_two_property/screens/Reports/ReportScreens/CompletedWorkOrders.dart'
    as admin_completed;
import 'package:three_zero_two_property/screens/Reports/ReportScreens/ExpiringLeases.dart'
    as admin_expiring;
import 'package:three_zero_two_property/screens/Reports/ReportScreens/OpenWorkOrders.dart'
    as admin_open;
import 'package:three_zero_two_property/screens/Reports/ReportScreens/Recurring_Payments_Configuration_table.dart'
    as admin_recurring;
import 'package:three_zero_two_property/screens/Reports/ReportScreens/ReopenWorkorder.dart';
import 'package:three_zero_two_property/screens/Reports/ReportScreens/RentRollReport.dart'
    as admin_rentroll;

/// Reports → Export on an empty report: the six reports the 10-23 simulator
/// sweep found still hiding Export (Expiring Leases, Open / Completed /
/// Reopen Work Orders, Recurring Payments) or leaving it enabled (Rent Roll
/// with rentals but no active leases). Each must show Export in place,
/// greyed and untappable. Admin and Staff.

/// Every endpoint answers "no rows"; Rent Roll answers with one rental that
/// has no active lease, so its table is empty while `rentals` is not.
MockClient _emptyServer() => MockClient((request) async {
      final path = request.url.path;
      if (path == '/api/auth') {
        return _json({
          'statusCode': 200,
          'themes': {'format': 'YYYY-MM-DD', 'timeFormat': '12'}
        });
      }
      if (path.contains('/api/rentals/rental-owners/')) {
        return _json([]); // this endpoint answers with a bare list
      }
      if (path.contains('rent-roll-report')) {
        return _json({
          'statusCode': 200,
          'data': {
            'rentals': [
              {
                'rental_id': 'R-1',
                'rentalAddress': '1 Test Street',
                'activeLeases': [],
              }
            ],
          },
        });
      }
      return _json({'statusCode': 200, 'data': []});
    });

http.Response _json(Object body) => http.Response(jsonEncode(body), 200,
    headers: {'content-type': 'application/json'});

Future<void> _settle(WidgetTester tester, [int ticks = 16]) async {
  for (var i = 0; i < ticks; i++) {
    await tester.pump(const Duration(milliseconds: 50));
  }
}

Finder get _export => find.byType(PopupMenuButton<String>);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
            const MethodChannel('PonnamKarthik/fluttertoast'), (_) async => true);
    ConnectivityPlatform.instance = _Online();
  });

  Future<void> openEmpty(
      WidgetTester tester, bool isStaff, Widget Function() screen,
      {Future<void> Function()? run}) async {
    SharedPreferences.setMockInitialValues(isStaff
        ? {
            'token': 'tkn',
            'adminId': 'ADMIN-1',
            'staff_id': 'STAFF-1',
            'role': 'Staffmember'
          }
        : {'token': 'tkn', 'adminId': 'ADMIN-1', 'role': 'Admin'});
    tester.view.physicalSize = const Size(430, 1600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    final original = FlutterError.onError;
    FlutterError.onError = (details) {
      if (details.exceptionAsString().contains('overflowed')) return;
      original?.call(details);
    };
    try {
      await http.runWithClient(() async {
        final dates = DateProvider();
        await dates.loadDateFormat();
        final permissions = StaffPermissionProvider();
        if (isStaff) await permissions.fetchPermissions();
        await tester.pumpWidget(MultiProvider(
          providers: [
            ChangeNotifierProvider<DateProvider>.value(value: dates),
            ChangeNotifierProvider(create: (_) => NotificationProvider()),
            ChangeNotifierProvider<StaffPermissionProvider>.value(
                value: permissions),
          ],
          child: MaterialApp(home: screen()),
        ));
        await _settle(tester, 30);
        if (run != null) {
          await run();
          await _settle(tester, 20);
        }

        expect(_export, findsWidgets,
            reason: 'empty report: Export keeps its place');
        for (final menu
            in tester.widgetList<PopupMenuButton<String>>(_export)) {
          expect(menu.enabled, isFalse,
              reason: 'empty report: Export is greyed and untappable');
        }
        await tester.tap(_export.first, warnIfMissed: false);
        await _settle(tester, 6);
        expect(find.text('CSV'), findsNothing,
            reason: 'tapping a greyed Export opens nothing');
        expect(find.text('Download as CSV'), findsNothing,
            reason: 'tapping a greyed Export opens nothing');
      }, _emptyServer);
      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(seconds: 2));
    } finally {
      FlutterError.onError = original;
    }
  }

  final screens = <String, (Widget Function(), Widget Function())>{
    'Expiring Leases': (
      () => admin_expiring.ExpiringLeases(),
      () => staff_expiring.ExpiringLeases()
    ),
    'Open Work Orders': (
      () => admin_open.OpenWorkOrders(),
      () => staff_open.OpenWorkOrders()
    ),
    'Completed Work Orders': (
      () => admin_completed.CompletedWorkOrders(),
      () => staff_completed.CompletedWorkOrders()
    ),
    'Reopen Work Orders': (
      () => const ReopenWorkorder(),
      () => const ReopenWorkorder(isStaffMode: true)
    ),
    'Recurring Payments Configuration': (
      () => const admin_recurring.Recurring_Payments_Configuration_Report(),
      () => const staff_recurring.Recurring_Payments_Configuration_Report()
    ),
    'Rent Roll (rentals without active leases)': (
      () => admin_rentroll.RentersInsurances(),
      () => staff_rentroll.RentersInsurances()
    ),
  };

  for (final entry in screens.entries) {
    for (final isStaff in [false, true]) {
      final role = isStaff ? 'Staff' : 'Admin';
      testWidgets('$role ${entry.key}: no rows → Export greyed, untappable',
          (tester) async {
        await openEmpty(
            tester, isStaff, isStaff ? entry.value.$2 : entry.value.$1);
      });
    }
  }
}

class _Online extends ConnectivityPlatform with MockPlatformInterfaceMixin {
  @override
  Future<ConnectivityResult> checkConnectivity() async =>
      ConnectivityResult.wifi;
  @override
  Stream<ConnectivityResult> get onConnectivityChanged => const Stream.empty();
}
