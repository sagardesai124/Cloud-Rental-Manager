import 'dart:convert';
import 'dart:io';

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
import 'package:three_zero_two_property/StaffModule/screen/Rental/Tenants/edit_tenants.dart'
    as staff;
import 'package:three_zero_two_property/provider/dateProvider.dart';
import 'package:three_zero_two_property/provider/notification_provider.dart';
import 'package:three_zero_two_property/screens/Rental/Tenants/edit_tenants.dart'
    as admin;
import 'package:three_zero_two_property/services/web_email.dart';

/// Add / Edit Tenant (Admin and Staff) check emails like web staging's tenant
/// form (tenantFormConfig.js): the same EMAIL_REGEX, "Invalid email address",
/// "Alternative email cannot be the same as the primary email" and
/// "Emergency email cannot be the same as the tenant's email".

const _alt = 'Alternative email cannot be the same as the primary email';
const _emg = "Emergency email cannot be the same as the tenant's email";

const _forms = [
  'lib/screens/Rental/Tenants/add_tenants.dart',
  'lib/screens/Rental/Tenants/edit_tenants.dart',
  'lib/StaffModule/screen/Rental/Tenants/add_tenants.dart',
  'lib/StaffModule/screen/Rental/Tenants/edit_tenants.dart',
];

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

  test('same accept / reject as web EMAIL_REGEX', () {
    const accepted = ['abc@test.com', 'a.b+c_d%e-f@mail.co.uk', 'A1@X.IO'];
    const rejected = [
      "o'brien@test.com", 'a!b@test.com', 'a&b@x.com', '"a"@x.com',
      'abc@test', 'abc@test.c', 'a b@test.com', 'abc@test.123', '',
    ];
    for (final e in accepted) {
      expect(isWebEmail(e), isTrue, reason: e);
    }
    for (final e in rejected) {
      expect(isWebEmail(e), isFalse, reason: e);
    }
    expect(webInvalidEmailMessage, 'Invalid email address');
  });

  for (final path in _forms) {
    test('$path uses web\'s email rule and messages', () {
      final src = File(path).readAsStringSync();
      final live = src
          .split('\n')
          .where((l) => !l.trimLeft().startsWith('//'))
          .join('\n');
      expect(live, isNot(contains('EmailValidator.validate(')));
      expect(live, isNot(contains('"Email is not valid"')));
      expect('isWebEmail('.allMatches(live).length, 2,
          reason: 'the required email box and the optional ones');
      expect(live, contains("sameEmailMessage: '$_alt'"));
      expect(live, contains('sameEmailMessage: "$_emg"'));
    });
  }

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

  Future<void> checkScreen(WidgetTester tester, Widget screen) async {
    tester.view.physicalSize = const Size(430, 4000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    final original = FlutterError.onError;
    FlutterError.onError = (details) {
      if (details.exceptionAsString().contains('overflowed')) return;
      original?.call(details);
    };
    Future<void> save() async {
      final btn = find.text('Save Changes');
      await tester.ensureVisible(btn);
      await tester.pump();
      await tester.tap(btn);
      await _settle(tester);
    }

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

        // 1. A primary email web rejects.
        await tester.enterText(_field('Enter email'), "o'brien@test.com");
        await save();
        expect(find.text('Invalid email address'), findsWidgets);
        expect(_savedBody, isNull, reason: 'not saved, like web');

        // 2. Alternative email the same as the primary.
        await tester.enterText(_field('Enter email'), 'ruth@example.com');
        await tester.enterText(
            _field('Enter alternative email'), 'ruth@example.com');
        await save();
        expect(find.text(_alt), findsOneWidget);
        expect(_savedBody, isNull, reason: 'not saved, like web');

        // 3. A different, valid alternative email saves.
        await tester.enterText(
            _field('Enter alternative email'), 'ruth.alt@example.com');
        await save();
        expect(_savedBody, isNotNull);
        expect(_savedBody!['tenant_alternativeEmail'], 'ruth.alt@example.com');
      }, () => _server);
      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(seconds: 5));
    } finally {
      FlutterError.onError = original;
    }
  }

  testWidgets('Admin Edit Tenant checks emails like web', (tester) async {
    await checkScreen(
        tester,
        admin.EditTenants(
            tenantId: 'T-1',
            tenants: Tenant.fromJson(Map<String, dynamic>.from(_record))));
  });

  testWidgets('Staff Edit Tenant checks emails like web', (tester) async {
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
