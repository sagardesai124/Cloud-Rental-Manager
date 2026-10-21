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
import 'package:three_zero_two_property/provider/dateProvider.dart';
import 'package:three_zero_two_property/provider/notification_provider.dart';
import 'package:three_zero_two_property/screens/Rental/Tenants/edit_tenants.dart'
    as admin;
import 'package:three_zero_two_property/StaffModule/screen/Rental/Tenants/edit_tenants.dart'
    as staff;

/// Edit Tenant (Admin and Staff) for a tenant with no alternate email or
/// alternate number on record: the boxes are empty and Save Changes never
/// sends the text "null", like web (Leasing.jsx loads `{...data}`, so a
/// missing value shows an empty box). Before, the model turned the missing
/// value into the text "null", which showed in the box and was saved back.

// A tenant record without tenant_alternativeEmail / tenant_alternativeNumber
// (demo-seeded tenants, some lease-created ones).
const _record = {
  'tenant_id': 'T-1',
  'admin_id': 'ADMIN-1',
  'tenant_firstName': 'Ruth',
  'tenant_lastName': 'Moss',
  'tenant_phoneNumber': '5551234567',
  'tenant_email': 'ruth@example.com',
};

Map<String, dynamic>? _savedBody;

final _server = MockClient((request) async {
  final path = request.url.path;
  if (path == '/api/auth') {
    return _json({
      'statusCode': 200,
      'themes': {'format': 'MM/DD/YYYY', 'timeFormat': '12'}
    });
  }
  if (path == '/api/tenant/get_tenant/T-1') {
    return _json({'statusCode': 200, 'data': _record});
  }
  if (request.method == 'PUT' && path == '/api/tenant/tenants/T-1') {
    _savedBody = jsonDecode(request.body) as Map<String, dynamic>;
    return _json({'statusCode': 200, 'data': {}});
  }
  return _json({'statusCode': 200, 'data': []});
});

http.Response _json(Object body) => http.Response(jsonEncode(body), 200,
    headers: {'content-type': 'application/json'});

Finder _field(String hint) => find
    .byWidgetPredicate((w) => w is TextField && w.decoration?.hintText == hint)
    .first;

Future<void> _settle(WidgetTester tester, [int ticks = 20]) async {
  for (var i = 0; i < ticks; i++) {
    await tester.pump(const Duration(milliseconds: 50));
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    _savedBody = null;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
            const MethodChannel('PonnamKarthik/fluttertoast'), (_) async => true);
    ConnectivityPlatform.instance = _OnlineConnectivity();
    SharedPreferences.setMockInitialValues({
      'token': 'tkn',
      'adminId': 'ADMIN-1',
      'staff_id': 'STAFF-1',
      'role': 'Admin',
    });
  });

  test('model keeps a missing alternate email / number empty, not "null"', () {
    final t = Tenant.fromJson(Map<String, dynamic>.from(_record));
    expect(t.tenantAlternativeEmail, isNull);
    expect(t.tenantAlternativeNumber, isNull);

    final withValues = Tenant.fromJson({
      ..._record,
      'tenant_alternativeEmail': 'alt@example.com',
      'tenant_alternativeNumber': '5559876543',
    });
    expect(withValues.tenantAlternativeEmail, 'alt@example.com');
    expect(withValues.tenantAlternativeNumber, '5559876543');
  });

  Future<void> checkScreen(WidgetTester tester, Widget screen) async {
    tester.view.physicalSize = const Size(430, 4000);
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

        final alterEmail = tester.widget<TextField>(_field('Enter alternative email'));
        expect(alterEmail.controller!.text, '',
            reason: 'Alternative Email box is empty, not "null"');
        expect(find.text('null'), findsNothing);

        final save = find.text('Save Changes');
        await tester.ensureVisible(save);
        await tester.pump();
        await tester.tap(save);
        await _settle(tester);

        expect(_savedBody, isNotNull, reason: 'Save Changes sent the update');
        expect(_savedBody!['tenant_alternativeEmail'], isNot('null'));
        expect(_savedBody!['tenant_alternativeEmail'], '');
        expect('${_savedBody!['tenant_alternativeNumber']}',
            isNot(contains('null')));
      }, () => _server);
      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(seconds: 5));
    } finally {
      FlutterError.onError = original;
    }
  }

  testWidgets('Admin Edit Tenant: empty Alternative Email, "null" never saved',
      (tester) async {
    await checkScreen(
        tester,
        admin.EditTenants(
            tenantId: 'T-1',
            tenants: Tenant.fromJson(Map<String, dynamic>.from(_record))));
  });

  testWidgets('Staff Edit Tenant: empty Alternative Email, "null" never saved',
      (tester) async {
    await checkScreen(
        tester,
        staff.EditTenants(
            tenantId: 'T-1',
            tenants: Tenant.fromJson(Map<String, dynamic>.from(_record))));
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
