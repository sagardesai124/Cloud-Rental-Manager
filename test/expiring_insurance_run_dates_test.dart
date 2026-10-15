import 'dart:convert';

import 'package:connectivity_plus_platform_interface/connectivity_plus_platform_interface.dart';
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
import 'package:three_zero_two_property/StaffModule/screen/Reports/ReportScreens/Expiring_Insurance.dart'
    as staff;
import 'package:three_zero_two_property/provider/dateProvider.dart';
import 'package:three_zero_two_property/provider/notification_provider.dart';
import 'package:three_zero_two_property/screens/Reports/ReportScreens/Expiring_Insurance.dart'
    as admin;

/// Expiring Insurance → Run sends the shown From/To dates as yyyy-MM-dd,
/// like web (`renter-insurance/expiring-policies?start_date=YYYY-MM-DD&...`),
/// whatever the company date format. The server reads them with
/// `new Date(...)`, so day-first dates were refused or read with day and
/// month swapped, and the report came back empty.

final List<Uri> _reportCalls = [];

MockClient _server(String companyFormat) => MockClient((request) async {
      final path = request.url.path;
      if (path == '/api/auth') {
        return _json({
          'statusCode': 200,
          'themes': {'format': companyFormat, 'timeFormat': '12'}
        });
      }
      if (path == '/api/renter-insurance/expiring-policies') {
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
    for (final format in ['MM/DD/YYYY', 'YYYY-MM-DD']) {
      testWidgets(
          '${isStaff ? 'Staff' : 'Admin'}, company format $format: Run sends '
          'yyyy-MM-dd dates', (tester) async {
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
                    ? staff.ExpiringInsurance()
                    : admin.ExpiringInsurance(),
              ),
            ));
            await _settle(tester, 30);

            await tester.tap(find.text('Run'));
            await _settle(tester, 20);

            expect(_reportCalls, isNotEmpty, reason: 'Run asked the server');
            final q = _reportCalls.last.queryParameters;
            final today = DateFormat('yyyy-MM-dd').format(DateTime.now());
            expect(q['start_date'], today,
                reason: 'From (today) sent as yyyy-MM-dd');
            expect(q['end_date'], matches(RegExp(r'^\d{4}-\d{2}-\d{2}$')));
            expect(DateTime.parse(q['end_date']!).isAfter(DateTime.parse(today)),
                isTrue,
                reason: 'To (one month on) is after From');
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
