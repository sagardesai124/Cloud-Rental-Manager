import 'dart:async';
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
import 'package:three_zero_two_property/StaffModule/repository/staffpermission_provider.dart';
import 'package:three_zero_two_property/TenantsModule/repository/permission_provider.dart';
import 'package:three_zero_two_property/provider/color_theme.dart';
import 'package:three_zero_two_property/provider/dateProvider.dart';
import 'package:three_zero_two_property/provider/notification_provider.dart';
import 'package:three_zero_two_property/screens/Login/login_screen.dart';
import 'package:three_zero_two_property/screens/Profile/Settings_screen.dart';
import 'package:three_zero_two_property/services/stale_staff_id_cleanup.dart';

/// A Staff session that ended without the menu Logout (expired token, app
/// closed) left `staff_id` on the device. Signed in as Admin afterwards, the
/// screens Admin and Staff share sent that old id in the `id` header and the
/// server answered 401 "User does not exist or is not active." (Settings:
/// "Failed to fetch vendors"). Web sends the current role's own id, so now:
/// - an Admin, Tenant or Vendor sign-in drops a leftover staff id;
/// - every launch drops it when the saved session is not a Staff one;
/// - a Staff sign-in keeps its own staff id.

const _oldStaffId = 'STAFF-OLD';

/// What the device holds after a Staff session ended without Logout: the
/// token is gone, the staff id and the role are not.
const _afterStaffSession = {
  'staff_id': _oldStaffId,
  'role': 'Staffmember',
  'adminId': 'ADMIN-1',
};

http.Response _json(Object body, [int status = 200]) => http.Response(
    jsonEncode(body), status,
    headers: {'content-type': 'application/json'});

/// The sign-in steps of the real server, for one account of [role].
class _LoginServer {
  _LoginServer(this.role);

  /// Role the account picker (check-credentials) reports.
  final String role;

  /// What /api/auth returns for each role's session.
  static const _sessions = {
    'admin': {
      'role': 'admin',
      'admin_id': 'ADMIN-1',
      'company_name': 'Acme',
      'first_name': 'Pat',
      'last_name': 'Lee',
      'email': 'pat@example.com',
    },
    'staffmember': {
      'staffmember_id': 'STAFF-NEW',
      'staffmember_name': 'Pat Lee',
      'staffmember_email': 'pat@example.com',
    },
    'tenant': {
      'tenant_id': 'TENANT-1',
      'tenant_firstName': 'Pat',
      'tenant_lastName': 'Lee',
      'tenant_email': 'pat@example.com',
    },
    'vendor': {
      'vendor_id': 'VENDOR-1',
      'vendor_name': 'Pat Lee',
      'vendor_email': 'pat@example.com',
    },
  };

  Future<http.Response> handle(http.Request r) async {
    final path = r.url.path;
    if (path.endsWith('/api/auth/check-credentials')) {
      return _json({
        'shouldLogin': true,
        'data': [
          {
            'role': role,
            'admin_id': 'ADMIN-1',
            'user_id': 'USER-1',
            'userName': 'Pat',
            'company_name': 'Acme',
          }
        ],
      });
    }
    if (path.contains('/api/admin/check_company/')) {
      return _json({
        'statusCode': 200,
        'data': {'admin_id': 'ADMIN-1'},
      });
    }
    if (path.endsWith('/api/auth/login')) {
      return _json({'statusCode': 200, 'token': 'tkn-new'});
    }
    if (path == '/api/auth') return _json(_sessions[role]!);
    return _json({'statusCode': 200, 'data': null});
  }
}

/// The `id` header of every request the Settings screen sends.
final List<String> _settingsIds = [];

final _settingsServer = MockClient((request) async {
  final id = request.headers['id'];
  if (id != null) _settingsIds.add(id);
  if (id == 'CRM $_oldStaffId') {
    // What staging answers a staff id sent with an Admin token.
    return _json({
      'statusCode': 401,
      'message': 'User does not exist or is not active.',
    }, 401);
  }
  if (request.url.path == '/api/auth') {
    return _json({
      'statusCode': 200,
      'themes': {'format': 'YYYY-MM-DD', 'timeFormat': '24'},
    });
  }
  return _json({'statusCode': 200, 'data': []});
});

Finder _field(String hint) => find.byWidgetPredicate(
    (w) => w is TextField && w.decoration?.hintText == hint);

Future<void> _settle(WidgetTester tester, [int ticks = 40]) async {
  for (var i = 0; i < ticks; i++) {
    await tester.pump(const Duration(milliseconds: 50));
  }
}

/// Runs [body] with layout-overflow noise ignored (the test font draws every
/// glyph as a full em square, so rows that fit on a device overflow here).
Future<void> _quietly(WidgetTester tester, Size size,
    Future<void> Function() body) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
  final original = FlutterError.onError;
  FlutterError.onError = (details) {
    if (details.exceptionAsString().contains('overflowed')) return;
    original?.call(details);
  };
  try {
    await body();
  } finally {
    FlutterError.onError = original;
  }
}

/// Signs in through the real login screen as [role]. Nothing the dashboards
/// need is provided, so the sign-in stops right after the session is saved
/// (its next step looks up a provider that is not there) instead of opening a
/// dashboard. Returns what that stop threw. Staff / Tenant / Vendor sign in
/// from an un-awaited step, so their stop is caught by a zone around the tap.
Future<List<Object>> _signIn(WidgetTester tester, String role) async {
  final stops = <Object>[];
  await _quietly(tester, const Size(390, 2000), () async {
    await http.runWithClient(() async {
      await tester.pumpWidget(MultiProvider(
        providers: [
          // Vendor sign-in loads these before it saves the session.
          ChangeNotifierProvider(create: (_) => PermissionProvider()),
        ],
        child: const MaterialApp(home: Login_Screen()),
      ));
      await tester.pump();
      await tester.enterText(_field('Email Address'), 'pat@example.com');
      await tester.enterText(_field('Password'), 'Secret#123');
      final login = find.text('Login').last;
      await tester.ensureVisible(login);
      await tester.pump();
      await runZonedGuarded(() => tester.tap(login), (e, _) => stops.add(e));
      await _settle(tester);
      final caught = tester.takeException();
      if (caught != null) stops.add(caught);
      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(seconds: 1));
    }, () => MockClient(_LoginServer(role).handle));
  });
  return stops;
}

Future<void> _pumpSettings(WidgetTester tester) async {
  final dates = DateProvider();
  await dates.loadDateFormat();
  await tester.pumpWidget(MultiProvider(
    providers: [
      ChangeNotifierProvider<DateProvider>.value(value: dates),
      ChangeNotifierProvider(create: (_) => ThemeProvider()),
      ChangeNotifierProvider(create: (_) => NotificationProvider()),
      // Provided app-wide (main.dart); Settings reads it when a staff id is set.
      ChangeNotifierProvider(create: (_) => StaffPermissionProvider()),
    ],
    child: const MaterialApp(home: TabBarExample()),
  ));
  await _settle(tester);
}

Future<void> _closeSettings(WidgetTester tester) async {
  await tester.pumpWidget(const SizedBox());
  await tester.pump(const Duration(seconds: 5));
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    _settingsIds.clear();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
            const MethodChannel('PonnamKarthik/fluttertoast'), (_) async => true);
    ConnectivityPlatform.instance = _OnlineConnectivity();
  });

  group('sign-in', () {
    const saved = {'admin': 'Admin', 'tenant': 'Tenant', 'vendor': 'Vendor'};
    for (final role in saved.keys) {
      testWidgets('${saved[role]} sign-in drops the staff id a Staff session left',
          (tester) async {
        SharedPreferences.setMockInitialValues(Map.of(_afterStaffSession));
        final stops = await _signIn(tester, role);
        expect(stops, everyElement(isA<ProviderNotFoundException>()),
            reason: 'only the planned stop after the session is saved');

        final prefs = await SharedPreferences.getInstance();
        expect(prefs.getString('role'), saved[role],
            reason: 'the new session was saved');
        expect(prefs.containsKey('staff_id'), isFalse,
            reason: 'no old staff id left for the shared screens to send');
      });
    }

    testWidgets('a Staff sign-in keeps its own staff id', (tester) async {
      SharedPreferences.setMockInitialValues(Map.of(_afterStaffSession));
      final stops = await _signIn(tester, 'staffmember');
      expect(stops, everyElement(isA<ProviderNotFoundException>()));

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('role'), 'Staffmember');
      expect(prefs.getString('staff_id'), 'STAFF-NEW');
    });
  });

  group('launch clean-up', () {
    for (final role in ['Admin', 'Tenant', 'Vendor']) {
      test('$role session: drops a leftover staff id, keeps the rest',
          () async {
        SharedPreferences.setMockInitialValues({
          'token': 'tkn',
          'adminId': 'ADMIN-1',
          'role': role,
          'staff_id': _oldStaffId,
        });
        await dropStaleStaffId();
        final prefs = await SharedPreferences.getInstance();
        expect(prefs.containsKey('staff_id'), isFalse);
        expect(prefs.getString('token'), 'tkn', reason: 'still signed in');
        expect(prefs.getString('adminId'), 'ADMIN-1');
        expect(prefs.getString('role'), role);
      });
    }

    test('Staff session keeps its staff id', () async {
      SharedPreferences.setMockInitialValues({
        'token': 'tkn',
        'adminId': 'ADMIN-1',
        'role': 'Staffmember',
        'staff_id': 'STAFF-1',
      });
      await dropStaleStaffId();
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('staff_id'), 'STAFF-1');
    });

    test('signed out: nothing left for the next sign-in to pick up', () async {
      SharedPreferences.setMockInitialValues({'staff_id': _oldStaffId});
      await dropStaleStaffId();
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.containsKey('staff_id'), isFalse);
    });

    test('runs at app start', () {
      final main = File('lib/main.dart').readAsStringSync();
      expect(main, contains('await dropStaleStaffId();'));
    });
  });

  testWidgets(
      'Settings as Admin: the old staff id got 401s; after the clean-up every '
      'call sends the Admin id', (tester) async {
    SharedPreferences.setMockInitialValues({
      'token': 'tkn',
      'adminId': 'ADMIN-1',
      'userId': 'ADMIN-1',
      'role': 'Admin',
      'staff_id': _oldStaffId,
    });
    await _quietly(tester, const Size(430, 3200), () async {
      await http.runWithClient(() async {
        // Before: what the simulator showed.
        await _pumpSettings(tester);
        expect(_settingsIds, contains('CRM $_oldStaffId'));
        expect(find.textContaining('Failed to fetch vendors'), findsWidgets);
        await _closeSettings(tester);

        // What every launch and every Admin sign-in now does first.
        await dropStaleStaffId();
        _settingsIds.clear();
        await _pumpSettings(tester);
        expect(_settingsIds, contains('CRM ADMIN-1'));
        expect(_settingsIds, isNot(contains('CRM $_oldStaffId')));
        expect(find.textContaining('Failed to fetch vendors'), findsNothing);
        await _closeSettings(tester);
      }, () => _settingsServer);
    });
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
