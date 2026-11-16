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
import 'package:three_zero_two_property/Model/tenants.dart';
import 'package:three_zero_two_property/StaffModule/repository/staffpermission_provider.dart';
import 'package:three_zero_two_property/StaffModule/screen/Rental/Tenants/Tenant_summary.dart'
    as staff;
import 'package:three_zero_two_property/provider/Plan%20Purchase/plancheckProvider.dart';
import 'package:three_zero_two_property/provider/dateProvider.dart';
import 'package:three_zero_two_property/provider/notification_provider.dart';
import 'package:three_zero_two_property/screens/Rental/Tenants/Tenant_summary.dart'
    as admin;
import 'package:three_zero_two_property/services/app_date_format.dart';

/// Tenant → Summary → Account & Login: "Password last set on …" and "Setup
/// email sent on …" use the company Date & Time Format like web staging
/// (TenantDetailPage.jsx `formatDateTime`, since web commit 20ca221f1):
///   moment(date).format(dateFormat) + " " +
///   (timeFormat === "12" ? "hh:mm:ss A" : "HH:mm:ss")
/// They always showed "7/15/2026, 6:22:35 PM" before.

String _web(DateTime d, String webDateFormat, String timeFormat) =>
    DateProvider.webDateTime(d,
        dateFormat: AppDateFormat.toIntl(webDateFormat), timeFormat: timeFormat);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('same text as web formatDateTime', () {
    final evening = DateTime(2026, 7, 15, 18, 22, 35);
    final morning = DateTime(2026, 1, 5, 9, 5, 3);

    test('24-hour', () {
      expect(_web(evening, 'YYYY-MM-DD', '24'), '2026-07-15 18:22:35');
      expect(_web(evening, 'MM/DD/YYYY', '24'), '07/15/2026 18:22:35');
      expect(_web(evening, 'YYYY-MMM-DD', '24'), '2026-Jul-15 18:22:35');
      expect(_web(morning, 'YYYY-MM-DD', '24'), '2026-01-05 09:05:03');
    });

    test('12-hour pads the hour like web hh:mm:ss A', () {
      expect(_web(evening, 'MM/DD/YYYY', '12'), '07/15/2026 06:22:35 PM');
      expect(_web(evening, 'YYYY-MM-DD', '12'), '2026-07-15 06:22:35 PM');
      expect(_web(morning, 'MM/DD/YYYY', '12'), '01/05/2026 09:05:03 AM');
      expect(_web(DateTime(2026, 7, 15, 0, 0, 0), 'MM/DD/YYYY', '12'),
          '07/15/2026 12:00:00 AM');
      expect(_web(DateTime(2026, 7, 15, 12, 0, 0), 'MM/DD/YYYY', '12'),
          '07/15/2026 12:00:00 PM');
    });

    test('a custom company format, like web', () {
      expect(_web(evening, 'DD/MMM/YYYY', '24'), '15/Jul/2026 18:22:35');
      expect(_web(evening, 'MM-DD-YYYY', '12'), '07-15-2026 06:22:35 PM');
    });

    test('anything but "12" is 24-hour, like web', () {
      expect(_web(evening, 'YYYY-MM-DD', ''), '2026-07-15 18:22:35');
    });

    test('a server UTC timestamp is shown in local time, like moment', () {
      final utc = DateTime.parse('2026-07-15T12:52:35.000Z');
      final local = utc.toLocal();
      String two(int n) => n.toString().padLeft(2, '0');
      expect(_web(utc, 'YYYY-MM-DD', '24'),
          '${local.year}-${two(local.month)}-${two(local.day)} '
          '${two(local.hour)}:${two(local.minute)}:${two(local.second)}');
    });
  });

  for (final path in [
    'lib/screens/Rental/Tenants/Tenant_summary.dart',
    'lib/StaffModule/screen/Rental/Tenants/Tenant_summary.dart',
  ]) {
    test('$path: Account & Login dates use the company format', () {
      final src = File(path).readAsStringSync();
      expect(src, isNot(contains("'M/d/yyyy, h:mm:ss a'")));
      final at = src.indexOf('String _formatAccountTimestamp(String raw)');
      expect(at, isNonNegative);
      expect(src.substring(at, src.indexOf('}', src.indexOf('catch', at))),
          contains('.formatWebDateTime(DateTime.parse(raw))'));
    });
  }

  // ---- The real Admin and Staff Tenant Summary screens ----

  setUp(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
            const MethodChannel('PonnamKarthik/fluttertoast'), (_) async => true);
    ConnectivityPlatform.instance = _OnlineConnectivity();
  });

  Future<void> check(
    WidgetTester tester, {
    required Widget Function(Tenant tenant) screen,
    required String role,
    required Map<String, dynamic> account,
    required String? format, // null with timeFormat null: nothing saved
    required String? timeFormat,
    required String expected,
  }) async {
    tester.view.physicalSize = const Size(430, 9000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    SharedPreferences.setMockInitialValues({
      'token': 'tkn',
      'adminId': 'ADMIN-1',
      'staff_id': 'STAFF-1',
      'role': role,
    });
    final record = {
      'tenant_id': 'T-1',
      'admin_id': 'ADMIN-1',
      'tenant_firstName': 'Ruth',
      'tenant_lastName': 'Moss',
      'tenant_phoneNumber': '5551234567',
      'tenant_email': 'ruth@example.com',
      'leaseData': [],
      ...account,
    };
    final server = MockClient((request) async {
      final path = request.url.path;
      Object body = {'statusCode': 200, 'data': []};
      if (path == '/api/auth') {
        body = {
          'statusCode': 200,
          if (format != null || timeFormat != null)
            'themes': {'format': format, 'timeFormat': timeFormat}
        };
      } else if (path == '/api/tenant/tenant_details/T-1') {
        body = {'statusCode': 200, 'data': [record]};
      }
      return http.Response(jsonEncode(body), 200,
          headers: {'content-type': 'application/json'});
    });
    final original = FlutterError.onError;
    FlutterError.onError = (d) {
      if (d.exceptionAsString().contains('overflowed')) return;
      original?.call(d);
    };
    try {
      await http.runWithClient(() async {
        final dates = DateProvider();
        await dates.loadDateFormat();
        final permissions = StaffPermissionProvider();
        await permissions.fetchPermissions();
        await tester.pumpWidget(MultiProvider(
          providers: [
            ChangeNotifierProvider<DateProvider>.value(value: dates),
            ChangeNotifierProvider(create: (_) => NotificationProvider()),
            ChangeNotifierProvider(create: (_) => checkPlanPurchaseProiver()),
            ChangeNotifierProvider<StaffPermissionProvider>.value(
                value: permissions),
          ],
          child: MaterialApp(
              home: screen(Tenant.fromJson(Map<String, dynamic>.from(record)))),
        ));
        for (var i = 0; i < 40; i++) {
          await tester.pump(const Duration(milliseconds: 50));
        }
        expect(find.textContaining(expected), findsOneWidget,
            reason: '$role: ${format ?? 'no saved format'} / ${timeFormat}h');
        expect(find.textContaining('7/15/2026, 6:22:35 PM'), findsNothing,
            reason: 'the old fixed format is gone');
      }, () => server);
      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(seconds: 5));
    } finally {
      FlutterError.onError = original;
    }
  }

  Widget adminScreen(Tenant t) =>
      admin.TenantSummaryMobile(tenantId: 'T-1', tenants: t);
  Widget staffScreen(Tenant t) =>
      staff.TenantSummaryMobile(tenantId: 'T-1', tenants: t);

  for (final entry in {'Admin': adminScreen, 'Staffmember': staffScreen}.entries) {
    testWidgets('${entry.key}: Password last set on, YYYY-MM-DD 24-hour',
        (tester) async {
      await check(tester,
          screen: entry.value,
          role: entry.key,
          account: {'password_set_at': '2026-07-15T18:22:35'},
          format: 'YYYY-MM-DD',
          timeFormat: '24',
          expected: 'Password last set on 2026-07-15 18:22:35.');
    });

    testWidgets('${entry.key}: Setup email sent on, MM/DD/YYYY 12-hour',
        (tester) async {
      await check(tester,
          screen: entry.value,
          role: entry.key,
          account: {'welcome_email_sent_at': '2026-07-15T18:22:35'},
          format: 'MM/DD/YYYY',
          timeFormat: '12',
          expected: 'Setup email sent on 07/15/2026 06:22:35 PM.');
    });

    testWidgets('${entry.key}: no saved Date Format shows YYYY-MM-DD like web',
        (tester) async {
      await check(tester,
          screen: entry.value,
          role: entry.key,
          account: {'password_set_at': '2026-07-15T18:22:35'},
          format: null,
          timeFormat: null,
          expected: 'Password last set on 2026-07-15 18:22:35.');
    });
  }

  // ---- A company that never saved a Date Format ----
  // Web's tenant page starts from "YYYY-MM-DD" / "24" and keeps them when
  // /auth has no saved format (`themes.format || "YYYY-MM-DD"`); the server
  // only sends `themes` once a themes record exists, and `format` has no
  // default there.

  group('company with no saved Date Format, like web tenant page', () {
    final at = DateTime(2026, 7, 15, 18, 22, 35);

    Future<DateProvider> load(Map<String, dynamic>? themes,
        {int status = 200}) async {
      SharedPreferences.setMockInitialValues(
          {'token': 'tkn', 'adminId': 'ADMIN-1', 'role': 'Admin'});
      late DateProvider dp;
      await http.runWithClient(() async {
        dp = DateProvider();
        await dp.loadDateFormat();
        await Future<void>.delayed(const Duration(milliseconds: 20));
      },
          () => MockClient((_) async => http.Response(
              jsonEncode({
                'statusCode': status,
                if (themes != null) 'themes': themes,
              }),
              status,
              headers: {'content-type': 'application/json'})));
      return dp;
    }

    test('nothing saved at all: YYYY-MM-DD, 24-hour', () async {
      final dp = await load(null);
      expect(dp.formatWebDateTime(at), '2026-07-15 18:22:35');
      expect(dp.dateFormat, 'MM/dd/yyyy',
          reason: 'the rest of the app keeps its MM/DD/YYYY default');
    });

    test('a theme with no Date Format (12-hour saved): YYYY-MM-DD', () async {
      final dp = await load({'timeFormat': '12'});
      expect(dp.formatWebDateTime(at), '2026-07-15 06:22:35 PM');
    });

    test('a blank saved Date Format: YYYY-MM-DD', () async {
      final dp = await load({'format': '', 'timeFormat': '24'});
      expect(dp.formatWebDateTime(at), '2026-07-15 18:22:35');
    });

    test('a saved Date Format is always used', () async {
      expect((await load({'format': 'MM/DD/YYYY', 'timeFormat': '24'}))
          .formatWebDateTime(at), '07/15/2026 18:22:35');
      expect((await load({'format': 'DD/MMM/YYYY', 'timeFormat': '12'}))
          .formatWebDateTime(at), '15/Jul/2026 06:22:35 PM');
      expect((await load({'format': 'YYYY-MM-DD', 'timeFormat': '12'}))
          .formatWebDateTime(at), '2026-07-15 06:22:35 PM');
    });

    test('no answer from the server: no guess, the app format stays', () async {
      final dp = await load(null, status: 500);
      expect(dp.formatWebDateTime(at), '07/15/2026 18:22:35');
    });

    test('once a Date Format is saved in Settings, it is used', () async {
      SharedPreferences.setMockInitialValues(
          {'token': 'tkn', 'adminId': 'ADMIN-1', 'role': 'Admin'});
      Map<String, dynamic>? themes; // nothing saved yet
      final client = MockClient((r) async {
        if (r.url.path == '/api/themes/date-format') {
          final b = jsonDecode(r.body) as Map<String, dynamic>;
          themes = {'format': b['format'], 'timeFormat': b['timeFormat']};
        }
        return http.Response(
            jsonEncode({'statusCode': 200, if (themes != null) 'themes': themes}),
            200,
            headers: {'content-type': 'application/json'});
      });
      await http.runWithClient(() async {
        final dp = DateProvider();
        await dp.loadDateFormat();
        // The constructor's own load settles first, as it does in the app
        // (the provider is created at startup, long before Settings).
        await Future<void>.delayed(const Duration(milliseconds: 20));
        expect(dp.formatWebDateTime(at), '2026-07-15 18:22:35');
        expect(await dp.updateDateFormat('MM/dd/yyyy', 0), isTrue);
        expect(dp.formatWebDateTime(at), '07/15/2026 18:22:35');
        await Future<void>.delayed(const Duration(milliseconds: 50));
        expect(dp.formatWebDateTime(at), '07/15/2026 18:22:35',
            reason: 'still the saved format after the background reload');
      }, () => client);
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
