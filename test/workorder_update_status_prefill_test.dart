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
import 'package:three_zero_two_property/StaffModule/screen/Maintenance/Workorder/workorder_summery.dart'
    as staff;
import 'package:three_zero_two_property/provider/dateProvider.dart';
import 'package:three_zero_two_property/provider/notification_provider.dart';
import 'package:three_zero_two_property/screens/Maintenance/Workorder/workorder_summery.dart'
    as admin;

/// Work Order Summary → Update (Admin and Staff) works like web's Update
/// (WorkOrderDetails.jsx on staging): it opens with the work order's current
/// status, assignee and due date filled in, and Status offers all six
/// choices — New, Open, In Progress, On Hold, Completed, Closed. Before, it
/// opened empty ("Select Status") and had no Open or Closed.

const _statuses = ['New', 'Open', 'In Progress', 'On Hold', 'Completed', 'Closed'];

final _workOrder = {
  'workOrder_id': 'WO-1',
  'ticket_number': '1001',
  'admin_id': 'ADMIN-1',
  'work_subject': 'Leaky tap',
  'work_category': 'Plumbing',
  'status': 'In Progress',
  'priority': 'High',
  'date': '2026-10-30',
  'staffmember_id': 'S-1',
  'staff_data': {'_id': 'S-1', 'firstname': 'Pat', 'lastname': 'Staff'},
  'property_data': {
    '_id': 'P-1',
    'property_name': 'Main St',
    'rental_adress': '123 Main St',
    'rental_city': 'Austin',
    'rental_state': 'TX',
    'rental_country': 'USA',
    'rental_postcode': '73301',
    'rental_image': '',
  },
  'unit_data': {
    '_id': 'U-1',
    'rental_unit_adress': '123 Main St',
    'rental_unit': 'A1',
    'unit_id': 'U-1',
  },
  'vendor_data': {'_id': 'V-1', 'vendor_name': 'Fixit Co'},
  'tenant_data': {'_id': 'T-1', 'tenant_firstName': 'Ruth', 'tenant_lastName': 'Moss'},
  'work_performed': 'Unit',
  'vendor_notes': '',
  'workorder_updates': [],
  'partsandcharge_data': [],
  'workOrder_images': [],
};

final _server = MockClient((request) async {
  final path = request.url.path;
  Object body = {'statusCode': 200, 'data': []};
  if (path == '/api/auth') {
    body = {
      'statusCode': 200,
      'themes': {'format': 'MM/DD/YYYY', 'timeFormat': '12'}
    };
  } else if (path.startsWith('/api/work-order/workorder_details/')) {
    body = {'statusCode': 200, 'data': _workOrder};
  } else if (path.startsWith('/api/staffmember/staff_member/')) {
    body = {
      'statusCode': 200,
      'data': [
        {'staffmember_id': 'S-1', 'staffmember_name': 'Pat Staff'},
        {'staffmember_id': 'S-2', 'staffmember_name': 'Lee Other'},
      ]
    };
  } else if (path.startsWith('/api/permission/permission/')) {
    body = {
      'statusCode': 200,
      'data': {
        'staff_permission': {
          'workorder_view': true,
          'workorder_add': true,
          'workorder_edit': true,
          'workorder_delete': true,
        }
      }
    };
  }
  return http.Response(jsonEncode(body), 200,
      headers: {'content-type': 'application/json'});
});

Future<void> _settle(WidgetTester tester, [int ticks = 40]) async {
  for (var i = 0; i < ticks; i++) {
    await tester.pump(const Duration(milliseconds: 50));
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

  Future<void> check(WidgetTester tester, Widget screen, String role) async {
    tester.view.physicalSize = const Size(430, 6000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    SharedPreferences.setMockInitialValues({
      'token': 'tkn',
      'adminId': 'ADMIN-1',
      'staff_id': 'STAFF-1',
      'role': role,
    });
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
        await permissions.fetchPermissions();
        await tester.pumpWidget(MultiProvider(
          providers: [
            ChangeNotifierProvider<DateProvider>.value(value: dates),
            ChangeNotifierProvider(create: (_) => NotificationProvider()),
            ChangeNotifierProvider<StaffPermissionProvider>.value(
                value: permissions),
          ],
          child: MaterialApp(home: screen),
        ));
        await _settle(tester);

        final update = find.widgetWithText(ElevatedButton, 'Update');
        final openUpdate =
            update.evaluate().isNotEmpty ? update.first : find.text('Update').first;
        await tester.ensureVisible(openUpdate);
        await tester.pump();
        await tester.tap(openUpdate);
        await _settle(tester);

        // Opens with the work order's current values, like web.
        expect(find.text('Select Status'), findsNothing,
            reason: 'status is pre-filled');
        expect(find.text('In Progress'), findsWidgets);
        expect(find.text('Pat Staff'), findsWidgets, reason: 'assignee pre-filled');
        expect(find.text(dates.formatCurrentDate('2026-10-30')), findsWidgets,
            reason: 'due date pre-filled');

        // All six web statuses are offered.
        await tester.tap(find.text('In Progress').last);
        await _settle(tester, 20);
        for (final s in _statuses) {
          expect(find.text(s), findsWidgets, reason: '$s offered');
        }
      }, () => _server);
      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(seconds: 5));
    } finally {
      FlutterError.onError = original;
    }
  }

  testWidgets('Admin Update opens with current values and all six statuses',
      (tester) async {
    await check(tester, admin.Workorder_summery(workorder_id: 'WO-1'), 'Admin');
  });

  testWidgets('Staff Update opens with current values and all six statuses',
      (tester) async {
    await check(
        tester, staff.Workorder_summery(workorder_id: 'WO-1'), 'Staffmember');
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
