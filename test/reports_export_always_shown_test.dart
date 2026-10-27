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
import 'package:three_zero_two_property/StaffModule/screen/Reports/ReportScreens/DelinquentTenants.dart'
    as staff_delinquent;
import 'package:three_zero_two_property/StaffModule/screen/Reports/ReportScreens/RentersInsurance.dart'
    as staff_renters;
import 'package:three_zero_two_property/provider/dateProvider.dart';
import 'package:three_zero_two_property/provider/notification_provider.dart';
import 'package:three_zero_two_property/screens/Reports/ReportScreens/DelinquentTenants.dart'
    as admin_delinquent;
import 'package:three_zero_two_property/screens/Reports/ReportScreens/RentersInsurance.dart'
    as admin_renters;

/// Reports → Renters Insurance and Delinquent Tenants: like staging web
/// (RentersInsurance.jsx / DelinquentTenants.jsx render <CommonExportButton>
/// with no gate, outside the loading and empty branches), the search box and
/// an enabled Export show in every state, including an empty report. Admin
/// and Staff. Every other report hides Export when empty, like web.

/// [status] 200 + empty data, or 404 (the server's "no rows" reply); the
/// reply waits [delay] so the loading state can be checked.
MockClient _server({int status = 200, Duration delay = Duration.zero}) =>
    MockClient((request) async {
      final path = request.url.path;
      if (path == '/api/auth') {
        return _json({
          'statusCode': 200,
          'themes': {'format': 'YYYY-MM-DD', 'timeFormat': '12'}
        });
      }
      if (path.startsWith('/api/renter-insurance/report/') ||
          path.startsWith('/api/charge/delinquent/')) {
        await Future<void>.delayed(delay);
        return status == 404
            ? _json({'statusCode': 404, 'message': 'No leases found'}, 404)
            : _json({'statusCode': 200, 'data': []});
      }
      return _json({'statusCode': 200, 'data': []});
    });

http.Response _json(Object body, [int code = 200]) => http.Response(
    jsonEncode(body), code,
    headers: {'content-type': 'application/json'});

Future<void> _settle(WidgetTester tester, [int ticks = 16]) async {
  for (var i = 0; i < ticks; i++) {
    await tester.pump(const Duration(milliseconds: 50));
  }
}

Finder get _export => find.byType(PopupMenuButton<String>);

typedef _Screen = Widget Function();

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
            const MethodChannel('PonnamKarthik/fluttertoast'), (_) async => true);
    ConnectivityPlatform.instance = _Online();
  });

  final screens = <String, (bool, _Screen)>{
    'Admin Renters Insurance': (false, () => admin_renters.RentersInsurance()),
    'Staff Renters Insurance': (true, () => staff_renters.RentersInsurance()),
    'Admin Delinquent Tenants': (
      false,
      () => admin_delinquent.DelinquentTenants()
    ),
    'Staff Delinquent Tenants': (
      true,
      () => staff_delinquent.DelinquentTenants()
    ),
  };

  Future<void> open(WidgetTester tester, bool isStaff, _Screen screen,
      MockClient server, Future<void> Function() body) async {
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
        await body();
      }, () => server);
      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(seconds: 3));
    } finally {
      FlutterError.onError = original;
    }
  }

  void expectEnabledExport(WidgetTester tester, String reason) {
    expect(_export, findsOneWidget, reason: reason);
    expect(tester.widget<PopupMenuButton<String>>(_export).enabled, isTrue,
        reason: reason);
    expect(find.text('Export'), findsOneWidget, reason: reason);
  }

  screens.forEach((name, entry) {
    final (isStaff, screen) = entry;

    testWidgets('$name: empty report still shows an enabled Export, like web',
        (tester) async {
      await open(tester, isStaff, screen, _server(), () async {
        await _settle(tester, 30);
        expect(find.text('No Data Available'), findsOneWidget);
        expectEnabledExport(tester, 'empty report');
      });
    });

    testWidgets('$name: server 404 "no rows" → Export still shown',
        (tester) async {
      await open(tester, isStaff, screen, _server(status: 404), () async {
        await _settle(tester, 30);
        expectEnabledExport(tester, '404 empty report');
      });
    });

    testWidgets('$name: Export shown while the report loads, like web',
        (tester) async {
      await open(tester, isStaff, screen,
          _server(delay: const Duration(seconds: 2)), () async {
        await _settle(tester, 6); // 0.3 s: still waiting for the server
        expectEnabledExport(tester, 'loading');
        await _settle(tester, 50); // let the reply land
      });
    });
  });
}

class _Online extends ConnectivityPlatform with MockPlatformInterfaceMixin {
  @override
  Future<ConnectivityResult> checkConnectivity() async =>
      ConnectivityResult.wifi;
  @override
  Stream<ConnectivityResult> get onConnectivityChanged => const Stream.empty();
}
