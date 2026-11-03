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
import 'package:three_zero_two_property/provider/color_theme.dart';
import 'package:three_zero_two_property/provider/dateProvider.dart';
import 'package:three_zero_two_property/provider/notification_provider.dart';
import 'package:three_zero_two_property/screens/Profile/Settings_screen.dart';

/// Settings → Late Fees, like web staging: the amount field's label carries
/// its unit, "Amount ($)" for a fixed late fee and "Percentage (%)" for a
/// percent one. Admin and Staff share this Settings screen.

/// The late fee the fake server returns.
String _calculationType = 'fixed';

final _server = MockClient((request) async {
  final path = request.url.path;
  Object body = {'statusCode': 200, 'data': []};
  if (path == '/api/auth') {
    body = {
      'statusCode': 200,
      'themes': {'format': 'YYYY-MM-DD', 'timeFormat': '24'}
    };
  } else if (path.startsWith('/api/latefee/latefee/')) {
    body = {
      'statusCode': 200,
      'data': {
        '_id': 'L-1',
        'admin_id': 'ADMIN-1',
        'createdAt': '2026-10-01T10:00:00.000Z',
        'updatedAt': '2026-10-01T10:00:00.000Z',
        'is_delete': false,
        '__v': 0,
        'latefee_id': 'LF-1',
        'duration': 5,
        'late_fee': 25,
        'grace_balance': 0,
        'calculation_type': _calculationType,
        'charge_account': 'Late Fee Income',
        'description': '',
      }
    };
  } else if (path.startsWith('/api/permission/permission/')) {
    body = {
      'statusCode': 200,
      'data': {
        'staff_permission': {'setting_view': true}
      }
    };
  }
  return http.Response(jsonEncode(body), 200,
      headers: {'content-type': 'application/json'});
});

Future<void> _settle(WidgetTester tester, [int ticks = 30]) async {
  for (var i = 0; i < ticks; i++) {
    await tester.pump(const Duration(milliseconds: 50));
  }
}

Future<void> _tap(WidgetTester tester, String label) async {
  final target = find.text(label).last;
  await tester.ensureVisible(target);
  await tester.pump();
  await tester.tap(target, warnIfMissed: false);
  await _settle(tester, 20);
}

/// Opens the real Settings screen on its Late Fees section.
Future<void> _openLateFees(WidgetTester tester, {required bool staff}) async {
  SharedPreferences.setMockInitialValues(staff
      ? {
          'token': 'tkn',
          'adminId': 'ADMIN-1',
          'staff_id': 'STAFF-1',
          'role': 'Staffmember'
        }
      : {'token': 'tkn', 'adminId': 'ADMIN-1', 'role': 'Admin'});
  tester.view.physicalSize = const Size(430, 3200);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
  final dates = DateProvider();
  await dates.loadDateFormat();
  final permissions = StaffPermissionProvider();
  await permissions.fetchPermissions();
  await tester.pumpWidget(MultiProvider(
    providers: [
      ChangeNotifierProvider<DateProvider>.value(value: dates),
      ChangeNotifierProvider(create: (_) => ThemeProvider()),
      ChangeNotifierProvider(create: (_) => NotificationProvider()),
      ChangeNotifierProvider<StaffPermissionProvider>.value(
          value: permissions),
    ],
    child: const MaterialApp(home: TabBarExample()),
  ));
  await _settle(tester, 40);
  await _tap(tester, 'Late Fees');
  await _settle(tester, 20);
}

Future<void> _run(WidgetTester tester, Future<void> Function() body) async {
  final original = FlutterError.onError;
  // Layout overflow (test font) and images (no decoding in tests) are noise
  // here.
  FlutterError.onError = (details) {
    if (details.exceptionAsString().contains('overflowed')) return;
    if (details.library == 'image resource service') return;
    original?.call(details);
  };
  try {
    await http.runWithClient(() async {
      await body();
      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(seconds: 2));
    }, () => _server);
  } finally {
    FlutterError.onError = original;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    _calculationType = 'fixed';
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
            const MethodChannel('PonnamKarthik/fluttertoast'), (_) async => true);
    ConnectivityPlatform.instance = _OnlineConnectivity();
  });

  testWidgets('Admin: Amount (\$) for fixed, Percentage (%) after picking Percent',
      (tester) async {
    await _run(tester, () async {
      await _openLateFees(tester, staff: false);
      expect(find.text('Amount (\$)'), findsOneWidget);
      expect(find.text('Percentage (%)'), findsNothing);

      await _tap(tester, 'Percent');
      expect(find.text('Percentage (%)'), findsOneWidget);
      expect(find.text('Amount (\$)'), findsNothing);
    });
  });

  for (final type in ['fixed', 'percent']) {
    final label = type == 'fixed' ? 'Amount (\$)' : 'Percentage (%)';
    testWidgets('Staff: a saved $type late fee shows "$label"', (tester) async {
      _calculationType = type;
      await _run(tester, () async {
        await _openLateFees(tester, staff: true);
        expect(find.text(label), findsOneWidget);
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
