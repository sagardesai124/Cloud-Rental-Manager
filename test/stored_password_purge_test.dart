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
import 'package:three_zero_two_property/provider/dateProvider.dart';
import 'package:three_zero_two_property/provider/notification_provider.dart';
import 'package:three_zero_two_property/services/stored_password_cleanup.dart';
import 'package:three_zero_two_property/StaffModule/repository/staffpermission_provider.dart';
import 'package:three_zero_two_property/StaffModule/screen/change_password.dart'
    as staff;
import 'package:three_zero_two_property/TenantsModule/screen/change_password.dart'
    as tenant;
import 'package:three_zero_two_property/VendorModule/screen/change_password.dart'
    as vendor;

/// The app no longer keeps the signed-in user's password on the device.
/// Older builds saved it in plain text on every login (`password`,
/// `staffmember_password`, `tenant_password`, `vendor_password`) only so the
/// change-password screens could compare against it. Now:
/// - every launch deletes any copy an older build left behind;
/// - Staff / Tenant / Vendor Change Password send the typed current password
///   and the server checks it, like web (`reset_password_v2` answers 203
///   "Current password is incorrect."), shown under the field as before;
/// - "same as the current password" is checked against what was typed;
/// - a successful change saves the new token but no password.

const _oldPassword = 'OldPass#123';
const _newPassword = 'NewPass#456';

final List<String> _toasts = [];
final List<http.Request> _requests = [];

/// What `reset_password_v2` answers in the current test.
http.Response Function() _resetReply = _wrongCurrent;

http.Response _wrongCurrent() => http.Response(
    jsonEncode({'message': 'Current password is incorrect.'}), 203,
    headers: {'content-type': 'application/json'});

http.Response _success() => http.Response(
    jsonEncode({
      'message': 'Password updated successfully',
      'newToken': 'tkn-after-change'
    }),
    200,
    headers: {'content-type': 'application/json'});

final _server = MockClient((request) async {
  _requests.add(request);
  if (request.url.path.endsWith('/reset_password_v2')) return _resetReply();
  return http.Response(jsonEncode({'statusCode': 200, 'data': []}), 200,
      headers: {'content-type': 'application/json'});
});

Finder _field(String hint) => find
    .byWidgetPredicate((w) => w is TextField && w.decoration?.hintText == hint)
    .first;

Future<void> _settle(WidgetTester tester, [int ticks = 20]) async {
  for (var i = 0; i < ticks; i++) {
    await tester.pump(const Duration(milliseconds: 50));
  }
}

const _legacyPrefs = {
  'password': 'leftover-admin',
  'staffmember_password': 'leftover-staff',
  'tenant_password': 'leftover-tenant',
  'vendor_password': 'leftover-vendor',
};

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    _toasts.clear();
    _requests.clear();
    _resetReply = _wrongCurrent;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
            const MethodChannel('PonnamKarthik/fluttertoast'), (call) async {
      if (call.method == 'showToast') {
        _toasts.add('${(call.arguments as Map)['msg']}');
      }
      return true;
    });
    ConnectivityPlatform.instance = _OnlineConnectivity();
  });

  group('launch clean-up', () {
    test('deletes every old saved password and keeps the session', () async {
      SharedPreferences.setMockInitialValues({
        ..._legacyPrefs,
        'token': 'tkn',
        'adminId': 'ADMIN-1',
        'role': 'Admin',
      });
      await purgeStoredSessionPasswords();
      final prefs = await SharedPreferences.getInstance();
      for (final key in legacySessionPasswordKeys) {
        expect(prefs.containsKey(key), isFalse, reason: '$key removed');
      }
      expect(prefs.getString('token'), 'tkn', reason: 'still signed in');
      expect(prefs.getString('adminId'), 'ADMIN-1');
      expect(prefs.getString('role'), 'Admin');
    });

    test('is safe when nothing was saved', () async {
      SharedPreferences.setMockInitialValues({'token': 'tkn'});
      await purgeStoredSessionPasswords();
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('token'), 'tkn');
    });

    test('runs at app start', () {
      final main = File('lib/main.dart').readAsStringSync();
      expect(main, contains('await purgeStoredSessionPasswords();'));
    });

    test('no code saves or reads the old password keys any more', () {
      final keyUse = RegExp(
          r'''(setString|getString)\(\s*['"](password|staffmember_password|tenant_password|vendor_password)['"]''');
      final offenders = <String>[];
      for (final f in Directory('lib').listSync(recursive: true)) {
        if (f is! File || !f.path.endsWith('.dart')) continue;
        final lines = f.readAsLinesSync();
        for (var i = 0; i < lines.length; i++) {
          final line = lines[i].trimLeft();
          if (line.startsWith('//')) continue;
          if (keyUse.hasMatch(line)) offenders.add('${f.path}:${i + 1}');
        }
      }
      expect(offenders, isEmpty);
    });
  });

  // One block per role: same screen shape, different module + endpoint.
  final roles = <String, ({Widget Function() screen, String endpoint, String idKey})>{
    'Staff': (
      screen: () => staff.Change_password(),
      endpoint: '/api/staffmember/reset_password_v2',
      idKey: 'staff_id'
    ),
    'Tenant': (
      screen: () => tenant.Change_password(),
      endpoint: '/api/tenant/reset_password_v2',
      idKey: 'tenant_id'
    ),
    'Vendor': (
      screen: () => vendor.Change_password(),
      endpoint: '/api/vendor/reset_password_v2',
      idKey: 'vendor_id'
    ),
  };

  for (final entry in roles.entries) {
    final role = entry.key;
    final r = entry.value;

    group('$role Change Password', () {
      Future<List<Object?>> open(WidgetTester tester) async {
        tester.view.physicalSize = const Size(430, 2600);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.reset);
        // No password saved on the device at all (the new normal).
        SharedPreferences.setMockInitialValues({
          'token': 'tkn',
          'adminId': 'ADMIN-1',
          r.idKey: 'USER-1',
          'staffemail': 'pat@example.com',
          'email': 'pat@example.com',
          'role': role,
        });
        final dates = DateProvider();
        await dates.loadDateFormat();
        final permissions = StaffPermissionProvider();
        await permissions.fetchPermissions();
        final pops = <Object?>[];
        await tester.pumpWidget(MultiProvider(
          providers: [
            ChangeNotifierProvider<DateProvider>.value(value: dates),
            ChangeNotifierProvider(create: (_) => NotificationProvider()),
            ChangeNotifierProvider<StaffPermissionProvider>.value(
                value: permissions),
          ],
          child: MaterialApp(
            home: Builder(
              builder: (context) => Scaffold(
                body: Center(
                  child: TextButton(
                    onPressed: () async => pops.add(await Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => r.screen()))),
                    child: const Text('open'),
                  ),
                ),
              ),
            ),
          ),
        ));
        await tester.tap(find.text('open'));
        await _settle(tester);
        return pops;
      }

      Future<void> fill(WidgetTester tester, String current, String next) async {
        await tester.enterText(_field('Current Password'), current);
        await tester.enterText(_field('New Password'), next);
        await tester.enterText(_field('Confirm password'), next);
        await tester.pump();
        final submit = find.text('Change Password').last;
        await tester.ensureVisible(submit);
        await tester.pump();
        await tester.tap(submit);
        await _settle(tester);
      }

      Future<void> run(WidgetTester tester, Future<void> Function() body) async {
        final original = FlutterError.onError;
        FlutterError.onError = (details) {
          if (details.exceptionAsString().contains('overflowed')) return;
          original?.call(details);
        };
        try {
          await http.runWithClient(body, () => _server);
          await tester.pumpWidget(const SizedBox());
          await tester.pump(const Duration(seconds: 5));
        } finally {
          FlutterError.onError = original;
        }
      }

      testWidgets('wrong current password: server says so, shown under the field',
          (tester) async {
        await run(tester, () async {
          final pops = await open(tester);
          _resetReply = _wrongCurrent;
          await fill(tester, 'Wrong#Pass9', _newPassword);

          final sent = _requests.where((q) => q.url.path == r.endpoint).toList();
          expect(sent, hasLength(1), reason: 'the server does the check');
          // Staff sends JSON; Tenant and Vendor send form fields (unchanged).
          final raw = sent.single.body;
          final body = raw.trimLeft().startsWith('{')
              ? jsonDecode(raw) as Map<String, dynamic>
              : Uri.splitQueryString(raw);
          expect(body['currentPassword'], 'Wrong#Pass9');
          expect(body['password'], _newPassword);

          expect(find.text('Current password is incorrect'), findsOneWidget);
          expect(pops, isEmpty, reason: 'screen stays open');
        });
      });

      testWidgets('right current password: changed, new token kept, no password saved',
          (tester) async {
        await run(tester, () async {
          final pops = await open(tester);
          _resetReply = _success;
          await fill(tester, _oldPassword, _newPassword);
          await _settle(tester, 20);

          expect(_requests.where((q) => q.url.path == r.endpoint), hasLength(1));
          expect(_toasts, contains('Password updated successfully'));
          expect(pops, hasLength(1), reason: 'screen closed');
          final prefs = await SharedPreferences.getInstance();
          expect(prefs.getString('token'), 'tkn-after-change');
          for (final key in legacySessionPasswordKeys) {
            expect(prefs.containsKey(key), isFalse, reason: '$key not saved');
          }
          expect(prefs.getKeys().where((k) => k.toLowerCase().contains('pass')),
              isEmpty);
        });
      });

      testWidgets('new password same as the typed current one: blocked, nothing sent',
          (tester) async {
        await run(tester, () async {
          await open(tester);
          await fill(tester, _oldPassword, _oldPassword);

          expect(find.text('New password cannot be the same as the old password'),
              findsOneWidget);
          expect(_requests.where((q) => q.url.path == r.endpoint), isEmpty);
        });
      });
    });
  }
}

class _OnlineConnectivity extends ConnectivityPlatform
    with MockPlatformInterfaceMixin {
  @override
  Future<ConnectivityResult> checkConnectivity() async =>
      ConnectivityResult.wifi;
  @override
  Stream<ConnectivityResult> get onConnectivityChanged => const Stream.empty();
}
