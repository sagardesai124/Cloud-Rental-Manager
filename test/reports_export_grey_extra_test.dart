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
import 'package:three_zero_two_property/StaffModule/screen/Reports/ReportScreens/PropertyRevenueReport.dart'
    as staff_revenue;
import 'package:three_zero_two_property/StaffModule/screen/Reports/ReportScreens/rentalownerreport.dart'
    as staff_owner;
import 'package:three_zero_two_property/provider/dateProvider.dart';
import 'package:three_zero_two_property/provider/notification_provider.dart';
import 'package:three_zero_two_property/screens/Dashboard/RentPastDueReport.dart';
import 'package:three_zero_two_property/screens/Reports/ReportScreens/PropertyRevenueReport.dart'
    as admin_revenue;
import 'package:three_zero_two_property/screens/Reports/ReportScreens/rentalownerreport.dart'
    as admin_owner;

/// Export greys out when there is no data on the last three screens the
/// audit found (QA: "disabled, greyed out, not hidden"):
/// - Rental Owner Report: Export was HIDDEN until the first Run.
/// - Property Revenue Report: Export stayed blue when the report had no
///   properties ("No Data Available").
/// - Rent Past Due / Due / Paid (Dashboard): Export was never greyed.
/// Admin and Staff (Rent Past Due is one shared screen).

/// Every report endpoint answers "no rows".
final _emptyServer = MockClient((request) async {
  final path = request.url.path;
  if (path == '/api/auth') {
    return _json({
      'statusCode': 200,
      'themes': {'format': 'YYYY-MM-DD', 'timeFormat': '12'}
    });
  }
  if (path.startsWith('/api/rentals/rental-owners/')) {
    return _json([]); // the owner picker reads a bare list
  }
  if (path.startsWith('/api/rentals/property_revenue_report/')) {
    return _json({
      'statusCode': 200,
      'data': {'properties': [], 'summary': {}}
    });
  }
  return _json({'statusCode': 200, 'data': []});
});

http.Response _json(Object body) => http.Response(jsonEncode(body), 200,
    headers: {'content-type': 'application/json'});

Future<void> _settle(WidgetTester tester, [int ticks = 30]) async {
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

  Future<void> open(WidgetTester tester, bool isStaff, Widget screen,
      Future<void> Function() body) async {
    SharedPreferences.setMockInitialValues(isStaff
        ? {
            'token': 'tkn',
            'adminId': 'ADMIN-1',
            'staff_id': 'STAFF-1',
            'role': 'Staffmember'
          }
        : {'token': 'tkn', 'adminId': 'ADMIN-1', 'role': 'Admin'});
    tester.view.physicalSize = const Size(430, 2000);
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
          child: MaterialApp(home: screen),
        ));
        await _settle(tester);
        await body();
      }, () => _emptyServer);
      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(seconds: 3));
    } finally {
      FlutterError.onError = original;
    }
  }

  void expectGreyExport(WidgetTester tester, String reason) {
    expect(_export, findsOneWidget, reason: '$reason: Export keeps its place');
    expect(tester.widget<PopupMenuButton<String>>(_export).enabled, isFalse,
        reason: '$reason: greyed, cannot open');
  }

  for (final isStaff in [false, true]) {
    final role = isStaff ? 'Staff' : 'Admin';

    testWidgets('$role Rental Owner: Export greyed (not hidden) before Run',
        (tester) async {
      await open(
          tester,
          isStaff,
          isStaff
              ? const staff_owner.RentalOwnerReports()
              : const admin_owner.RentalOwnerReports(),
          () async => expectGreyExport(tester, 'before the first Run'));
    });

    testWidgets('$role Property Revenue: no properties → Export greyed',
        (tester) async {
      await open(
          tester,
          isStaff,
          isStaff
              ? staff_revenue.PropertyRevenueReport()
              : admin_revenue.PropertyRevenueReport(),
          () async {
        await tester.tap(find.byIcon(Icons.more_vert).first);
        await _settle(tester, 10);
        final apply = find.text('Apply Filters');
        await tester.ensureVisible(apply);
        await tester.pump();
        await tester.tap(apply);
        await _settle(tester);
        expect(find.text('No Data Available'), findsOneWidget);
        expectGreyExport(tester, 'report ran, no properties');
      });
    });

    testWidgets('$role Rent Past Due: no rows → Export greyed',
        (tester) async {
      await open(
          tester,
          isStaff,
          RentPastDueReports(title: 'Rent Past Due', fromStaffModule: isStaff),
          () async => expectGreyExport(tester, 'no charges'));
    });
  }
}

class _Online extends ConnectivityPlatform with MockPlatformInterfaceMixin {
  @override
  Future<ConnectivityResult> checkConnectivity() async =>
      ConnectivityResult.wifi;
  @override
  Stream<ConnectivityResult> get onConnectivityChanged => const Stream.empty();
}
