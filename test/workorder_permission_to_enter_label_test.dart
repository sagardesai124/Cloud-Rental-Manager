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
import 'package:three_zero_two_property/StaffModule/repository/staffpermission_provider.dart';
import 'package:three_zero_two_property/StaffModule/screen/Maintenance/Workorder/workorder_summery.dart'
    as staff;
import 'package:three_zero_two_property/TenantsModule/screen/work_order/workorder_summery.dart'
    as tenant;
import 'package:three_zero_two_property/VendorModule/repository/vendor_permission.dart';
import 'package:three_zero_two_property/VendorModule/screen/work_order/workorder_summery.dart'
    as vendor;
import 'package:three_zero_two_property/provider/Plan%20Purchase/plancheckProvider.dart';
import 'package:three_zero_two_property/provider/dateProvider.dart';
import 'package:three_zero_two_property/provider/notification_provider.dart';
import 'package:three_zero_two_property/screens/Maintenance/Workorder/workorder_summery.dart'
    as admin;

/// Work Order Summary labels the entry permission "Permission To Enter" on
/// the Summary card and the Task tab, like web staging (WorkOrderDetails.jsx,
/// which every role opens). It read just "Permission" in all four roles.

final _workOrder = {
  'workOrder_id': 'WO-1',
  'ticket_number': '1001',
  'admin_id': 'ADMIN-1',
  'work_subject': 'Leaky tap',
  'work_category': 'Plumbing',
  'status': 'In Progress',
  'priority': 'High',
  'date': '2026-10-30',
  'entry_allowed': true,
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
  if (path.startsWith('/api/work-order/workorder_details/')) {
    body = {'statusCode': 200, 'data': _workOrder};
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

/// Whether an overflow reported in [details] is the Permission To Enter row
/// (or the pill it sits in), rather than some other row on the screen.
bool _isPermissionRow(FlutterErrorDetails details) {
  final at = RegExp(r'(lib/[^\s:]*workorder_summery\.dart):(\d+)')
      .firstMatch(details.toString());
  if (at == null) return true; // can't place it: count it
  final lines = File(at.group(1)!).readAsLinesSync();
  final line = int.parse(at.group(2)!);
  final window = lines
      .sublist((line - 2).clamp(0, lines.length), (line + 8).clamp(0, lines.length))
      .join('\n');
  return window.contains('Permission To Enter') || window.contains('Text(label');
}

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

  /// Opens [screen] at a small phone width and checks the label on the
  /// Summary card and the Task tab. A layout error on the Permission To
  /// Enter row fails the test, so the longer label must fit.
  Future<void> check(WidgetTester tester, Widget screen, String role) async {
    tester.view.physicalSize = const Size(360, 6000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    SharedPreferences.setMockInitialValues({
      'token': 'tkn',
      'adminId': 'ADMIN-1',
      'staff_id': 'S-1',
      'tenant_id': 'T-1',
      'vendor_id': 'V-1',
      'role': role,
    });
    final layoutErrors = <String>[];
    final original = FlutterError.onError;
    FlutterError.onError = (details) {
      if (details.exceptionAsString().contains('overflowed')) {
        // Other rows on these screens may not fit at 360 wide; only the
        // Permission To Enter row is this test's concern.
        if (_isPermissionRow(details)) {
          layoutErrors.add(details.exceptionAsString());
        }
        return;
      }
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
            ChangeNotifierProvider(create: (_) => checkPlanPurchaseProiver()),
            ChangeNotifierProvider(create: (_) => VendorPermission()),
            ChangeNotifierProvider<StaffPermissionProvider>.value(
                value: permissions),
          ],
          child: MaterialApp(home: screen),
        ));
        await _settle(tester);

        // Summary card.
        expect(find.text('Permission To Enter'), findsWidgets,
            reason: '$role Summary');
        expect(find.text('Permission'), findsNothing, reason: '$role Summary');

        // Task tab.
        final task = find.text('Task').first;
        await tester.ensureVisible(task);
        await tester.pump();
        await tester.tap(task);
        await _settle(tester);
        expect(find.text('Permission To Enter'), findsWidgets,
            reason: '$role Task tab');
        expect(find.text('Permission'), findsNothing, reason: '$role Task tab');
        expect(find.text('Yes'), findsWidgets, reason: 'value unchanged');
      }, () => _server);
      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(seconds: 5));
    } finally {
      FlutterError.onError = original;
    }
    expect(layoutErrors, isEmpty,
        reason: '$role: the label must fit at 360 wide');
  }

  testWidgets('Admin', (tester) async {
    await check(tester, admin.Workorder_summery(workorder_id: 'WO-1'), 'Admin');
  });

  testWidgets('Staff', (tester) async {
    await check(
        tester, staff.Workorder_summery(workorder_id: 'WO-1'), 'Staffmember');
  });

  testWidgets('Tenant', (tester) async {
    await check(tester, tenant.Workorder_summery(workorder_id: 'WO-1'), 'Tenant');
  });

  testWidgets('Vendor', (tester) async {
    await check(tester, vendor.Workorder_summery(workorder_id: 'WO-1'), 'Vendor');
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
