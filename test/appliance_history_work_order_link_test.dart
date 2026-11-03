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
import 'package:three_zero_two_property/Model/unit.dart';
import 'package:three_zero_two_property/StaffModule/repository/staffpermission_provider.dart';
import 'package:three_zero_two_property/StaffModule/screen/Maintenance/Workorder/workorder_summery.dart'
    as staff_wo;
import 'package:three_zero_two_property/StaffModule/screen/Rental/Properties/applience/ApplianceSummary.dart'
    as staff;
import 'package:three_zero_two_property/provider/dateProvider.dart';
import 'package:three_zero_two_property/provider/notification_provider.dart';
import 'package:three_zero_two_property/screens/Maintenance/Workorder/workorder_summery.dart'
    as admin_wo;
import 'package:three_zero_two_property/screens/Rental/Properties/applience/ApplianceSummary.dart'
    as admin;

/// Appliance → Maintenance History, like web staging: an entry linked to a
/// work order (`workorder_id`, set when a work order is created for the
/// appliance) shows "View Work Order" and opens that work order; the rest say
/// "No WO". The app used to read `work_order`, which the server never sends,
/// so every entry said "No WO".

http.Response _json(Object body) => http.Response(jsonEncode(body), 200,
    headers: {'content-type': 'application/json'});

const _appliance = {
  'appliance_id': 'AP-1',
  'admin_id': 'ADMIN-1',
  'appliance_name': 'Water Heater',
  'status': 'Working',
  'maintenance_history': [
    {
      'timestamp': '2026-10-30T10:00:00.000Z',
      'event': 'Repair Request',
      'vendor': 'Acme Plumbing',
      'workorder_id': 'WO-1',
    },
    {
      // What web's Add History sends when no work order is picked.
      'timestamp': '2026-09-01T10:00:00.000Z',
      'event': 'Install',
      'vendor': 'Acme Plumbing',
      'workorder_id': '',
    },
  ],
};

final _server = MockClient((request) async {
  final path = request.url.path;
  if (path.startsWith('/api/appliance/appliance_details/')) {
    return _json({'statusCode': 200, 'data': _appliance});
  }
  if (path.startsWith('/api/permission/permission/')) {
    return _json({
      'statusCode': 200,
      'data': {
        'staff_permission': {
          'workorder_view': true,
          'workorder_add': true,
          'workorder_edit': true,
          'workorder_delete': true,
        }
      }
    });
  }
  if (path == '/api/auth') {
    return _json({
      'statusCode': 200,
      'themes': {'format': 'YYYY-MM-DD', 'timeFormat': '24'},
    });
  }
  // The work order screen's own loading is not under test here; a quick "not
  // found" keeps it from waiting on the request timeouts.
  if (path.contains('workorder') || path.contains('staffmember')) {
    return http.Response(jsonEncode({'statusCode': 404}), 404,
        headers: {'content-type': 'application/json'});
  }
  return _json({'statusCode': 200, 'data': []});
});

Future<void> _settle(WidgetTester tester, [int ticks = 30]) async {
  for (var i = 0; i < ticks; i++) {
    await tester.pump(const Duration(milliseconds: 50));
  }
}

/// Opens the real appliance details and expands both history entries.
Future<void> _open(WidgetTester tester, bool isStaff) async {
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
  final dates = DateProvider();
  await dates.loadDateFormat();
  final permissions = StaffPermissionProvider();
  await permissions.fetchPermissions();
  final appliance =
      unit_appliance.fromJson({'appliance_id': 'AP-1', 'appliance_name': 'Water Heater'});
  await tester.pumpWidget(MultiProvider(
    providers: [
      ChangeNotifierProvider<DateProvider>.value(value: dates),
      ChangeNotifierProvider(create: (_) => NotificationProvider()),
      ChangeNotifierProvider<StaffPermissionProvider>.value(
          value: permissions),
    ],
    child: MaterialApp(
      home: isStaff
          ? staff.ApplianceSummary(appliance: appliance)
          : admin.ApplianceSummary(appliance: appliance),
    ),
  ));
  await _settle(tester);
  for (final event in ['Repair Request', 'Install']) {
    await tester.ensureVisible(find.text(event));
    await tester.tap(find.text(event));
    await _settle(tester, 6);
  }
}

Future<void> _run(WidgetTester tester, Future<void> Function() body) async {
  final original = FlutterError.onError;
  // Layout overflow (test font) and images (no decoding in tests) are noise
  // here.
  FlutterError.onError = (details) {
    if (details.exceptionAsString().contains('overflowed')) return;
    if (details.library == 'image resource service') return;
    original?.call(details);
  };
  try {
    await http.runWithClient(() async {
      await body();
      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(seconds: 2));
    }, () => _server);
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

  for (final isStaff in [false, true]) {
    final who = isStaff ? 'Staff' : 'Admin';

    testWidgets('$who: a linked entry shows View Work Order, the rest No WO',
        (tester) async {
      await _run(tester, () async {
        await _open(tester, isStaff);
        expect(find.text('View Work Order'), findsOneWidget,
            reason: 'the Repair Request entry is linked to WO-1');
        expect(find.text('No WO'), findsOneWidget,
            reason: 'the Install entry has no work order');
      });
    });

    testWidgets('$who: View Work Order opens that work order', (tester) async {
      await _run(tester, () async {
        await _open(tester, isStaff);
        await tester.tap(find.text('View Work Order'));
        await _settle(tester, 12);
        final String? opened = isStaff
            ? tester
                .widget<staff_wo.Workorder_summery>(
                    find.byType(staff_wo.Workorder_summery))
                .workorder_id
            : tester
                .widget<admin_wo.Workorder_summery>(
                    find.byType(admin_wo.Workorder_summery))
                .workorder_id;
        expect(opened, 'WO-1');
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
