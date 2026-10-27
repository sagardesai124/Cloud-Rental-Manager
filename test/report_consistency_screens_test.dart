import 'dart:async';
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
import 'package:three_zero_two_property/StaffModule/screen/Rental/mortgage/mortgageTable.dart'
    as s_mort;
import 'package:three_zero_two_property/StaffModule/screen/Reports/ReportScreens/CustomReportBuilder.dart'
    as s_crb;
import 'package:three_zero_two_property/StaffModule/screen/Reports/ReportScreens/ExpiringLeases.dart'
    as s_exl;
import 'package:three_zero_two_property/StaffModule/screen/Reports/ReportScreens/LeaseRenewalReport.dart'
    as s_lr;
import 'package:three_zero_two_property/StaffModule/screen/Reports/ReportScreens/LoanSummaryReport.dart'
    as s_loan;
import 'package:three_zero_two_property/StaffModule/screen/Reports/ReportScreens/OutstandingLeaseBalance.dart'
    as s_olb;
import 'package:three_zero_two_property/StaffModule/screen/Reports/ReportScreens/Recurring_Payments_Configuration_table.dart'
    as s_rec;
import 'package:three_zero_two_property/provider/dateProvider.dart';
import 'package:three_zero_two_property/provider/notification_provider.dart';
import 'package:three_zero_two_property/screens/Rental/mortgage/mortgageTable.dart'
    as a_mort;
import 'package:three_zero_two_property/screens/Reports/ReportScreens/CustomReportBuilder.dart'
    as a_crb;
import 'package:three_zero_two_property/screens/Reports/ReportScreens/ExpiringLeases.dart'
    as a_exl;
import 'package:three_zero_two_property/screens/Reports/ReportScreens/ReopenWorkorder.dart';
import 'package:three_zero_two_property/screens/Reports/ReportScreens/LeaseRenewalReport.dart'
    as a_lr;
import 'package:three_zero_two_property/screens/Reports/ReportScreens/LoanSummaryReport.dart'
    as a_loan;
import 'package:three_zero_two_property/screens/Reports/ReportScreens/OutstandingLeaseBalance.dart'
    as a_olb;
import 'package:three_zero_two_property/screens/Reports/ReportScreens/Recurring_Payments_Configuration_table.dart'
    as a_rec;

/// QA (Android 1.0.245+248), checked on the real screens with an empty
/// server reply, in Admin and Staff:
/// - every report has the back arrow beside its title;
/// - with no data, every report shows the standard empty state: the
///   magnifying-glass picture (transparent, so no white box on grey pages)
///   with a bold "No Data Available" heading;
/// - Expiring Lease uses the same filters as the other reports.

/// Every request gets an empty, successful reply.
final _emptyServer = MockClient((request) async {
  Object body = {'statusCode': 200, 'success': true, 'data': []};
  if (request.url.path.contains('lease-renewal-report')) {
    body = {
      'statusCode': 200,
      'data': {'leases_ending': [], 'mtm_leases': [], 'summary': {}},
    };
  }
  return http.Response(jsonEncode(body), 200,
      headers: {'content-type': 'application/json'});
});

const Map<String, Object> _adminPrefs = {
  'token': 'tkn',
  'adminId': 'ADMIN-1',
  'role': 'Admin',
};
const Map<String, Object> _staffPrefs = {
  'token': 'tkn',
  'adminId': 'ADMIN-1',
  'role': 'Staffmember',
  'staff_id': 'STAFF-1',
};

Future<void> _settle(WidgetTester tester, [int ticks = 20]) async {
  for (var i = 0; i < ticks; i++) {
    await tester.pump(const Duration(milliseconds: 50));
  }
}

Future<void> _show(WidgetTester tester, Widget screen) async {
  tester.view.physicalSize = const Size(1080, 4000);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
  final permissions = StaffPermissionProvider();
  await permissions.fetchPermissions();
  await tester.pumpWidget(MultiProvider(
    providers: [
      ChangeNotifierProvider(create: (_) => DateProvider()),
      ChangeNotifierProvider(create: (_) => NotificationProvider()),
      ChangeNotifierProvider<StaffPermissionProvider>.value(value: permissions),
    ],
    child: MaterialApp(home: Scaffold(body: screen)),
  ));
  await _settle(tester, 40);
}

Future<void> _finish(WidgetTester tester) async {
  await tester.pump(const Duration(seconds: 5));
  await _settle(tester, 10);
  await tester.pumpWidget(const SizedBox());
  await tester.pump(const Duration(seconds: 2));
}

/// The test font draws every glyph as a full em square, so dense rows
/// overflow here; that layout noise is ignored.
Future<void> _run(Future<void> Function() body) async {
  final original = FlutterError.onError;
  FlutterError.onError = (details) {
    if (details.exceptionAsString().contains('overflowed')) return;
    original?.call(details);
  };
  try {
    await http.runWithClient(body, () => _emptyServer);
  } finally {
    FlutterError.onError = original;
  }
}

final _picture = find.byWidgetPredicate((w) =>
    w is Image &&
    w.image is AssetImage &&
    (w.image as AssetImage).assetName ==
        'assets/images/no_data_transparent.png');

void _expectStandardEmptyState([String text = 'No Data Available']) {
  expect(_picture, findsOneWidget, reason: 'magnifying-glass picture');
  expect(find.text(text), findsOneWidget);
  final heading = find.text(text).evaluate().single.widget as Text;
  expect(heading.style?.fontWeight, FontWeight.bold);
}

class _Case {
  const _Case(this.name, this.build,
      {this.oldTexts = const [], this.heading = 'No Data Available'});
  final String name;
  final Widget Function() build;
  final List<String> oldTexts;
  final String heading;
}

List<_Case> _cases(bool staff) => [
      _Case(
          'Recurring Payments Configuration',
          () => staff
              ? const s_rec.Recurring_Payments_Configuration_Report()
              : const a_rec.Recurring_Payments_Configuration_Report()),
      _Case('Lease Renewal',
          () => staff ? s_lr.LeaseRenewalReportScreen() : a_lr.LeaseRenewalReportScreen(),
          oldTexts: ['LEASES ENDING (0)', 'MONTH-TO-MONTH (0)']),
      _Case('Mortgages',
          () => staff ? const s_mort.MortgageTable() : const a_mort.MortgageTable(),
          oldTexts: [
            'No mortgages found',
            'Try adjusting your search or add a new mortgage'
          ]),
      _Case('Loan Summary',
          () => staff ? const s_loan.Loansummaryreport() : const a_loan.Loansummaryreport(),
          oldTexts: ['No loans found']),
      _Case('Outstanding Lease Balance',
          () => staff ? s_olb.OutstandingLeaseBalance() : a_olb.OutstandingLeaseBalance(),
          oldTexts: ['No Outstanding Lease Balance Data']),
      _Case('Expiring Lease',
          () => staff ? s_exl.ExpiringLeases() : a_exl.ExpiringLeases()),
      _Case('Reopen Work Orders',
          () => ReopenWorkorder(isStaffMode: staff),
          oldTexts: ['No Work Orders on Hold Found', 'No reopen work orders found']),
      // Before a saved report is picked: web's prompt, same design.
      _Case('Custom Report Builder',
          () => staff ? const s_crb.CustomReportBuilder() : const a_crb.CustomReportBuilder(),
          heading: 'Please select a saved report',
          oldTexts: ['Select a report from Saved Reports to view data', 'No data for this report']),
    ];

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
            const MethodChannel('PonnamKarthik/fluttertoast'), (_) async => true);
    ConnectivityPlatform.instance = _OnlineConnectivity();
  });

  for (final staff in [false, true]) {
    final role = staff ? 'Staff' : 'Admin';
    group(role, () {
      for (final c in _cases(staff)) {
        testWidgets('${c.name}: back arrow and standard empty state',
            (tester) async {
          SharedPreferences.setMockInitialValues(staff ? _staffPrefs : _adminPrefs);
          await _run(() async {
            await _show(tester, c.build());
            expect(find.byIcon(Icons.arrow_back_ios_new), findsOneWidget,
                reason: 'back arrow beside the title');
            _expectStandardEmptyState(c.heading);
            for (final old in c.oldTexts) {
              expect(find.textContaining(old), findsNothing, reason: old);
            }
            expect(find.byIcon(Icons.inbox_outlined), findsNothing);
            await _finish(tester);
          });
        });
      }

      testWidgets('Expiring Lease: filters like the other reports',
          (tester) async {
        SharedPreferences.setMockInitialValues(staff ? _staffPrefs : _adminPrefs);
        await _run(() async {
          await _show(tester, staff ? s_exl.ExpiringLeases() : a_exl.ExpiringLeases());
          // No card labels or calendar icons.
          for (final label in ['DATE RANGE', 'FROM', 'TO', 'MM/DD/YYYY']) {
            expect(find.text(label), findsNothing, reason: label);
          }
          expect(find.byIcon(Icons.calendar_today_outlined), findsNothing);
          // Outlined Date Range, From and To, then Run beside Export.
          expect(find.text('Custom Date'), findsOneWidget);
          expect(find.text('From'), findsOneWidget);
          expect(find.text('To'), findsOneWidget);
          final run = tester.getRect(find.text('Run'));
          final export = tester.getRect(find.text('Export'));
          expect((run.center.dy - export.center.dy).abs(), lessThan(2),
              reason: 'Run and Export on one row');
          expect(export.left, greaterThan(run.right));
          expect(tester.getRect(find.text('From')).bottom,
              lessThan(run.top), reason: 'dates above the buttons');
          await _finish(tester);
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
