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
import 'package:three_zero_two_property/model/properties.dart';
import 'package:three_zero_two_property/StaffModule/repository/staffpermission_provider.dart';
import 'package:three_zero_two_property/StaffModule/screen/Rental/Properties/summery_page.dart'
    as staff;
import 'package:three_zero_two_property/provider/dateProvider.dart';
import 'package:three_zero_two_property/provider/lease_provider.dart';
import 'package:three_zero_two_property/provider/notification_provider.dart';
import 'package:three_zero_two_property/provider/properties_workorders.dart';
import 'package:three_zero_two_property/repository/properties_summery.dart';
import 'package:three_zero_two_property/screens/Rental/Properties/summery_page.dart'
    as admin;

/// Property → "Tenant (n)" tab, like web staging: the number is the `count`
/// the server sends with the property's tenants, which leaves out tenants
/// with a move-out date. It used to count every row in the list, so after a
/// Move out the app said Tenant (2) where web said Tenant (1).

http.Response _json(Object body) => http.Response(jsonEncode(body), 200,
    headers: {'content-type': 'application/json'});

/// One active tenant and one who has moved out; the server counts 1.
final _tenantsReply = {
  'statusCode': 200,
  'data': [
    {'_id': 'T-1', 'tenant_id': 'T-1', 'tenant_firstName': 'Ruth'},
    {
      '_id': 'T-2',
      'tenant_id': 'T-2',
      'tenant_firstName': 'Leo',
      'moveout_date': '2026-10-30',
    },
  ],
  'count': 1,
};

Map<String, Object?> _reply = _tenantsReply;

const _property = {
  '_id': 'R-1',
  'rental_id': 'P-1',
  'admin_id': 'ADMIN-1',
  'rental_adress': '12 Main St',
  'rental_city': 'Austin',
  'rental_state': 'TX',
  'rental_country': 'USA',
  'rental_postcode': '73301',
};

final _server = MockClient((request) async {
  final path = request.url.path;
  if (path.startsWith('/api/tenant/rental_tenant/')) return _json(_reply);
  if (path.startsWith('/api/rentals/rental_summary/')) {
    return _json({
      'statusCode': 200,
      'data': [_property],
    });
  }
  if (path == '/api/auth') {
    return _json({
      'statusCode': 200,
      'themes': {'format': 'YYYY-MM-DD', 'timeFormat': '24'},
    });
  }
  return _json({'statusCode': 200, 'data': []});
});

Future<void> _settle(WidgetTester tester, [int ticks = 30]) async {
  for (var i = 0; i < ticks; i++) {
    await tester.pump(const Duration(milliseconds: 50));
  }
}

/// Opens the real property summary, then its tab dropdown.
Future<void> _openTabs(WidgetTester tester, bool isStaff) async {
  SharedPreferences.setMockInitialValues(isStaff
      ? {
          'token': 'tkn',
          'adminId': 'ADMIN-1',
          'staff_id': 'STAFF-1',
          'role': 'Staffmember'
        }
      : {'token': 'tkn', 'adminId': 'ADMIN-1', 'role': 'Admin'});
  tester.view.physicalSize = const Size(430, 2400);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
  final property = Rentals.fromJson(_property);
  final dates = DateProvider();
  await dates.loadDateFormat();
  await tester.pumpWidget(MultiProvider(
    providers: [
      ChangeNotifierProvider<DateProvider>.value(value: dates),
      ChangeNotifierProvider(create: (_) => NotificationProvider()),
      ChangeNotifierProvider(create: (_) => StaffPermissionProvider()),
      ChangeNotifierProvider(create: (_) => WorkOrderCountProvider()),
      ChangeNotifierProvider(create: (_) => DropdownProvider()),
      ChangeNotifierProvider(create: (_) => SelectedTenantsProvider()),
      ChangeNotifierProvider(create: (_) => SelectedCosignersProvider()),
    ],
    child: MaterialApp(
      home: isStaff
          ? staff.Summery_page(properties: property)
          : admin.Summery_page(properties: property),
    ),
  ));
  await _settle(tester);
  await tester.tap(find.text('Summary').first);
  await _settle(tester, 10);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    _reply = _tenantsReply;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
            const MethodChannel('PonnamKarthik/fluttertoast'), (_) async => true);
    ConnectivityPlatform.instance = _OnlineConnectivity();
  });

  for (final isStaff in [false, true]) {
    testWidgets(
        '${isStaff ? 'Staff' : 'Admin'}: Tenant tab shows the server count, '
        'like web', (tester) async {
      final original = FlutterError.onError;
      // Layout overflow (test font) and network images (no network in
      // tests) are noise here.
      FlutterError.onError = (details) {
        if (details.exceptionAsString().contains('overflowed')) return;
        if (details.library == 'image resource service') return;
        original?.call(details);
      };
      try {
        await http.runWithClient(() async {
          await _openTabs(tester, isStaff);
          expect(find.text('Tenant (1)'), findsWidgets,
              reason: 'the moved-out tenant is not counted');
          expect(find.text('Tenant (2)'), findsNothing);
          await tester.pumpWidget(const SizedBox());
          await tester.pump(const Duration(seconds: 2));
        }, () => _server);
      } finally {
        FlutterError.onError = original;
      }
    });
  }

  test('a reply without count still leaves out moved-out tenants', () async {
    SharedPreferences.setMockInitialValues(
        {'token': 'tkn', 'adminId': 'ADMIN-1', 'role': 'Admin'});
    _reply = {
      'statusCode': 200,
      'data': (_tenantsReply['data'] as List),
    };
    final count = await http.runWithClient(
        () => Properies_summery_Repo().fetchRentalTenantCount('P-1'),
        () => _server);
    expect(count, 1);
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
