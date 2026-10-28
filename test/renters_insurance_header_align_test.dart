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
import 'package:three_zero_two_property/StaffModule/screen/Reports/ReportScreens/RentersInsurance.dart'
    as staff_renters;
import 'package:three_zero_two_property/provider/dateProvider.dart';
import 'package:three_zero_two_property/provider/notification_provider.dart';
import 'package:three_zero_two_property/screens/Reports/ReportScreens/RentersInsurance.dart'
    as admin_renters;

/// Reports → Renters Insurance (phone): the "Insurance Provider" column
/// header wraps to two lines; both lines start at the column's left edge,
/// like the other headers and the provider names under it (a space before
/// "Provider" used to push the second line in). Admin and Staff.

final _server = MockClient((request) async {
  final path = request.url.path;
  Object body = {'statusCode': 200, 'data': []};
  if (path == '/api/auth') {
    body = {
      'statusCode': 200,
      'themes': {'format': 'YYYY-MM-DD', 'timeFormat': '12'}
    };
  } else if (path.startsWith('/api/renter-insurance/report/')) {
    body = {
      'statusCode': 200,
      'data': [
        {
          '_id': 'RI-1',
          'lease_id': 'L-1',
          'rental_address': '12 Test Street',
          'tenant_id': 'T-1',
          'tenant_name': 'Pat Tenant',
          'rentersInsurance': {
            '_id': 'P-1',
            'renters_insurance_id': 'RIN-1',
            'lease_id': 'L-1',
            'tenants': ['T-1'],
            'insurance_company': 'Test Mutual',
            'insurance_company_phone_number': '5551234567',
            'policy_id': 'POL-1',
            'effective_date': '2026-01-01',
            'expiration_date': '2026-12-31',
            'liability_coverage': 100000,
            'active': true,
            'is_delete': false,
          },
        }
      ],
    };
  }
  return http.Response(jsonEncode(body), 200,
      headers: {'content-type': 'application/json'});
});

Future<void> _settle(WidgetTester tester, [int ticks = 16]) async {
  for (var i = 0; i < ticks; i++) {
    await tester.pump(const Duration(milliseconds: 50));
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
            const MethodChannel('PonnamKarthik/fluttertoast'), (_) async => true);
    ConnectivityPlatform.instance = _Online();
  });

  for (final (name, isStaff, screen) in [
    ('Admin', false, () => admin_renters.RentersInsurance() as Widget),
    ('Staff', true, () => staff_renters.RentersInsurance() as Widget),
  ]) {
    testWidgets('$name Renters Insurance: "Insurance Provider" header lines start together',
        (tester) async {
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
          expect(find.text('Test Mutual'), findsOneWidget,
              reason: 'the row is on screen');
          expect(find.text('Insurance\nProvider'), findsOneWidget);
          expect(find.text('Insurance\n Provider'), findsNothing);
        }, () => _server);
        await tester.pumpWidget(const SizedBox());
        await tester.pump(const Duration(seconds: 3));
      } finally {
        FlutterError.onError = original;
      }
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
