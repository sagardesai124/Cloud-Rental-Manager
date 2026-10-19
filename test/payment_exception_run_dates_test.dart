import 'dart:convert';

import 'package:connectivity_plus_platform_interface/connectivity_plus_platform_interface.dart';
import 'package:dropdown_button2/dropdown_button2.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:intl/intl.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:three_zero_two_property/StaffModule/repository/staffpermission_provider.dart';
import 'package:three_zero_two_property/StaffModule/screen/Reports/ReportScreens/Payment_Exception.dart'
    as staff;
import 'package:three_zero_two_property/provider/dateProvider.dart';
import 'package:three_zero_two_property/provider/notification_provider.dart';
import 'package:three_zero_two_property/screens/Reports/ReportScreens/Payment_Exception.dart'
    as admin;

/// Payment Exception → Run Report works with every company date format,
/// including YYYY-MMM-DD (e.g. 2026-Oct-19), and sends startDate/endDate as
/// yyyy-MM-dd like web. Before, YYYY-MMM-DD dates could not be read, so
/// tapping Run Report did nothing.

final List<Uri> _reportCalls = [];

MockClient _server(String companyFormat) => MockClient((request) async {
      final path = request.url.path;
      if (path == '/api/auth') {
        return _json({
          'statusCode': 200,
          'themes': {'format': companyFormat, 'timeFormat': '12'}
        });
      }
      if (path.startsWith('/api/payment/exception-payments/')) {
        _reportCalls.add(request.url);
        return _json({'statusCode': 200, 'data': []});
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

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    _reportCalls.clear();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
            const MethodChannel('PonnamKarthik/fluttertoast'), (_) async => true);
    ConnectivityPlatform.instance = _Online();
  });

  for (final isStaff in [false, true]) {
    for (final format in ['YYYY-MMM-DD', 'MM/DD/YYYY', 'YYYY-MM-DD']) {
      testWidgets(
          '${isStaff ? 'Staff' : 'Admin'}, company format $format: Today → '
          'Run Report sends yyyy-MM-dd dates', (tester) async {
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
                    ? staff.PaymentExceptionReports()
                    : admin.PaymentExceptionReports(),
              ),
            ));
            await _settle(tester, 30);

            // Date Range → Today fills both dates in the company format.
            final label = find.text('Custom Date');
            expect(label, findsWidgets, reason: 'date range dropdown shown');
            final dropdown = find
                .ancestor(
                    of: label.first,
                    matching: find.byType(DropdownButton2<String>))
                .first;
            await tester.tap(dropdown);
            await _settle(tester, 10);
            // The menu opens scrolled to the selected "Custom Date" (last);
            // scroll up to "Today".
            await tester.scrollUntilVisible(find.text('Today'), -100,
                scrollable: find.byType(Scrollable).last);
            await _settle(tester, 4);
            await tester.tap(find.text('Today').last);
            await _settle(tester, 10);

            final run = find.text('Run Report');
            await tester.ensureVisible(run);
            await tester.pump();
            await tester.tap(run);
            await _settle(tester, 20);

            expect(_reportCalls, isNotEmpty,
                reason: 'Run Report asked the server');
            final q = _reportCalls.last.queryParameters;
            final today = DateFormat('yyyy-MM-dd').format(DateTime.now());
            expect(q['startDate'], today);
            expect(q['endDate'], today);
          }, () => _server(format));
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
