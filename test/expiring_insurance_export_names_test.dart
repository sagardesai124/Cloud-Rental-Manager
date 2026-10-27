import 'dart:convert';
import 'dart:io';

import 'package:connectivity_plus_platform_interface/connectivity_plus_platform_interface.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';
import 'package:provider/provider.dart';
import 'package:share_plus_platform_interface/share_plus_platform_interface.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:three_zero_two_property/StaffModule/repository/staffpermission_provider.dart';
import 'package:three_zero_two_property/StaffModule/screen/Reports/ReportScreens/Expiring_Insurance.dart'
    as staff;
import 'package:three_zero_two_property/provider/dateProvider.dart';
import 'package:three_zero_two_property/provider/notification_provider.dart';
import 'package:three_zero_two_property/screens/Reports/ReportScreens/Expiring_Insurance.dart'
    as admin;

/// Expiring Insurance → Export → Excel / CSV share files named like web's
/// ("Expiring-Renter's-Insurance.xlsx" / ".csv"). Before, the CSV was named
/// after another report (Account_totals_report_<time>.csv) and the Excel
/// file Renters_insurance_report_<time>.xlsx.

final List<String> _sharedFiles = [];
late Directory _docs;

class _FakeShare extends SharePlatform with MockPlatformInterfaceMixin {
  @override
  Future<ShareResult> share(ShareParams params) async {
    _sharedFiles.addAll((params.files ?? []).map((f) => f.path));
    return const ShareResult('ok', ShareResultStatus.success);
  }
}

class _FakePaths extends PathProviderPlatform with MockPlatformInterfaceMixin {
  @override
  Future<String?> getApplicationDocumentsPath() async => _docs.path;
}

class _Online extends ConnectivityPlatform with MockPlatformInterfaceMixin {
  @override
  Future<ConnectivityResult> checkConnectivity() async =>
      ConnectivityResult.wifi;
  @override
  Stream<ConnectivityResult> get onConnectivityChanged => const Stream.empty();
}

MockClient _server() => MockClient((request) async {
      final path = request.url.path;
      if (path == '/api/auth') {
        return _json({
          'statusCode': 200,
          'themes': {'format': 'YYYY-MM-DD', 'timeFormat': '12'}
        });
      }
      if (path == '/api/renter-insurance/expiring-policies') {
        return _json({
          'statusCode': 200,
          'data': [
            {
              '_id': 'P-1',
              'renters_insurance_id': 'RI-1',
              'lease_id': 'L-1',
              'tenants': [],
              'insurance_company': 'Pwc',
              'policy_id': 'POL-1',
              'effective_date': '2026-03-03',
              'expiration_date': '2026-03-20',
              'tenant_details': [],
            }
          ],
        });
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
    _sharedFiles.clear();
    _docs = Directory.systemTemp.createTempSync('ei_export_');
    SharePlatform.instance = _FakeShare();
    PathProviderPlatform.instance = _FakePaths();
    ConnectivityPlatform.instance = _Online();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
            const MethodChannel('PonnamKarthik/fluttertoast'), (_) async => true);
    // CSV export asks for storage permission first: grant everything.
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
            const MethodChannel('flutter.baseflow.com/permissions/methods'),
            (call) async => {for (var i = 0; i < 40; i++) i: 1});
  });
  tearDown(() {
    if (_docs.existsSync()) _docs.deleteSync(recursive: true);
  });

  for (final isStaff in [false, true]) {
    for (final kind in ['XLSX', 'CSV']) {
      testWidgets(
          '${isStaff ? 'Staff' : 'Admin'}: Export → $kind shares '
          "Expiring-Renter's-Insurance", (tester) async {
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

            // Export appears only once a Run returns policies, like web.
            await tester.tap(find.text('Run'));
            await _settle(tester, 20);
            await tester.tap(find.text('Export'));
            await _settle(tester, 10);
            await tester.tap(find.text(kind).last);
            // The export waits for the (fake) server, then writes a real
            // file: alternate test time and real time until it is shared.
            for (var i = 0; i < 20 && _sharedFiles.isEmpty; i++) {
              await tester.pump(const Duration(milliseconds: 50));
              await tester.runAsync(() =>
                  Future<void>.delayed(const Duration(milliseconds: 100)));
            }

            expect(_sharedFiles, hasLength(1), reason: 'one file shared');
            final name = _sharedFiles.single.split('/').last;
            expect(name,
                "Expiring-Renter's-Insurance.${kind == 'XLSX' ? 'xlsx' : 'csv'}");
            expect(File(_sharedFiles.single).existsSync(), isTrue);
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
