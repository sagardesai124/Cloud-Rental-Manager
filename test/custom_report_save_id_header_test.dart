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
import 'package:three_zero_two_property/Model/SavedReportModel.dart';
import 'package:three_zero_two_property/StaffModule/repository/staffpermission_provider.dart';
import 'package:three_zero_two_property/StaffModule/screen/Reports/ReportScreens/CustomReportBuilder.dart'
    as staff;
import 'package:three_zero_two_property/provider/dateProvider.dart';
import 'package:three_zero_two_property/provider/notification_provider.dart';
import 'package:three_zero_two_property/repository/CustomReportService.dart';
import 'package:three_zero_two_property/screens/Reports/ReportScreens/CreateCustomReportScreen.dart';

/// Lou's trace (10/6): Staff Custom Reports open the shared Create/Edit
/// report screen, whose save and update sent `id: CRM <adminId>` — refused by
/// the server (VerifyToken.js, production since 10/5) with a staff token. The
/// list, run and delete calls already sent staff_id via `isStaff`; save and
/// update now do the same. The company id stays in the URL/body, and Admin is
/// unchanged even with a stale staff_id left behind.

const _adminId = 'ADMIN-1';
const _staffId = 'STAFF-1';

const Map<String, Object> _staffPrefs = {
  'token': 'tkn',
  'adminId': _adminId,
  'role': 'Staffmember',
  'staff_id': _staffId,
};

const Map<String, Object> _adminPrefsWithStaleStaffId = {
  'token': 'tkn',
  'adminId': _adminId,
  'role': 'Admin',
  'staff_id': 'STALE-STAFF',
};

SavedReport _report(String reportId) => SavedReport(
      id: 'X-1',
      reportId: reportId,
      adminId: _adminId,
      name: 'Rent roll',
      description: 'monthly',
      selectedColumns: const ['tenant_name'],
      dateRange: '',
      includeHistory: false,
      isDelete: false,
    );

class _Server {
  final List<http.Request> requests = [];
  late final MockClient client = MockClient((request) async {
    requests.add(request);
    Object body = {'statusCode': 200, 'message': 'ok', 'data': []};
    return http.Response(jsonEncode(body), 200,
        headers: {'content-type': 'application/json'});
  });

  http.Request only(String method, String path) =>
      requests.singleWhere((r) => r.method == method && r.url.path == path);
}

Future<void> _settle(WidgetTester tester, [int ticks = 16]) async {
  for (var i = 0; i < ticks; i++) {
    await tester.pump(const Duration(milliseconds: 50));
  }
}

Future<void> _pump(WidgetTester tester, Widget home) async {
  tester.view.physicalSize = const Size(1080, 5000);
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
    child: MaterialApp(home: home),
  ));
  await _settle(tester, 20);
}

/// Lets the post-save pop and pending timers run before teardown.
Future<void> _finish(WidgetTester tester) async {
  await tester.pump(const Duration(seconds: 2));
  await _settle(tester, 10);
  await tester.pumpWidget(const SizedBox());
  await tester.pump(const Duration(seconds: 2));
}

/// The test font draws every glyph as a full em square, so dense rows
/// overflow here; that layout noise is ignored.
Future<void> _run(_Server server, Future<void> Function() body) async {
  final original = FlutterError.onError;
  FlutterError.onError = (details) {
    if (details.exceptionAsString().contains('overflowed')) return;
    original?.call(details);
  };
  try {
    await http.runWithClient(body, () => server.client);
  } finally {
    FlutterError.onError = original;
  }
}

Future<void> _tapSave(WidgetTester tester) async {
  final save = find.text('Save Report');
  expect(save, findsOneWidget);
  await tester.ensureVisible(save);
  await tester.tap(save);
  await _settle(tester, 10);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
            const MethodChannel('PonnamKarthik/fluttertoast'), (_) async => true);
    ConnectivityPlatform.instance = _OnlineConnectivity();
  });

  group('service', () {
    Future<http.Request> save({bool? isStaff}) async {
      final server = _Server();
      await http.runWithClient(
          () => isStaff == null
              ? CustomReportService().saveReport(
                  adminId: _adminId,
                  name: 'n',
                  description: 'd',
                  selectedColumns: const ['tenant_name'],
                  includeHistory: false)
              : CustomReportService().saveReport(
                  adminId: _adminId,
                  name: 'n',
                  description: 'd',
                  selectedColumns: const ['tenant_name'],
                  includeHistory: false,
                  isStaff: isStaff),
          () => server.client);
      return server.only('POST', '/api/reports/save');
    }

    Future<http.Request> update({bool? isStaff}) async {
      final server = _Server();
      await http.runWithClient(
          () => isStaff == null
              ? CustomReportService().updateReport(
                  adminId: _adminId,
                  reportId: 'R-1',
                  name: 'n',
                  description: 'd',
                  selectedColumns: const ['tenant_name'],
                  includeHistory: false)
              : CustomReportService().updateReport(
                  adminId: _adminId,
                  reportId: 'R-1',
                  name: 'n',
                  description: 'd',
                  selectedColumns: const ['tenant_name'],
                  includeHistory: false,
                  isStaff: isStaff),
          () => server.client);
      return server.only('PUT', '/api/reports/saved/R-1');
    }

    test('Staff save: own staff_id, company id stays in the body', () async {
      SharedPreferences.setMockInitialValues(_staffPrefs);
      final r = await save(isStaff: true);
      expect(r.headers['id'], 'CRM $_staffId');
      expect(jsonDecode(r.body)['admin_id'], _adminId);
    });

    test('Staff update: own staff_id, company id stays in the URL', () async {
      SharedPreferences.setMockInitialValues(_staffPrefs);
      final r = await update(isStaff: true);
      expect(r.headers['id'], 'CRM $_staffId');
      expect(r.url.queryParameters['admin_id'], _adminId);
    });

    test('Admin save + update keep adminId (stale staff_id ignored)',
        () async {
      SharedPreferences.setMockInitialValues(_adminPrefsWithStaleStaffId);
      expect((await save()).headers['id'], 'CRM $_adminId');
      expect((await update()).headers['id'], 'CRM $_adminId');
    });
  });

  group('shared Create/Edit screen passes the flag through', () {
    testWidgets('Staff edit → PUT with staff_id', (tester) async {
      SharedPreferences.setMockInitialValues(_staffPrefs);
      final server = _Server();
      await _run(server, () async {
        await _pump(
            tester,
            CreateCustomReportScreen(
                adminId: _adminId, existingReport: _report('R-1'), isStaff: true));
        await _tapSave(tester);
        final r = server.only('PUT', '/api/reports/saved/R-1');
        expect(r.headers['id'], 'CRM $_staffId');
        await _finish(tester);
      });
    });

    testWidgets('Staff create → POST with staff_id', (tester) async {
      SharedPreferences.setMockInitialValues(_staffPrefs);
      final server = _Server();
      await _run(server, () async {
        // A report without an id pre-fills the form but saves as new.
        await _pump(
            tester,
            CreateCustomReportScreen(
                adminId: _adminId, existingReport: _report(''), isStaff: true));
        await _tapSave(tester);
        final r = server.only('POST', '/api/reports/save');
        expect(r.headers['id'], 'CRM $_staffId');
        await _finish(tester);
      });
    });

    testWidgets('Admin (no flag) → adminId even with a stale staff_id',
        (tester) async {
      SharedPreferences.setMockInitialValues(_adminPrefsWithStaleStaffId);
      final server = _Server();
      await _run(server, () async {
        await _pump(tester,
            CreateCustomReportScreen(adminId: _adminId, existingReport: _report('R-1')));
        await _tapSave(tester);
        final r = server.only('PUT', '/api/reports/saved/R-1');
        expect(r.headers['id'], 'CRM $_adminId');
        await _finish(tester);
      });
    });
  });

  testWidgets('Staff Custom Reports opens Create with isStaff', (tester) async {
    SharedPreferences.setMockInitialValues(_staffPrefs);
    final server = _Server();
    await _run(server, () async {
      await _pump(tester, const staff.CustomReportBuilder());
      final create = find.text('Create');
      expect(create, findsOneWidget);
      await tester.ensureVisible(create);
      await tester.tap(create);
      await _settle(tester, 20);
      final screen = tester
          .widget<CreateCustomReportScreen>(find.byType(CreateCustomReportScreen));
      expect(screen.isStaff, isTrue);
      expect(screen.adminId, _adminId);
      await _finish(tester);
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
