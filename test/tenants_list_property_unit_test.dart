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
import 'package:three_zero_two_property/Model/tenants.dart';
import 'package:three_zero_two_property/StaffModule/repository/staffpermission_provider.dart';
import 'package:three_zero_two_property/StaffModule/screen/Rental/Tenants/Tenants_table.dart'
    as staff;
import 'package:three_zero_two_property/provider/dateProvider.dart';
import 'package:three_zero_two_property/provider/notification_provider.dart';
import 'package:three_zero_two_property/screens/Rental/Tenants/Tenants_table.dart'
    as admin;

/// ☰ → Tenants (Admin and Staff): the Property column shows the address and
/// the unit like web staging's Tenants list (TenantsTable.jsx:
/// "address - unit", only the address when there is no unit, "Not available"
/// when there is no address). Before, the app dropped the unit and said
/// "Not Available".

Map<String, dynamic> _tenant(String id, String first,
        {String? address, String? unit}) =>
    {
      'tenant_id': id,
      'tenant_firstName': first,
      'tenant_lastName': 'Test',
      'tenant_phoneNumber': '5551234567',
      'tenant_email': '${first.toLowerCase()}@example.com',
      'is_current_tenant': true,
      'createdAt': '2026-10-01T10:00:00.000Z',
      if (address != null) 'rental_adress': address,
      if (unit != null) 'rental_unit': unit,
    };

final _tenants = [
  _tenant('T-1', 'Unit', address: '123 Main St', unit: 'A1'),
  _tenant('T-2', 'Single', address: '155 Maple Avenue', unit: ''),
  _tenant('T-3', 'Nohome'),
];

final _server = MockClient((request) async {
  final path = request.url.path;
  Object body = {'statusCode': 200, 'data': []};
  if (path.startsWith('/api/tenant/tenants/v2/')) {
    body = {
      'statusCode': 200,
      'data': {'tenants': _tenants},
      'pagination': {
        'currentPage': 1,
        'totalPages': 1,
        'totalItems': _tenants.length,
        'itemsPerPage': 10
      },
    };
  } else if (path.startsWith('/api/tenant/limitation/')) {
    body = {'statusCode': 200, 'rentalCount': _tenants.length};
  } else if (path.startsWith('/api/permission/permission/')) {
    body = {
      'statusCode': 200,
      'data': {
        'staff_permission': {
          'tenant_view': true,
          'tenant_add': true,
          'tenant_edit': true,
          'tenant_delete': true,
        }
      }
    };
  }
  return http.Response(jsonEncode(body), 200,
      headers: {'content-type': 'application/json'});
});

Future<void> _settle(WidgetTester tester, [int ticks = 40]) async {
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
    ConnectivityPlatform.instance = _OnlineConnectivity();
  });

  test('Property text follows web: address - unit / address / Not available',
      () {
    expect(tenantPropertyLine(Tenant(rentalAddress: '123 Main St', rentalUnit: 'A1')),
        '123 Main St - A1');
    expect(tenantPropertyLine(Tenant(rentalAddress: '155 Maple Avenue', rentalUnit: '')),
        '155 Maple Avenue');
    expect(tenantPropertyLine(Tenant(rentalAddress: '155 Maple Avenue')),
        '155 Maple Avenue');
    expect(tenantPropertyLine(Tenant(rentalAddress: '', rentalUnit: 'A1')),
        'Not available');
    expect(tenantPropertyLine(Tenant()), 'Not available');
  });

  Future<void> check(WidgetTester tester, Widget screen, String role) async {
    tester.view.physicalSize = const Size(430, 3000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    SharedPreferences.setMockInitialValues({
      'token': 'tkn',
      'adminId': 'ADMIN-1',
      'staff_id': 'STAFF-1',
      'role': role,
    });
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
        await permissions.fetchPermissions();
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

        expect(find.text('123 Main St - A1'), findsOneWidget,
            reason: 'multi-unit: address and unit');
        expect(find.text('155 Maple Avenue'), findsOneWidget,
            reason: 'no unit: address only');
        expect(find.text('Not available'), findsOneWidget,
            reason: 'no address: web wording');
        expect(find.text('Not Available'), findsNothing);
      }, () => _server);
      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(seconds: 5));
    } finally {
      FlutterError.onError = original;
    }
  }

  testWidgets('Admin Tenants list shows address and unit like web',
      (tester) async {
    await check(tester, admin.Tenants_table(), 'Admin');
  });

  testWidgets('Staff Tenants list shows address and unit like web',
      (tester) async {
    await check(tester, staff.Tenants_table(), 'Staffmember');
  });
}

class _OnlineConnectivity extends ConnectivityPlatform
    with MockPlatformInterfaceMixin {
  @override
  Future<ConnectivityResult> checkConnectivity() async =>
      ConnectivityResult.wifi;
  @override
  Stream<ConnectivityResult> get onConnectivityChanged => const Stream.empty();
}
