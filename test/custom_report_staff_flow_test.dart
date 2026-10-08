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
import 'package:three_zero_two_property/StaffModule/screen/Reports/ReportScreens/CustomReportBuilder.dart'
    as staff;
import 'package:three_zero_two_property/provider/dateProvider.dart';
import 'package:three_zero_two_property/provider/notification_provider.dart';
import 'package:three_zero_two_property/screens/Reports/ReportScreens/CreateCustomReportScreen.dart';
import 'package:three_zero_two_property/screens/Reports/ReportScreens/CustomReportBuilder.dart'
    as admin;

/// The whole Custom Reports edit flow, driven against a fake server:
/// Custom Reports → saved report → Edit → Save Report. A Staff session must
/// send its own staff_id (the server refuses adminId with a staff token since
/// 10/5); an Admin session keeps adminId even with a stale staff_id left
/// behind. Uses no new API, so it runs against the old code too.

const _adminId = 'ADMIN-1';
const _staffId = 'STAFF-1';

final _savedReport = {
  '_id': 'X-1',
  'report_id': 'R-1',
  'admin_id': _adminId,
  'name': 'Rent roll',
  'description': 'monthly',
  'selectedColumns': ['tenant_name'],
  'dateRange': '',
  'includeHistory': false,
  'is_delete': false,
};

class _Server {
  final List<http.Request> requests = [];
  late final MockClient client = MockClient((request) async {
    requests.add(request);
    Object body = {'statusCode': 200, 'message': 'ok', 'data': []};
    if (request.method == 'GET' && request.url.path == '/api/reports/saved') {
      body = {
        'statusCode': 200,
        'data': [_savedReport],
        'count': 1
      };
    }
    return http.Response(jsonEncode(body), 200,
        headers: {'content-type': 'application/json'});
  });

  Iterable<http.Request> get updates => requests.where(
      (r) => r.method == 'PUT' && r.url.path == '/api/reports/saved/R-1');
}

Future<void> _settle(WidgetTester tester, [int ticks = 16]) async {
  for (var i = 0; i < ticks; i++) {
    await tester.pump(const Duration(milliseconds: 50));
  }
}

Future<void> _editAndSave(WidgetTester tester, Widget builder) async {
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
    child: MaterialApp(home: builder),
  ));
  await _settle(tester, 30);

  // Open the saved-report picker and tap the report's Edit icon.
  final picker = find.text('Select report');
  expect(picker, findsOneWidget, reason: 'saved reports loaded');
  await tester.tap(picker);
  await _settle(tester, 10);
  final edit = find.byIcon(Icons.edit_outlined);
  expect(edit, findsWidgets, reason: 'picker shows Edit for the report');
  await tester.tap(edit.last);
  await _settle(tester, 20);
  expect(find.byType(CreateCustomReportScreen), findsOneWidget);

  final save = find.text('Save Report');
  await tester.ensureVisible(save);
  await tester.tap(save);
  await _settle(tester, 10);
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

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
            const MethodChannel('PonnamKarthik/fluttertoast'), (_) async => true);
    ConnectivityPlatform.instance = _OnlineConnectivity();
  });

  testWidgets('Staff: edit + save a saved report sends staff_id',
      (tester) async {
    SharedPreferences.setMockInitialValues({
      'token': 'tkn',
      'adminId': _adminId,
      'role': 'Staffmember',
      'staff_id': _staffId,
    });
    final server = _Server();
    await _run(server, () async {
      await _editAndSave(tester, const staff.CustomReportBuilder());
      expect(server.updates, hasLength(1));
      final r = server.updates.single;
      expect(r.headers['id'], 'CRM $_staffId');
      expect(r.url.queryParameters['admin_id'], _adminId);
      await _finish(tester);
    });
  });

  testWidgets('Admin: edit + save keeps adminId (stale staff_id ignored)',
      (tester) async {
    SharedPreferences.setMockInitialValues({
      'token': 'tkn',
      'adminId': _adminId,
      'role': 'Admin',
      'staff_id': 'STALE-STAFF',
    });
    final server = _Server();
    await _run(server, () async {
      await _editAndSave(tester, const admin.CustomReportBuilder());
      expect(server.updates, hasLength(1));
      expect(server.updates.single.headers['id'], 'CRM $_adminId');
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
