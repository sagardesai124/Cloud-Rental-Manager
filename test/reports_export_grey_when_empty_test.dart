import 'dart:convert';

import 'package:connectivity_plus_platform_interface/connectivity_plus_platform_interface.dart';
import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:three_zero_two_property/StaffModule/repository/staffpermission_provider.dart';
import 'package:three_zero_two_property/StaffModule/screen/Reports/ReportScreens/Expiring_Insurance.dart'
    as staff;
import 'package:three_zero_two_property/StaffModule/screen/Reports/ReportScreens/Home_System_Report.dart'
    as staff_home;
import 'package:three_zero_two_property/screens/Reports/ReportScreens/Home_System_Report.dart'
    as admin_home;
import 'package:three_zero_two_property/provider/dateProvider.dart';
import 'package:three_zero_two_property/provider/notification_provider.dart';
import 'package:three_zero_two_property/screens/Reports/ReportScreens/Expiring_Insurance.dart'
    as admin;

/// Reports → Export: a report with no data shows Export greyed out and
/// untappable (QA ticket: "disabled, greyed out, not hidden", same as the
/// CRM-4567 list screens); with data it is the normal enabled Export. Export
/// always keeps its place, so Run never resizes. Expiring Insurance is the
/// example from the ticket. Admin and Staff.

const _policy = {
  '_id': 'P-1',
  'renters_insurance_id': 'RI-1',
  'lease_id': 'L-1',
  'tenants': [],
  'insurance_company': 'Pwc',
  'policy_id': 'POL-1',
  'effective_date': '2026-03-03',
  'expiration_date': '2026-03-20',
  'tenant_details': [],
};

MockClient _server(List<Map<String, Object>> policies) =>
    MockClient((request) async {
      final path = request.url.path;
      if (path == '/api/auth') {
        return _json({
          'statusCode': 200,
          'themes': {'format': 'YYYY-MM-DD', 'timeFormat': '12'}
        });
      }
      if (path == '/api/renter-insurance/expiring-policies') {
        return _json({'statusCode': 200, 'data': policies});
      }
      return _json({'statusCode': 200, 'data': []});
    });

http.Response _json(Object body) => http.Response(jsonEncode(body), 200,
    headers: {'content-type': 'application/json'});

Future<void> _settle(WidgetTester tester, [int ticks = 16]) async {
  for (var i = 0; i < ticks; i++) {
    await tester.pump(const Duration(milliseconds: 50));
  }
}

/// The report's Export trigger (the only live PopupMenuButton on the screen).
Finder get _export => find.byType(PopupMenuButton<String>);

/// Export is on screen, enabled or greyed out.
void _expectExport(WidgetTester tester,
    {required bool enabled, required String reason}) {
  expect(_export, findsOneWidget, reason: '$reason: Export keeps its place');
  expect(tester.widget<PopupMenuButton<String>>(_export).enabled, enabled,
      reason: reason);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
            const MethodChannel('PonnamKarthik/fluttertoast'), (_) async => true);
    ConnectivityPlatform.instance = _Online();
  });

  Future<void> openAndRun(WidgetTester tester, bool isStaff,
      List<Map<String, Object>> policies,
      {required Future<void> Function() beforeRun,
      required Future<void> Function() afterRun}) async {
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
          child: MaterialApp(
            home:
                isStaff ? staff.ExpiringInsurance() : admin.ExpiringInsurance(),
          ),
        ));
        await _settle(tester, 30);
        await beforeRun();
        await tester.tap(find.text('Run'));
        await _settle(tester, 20);
        await afterRun();
      }, () => _server(policies));
      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(seconds: 2));
    } finally {
      FlutterError.onError = original;
    }
  }

  for (final isStaff in [false, true]) {
    final role = isStaff ? 'Staff' : 'Admin';

    testWidgets('$role Expiring Insurance: no data → Export greyed, untappable',
        (tester) async {
      await openAndRun(tester, isStaff, const [],
          beforeRun: () async => _expectExport(tester,
              enabled: false, reason: 'greyed before Run'),
          afterRun: () async {
            _expectExport(tester,
                enabled: false, reason: 'empty report → Export greyed');
            expect(_runWidth(tester), lessThan(430 * 0.6),
                reason: 'Run keeps its half of the row, not full width');
            await tester.tap(_export, warnIfMissed: false);
            await _settle(tester, 6);
            expect(find.text('CSV'), findsNothing,
                reason: 'tapping a greyed Export opens nothing');
          });
    });

    testWidgets('$role Expiring Insurance: rows → Export shown and enabled',
        (tester) async {
      late double runBefore;
      await openAndRun(tester, isStaff, const [_policy],
          beforeRun: () async {
            _expectExport(tester, enabled: false, reason: 'no data yet');
            runBefore = _runWidth(tester);
          },
          afterRun: () async {
            expect(_runWidth(tester), runBefore,
                reason: 'Run is the same width with Export greyed or enabled');
            _expectExport(tester, enabled: true, reason: 'report has rows');
          });
    });
  }

  _homeTests();
}

/// Home System's Run button (a FontAwesome play icon, which find.byIcon
/// does not match).
Finder get _run => find
    .byWidgetPredicate(
        (w) => w is FaIcon && w.icon == FontAwesomeIcons.circlePlay)
    .first;

/// Width of the report's Run button: it keeps its half of the row whether
/// Export is greyed or enabled.
double _runWidth(WidgetTester tester) => tester
    .getSize(find
        .ancestor(of: find.text('Run'), matching: find.byType(ElevatedButton))
        .first)
    .width;

/// Home System: web clears the report when the property changes
/// (HomeSystemReport.jsx handlePropertySelect → setApplianceData([])), so
/// Export is greyed again until the next Run.
MockClient _homeServer() => MockClient((request) async {
      final path = request.url.path;
      if (path == '/api/auth') {
        return _json({
          'statusCode': 200,
          'themes': {'format': 'YYYY-MM-DD', 'timeFormat': '12'}
        });
      }
      if (path.startsWith('/api/rentals/rentals/')) {
        return _json({
          'statusCode': 200,
          'data': [
            {'rental_id': 'R-1', 'rental_adress': '1 Elm St'},
            {'rental_id': 'R-2', 'rental_adress': '9 Oak Ave'},
          ]
        });
      }
      if (path.startsWith('/api/appliance/appliance-report/')) {
        return _json({
          'statusCode': 200,
          'data': {
            'rental_id': path.split('/').last,
            'total_units': 1,
            'total_appliances': 0,
            'units': [
              {
                'unit_id': 'U-1',
                'unit_address': '1 Elm St',
                'unit_number': 'A',
                'total_appliances': 0,
                'appliances': [],
              }
            ],
          }
        });
      }
      return _json({'statusCode': 200, 'data': []});
    });

void _homeTests() {
  for (final isStaff in [false, true]) {
    final role = isStaff ? 'Staff' : 'Admin';
    testWidgets(
        '$role Home System: Export enabled after Run, greyed again when the property '
        'changes, like web', (tester) async {
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
            child: MaterialApp(
              home: isStaff
                  ? staff_home.HomeSystemReportScreen()
                  : admin_home.HomeSystemReportScreen(),
            ),
          ));
          await _settle(tester, 30);
          _expectExport(tester, enabled: false, reason: 'no report yet');

          Future<void> pick(String address) async {
            await tester.tap(find.text('Select Property').evaluate().isNotEmpty
                ? find.text('Select Property')
                : find.byType(DropdownButtonHideUnderline).first);
            await _settle(tester, 10);
            await tester.tap(find.text(address).last);
            await _settle(tester, 10);
          }

          await pick('1 Elm St');
          await tester.tap(_run);
          await _settle(tester, 20);
          _expectExport(tester, enabled: true, reason: 'report has units');

          await pick('9 Oak Ave');
          _expectExport(tester,
              enabled: false,
              reason: 'property changed → old report not exportable');

          await tester.tap(_run);
          await _settle(tester, 20);
          _expectExport(tester, enabled: true, reason: 'Run for the new property');
        }, _homeServer);
        await tester.pumpWidget(const SizedBox());
        await tester.pump(const Duration(seconds: 2));
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
