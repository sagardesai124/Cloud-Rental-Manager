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

/// Reports → Renters Insurance and Delinquent Tenants: the search box and
/// Export show in every state, and Export is greyed out and not tappable
/// while the report has no data (empty, the server's 404 "no rows", or still
/// loading), like every other report (QA retest of the Export-when-empty
/// ticket: Renter's Insurance kept Export enabled). With data it works.
/// Admin and Staff.

/// [status] 200 + empty data, or 404 (the server's "no rows" reply); the
/// reply waits [delay] so the loading state can be checked. [withRow] sends
/// one row instead of none.
MockClient _server(
        {int status = 200,
        Duration delay = Duration.zero,
        bool withRow = false}) =>
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
            : _json({
                'statusCode': 200,
                'data': withRow
                    ? [
                        path.startsWith('/api/renter-insurance/report/')
                            ? _renterRow
                            : _delinquentRow
                      ]
                    : [],
                if (withRow && path.startsWith('/api/charge/delinquent/'))
                  'grandtotal': _totals,
              });
      }
      return _json({'statusCode': 200, 'data': []});
    });

const _totals = {
  'last_30_days': 120,
  'last_31_to_60_days': 0,
  'last_61_to_90_days': 0,
  'last_91_plus_days': 0,
  'totalDaysAmount': 120,
};

const _renterRow = {
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
};

const _delinquentRow = {
  'lease_id': 'L-1',
  'rental_address': '12 Test Street',
  'tenants': [
    {
      'tenant_id': 'T-1',
      'tenant_name': 'Pat Tenant',
      'unit_details': '',
      'Charges': [],
      'pdf_data': _totals,
    }
  ],
  'alltotalamount': _totals,
};

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

  /// Export is on screen; [enabled] says whether it can be used. Greyed is
  /// the button's disabled look (grey with white text) and no menu.
  void expectExport(WidgetTester tester, String reason,
      {required bool enabled}) {
    expect(_export, findsOneWidget, reason: reason);
    expect(find.text('Export'), findsOneWidget, reason: reason);
    expect(tester.widget<PopupMenuButton<String>>(_export).enabled, enabled,
        reason: reason);
    final button = tester.widget<ElevatedButton>(find.ancestor(
        of: _export, matching: find.byType(ElevatedButton)));
    expect(button.onPressed != null, enabled, reason: reason);
  }

  screens.forEach((name, entry) {
    final (isStaff, screen) = entry;

    testWidgets('$name: empty report shows Export greyed out',
        (tester) async {
      await open(tester, isStaff, screen, _server(), () async {
        await _settle(tester, 30);
        expect(find.text('No Data Available'), findsOneWidget);
        expectExport(tester, 'empty report', enabled: false);
        // Tapping it opens nothing.
        await tester.tap(find.text('Export'), warnIfMissed: false);
        await _settle(tester, 6);
        expect(find.text('CSV'), findsNothing);
      });
    });

    testWidgets('$name: with data, Export works', (tester) async {
      await open(tester, isStaff, screen, _server(withRow: true), () async {
        await _settle(tester, 30);
        expect(find.text('No Data Available'), findsNothing);
        expectExport(tester, 'report with a row', enabled: true);
        await tester.tap(find.text('Export'));
        await _settle(tester, 6);
        expect(find.text('CSV'), findsOneWidget, reason: 'menu opens');
        await tester.tapAt(const Offset(5, 5)); // close the menu
        await _settle(tester, 6);
      });
    });

    testWidgets('$name: server 404 "no rows" → Export greyed out',
        (tester) async {
      await open(tester, isStaff, screen, _server(status: 404), () async {
        await _settle(tester, 30);
        expectExport(tester, '404 empty report', enabled: false);
      });
    });

    testWidgets('$name: Export shown but greyed while the report loads',
        (tester) async {
      await open(tester, isStaff, screen,
          _server(delay: const Duration(seconds: 2)), () async {
        await _settle(tester, 6); // 0.3 s: still waiting for the server
        expectExport(tester, 'loading', enabled: false);
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
