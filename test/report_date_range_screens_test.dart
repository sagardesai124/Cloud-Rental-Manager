import 'dart:convert';

import 'package:connectivity_plus_platform_interface/connectivity_plus_platform_interface.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:three_zero_two_property/StaffModule/repository/staffpermission_provider.dart';
import 'package:three_zero_two_property/StaffModule/screen/Reports/ReportScreens/AccountTotals.dart'
    as s_acc;
import 'package:three_zero_two_property/StaffModule/screen/Reports/ReportScreens/CompletedWorkOrders.dart'
    as s_cwo;
import 'package:three_zero_two_property/StaffModule/screen/Reports/ReportScreens/DailyTransaction.dart'
    as s_daily;
import 'package:three_zero_two_property/StaffModule/screen/Reports/ReportScreens/ExpiringLeases.dart'
    as s_exl;
import 'package:three_zero_two_property/StaffModule/screen/Reports/ReportScreens/LeaseRenewalReport.dart'
    as s_ren;
import 'package:three_zero_two_property/StaffModule/screen/Reports/ReportScreens/OpenWorkOrders.dart'
    as s_owo;
import 'package:three_zero_two_property/StaffModule/screen/Reports/ReportScreens/Payment_Exception.dart'
    as s_pe;
import 'package:three_zero_two_property/StaffModule/screen/Reports/ReportScreens/rentalownerreport.dart'
    as s_own;
import 'package:three_zero_two_property/constant/constant.dart';
import 'package:three_zero_two_property/provider/dateProvider.dart';
import 'package:three_zero_two_property/provider/notification_provider.dart';
import 'package:three_zero_two_property/screens/Reports/ReportScreens/AccountTotals.dart'
    as a_acc;
import 'package:three_zero_two_property/screens/Reports/ReportScreens/CompletedWorkOrders.dart'
    as a_cwo;
import 'package:three_zero_two_property/screens/Reports/ReportScreens/DailyTransaction.dart'
    as a_daily;
import 'package:three_zero_two_property/screens/Reports/ReportScreens/ExpiringLeases.dart'
    as a_exl;
import 'package:three_zero_two_property/screens/Reports/ReportScreens/LeaseRenewalReport.dart'
    as a_ren;
import 'package:three_zero_two_property/screens/Reports/ReportScreens/OpenWorkOrders.dart'
    as a_owo;
import 'package:three_zero_two_property/screens/Reports/ReportScreens/Payment_Exception.dart'
    as a_pe;
import 'package:three_zero_two_property/screens/Reports/ReportScreens/rentalownerreport.dart'
    as a_own;
import 'package:three_zero_two_property/widgets/report_date_range.dart';

/// The 8 date-range reports refuse a From date after the To date the way
/// web does (AccountTotalReport.jsx, DailyTransactionReport.jsx,
/// Rentalownerreport.jsx, Payment-Exception-Report/Report.jsx,
/// CompletedWorkReport.jsx, OpenWorkReport.jsx, ExpiringLease.jsx,
/// LeaseRenewalReport.jsx): the red message shows under the dates and Run is
/// disabled; correcting the dates clears it. Admin and Staff.

class _Report {
  final String name;
  final Widget Function() admin;
  final Widget Function() staff;
  final bool pickerBoxes;
  const _Report(this.name, this.admin, this.staff, {this.pickerBoxes = false});
}

/// Opens the [index]th date field (0 = From, 1 = To) and picks [day] of the
/// month it opens on.
Future<void> _pickDay(WidgetTester tester, int index, int day) async {
  await tester.tap(find.byKey(
      ValueKey(index == 0 ? 'expiring-lease-from' : 'expiring-lease-to')));
  await _settle(tester, 10);
  await tester.tap(find
      .descendant(
          of: find.byType(DatePickerDialog), matching: find.text('$day'))
      .first);
  await _settle(tester, 4);
  await tester.tap(find.text('OK'));
  await _settle(tester, 10);
}

final _reports = <_Report>[
  _Report('Account Totals', () => const a_acc.AccountTotalsReports(),
      () => const s_acc.AccountTotalsReports()),
  _Report('Daily Transaction', () => const a_daily.DailyTransactions(),
      () => const s_daily.DailyTransactions()),
  _Report('Rental Owner', () => const a_own.RentalOwnerReports(),
      () => const s_own.RentalOwnerReports()),
  _Report('Payment Exception', () => const a_pe.PaymentExceptionReports(),
      () => const s_pe.PaymentExceptionReports()),
  _Report('Completed Work Orders', () => a_cwo.CompletedWorkOrders(),
      () => s_cwo.CompletedWorkOrders()),
  _Report('Open Work Orders', () => a_owo.OpenWorkOrders(),
      () => s_owo.OpenWorkOrders()),
  _Report('Expiring Leases', () => a_exl.ExpiringLeases(),
      () => s_exl.ExpiringLeases(), pickerBoxes: true),
  _Report('Lease Renewal', () => a_ren.LeaseRenewalReportScreen(),
      () => s_ren.LeaseRenewalReportScreen()),
];

MockClient _server() => MockClient((request) async {
      if (request.url.path == '/api/auth') {
        return _json({
          'statusCode': 200,
          'themes': {'format': 'YYYY-MM-DD', 'timeFormat': '12'}
        });
      }
      if (request.url.path.startsWith('/api/rentals/rental-owners/')) {
        return http.Response('[]', 200,
            headers: {'content-type': 'application/json'});
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

/// The From and To fields: the read-only (picker) text fields, in order.
List<TextEditingController> _dateControllers(WidgetTester tester) => tester
    .widgetList<TextField>(find.byWidgetPredicate(
        (w) => w is TextField && w.readOnly && w.controller != null))
    .map((t) => t.controller!)
    .toList();

/// Run is disabled when its button has no onPressed (text button or the
/// Account Totals play icon).
bool _runEnabled(WidgetTester tester) {
  final icon = find.byTooltip('Run Report');
  if (icon.evaluate().isNotEmpty) {
    return tester
            .widget<IconButton>(
                find.ancestor(of: icon, matching: find.byType(IconButton)).first)
            .onPressed !=
        null;
  }
  final label = find.byWidgetPredicate((w) =>
      w is Text && (w.data == 'Run' || w.data == 'Run Report'));
  final button = find.ancestor(
      of: label.first,
      matching: find.byWidgetPredicate((w) => w is ButtonStyleButton));
  return tester.widget<ButtonStyleButton>(button.first).onPressed != null;
}

/// The Account Totals play icon's colour, or null on reports without it.
Color? _playIconColor(WidgetTester tester) {
  final icon = find.byWidgetPredicate(
      (w) => w is FaIcon && w.icon == FontAwesomeIcons.circlePlay);
  if (icon.evaluate().isEmpty) return null;
  return tester.widget<FaIcon>(icon.first).color;
}

void _redraw(WidgetTester tester) {
  // Date pickers set the text inside setState; do the same here.
  final st = tester.state(find.byWidgetPredicate((w) => w is StatefulWidget &&
      w.runtimeType.toString().contains(RegExp(
          r'^(AccountTotalsReports|DailyTransactions|RentalOwnerReports|PaymentExceptionReports|CompletedWorkOrders|OpenWorkOrders|ExpiringLeases|LeaseRenewalReportScreen)$'))));
  // ignore: invalid_use_of_protected_member
  st.setState(() {});
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
            const MethodChannel('PonnamKarthik/fluttertoast'), (_) async => true);
    ConnectivityPlatform.instance = _Online();
  });

  for (final isStaff in [false, true]) {
    for (final r in _reports) {
      testWidgets(
          '${isStaff ? 'Staff' : 'Admin'} ${r.name}: From after To shows '
          "web's message and disables Run", (tester) async {
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
              child: MaterialApp(home: isStaff ? r.staff() : r.admin()),
            ));
            await _settle(tester, 30);

            if (r.pickerBoxes) {
              // From the 20th, To the 1st: From after To.
              await _pickDay(tester, 0, 20);
              await _pickDay(tester, 1, 1);
            } else {
              if (_dateControllers(tester).length < 2) {
                // Lease Renewal shows its dates only for a Custom range.
                await tester.tap(find.byType(DropdownButton<String>).first);
                await _settle(tester, 10);
                await tester.tap(find.text('Custom').last);
                await _settle(tester, 10);
              }
              final c = _dateControllers(tester);
              expect(c.length, greaterThanOrEqualTo(2),
                  reason: 'From and To fields found');
              c[0].text = '2026-10-20';
              c[1].text = '2026-10-01';
              _redraw(tester);
              await _settle(tester, 4);
            }
            expect(find.text(reportDateRangeMessage), findsOneWidget);
            expect(_runEnabled(tester), isFalse, reason: 'Run disabled');
            if (_playIconColor(tester) != null) {
              expect(_playIconColor(tester), blueColor.withOpacity(0.6),
                  reason: 'play icon greyed while the range is invalid');
            }

            // Corrected.
            if (r.pickerBoxes) {
              await _pickDay(tester, 1, 28);
            } else {
              _dateControllers(tester)[1].text = '2026-10-31';
              _redraw(tester);
              await _settle(tester, 4);
            }
            expect(find.text(reportDateRangeMessage), findsNothing);
            expect(_runEnabled(tester), isTrue, reason: 'Run enabled again');
            if (_playIconColor(tester) != null) {
              expect(_playIconColor(tester), blueColor,
                  reason: 'play icon navy again once the range is valid');
            }
          }, _server);
          await tester.pumpWidget(const SizedBox());
          await tester.pump(const Duration(seconds: 2));
        } finally {
          FlutterError.onError = original;
        }
      });
    }
  }
}

class _Online extends ConnectivityPlatform with MockPlatformInterfaceMixin {
  @override
  Future<ConnectivityResult> checkConnectivity() async =>
      ConnectivityResult.wifi;
  @override
  Stream<ConnectivityResult> get onConnectivityChanged => const Stream.empty();
}
